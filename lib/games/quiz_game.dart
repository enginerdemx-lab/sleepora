import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/subscription_service.dart';
import '../services/leaderboard_service.dart';
import '../services/auth_service.dart';
import '../services/ad_service.dart';
import '../services/localization_service.dart';
import '../widgets/banner_ad_widget.dart';
import '../screens/paywall_screen.dart';
import '../screens/leaderboard_screen.dart';
import '../screens/login_screen.dart';

// ─── Veri Modelleri ───
class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  const QuizQuestion({required this.question, required this.options, required this.correctIndex});
}

class QuizCategory {
  final String name;
  final IconData icon;
  final Color color;
  final List<QuizQuestion> questions;
  const QuizCategory({required this.name, required this.icon, required this.color, required this.questions});
}

// ─── Soru Bankası (400+ soru — her kategoride 50+) ───
// Sürekli oynayan kullanıcılar aynı sorularla sık karşılaşmasın diye
// kategori başına büyük havuz tutuluyor. Ayrıca _QuizPlayScreen içinde
// SharedPreferences tabanlı "yakında görülen" kaydı var → son 35-40 soru
// tekrar çıkmıyor, havuz tükenince otomatik sıfırlanıyor.
final _categories = <QuizCategory>[
  QuizCategory(
    name: 'Genel Kültür',
    icon: Icons.public_rounded,
    color: AppColors.purple,
    questions: const [
      QuizQuestion(question: 'Dünyanın en büyük okyanusu hangisidir?', options: ['Atlas', 'Hint', 'Pasifik', 'Kuzey Buz'], correctIndex: 2),
      QuizQuestion(question: 'İnsan vücudunda kaç kemik vardır?', options: ['186', '206', '226', '256'], correctIndex: 1),
      QuizQuestion(question: 'Hangi gezegen "Kızıl Gezegen" olarak bilinir?', options: ['Venüs', 'Jüpiter', 'Mars', 'Satürn'], correctIndex: 2),
      QuizQuestion(question: 'Einstein\'ın ünlü denklemi nedir?', options: ['E=mc²', 'F=ma', 'PV=nRT', 'a²+b²=c²'], correctIndex: 0),
      QuizQuestion(question: 'DNA\'nın açılımı nedir?', options: ['Deoksiribonükleik Asit', 'Dinitrojen Asit', 'Dinamik Nükleer Asit', 'Deoksinükleotid Amini'], correctIndex: 0),
      QuizQuestion(question: 'Hangi element periyodik tabloda "Au" ile gösterilir?', options: ['Gümüş', 'Altın', 'Alüminyum', 'Argon'], correctIndex: 1),
      QuizQuestion(question: 'Işık hızı yaklaşık kaç km/s\'dir?', options: ['150.000', '200.000', '300.000', '400.000'], correctIndex: 2),
      QuizQuestion(question: 'Hangi ülke nüfus bakımından dünyada birinci sıradadır?', options: ['ABD', 'Çin', 'Hindistan', 'Endonezya'], correctIndex: 2),
      QuizQuestion(question: 'Bir yılda yaklaşık kaç milyon saniye vardır?', options: ['15', '31', '52', '86'], correctIndex: 1),
      QuizQuestion(question: 'İlk matbaayı kim icat etti?', options: ['Da Vinci', 'Gutenberg', 'Newton', 'Edison'], correctIndex: 1),
      QuizQuestion(question: 'Gökkuşağında kaç renk vardır?', options: ['5', '6', '7', '8'], correctIndex: 2),
      QuizQuestion(question: 'Dünya üzerinde en çok konuşulan dil hangisidir?', options: ['İngilizce', 'İspanyolca', 'Mandarin Çincesi', 'Hintçe'], correctIndex: 2),
      QuizQuestion(question: 'Bir olimpiyat havuzu kaç metre uzunluğundadır?', options: ['25', '50', '75', '100'], correctIndex: 1),
      QuizQuestion(question: 'Hangi vitamin güneş ışığından sentezlenir?', options: ['A', 'B12', 'C', 'D'], correctIndex: 3),
      QuizQuestion(question: 'Pi sayısının ilk üç basamağı nedir?', options: ['3.12', '3.14', '3.16', '3.18'], correctIndex: 1),
      QuizQuestion(question: 'Mona Lisa\'yı kim yapmıştır?', options: ['Picasso', 'Da Vinci', 'Michelangelo', 'Rembrandt'], correctIndex: 1),
      QuizQuestion(question: 'Hangi organ vücuttaki en büyük organdır?', options: ['Karaciğer', 'Beyin', 'Deri', 'Akciğer'], correctIndex: 2),
      QuizQuestion(question: 'Bir dekatta kaç yıl vardır?', options: ['5', '10', '50', '100'], correctIndex: 1),
      QuizQuestion(question: 'Kahvenin anavatanı hangi kıtadır?', options: ['Asya', 'G. Amerika', 'Afrika', 'Avrupa'], correctIndex: 2),
      QuizQuestion(question: 'Hangi hayvan en uzun uyur?', options: ['Kedi', 'Koala', 'Aslan', 'Yarasa'], correctIndex: 1),
      // ─── Genişletilmiş havuz ───
      QuizQuestion(question: 'Dünyanın en kısa savaşı kaç dakika sürmüştür?', options: ['38', '78', '128', '178'], correctIndex: 0),
      QuizQuestion(question: 'Bir futbol sahası ortalama kaç metre uzunluğundadır?', options: ['80-90', '100-110', '120-130', '140-150'], correctIndex: 1),
      QuizQuestion(question: 'İnsan beyninin ağırlığı ortalama ne kadardır?', options: ['0.8 kg', '1.4 kg', '2.1 kg', '2.8 kg'], correctIndex: 1),
      QuizQuestion(question: 'Hangi renk en uzun dalga boyuna sahiptir?', options: ['Mavi', 'Yeşil', 'Sarı', 'Kırmızı'], correctIndex: 3),
      QuizQuestion(question: 'Bir insanda kaç tane çene dişi bulunur (toplam)?', options: ['8', '12', '20', '32'], correctIndex: 1),
      QuizQuestion(question: 'Dünyanın en derin noktası hangisidir?', options: ['Mariana Çukuru', 'Tonga Çukuru', 'Kuril Çukuru', 'Porto Riko Çukuru'], correctIndex: 0),
      QuizQuestion(question: 'Bir atomda hangi parçacık pozitif yüklüdür?', options: ['Elektron', 'Nötron', 'Proton', 'Foton'], correctIndex: 2),
      QuizQuestion(question: 'Hangi ülkenin bayrağında akçaağaç yaprağı vardır?', options: ['ABD', 'Kanada', 'Avustralya', 'Norveç'], correctIndex: 1),
      QuizQuestion(question: 'Soğuk kahve sütlü içeceğe ne denir?', options: ['Espresso', 'Americano', 'Latte', 'Cappuccino'], correctIndex: 2),
      QuizQuestion(question: 'Hangi gezegen güneşe en yakındır?', options: ['Venüs', 'Mars', 'Merkür', 'Dünya'], correctIndex: 2),
      QuizQuestion(question: 'İnsan kalbi dakikada ortalama kaç kez atar?', options: ['40-50', '60-100', '110-140', '140-180'], correctIndex: 1),
      QuizQuestion(question: 'Dünyanın en büyük anıtı hangisidir?', options: ['Mount Rushmore', 'Christ the Redeemer', 'Great Buddha', 'Statue of Unity'], correctIndex: 3),
      QuizQuestion(question: 'Hangi gaz atmosferde en çok bulunur?', options: ['Oksijen', 'Karbondioksit', 'Azot', 'Argon'], correctIndex: 2),
      QuizQuestion(question: 'Bir yıl yaklaşık kaç gündür (gregoryen)?', options: ['364.25', '365.25', '366.25', '367.25'], correctIndex: 1),
      QuizQuestion(question: 'En eski canlı tür olarak bilinen organizma hangisidir?', options: ['Bakteri', 'Siyanobakteri', 'Alg', 'Mantar'], correctIndex: 1),
      QuizQuestion(question: 'Sıfır (0) sayısını hangi uygarlık icat etti?', options: ['Yunan', 'Roma', 'Hint', 'Arap'], correctIndex: 2),
      QuizQuestion(question: 'Hangi ünlü filozof "Bilgim yalnızca bilmediğimi bilmektir" der?', options: ['Aristoteles', 'Platon', 'Sokrates', 'Kant'], correctIndex: 2),
      QuizQuestion(question: 'Bir insanın DNA\'sı yaklaşık kaç gen içerir?', options: ['5.000', '20.000', '50.000', '100.000'], correctIndex: 1),
      QuizQuestion(question: 'Dünyanın en büyük yağmur ormanı hangisidir?', options: ['Kongo', 'Amazon', 'Borneo', 'Daintree'], correctIndex: 1),
      QuizQuestion(question: 'Hangi malzeme eskiden para olarak kullanılırdı?', options: ['Kabuk', 'Tuz', 'Çay', 'Hepsi'], correctIndex: 3),
      QuizQuestion(question: 'Bir yetişkinin vücudu yaklaşık yüzde kaç sudur?', options: ['%40', '%50', '%60', '%80'], correctIndex: 2),
      QuizQuestion(question: 'Hangi organ kan pompalamaz?', options: ['Kalp', 'Akciğer', 'Damar', 'Arter'], correctIndex: 1),
      QuizQuestion(question: 'Dünyanın ekseni kaç derece eğiktir?', options: ['15.5', '23.5', '45.0', '90.0'], correctIndex: 1),
      QuizQuestion(question: 'Güneş hangi galakside yer alır?', options: ['Andromeda', 'Samanyolu', 'Girdap', 'Üçgen'], correctIndex: 1),
      QuizQuestion(question: 'İlk Nobel ödülleri hangi yıl verildi?', options: ['1895', '1901', '1912', '1920'], correctIndex: 1),
      QuizQuestion(question: 'Türk lirasının sembolü nedir?', options: ['₺', '€', '\$', '¥'], correctIndex: 0),
      QuizQuestion(question: 'Hangi meyve "kral meyve" olarak bilinir?', options: ['Muz', 'Durian', 'Mango', 'Ananas'], correctIndex: 1),
      QuizQuestion(question: 'Bir saatin dakikası kaç saniyedir?', options: ['30', '60', '90', '120'], correctIndex: 1),
      QuizQuestion(question: 'Güneş sisteminin en büyük gezegeni hangisidir?', options: ['Satürn', 'Jüpiter', 'Neptün', 'Uranüs'], correctIndex: 1),
      QuizQuestion(question: 'Hangi kutup daha soğuktur?', options: ['Kuzey', 'Güney', 'Eşit', 'Değişken'], correctIndex: 1),
      QuizQuestion(question: 'Yerçekimi en fazla olan gezegen hangisidir?', options: ['Dünya', 'Mars', 'Jüpiter', 'Neptün'], correctIndex: 2),
      QuizQuestion(question: 'Bir insanın normal vücut sıcaklığı kaçtır?', options: ['35.5°C', '36.5°C', '37.5°C', '38.5°C'], correctIndex: 1),
      QuizQuestion(question: 'En büyük iç deniz hangisidir?', options: ['Akdeniz', 'Baltık', 'Karadeniz', 'Kızıldeniz'], correctIndex: 0),
      QuizQuestion(question: 'Hangi element kalsiyum simgesi olarak kullanılır?', options: ['C', 'Cl', 'Ca', 'Cs'], correctIndex: 2),
      QuizQuestion(question: 'Uçak kara kutusu aslında hangi renktedir?', options: ['Siyah', 'Beyaz', 'Turuncu', 'Kırmızı'], correctIndex: 2),
    ],
  ),
  QuizCategory(
    name: 'Spor',
    icon: Icons.sports_soccer_rounded,
    color: const Color(0xFF10B981),
    questions: const [
      QuizQuestion(question: 'FIFA Dünya Kupası kaç yılda bir düzenlenir?', options: ['2', '3', '4', '5'], correctIndex: 2),
      QuizQuestion(question: 'Olimpiyat halkaları kaç tanedir?', options: ['4', '5', '6', '7'], correctIndex: 1),
      QuizQuestion(question: 'Bir futbol maçı kaç dakikadır?', options: ['80', '90', '100', '120'], correctIndex: 1),
      QuizQuestion(question: 'NBA\'de bir takımda sahada kaç oyuncu bulunur?', options: ['4', '5', '6', '7'], correctIndex: 1),
      QuizQuestion(question: 'Hangi ülke 2022 FIFA Dünya Kupası\'na ev sahipliği yaptı?', options: ['Rusya', 'Katar', 'BAE', 'S. Arabistan'], correctIndex: 1),
      QuizQuestion(question: 'Teniste "Grand Slam" kaç turnuvadan oluşur?', options: ['3', '4', '5', '6'], correctIndex: 1),
      QuizQuestion(question: 'Usain Bolt\'un 100m dünya rekoru kaç saniyedir?', options: ['9.38', '9.58', '9.78', '9.98'], correctIndex: 1),
      QuizQuestion(question: 'Hangi spor dalında "ace" terimi kullanılır?', options: ['Futbol', 'Tenis', 'Basketbol', 'Yüzme'], correctIndex: 1),
      QuizQuestion(question: 'Bir maratonda kaç km koşulur?', options: ['36.195', '40.195', '42.195', '44.195'], correctIndex: 2),
      QuizQuestion(question: 'Cristiano Ronaldo hangi ülkedendir?', options: ['Brezilya', 'İspanya', 'Portekiz', 'Arjantin'], correctIndex: 2),
      QuizQuestion(question: 'Voleybolda bir takım sahada kaç kişidir?', options: ['5', '6', '7', '8'], correctIndex: 1),
      QuizQuestion(question: 'Hangi ülke en çok Dünya Kupası kazanmıştır?', options: ['Almanya', 'Arjantin', 'Brezilya', 'İtalya'], correctIndex: 2),
      QuizQuestion(question: 'Bir boks raundı kaç dakikadır?', options: ['2', '3', '4', '5'], correctIndex: 1),
      QuizQuestion(question: 'Golf\'te "birdie" ne demektir?', options: ['Par üstü 1', 'Par altı 1', 'Par altı 2', 'Eşit par'], correctIndex: 1),
      QuizQuestion(question: 'Formula 1\'de yarışlar kaç tur sürer (ortalama)?', options: ['30-40', '50-70', '80-100', '100-120'], correctIndex: 1),
      QuizQuestion(question: 'Hangi spor dalında "hat-trick" terimi kullanılır?', options: ['Basketbol', 'Tenis', 'Futbol', 'Yüzme'], correctIndex: 2),
      QuizQuestion(question: 'Wimbledon hangi spor dalında düzenlenir?', options: ['Golf', 'Tenis', 'Kriket', 'Atletizm'], correctIndex: 1),
      QuizQuestion(question: 'Michael Jordan hangi spor dalında ünlüdür?', options: ['Futbol', 'Beyzbol', 'Basketbol', 'Amerikan Futbolu'], correctIndex: 2),
      QuizQuestion(question: 'Bir rugby takımında kaç oyuncu sahada bulunur?', options: ['11', '13', '15', '17'], correctIndex: 2),
      QuizQuestion(question: 'Hangi ülke sumo güreşiyle bilinir?', options: ['Çin', 'Kore', 'Japonya', 'Moğolistan'], correctIndex: 2),
      // ─── Genişletilmiş havuz ───
      QuizQuestion(question: '2022 FIFA Dünya Kupası\'nı hangi takım kazandı?', options: ['Fransa', 'Arjantin', 'Brezilya', 'Almanya'], correctIndex: 1),
      QuizQuestion(question: '2022 Dünya Kupası finalinde Arjantin hangi ülkeyi yendi?', options: ['Brezilya', 'Fransa', 'Almanya', 'İngiltere'], correctIndex: 1),
      QuizQuestion(question: '2024 Yaz Olimpiyatları hangi şehirde düzenlendi?', options: ['Tokyo', 'Paris', 'Los Angeles', 'Madrid'], correctIndex: 1),
      QuizQuestion(question: '2024 Euro\'yu (UEFA EURO 2024) hangi ülke kazandı?', options: ['İngiltere', 'İspanya', 'Fransa', 'Almanya'], correctIndex: 1),
      QuizQuestion(question: '2024 Euro hangi ülkede düzenlendi?', options: ['İngiltere', 'Almanya', 'Fransa', 'İtalya'], correctIndex: 1),
      QuizQuestion(question: 'Lionel Messi kaç Ballon d\'Or ödülü kazandı?', options: ['6', '7', '8', '9'], correctIndex: 2),
      QuizQuestion(question: 'Galatasaray kaç kez Türkiye Şampiyonu olmuştur (2024 itibarıyla)?', options: ['20\'den az', '21-23', '24-25', '25\'ten fazla'], correctIndex: 3),
      QuizQuestion(question: 'Hangi ünlü basketbolcu "King James" lakaplıdır?', options: ['LeBron James', 'Kevin Durant', 'Stephen Curry', 'James Harden'], correctIndex: 0),
      QuizQuestion(question: 'Pickleball hangi iki sporun karışımıdır?', options: ['Tenis-Badminton', 'Voleybol-Basket', 'Kriket-Beyzbol', 'Hokey-Lakros'], correctIndex: 0),
      QuizQuestion(question: 'Hangi ülke 2024 Paris Olimpiyatları\'nda en çok madalyayı aldı?', options: ['Çin', 'ABD', 'Japonya', 'Fransa'], correctIndex: 1),
      QuizQuestion(question: 'Türkiye\'nin ilk NBA oyuncusu kimdir?', options: ['Hedo Türkoğlu', 'Mehmet Okur', 'İbrahim Kutluay', 'Ersan İlyasova'], correctIndex: 0),
      QuizQuestion(question: 'Bir curling maçında her takımdan kaç oyuncu bulunur?', options: ['3', '4', '5', '6'], correctIndex: 1),
      QuizQuestion(question: 'Hangi sporcu "Dağ" lakabı ile anılır (mini-zanaat)?', options: ['Hafþór Björnsson', 'Eddie Hall', 'Brian Shaw', 'Mariusz Pudzianowski'], correctIndex: 0),
      QuizQuestion(question: 'Bir basketbol çember yerden kaç cm yüksekliktedir?', options: ['280', '305', '325', '345'], correctIndex: 1),
      QuizQuestion(question: 'Hangi ülke en çok olimpiyat altın madalyası kazanmıştır (tarihsel)?', options: ['SSCB/Rusya', 'ABD', 'Çin', 'Almanya'], correctIndex: 1),
      QuizQuestion(question: 'NBA tarihinde en çok üçlük atan oyuncu kimdir?', options: ['Ray Allen', 'Reggie Miller', 'Stephen Curry', 'Klay Thompson'], correctIndex: 2),
      QuizQuestion(question: '"The GOAT" lakabı en çok hangi sporcuya atfedilir?', options: ['Ronaldo', 'Messi', 'Jordan', 'Değişir'], correctIndex: 3),
      QuizQuestion(question: 'Fenerbahçe kaç kez UEFA Avrupa Ligi (UEFA Kupası) finaline çıkmıştır?', options: ['0', '1', '2', '3'], correctIndex: 0),
      QuizQuestion(question: 'Kerem Aktürkoğlu 2024 Euro\'da hangi takımla oynadı?', options: ['Galatasaray', 'Benfica', 'Beşiktaş', 'Başakşehir'], correctIndex: 0),
      QuizQuestion(question: 'Lewis Hamilton 2024 sezonu sonunda hangi takıma transfer oldu?', options: ['Red Bull', 'Ferrari', 'Mercedes', 'McLaren'], correctIndex: 1),
      QuizQuestion(question: 'Max Verstappen kaç kez F1 Dünya Şampiyonu oldu (2024 sonu)?', options: ['2', '3', '4', '5'], correctIndex: 2),
      QuizQuestion(question: 'Simone Biles hangi spor dalında efsanedir?', options: ['Yüzme', 'Atletizm', 'Cimnastik', 'Tenis'], correctIndex: 2),
      QuizQuestion(question: 'Rugby\'de bir try kaç puandır?', options: ['3', '4', '5', '7'], correctIndex: 2),
      QuizQuestion(question: 'Hangi spor "kardeş spor" olarak da bilinir (çift kişilik)?', options: ['Paten', 'Artistik Paten', 'Buz Dansı', 'Senkronize Yüzme'], correctIndex: 1),
      QuizQuestion(question: 'Bir NFL oyunu kaç çeyrekten oluşur?', options: ['2', '3', '4', '5'], correctIndex: 2),
      QuizQuestion(question: 'Arda Güler hangi kulüpte oynamaktadır (2024)?', options: ['Juventus', 'Real Madrid', 'Barcelona', 'Manchester City'], correctIndex: 1),
      QuizQuestion(question: 'Kenan Yıldız hangi kulüpte oynar?', options: ['Milan', 'Juventus', 'Napoli', 'Roma'], correctIndex: 1),
      QuizQuestion(question: 'Copa America 2024\'ü hangi ülke kazandı?', options: ['Brezilya', 'Kolombiya', 'Arjantin', 'Uruguay'], correctIndex: 2),
      QuizQuestion(question: 'Hangi kupa dünyanın en eski futbol kupasıdır?', options: ['FA Cup', 'Dünya Kupası', 'Champions League', 'Copa América'], correctIndex: 0),
      QuizQuestion(question: 'Bir voleybol maçında set kaç sayı üzerinden oynanır (son set hariç)?', options: ['15', '21', '25', '30'], correctIndex: 2),
      QuizQuestion(question: 'Türkiye\'nin 2003\'te Dünya Şampiyonu olduğu spor hangisidir?', options: ['Güreş', 'Basketbol', 'Halter', 'Atletizm'], correctIndex: 2),
      QuizQuestion(question: 'Pepe, hangi futbolcu 41 yaşında Euro 2024\'te oynadı?', options: ['Doğru', 'Hayır 38\'di', 'Hayır 43\'tü', 'Hayır 45\'ti'], correctIndex: 0),
    ],
  ),
  QuizCategory(
    name: 'Tarih',
    icon: Icons.history_edu_rounded,
    color: const Color(0xFFF59E0B),
    questions: const [
      QuizQuestion(question: 'İstanbul\'un fethi hangi yılda gerçekleşti?', options: ['1453', '1461', '1071', '1299'], correctIndex: 0),
      QuizQuestion(question: 'Türkiye Cumhuriyeti ne zaman ilan edildi?', options: ['1920', '1921', '1922', '1923'], correctIndex: 3),
      QuizQuestion(question: 'İlk Çağ hangi olayla sona erdi?', options: ['Roma\'nın yıkılışı', 'İstanbul\'un fethi', 'Hicret', 'Kavimler göçü'], correctIndex: 0),
      QuizQuestion(question: 'Saraybosna suikasti hangi savaşı başlattı?', options: ['II. Dünya Savaşı', 'I. Dünya Savaşı', 'Kore Savaşı', 'Kırım Savaşı'], correctIndex: 1),
      QuizQuestion(question: 'Büyük İskender hangi ülkedendir?', options: ['Roma', 'Mısır', 'Makedonya', 'Pers'], correctIndex: 2),
      QuizQuestion(question: 'Ay\'a ilk ayak basan astronot kimdir?', options: ['Buzz Aldrin', 'Neil Armstrong', 'Yuri Gagarin', 'John Glenn'], correctIndex: 1),
      QuizQuestion(question: 'Berlin Duvarı hangi yıl yıkıldı?', options: ['1987', '1988', '1989', '1990'], correctIndex: 2),
      QuizQuestion(question: 'Osmanlı Devleti hangi yılda kuruldu?', options: ['1071', '1243', '1299', '1326'], correctIndex: 2),
      QuizQuestion(question: 'Çanakkale Savaşı hangi yılda yapıldı?', options: ['1914', '1915', '1916', '1917'], correctIndex: 1),
      QuizQuestion(question: 'Sanayi Devrimi hangi ülkede başladı?', options: ['Fransa', 'Almanya', 'İngiltere', 'ABD'], correctIndex: 2),
      QuizQuestion(question: 'Fatih Sultan Mehmet kaçıncı padişahtır?', options: ['5.', '6.', '7.', '8.'], correctIndex: 2),
      QuizQuestion(question: 'Fransız Devrimi hangi yılda başladı?', options: ['1776', '1789', '1804', '1815'], correctIndex: 1),
      QuizQuestion(question: 'Titanic hangi yılda battı?', options: ['1910', '1912', '1914', '1916'], correctIndex: 1),
      QuizQuestion(question: 'Soğuk Savaş hangi iki süper güç arasındaydı?', options: ['ABD - Çin', 'ABD - SSCB', 'İngiltere - Fransa', 'Almanya - Rusya'], correctIndex: 1),
      QuizQuestion(question: 'İlk yazıyı hangi uygarlık bulmuştur?', options: ['Mısır', 'Sümer', 'Çin', 'Hint'], correctIndex: 1),
      QuizQuestion(question: 'Atatürk hangi yılda doğdu?', options: ['1879', '1881', '1883', '1885'], correctIndex: 1),
      QuizQuestion(question: 'Magna Carta hangi yılda imzalandı?', options: ['1215', '1315', '1415', '1515'], correctIndex: 0),
      QuizQuestion(question: 'Amerika kıtasını hangi kaşif keşfetti?', options: ['Macellan', 'Kolomb', 'Vasco da Gama', 'Amerigo Vespucci'], correctIndex: 1),
      QuizQuestion(question: 'II. Dünya Savaşı hangi yılda bitti?', options: ['1943', '1944', '1945', '1946'], correctIndex: 2),
      QuizQuestion(question: 'Kurtuluş Savaşı\'nın son muharebesi hangisidir?', options: ['Sakarya', 'İnönü', 'Büyük Taarruz', 'Dumlupınar'], correctIndex: 3),
      // ─── Genişletilmiş havuz ───
      QuizQuestion(question: 'Malazgirt Meydan Muharebesi hangi yılda yapıldı?', options: ['1071', '1081', '1091', '1101'], correctIndex: 0),
      QuizQuestion(question: 'Cumhuriyet\'in ilk cumhurbaşkanı kimdir?', options: ['İsmet İnönü', 'Mustafa Kemal Atatürk', 'Celal Bayar', 'Cemal Gürsel'], correctIndex: 1),
      QuizQuestion(question: 'Hangi yıl Türkiye\'de çok partili sisteme geçildi?', options: ['1945-46', '1950', '1961', '1973'], correctIndex: 0),
      QuizQuestion(question: 'Kanuni Sultan Süleyman kaç yıl tahtta kaldı?', options: ['36', '42', '46', '52'], correctIndex: 2),
      QuizQuestion(question: 'Napolyon Bonapart hangi adada sürgünde öldü?', options: ['Korsika', 'Elba', 'Aziz Helena', 'Malta'], correctIndex: 2),
      QuizQuestion(question: 'İkinci Dünya Savaşı\'nda D-Day hangi yıl gerçekleşti?', options: ['1942', '1943', '1944', '1945'], correctIndex: 2),
      QuizQuestion(question: 'Hiroşima\'ya atom bombası hangi yıl atıldı?', options: ['1944', '1945', '1946', '1947'], correctIndex: 1),
      QuizQuestion(question: 'Bizans İmparatorluğu kaç yıl sürdü (yaklaşık)?', options: ['500', '800', '1100', '1450'], correctIndex: 2),
      QuizQuestion(question: 'Kim ünlü "Geldim, gördüm, yendim" sözünü söyledi?', options: ['İskender', 'Sezar', 'Napolyon', 'Caesar Augustus'], correctIndex: 1),
      QuizQuestion(question: 'Çanakkale Geçilmez sözü kimin?', options: ['Mustafa Kemal', 'Enver Paşa', 'Cemal Paşa', 'Talat Paşa'], correctIndex: 0),
      QuizQuestion(question: 'Hangi padişah "Muhteşem" lakabıyla tanınır?', options: ['II. Mehmet', 'I. Süleyman', 'I. Selim', 'II. Mahmud'], correctIndex: 1),
      QuizQuestion(question: 'Tarihteki ilk demokrasinin doğduğu şehir hangisidir?', options: ['Roma', 'Atina', 'Sparta', 'Kartaca'], correctIndex: 1),
      QuizQuestion(question: 'Piramitler hangi uygarlık tarafından yapılmıştır?', options: ['Sümer', 'Mısır', 'Asur', 'Babil'], correctIndex: 1),
      QuizQuestion(question: 'Büyük Taarruz hangi yıl gerçekleşti?', options: ['1920', '1921', '1922', '1923'], correctIndex: 2),
      QuizQuestion(question: 'Latin alfabesine Türkiye\'de hangi yılda geçildi?', options: ['1923', '1925', '1928', '1934'], correctIndex: 2),
      QuizQuestion(question: 'Kadınlara seçme ve seçilme hakkı Türkiye\'de hangi yılda verildi?', options: ['1930', '1934', '1938', '1945'], correctIndex: 1),
      QuizQuestion(question: 'Osmanlı Devleti resmi olarak hangi yılda sona erdi?', options: ['1918', '1920', '1922', '1923'], correctIndex: 2),
      QuizQuestion(question: 'Kore Savaşı kaç yıl sürdü?', options: ['2', '3', '5', '7'], correctIndex: 1),
      QuizQuestion(question: 'İpek Yolu hangi iki kıtayı birleştiriyordu?', options: ['Avrupa-Asya', 'Afrika-Asya', 'Avrupa-Afrika', 'Asya-Amerika'], correctIndex: 0),
      QuizQuestion(question: 'Haçlı Seferleri kaç yüzyıl sürdü?', options: ['1', '2', '3', '4'], correctIndex: 1),
      QuizQuestion(question: 'Rönesans hangi ülkede başladı?', options: ['Fransa', 'İtalya', 'İspanya', 'Almanya'], correctIndex: 1),
      QuizQuestion(question: 'Sputnik uydusu hangi ülke tarafından fırlatıldı?', options: ['ABD', 'Almanya', 'SSCB', 'Çin'], correctIndex: 2),
      QuizQuestion(question: 'Hangi Kral "Güneş Kral" olarak bilinir?', options: ['XIV. Louis', 'I. James', 'VIII. Henry', 'II. Philip'], correctIndex: 0),
      QuizQuestion(question: 'Mısır\'ın son firavunu olarak bilinen kadın kimdir?', options: ['Nefertiti', 'Hatshepsut', 'Cleopatra', 'Nefertari'], correctIndex: 2),
      QuizQuestion(question: 'Türkiye NATO\'ya hangi yıl katıldı?', options: ['1949', '1952', '1955', '1960'], correctIndex: 1),
      QuizQuestion(question: 'Vietnam Savaşı kaç yılda sona erdi?', options: ['1973', '1975', '1977', '1979'], correctIndex: 1),
      QuizQuestion(question: 'Kızıl Meydan hangi şehirdedir?', options: ['Leningrad', 'St. Petersburg', 'Moskova', 'Kiev'], correctIndex: 2),
      QuizQuestion(question: 'Atatürk\'ün doğduğu şehir hangisidir?', options: ['İstanbul', 'Selanik', 'Manastır', 'Sofya'], correctIndex: 1),
      QuizQuestion(question: 'İlk televizyon yayını hangi yıl yapıldı?', options: ['1920', '1927', '1936', '1940'], correctIndex: 1),
      QuizQuestion(question: 'Truva Atı hikayesi hangi destan eserinde anlatılır?', options: ['İlyada', 'Odise', 'Eneid', 'Gılgamış'], correctIndex: 0),
      QuizQuestion(question: 'Çernobil felaketi hangi yıl yaşandı?', options: ['1984', '1986', '1988', '1990'], correctIndex: 1),
      QuizQuestion(question: 'Mao Zedong hangi ülkenin liderliğini yaptı?', options: ['Rusya', 'Kuzey Kore', 'Çin', 'Vietnam'], correctIndex: 2),
    ],
  ),
  QuizCategory(
    name: 'Coğrafya',
    icon: Icons.map_rounded,
    color: const Color(0xFFEF4444),
    questions: const [
      QuizQuestion(question: 'Dünyanın en uzun nehri hangisidir?', options: ['Amazon', 'Nil', 'Mississippi', 'Yangtze'], correctIndex: 1),
      QuizQuestion(question: 'Türkiye\'nin en yüksek dağı hangisidir?', options: ['Uludağ', 'Erciyes', 'Ağrı', 'Süphan'], correctIndex: 2),
      QuizQuestion(question: 'Hangi kıta en küçüktür?', options: ['Avrupa', 'Antarktika', 'Avustralya', 'G. Amerika'], correctIndex: 2),
      QuizQuestion(question: 'Japonya\'nın başkenti neresidir?', options: ['Osaka', 'Kyoto', 'Tokyo', 'Nagoya'], correctIndex: 2),
      QuizQuestion(question: 'Dünyada kaç kıta vardır?', options: ['5', '6', '7', '8'], correctIndex: 2),
      QuizQuestion(question: 'Sahara Çölü hangi kıtadadır?', options: ['Asya', 'Afrika', 'Avustralya', 'G. Amerika'], correctIndex: 1),
      QuizQuestion(question: 'Hangi ülke hem Avrupa hem Asya\'da yer alır?', options: ['Türkiye', 'Yunanistan', 'Mısır', 'İran'], correctIndex: 0),
      QuizQuestion(question: 'Everest Dağı hangi ülkededir?', options: ['Çin', 'Hindistan', 'Nepal', 'Pakistan'], correctIndex: 2),
      QuizQuestion(question: 'Akdeniz\'in en büyük adası hangisidir?', options: ['Kıbrıs', 'Girit', 'Sicilya', 'Sardunya'], correctIndex: 2),
      QuizQuestion(question: 'Amazon Ormanları hangi kıtadadır?', options: ['Afrika', 'Asya', 'G. Amerika', 'K. Amerika'], correctIndex: 2),
      QuizQuestion(question: 'Dünyanın en büyük gölü hangisidir?', options: ['Baykal', 'Victoria', 'Hazar', 'Superior'], correctIndex: 2),
      QuizQuestion(question: 'İstanbul Boğazı hangi denizleri birleştirir?', options: ['Ege-Akdeniz', 'Karadeniz-Marmara', 'Marmara-Ege', 'Karadeniz-Akdeniz'], correctIndex: 1),
      QuizQuestion(question: 'Hangi ülkenin bayrağında ay ve yıldız vardır?', options: ['Mısır', 'Türkiye', 'İran', 'Irak'], correctIndex: 1),
      QuizQuestion(question: 'Dünyanın en kalabalık şehri hangisidir?', options: ['Pekin', 'New York', 'Tokyo', 'İstanbul'], correctIndex: 2),
      QuizQuestion(question: 'Karadeniz\'e kıyısı olmayan il hangisidir?', options: ['Trabzon', 'Rize', 'Erzurum', 'Artvin'], correctIndex: 2),
      QuizQuestion(question: 'Avustralya\'nın başkenti neresidir?', options: ['Sydney', 'Melbourne', 'Canberra', 'Brisbane'], correctIndex: 2),
      QuizQuestion(question: 'Hangi nehir Mısır\'dan geçer?', options: ['Amazon', 'Fırat', 'Nil', 'Tuna'], correctIndex: 2),
      QuizQuestion(question: 'Türkiye\'nin en büyük gölü hangisidir?', options: ['Tuz Gölü', 'Van Gölü', 'Beyşehir', 'Burdur'], correctIndex: 1),
      QuizQuestion(question: 'Kanada\'nın resmi dilleri hangileridir?', options: ['İngilizce-İspanyolca', 'İngilizce-Fransızca', 'Fransızca-Almanca', 'İngilizce-Portekizce'], correctIndex: 1),
      QuizQuestion(question: 'Dünyanın en kurak çölü hangisidir?', options: ['Sahara', 'Gobi', 'Atacama', 'Kalahari'], correctIndex: 2),
      // ─── Genişletilmiş havuz ───
      QuizQuestion(question: 'Kuzey yarımkürede güneşi görmek için hangi yönde bir çatı idealdir?', options: ['Kuzey', 'Güney', 'Doğu', 'Batı'], correctIndex: 1),
      QuizQuestion(question: 'Büyük Okyanus\'un en derin noktası olan çukur hangisidir?', options: ['Porto Riko', 'Mariana', 'Java', 'Sunda'], correctIndex: 1),
      QuizQuestion(question: 'Türkiye\'nin yüzölçümü yaklaşık kaç km²\'dir?', options: ['500.000', '650.000', '780.000', '900.000'], correctIndex: 2),
      QuizQuestion(question: 'Afrika\'nın en yüksek dağı hangisidir?', options: ['Kenya', 'Kilimanjaro', 'Ruwenzori', 'Meru'], correctIndex: 1),
      QuizQuestion(question: 'Hangi ülke dünyanın en uzun kara sınırına sahiptir (Kanada hariç)?', options: ['Rusya', 'ABD', 'Çin', 'Brezilya'], correctIndex: 2),
      QuizQuestion(question: 'Türkiye\'nin nüfusu yaklaşık kaç milyondur (2024)?', options: ['75', '80', '85', '90'], correctIndex: 2),
      QuizQuestion(question: 'Hangi şehir "Pembe Şehir" olarak anılır?', options: ['Petra', 'Jaipur', 'Marrakeş', 'Toulouse'], correctIndex: 1),
      QuizQuestion(question: 'Dünyanın en küçük ülkesi hangisidir?', options: ['Monako', 'San Marino', 'Vatikan', 'Tuvalu'], correctIndex: 2),
      QuizQuestion(question: 'Boğaziçi Köprüsü\'nün bugünkü adı nedir?', options: ['Yavuz Sultan Selim', '15 Temmuz Şehitler', 'Fatih Sultan Mehmet', 'Osmangazi'], correctIndex: 1),
      QuizQuestion(question: 'Türkiye\'nin en doğusundaki il hangisidir?', options: ['Iğdır', 'Van', 'Hakkari', 'Ağrı'], correctIndex: 0),
      QuizQuestion(question: 'Dünyanın en uzun kıyı şeridi hangi ülkeye aittir?', options: ['Rusya', 'Kanada', 'Endonezya', 'Avustralya'], correctIndex: 1),
      QuizQuestion(question: 'Victoria Şelaleleri hangi iki ülke arasındadır?', options: ['Güney Afrika-Botsvana', 'Zimbabve-Zambiya', 'Kenya-Tanzanya', 'Uganda-Ruanda'], correctIndex: 1),
      QuizQuestion(question: 'Hangi nehir Tuna\'dan sonra Avrupa\'nın 2. uzun nehridir?', options: ['Volga', 'Ren', 'Seine', 'Po'], correctIndex: 0),
      QuizQuestion(question: 'Ege Denizi kaç ülke arasındadır (kıyıdaş)?', options: ['2', '3', '4', '5'], correctIndex: 0),
      QuizQuestion(question: 'Tayland\'ın başkenti neresidir?', options: ['Hanoi', 'Bangkok', 'Manila', 'Jakarta'], correctIndex: 1),
      QuizQuestion(question: 'Hangi şehir "Kuzey Venedik"i olarak bilinir?', options: ['Stockholm', 'Brugge', 'Amsterdam', 'St. Petersburg'], correctIndex: 2),
      QuizQuestion(question: 'Mısır\'ın başkenti neresidir?', options: ['İskenderiye', 'Kahire', 'Luksor', 'Giza'], correctIndex: 1),
      QuizQuestion(question: 'Karadeniz\'e kıyısı olan ülke sayısı kaçtır?', options: ['4', '5', '6', '7'], correctIndex: 2),
      QuizQuestion(question: 'Grönland siyasi olarak hangi ülkeye bağlıdır?', options: ['Kanada', 'İzlanda', 'Danimarka', 'Norveç'], correctIndex: 2),
      QuizQuestion(question: 'Andlar dağ silsilesi hangi kıtadadır?', options: ['K. Amerika', 'G. Amerika', 'Asya', 'Afrika'], correctIndex: 1),
      QuizQuestion(question: 'Türkiye\'nin en yüksek rakımlı ili hangisidir?', options: ['Erzurum', 'Kars', 'Hakkari', 'Van'], correctIndex: 2),
      QuizQuestion(question: 'Dünyanın en büyük yarımadası hangisidir?', options: ['Hindistan', 'Arap', 'İskandinavya', 'Alaska'], correctIndex: 1),
      QuizQuestion(question: 'Hangi ülke "Binlerce Göller Ülkesi" olarak bilinir?', options: ['Kanada', 'İsveç', 'Finlandiya', 'Norveç'], correctIndex: 2),
      QuizQuestion(question: 'Türkiye\'nin kaç komşusu vardır?', options: ['6', '7', '8', '9'], correctIndex: 2),
      QuizQuestion(question: 'Kapadokya hangi ilin sınırları içindedir?', options: ['Kayseri', 'Nevşehir', 'Aksaray', 'Niğde'], correctIndex: 1),
      QuizQuestion(question: 'Dünyanın en büyük takımada ülkesi hangisidir?', options: ['Filipinler', 'Japonya', 'Endonezya', 'Madagaskar'], correctIndex: 2),
      QuizQuestion(question: 'Ege\'nin en büyük Yunan adası hangisidir?', options: ['Rodos', 'Girit', 'Korfu', 'Midilli'], correctIndex: 1),
      QuizQuestion(question: 'Hangi körfez Suudi Arabistan ve İran arasındadır?', options: ['Umman', 'Kızıldeniz', 'Basra', 'Aden'], correctIndex: 2),
      QuizQuestion(question: 'Türkiye\'nin en büyük barajı hangisidir?', options: ['Keban', 'Atatürk', 'Karakaya', 'Altınkaya'], correctIndex: 1),
      QuizQuestion(question: 'Dünya coğrafi merkezi olarak kabul edilen şehir hangisidir?', options: ['Londra', 'Paris', 'Greenwich', 'Roma'], correctIndex: 2),
      QuizQuestion(question: 'Stonehenge hangi ülkededir?', options: ['İrlanda', 'İskoçya', 'İngiltere', 'Galler'], correctIndex: 2),
      QuizQuestion(question: 'Rio de Janeiro hangi ülkededir?', options: ['Arjantin', 'Brezilya', 'Şili', 'Peru'], correctIndex: 1),
    ],
  ),
  QuizCategory(
    name: 'Bilim & Teknoloji',
    icon: Icons.science_rounded,
    color: const Color(0xFF8B5CF6),
    questions: const [
      QuizQuestion(question: 'İnternetin atası sayılan ağ hangisidir?', options: ['Ethernet', 'ARPANET', 'WiFi', 'Bluetooth'], correctIndex: 1),
      QuizQuestion(question: 'Apple\'ın kurucusu kimdir?', options: ['Bill Gates', 'Steve Jobs', 'Elon Musk', 'Jeff Bezos'], correctIndex: 1),
      QuizQuestion(question: 'Bir byte kaç bitten oluşur?', options: ['4', '8', '16', '32'], correctIndex: 1),
      QuizQuestion(question: 'Hangi programlama dili Google tarafından geliştirildi?', options: ['Swift', 'Kotlin', 'Go', 'Rust'], correctIndex: 2),
      QuizQuestion(question: 'İlk bilgisayar programcısı kim kabul edilir?', options: ['Alan Turing', 'Ada Lovelace', 'Grace Hopper', 'Charles Babbage'], correctIndex: 1),
      QuizQuestion(question: 'HTTP\'nin açılımı nedir?', options: ['HyperText Transfer Protocol', 'High Tech Transfer Protocol', 'Hyper Transfer Text Protocol', 'High Text Transfer Program'], correctIndex: 0),
      QuizQuestion(question: 'Hangisi bir işletim sistemi değildir?', options: ['Linux', 'Windows', 'Oracle', 'macOS'], correctIndex: 2),
      QuizQuestion(question: 'İlk akıllı telefon hangisidir?', options: ['iPhone', 'BlackBerry', 'IBM Simon', 'Nokia 9000'], correctIndex: 2),
      QuizQuestion(question: 'Yapay zeka terimi ilk kez ne zaman kullanıldı?', options: ['1936', '1956', '1976', '1996'], correctIndex: 1),
      QuizQuestion(question: 'Tesla\'nın CEO\'su kimdir?', options: ['Jeff Bezos', 'Tim Cook', 'Elon Musk', 'Sundar Pichai'], correctIndex: 2),
      QuizQuestion(question: 'WWW\'yi kim icat etti?', options: ['Bill Gates', 'Tim Berners-Lee', 'Steve Wozniak', 'Linus Torvalds'], correctIndex: 1),
      QuizQuestion(question: 'Hangi element suyun formülündedir?', options: ['Helyum', 'Karbon', 'Hidrojen', 'Azot'], correctIndex: 2),
      QuizQuestion(question: 'Yerçekimini kim keşfetti?', options: ['Einstein', 'Newton', 'Galileo', 'Kepler'], correctIndex: 1),
      QuizQuestion(question: 'Bir kilobayt kaç bayttır?', options: ['100', '512', '1000', '1024'], correctIndex: 3),
      QuizQuestion(question: 'Mars\'a gönderilen rover\'ın adı nedir?', options: ['Spirit', 'Curiosity', 'Perseverance', 'Opportunity'], correctIndex: 2),
      QuizQuestion(question: 'Bluetooth teknolojisi adını nereden alır?', options: ['Bir bilim insanı', 'Viking kralı', 'Bir şirket', 'Bir renk'], correctIndex: 1),
      QuizQuestion(question: 'Fotosentez sırasında hangi gaz açığa çıkar?', options: ['Karbondioksit', 'Azot', 'Oksijen', 'Hidrojen'], correctIndex: 2),
      QuizQuestion(question: 'İnsan genomu projesi ne zaman tamamlandı?', options: ['1993', '1998', '2003', '2008'], correctIndex: 2),
      QuizQuestion(question: 'Hangisi bir arama motoru değildir?', options: ['Bing', 'Yahoo', 'Firefox', 'DuckDuckGo'], correctIndex: 2),
      QuizQuestion(question: 'Elektrik ampulünü kim icat etti?', options: ['Tesla', 'Edison', 'Bell', 'Faraday'], correctIndex: 1),
      // ─── Genişletilmiş havuz (güncel teknoloji + AI dahil) ───
      QuizQuestion(question: 'ChatGPT\'yi geliştiren şirket hangisidir?', options: ['Google', 'Meta', 'OpenAI', 'Microsoft'], correctIndex: 2),
      QuizQuestion(question: 'Anthropic\'in geliştirdiği yapay zeka asistanının adı nedir?', options: ['Gemini', 'Claude', 'Llama', 'Mistral'], correctIndex: 1),
      QuizQuestion(question: 'Google\'ın yapay zeka asistanı hangisidir?', options: ['Bard/Gemini', 'Copilot', 'Cortana', 'Alexa'], correctIndex: 0),
      QuizQuestion(question: 'Meta\'nın açık kaynaklı dil modeli hangisidir?', options: ['Llama', 'PaLM', 'Claude', 'Mistral'], correctIndex: 0),
      QuizQuestion(question: 'Apple Vision Pro hangi yıl piyasaya çıktı?', options: ['2022', '2023', '2024', '2025'], correctIndex: 2),
      QuizQuestion(question: 'iPhone 15 hangi yıl tanıtıldı?', options: ['2021', '2022', '2023', '2024'], correctIndex: 2),
      QuizQuestion(question: 'iPhone 16\'da ilk defa gelen AI sistemi hangisidir?', options: ['Apple Intelligence', 'Siri X', 'iOS AI', 'MacBrain'], correctIndex: 0),
      QuizQuestion(question: 'SpaceX\'in en büyük roketinin adı nedir?', options: ['Falcon 9', 'Falcon Heavy', 'Starship', 'Dragon'], correctIndex: 2),
      QuizQuestion(question: 'Twitter\'ın 2023\'te yeni ismi ne oldu?', options: ['X', 'Threads', 'Chirp', 'Post'], correctIndex: 0),
      QuizQuestion(question: 'Meta\'nın Twitter rakibi platformun adı nedir?', options: ['Threads', 'Bluesky', 'Post', 'Mastodon'], correctIndex: 0),
      QuizQuestion(question: 'Quantum (kuantum) bilgisayar hangi birimi kullanır?', options: ['Bit', 'Byte', 'Qubit', 'Qbyte'], correctIndex: 2),
      QuizQuestion(question: 'CRISPR teknolojisi ne için kullanılır?', options: ['Sinyal iletimi', 'Gen düzenleme', 'Enerji üretimi', 'Veri sıkıştırma'], correctIndex: 1),
      QuizQuestion(question: 'Metaverse kavramını kim popülerleştirdi (kelimenin kendisi)?', options: ['Mark Zuckerberg', 'Neal Stephenson', 'William Gibson', 'Elon Musk'], correctIndex: 1),
      QuizQuestion(question: '5G teknolojisi hangi "G" kuşağıdır?', options: ['3.', '4.', '5.', '6.'], correctIndex: 2),
      QuizQuestion(question: 'Hangi şirket dünyanın en değerli şirketlerinden biridir (2024)?', options: ['Apple', 'Microsoft', 'NVIDIA', 'Hepsi'], correctIndex: 3),
      QuizQuestion(question: 'Python programlama dili hangi hayvandan ismini alır?', options: ['Piton yılanı', 'Komedi grubu (Monty Python)', 'Bir kuş türü', 'Bir yunanca kelime'], correctIndex: 1),
      QuizQuestion(question: 'Android işletim sistemi hangi şirket tarafından geliştirilir?', options: ['Samsung', 'Google', 'Huawei', 'OnePlus'], correctIndex: 1),
      QuizQuestion(question: 'Bir URL\'deki "https" ne anlama gelir?', options: ['Gizli bağlantı', 'Güvenli HTTP', 'Hızlı sayfa', 'Yüksek trafik'], correctIndex: 1),
      QuizQuestion(question: 'GitHub\'ı satın alan şirket hangisidir?', options: ['Google', 'Microsoft', 'Amazon', 'Meta'], correctIndex: 1),
      QuizQuestion(question: 'Bitcoin hangi yıl ortaya çıktı?', options: ['2005', '2009', '2013', '2017'], correctIndex: 1),
      QuizQuestion(question: 'Ethereum\'u kim yarattı?', options: ['Satoshi Nakamoto', 'Vitalik Buterin', 'Charles Hoskinson', 'Gavin Wood'], correctIndex: 1),
      QuizQuestion(question: 'NFT\'nin açılımı nedir?', options: ['Non-Fungible Token', 'Network File Transfer', 'New Format Tag', 'Numeric File Type'], correctIndex: 0),
      QuizQuestion(question: 'Hangi şirket elektrikli araçlar üretir?', options: ['Tesla', 'Rivian', 'BYD', 'Hepsi'], correctIndex: 3),
      QuizQuestion(question: 'James Webb Uzay Teleskobu hangi yıl fırlatıldı?', options: ['2020', '2021', '2022', '2023'], correctIndex: 1),
      QuizQuestion(question: 'Hangisi bir ses asistanı değildir?', options: ['Alexa', 'Siri', 'Roku', 'Cortana'], correctIndex: 2),
      QuizQuestion(question: 'OpenAI\'ın görüntü üretme modelinin adı nedir?', options: ['Sora', 'DALL-E', 'Midjourney', 'Stable Diffusion'], correctIndex: 1),
      QuizQuestion(question: 'OpenAI\'ın 2024\'te tanıttığı video üretme modeli hangisidir?', options: ['Runway', 'Sora', 'Luma', 'Pika'], correctIndex: 1),
      QuizQuestion(question: 'NVIDIA hangi ürün türüyle ünlüdür?', options: ['CPU', 'GPU', 'RAM', 'SSD'], correctIndex: 1),
      QuizQuestion(question: 'iPhone\'un lansmanı hangi yılda yapıldı?', options: ['2005', '2007', '2009', '2010'], correctIndex: 1),
      QuizQuestion(question: 'Bir drone\'un en temel uçuş parçası hangisidir?', options: ['Pervaneler', 'GPS', 'Kamera', 'Işıklar'], correctIndex: 0),
      QuizQuestion(question: 'HTML hangi yıl oluşturuldu?', options: ['1985', '1989', '1993', '1997'], correctIndex: 2),
      QuizQuestion(question: 'VPN\'in açılımı nedir?', options: ['Virtual Private Network', 'Visible Public Network', 'Variable Protocol Node', 'Verified Protected Node'], correctIndex: 0),
      QuizQuestion(question: 'En hızlı kablosuz şarj hangi watt üzerinden yapılır (2024)?', options: ['15W', '30W', '65W', '240W+'], correctIndex: 3),
      QuizQuestion(question: 'Neuralink hangi alanda çalışıyor?', options: ['Uzay', 'Beyin-bilgisayar', 'Nükleer', 'Genetik'], correctIndex: 1),
      QuizQuestion(question: 'Bir bilgisayarın beyni olarak hangi parça görülür?', options: ['RAM', 'CPU', 'GPU', 'SSD'], correctIndex: 1),
      QuizQuestion(question: 'Dünyada en çok kullanılan arama motoru hangisidir?', options: ['Bing', 'Yahoo', 'Google', 'DuckDuckGo'], correctIndex: 2),
      QuizQuestion(question: 'Kripto para "madenciliği" aslında ne anlamına gelir?', options: ['Para basmak', 'Sunucu kiralamak', 'Bulmaca çözmek / doğrulama', 'Depolama yapmak'], correctIndex: 2),
    ],
  ),
  QuizCategory(
    name: 'Sinema & Müzik',
    icon: Icons.movie_creation_rounded,
    color: const Color(0xFFEC4899),
    questions: const [
      QuizQuestion(question: 'Oscar\'da en iyi film ödülü en çok hangi filme verilmiştir?', options: ['Titanic', 'Ben-Hur', 'Yüzüklerin Efendisi', 'Hepsi eşit'], correctIndex: 3),
      QuizQuestion(question: 'Star Wars serisinin yaratıcısı kimdir?', options: ['Steven Spielberg', 'George Lucas', 'James Cameron', 'Ridley Scott'], correctIndex: 1),
      QuizQuestion(question: 'Hangi müzik aleti en çok tele sahiptir?', options: ['Gitar', 'Keman', 'Piyano', 'Arp'], correctIndex: 2),
      QuizQuestion(question: '\"Bohemian Rhapsody\" hangi grubun şarkısıdır?', options: ['The Beatles', 'Led Zeppelin', 'Queen', 'Pink Floyd'], correctIndex: 2),
      QuizQuestion(question: 'Hollywood hangi şehirdedir?', options: ['New York', 'Los Angeles', 'Chicago', 'San Francisco'], correctIndex: 1),
      QuizQuestion(question: 'Hangi film serisi \"Güç seninle olsun\" sözüyle bilinir?', options: ['Harry Potter', 'Star Wars', 'Matrix', 'Avengers'], correctIndex: 1),
      QuizQuestion(question: 'Mozart hangi ülkede doğmuştur?', options: ['Almanya', 'Avusturya', 'İtalya', 'Fransa'], correctIndex: 1),
      QuizQuestion(question: 'Dünyada en çok satan müzik albümü hangisidir?', options: ['Back in Black', 'Thriller', 'The Wall', 'Abbey Road'], correctIndex: 1),
      QuizQuestion(question: 'Titanic filminin yönetmeni kimdir?', options: ['Spielberg', 'Nolan', 'Cameron', 'Scorsese'], correctIndex: 2),
      QuizQuestion(question: 'Hangi enstrüman üflemeli çalgıdır?', options: ['Keman', 'Gitar', 'Flüt', 'Piyano'], correctIndex: 2),
      QuizQuestion(question: 'Beethoven\'ın en ünlü senfonisi hangisidir?', options: ['3.', '5.', '7.', '9.'], correctIndex: 3),
      QuizQuestion(question: 'Marvel Sinematik Evreni\'nin ilk filmi hangisidir?', options: ['Thor', 'Iron Man', 'Hulk', 'Captain America'], correctIndex: 1),
      QuizQuestion(question: 'Grammy ödülleri hangi alanda verilir?', options: ['Sinema', 'Müzik', 'Edebiyat', 'Bilim'], correctIndex: 1),
      QuizQuestion(question: 'Hangi film \"Kural 1: Fight Club hakkında konuşma\" sözüyle bilinir?', options: ['Matrix', 'Fight Club', 'Inception', 'Se7en'], correctIndex: 1),
      QuizQuestion(question: 'Elvis Presley\'nin lakabı nedir?', options: ['Kral', 'Pop Kralı', 'Rock Kralı', 'Müzik Kralı'], correctIndex: 0),
      QuizQuestion(question: 'Hangi Disney filmi \"Let It Go\" şarkısını içerir?', options: ['Moana', 'Tangled', 'Frozen', 'Encanto'], correctIndex: 2),
      QuizQuestion(question: 'The Dark Knight filminde Joker\'i kim canlandırdı?', options: ['Jack Nicholson', 'Heath Ledger', 'Jared Leto', 'Joaquin Phoenix'], correctIndex: 1),
      QuizQuestion(question: 'Hangi nota müzik dizisinin ilk notasıdır?', options: ['Re', 'Mi', 'Do', 'Si'], correctIndex: 2),
      QuizQuestion(question: 'Inception filminin yönetmeni kimdir?', options: ['Tarantino', 'Fincher', 'Nolan', 'Villeneuve'], correctIndex: 2),
      QuizQuestion(question: 'K-pop müzik türü hangi ülkeye aittir?', options: ['Japonya', 'Çin', 'Güney Kore', 'Tayland'], correctIndex: 2),
      // ─── Genişletilmiş havuz ───
      QuizQuestion(question: '2024 Oscar\'da En İyi Film hangisidir?', options: ['Oppenheimer', 'Barbie', 'Killers of the Flower Moon', 'Past Lives'], correctIndex: 0),
      QuizQuestion(question: 'Oppenheimer filminin yönetmeni kimdir?', options: ['Spielberg', 'Nolan', 'Scorsese', 'Tarantino'], correctIndex: 1),
      QuizQuestion(question: 'Taylor Swift\'in 2023-2024\'teki dünya turnesinin adı nedir?', options: ['Reputation', 'Lover Tour', 'Eras Tour', 'Speak Now Tour'], correctIndex: 2),
      QuizQuestion(question: 'BTS hangi ülkeden bir K-pop grubudur?', options: ['Japonya', 'Çin', 'Güney Kore', 'Tayvan'], correctIndex: 2),
      QuizQuestion(question: 'Hangi şarkıcı "Espresso" şarkısı ile 2024\'te zirveye çıktı?', options: ['Olivia Rodrigo', 'Sabrina Carpenter', 'Tate McRae', 'Doja Cat'], correctIndex: 1),
      QuizQuestion(question: 'Avatar 2 (Suyun Yolu) hangi yıl vizyona girdi?', options: ['2020', '2021', '2022', '2023'], correctIndex: 2),
      QuizQuestion(question: 'Joker (2019) filminde Joker\'i kim canlandırdı?', options: ['Heath Ledger', 'Joaquin Phoenix', 'Jared Leto', 'Jack Nicholson'], correctIndex: 1),
      QuizQuestion(question: 'Squid Game hangi ülkenin dizisidir?', options: ['Japonya', 'Çin', 'Güney Kore', 'Tayvan'], correctIndex: 2),
      QuizQuestion(question: 'Wednesday dizisinde başrolü kim oynar?', options: ['Millie Bobby Brown', 'Jenna Ortega', 'Sadie Sink', 'Maya Hawke'], correctIndex: 1),
      QuizQuestion(question: 'Stranger Things hangi platformda yayınlanır?', options: ['HBO', 'Netflix', 'Disney+', 'Prime'], correctIndex: 1),
      QuizQuestion(question: 'House of the Dragon dizisi hangi serinin spin-off\'udur?', options: ['Lord of the Rings', 'Game of Thrones', 'The Witcher', 'Wheel of Time'], correctIndex: 1),
      QuizQuestion(question: 'Beyoncé hangi ülkedendir?', options: ['ABD', 'Kanada', 'İngiltere', 'Avustralya'], correctIndex: 0),
      QuizQuestion(question: 'Hangi piyanist "Senfoniler"i meşhurdur?', options: ['Chopin', 'Mozart', 'Beethoven', 'Bach'], correctIndex: 2),
      QuizQuestion(question: 'Bridgerton dizisi hangi platforma aittir?', options: ['Netflix', 'HBO', 'Disney+', 'Prime'], correctIndex: 0),
      QuizQuestion(question: 'Dune (2021) filmin yönetmeni kimdir?', options: ['Denis Villeneuve', 'Ridley Scott', 'Christopher Nolan', 'Damien Chazelle'], correctIndex: 0),
      QuizQuestion(question: 'Spider-Man\'in alter egosu kimdir?', options: ['Bruce Wayne', 'Peter Parker', 'Tony Stark', 'Clark Kent'], correctIndex: 1),
      QuizQuestion(question: 'Ed Sheeran hangi ülkelidir?', options: ['ABD', 'Kanada', 'İngiltere', 'İrlanda'], correctIndex: 2),
      QuizQuestion(question: 'Hangi Türk grup Eurovision 2003\'ü kazandı?', options: ['MaNga', 'Sertab Erener', 'Hadise', 'Tarkan'], correctIndex: 1),
      QuizQuestion(question: 'Netflix\'in en çok izlenen filmi hangisidir (2024)?', options: ['Red Notice', 'Don\'t Look Up', 'The Gray Man', 'Red Notice/Carry-On (sürekli değişir)'], correctIndex: 3),
      QuizQuestion(question: 'Sezen Aksu lakabı nedir?', options: ['Türk Annesi', 'Minik Serçe', 'Pop Kraliçesi', 'Diva'], correctIndex: 1),
      QuizQuestion(question: 'Coldplay hangi ülkelidir?', options: ['ABD', 'İngiltere', 'Avustralya', 'İrlanda'], correctIndex: 1),
      QuizQuestion(question: 'Hangi rapper "Gangnam Style" ile dünyaca ünlüdür?', options: ['G-Dragon', 'PSY', 'Suga', 'RM'], correctIndex: 1),
      QuizQuestion(question: 'Peaky Blinders dizisi hangi şehirde geçer?', options: ['Londra', 'Manchester', 'Birmingham', 'Liverpool'], correctIndex: 2),
      QuizQuestion(question: 'Game of Thrones\'un yazarı kimdir?', options: ['J.K. Rowling', 'George R.R. Martin', 'J.R.R. Tolkien', 'Stephen King'], correctIndex: 1),
      QuizQuestion(question: 'Hangi opera bestecisidir Verdi?', options: ['Alman', 'İtalyan', 'Fransız', 'Avusturyalı'], correctIndex: 1),
      QuizQuestion(question: 'Lady Gaga\'nın gerçek adı nedir?', options: ['Stefani Germanotta', 'Stefania Joanne', 'Stephanie Gaga', 'Stefani Lambert'], correctIndex: 0),
      QuizQuestion(question: 'Shrek serisi hangi stüdyoya aittir?', options: ['Pixar', 'DreamWorks', 'Disney', 'Illumination'], correctIndex: 1),
      QuizQuestion(question: 'Hangi Türk yönetmen Cannes\'dan ödül aldı (Bir Zamanlar Anadolu\'da)?', options: ['Reha Erdem', 'Nuri Bilge Ceylan', 'Ferzan Özpetek', 'Ahmet Uluçay'], correctIndex: 1),
      QuizQuestion(question: 'Adele hangi ülkelidir?', options: ['ABD', 'Kanada', 'İngiltere', 'İrlanda'], correctIndex: 2),
      QuizQuestion(question: 'Drake hangi ülkelidir?', options: ['ABD', 'Kanada', 'İngiltere', 'Avustralya'], correctIndex: 1),
      QuizQuestion(question: 'Hangi grup "Hotel California" şarkısı ile ünlüdür?', options: ['Pink Floyd', 'Eagles', 'Led Zeppelin', 'The Doors'], correctIndex: 1),
      QuizQuestion(question: 'Akira Kurosawa hangi ülkenin yönetmenidir?', options: ['Çin', 'Kore', 'Japonya', 'Tayvan'], correctIndex: 2),
    ],
  ),
  QuizCategory(
    name: 'Yemek & Kültür',
    icon: Icons.restaurant_rounded,
    color: const Color(0xFFF97316),
    questions: const [
      QuizQuestion(question: 'Sushi hangi ülkenin geleneksel yemeğidir?', options: ['Çin', 'Kore', 'Japonya', 'Tayland'], correctIndex: 2),
      QuizQuestion(question: 'Baklava hangi mutfağın meşhur tatlısıdır?', options: ['Arap', 'Türk', 'İran', 'Yunan'], correctIndex: 1),
      QuizQuestion(question: 'Pizza hangi ülkede ortaya çıkmıştır?', options: ['ABD', 'Fransa', 'İtalya', 'İspanya'], correctIndex: 2),
      QuizQuestion(question: 'Dünyada en çok tüketilen baharat hangisidir?', options: ['Tuz', 'Karabiber', 'Kimyon', 'Zerdeçal'], correctIndex: 1),
      QuizQuestion(question: 'Croissant hangi ülkenin simgesidir?', options: ['İtalya', 'Avusturya', 'Fransa', 'İsviçre'], correctIndex: 2),
      QuizQuestion(question: 'Çay en çok hangi ülkede tüketilir?', options: ['İngiltere', 'Türkiye', 'Çin', 'Hindistan'], correctIndex: 1),
      QuizQuestion(question: 'Kebap hangi pişirme yöntemiyle yapılır?', options: ['Buğulama', 'Kızartma', 'Izgara', 'Fırınlama'], correctIndex: 2),
      QuizQuestion(question: 'Paella hangi ülkenin yemeğidir?', options: ['İtalya', 'Portekiz', 'İspanya', 'Yunanistan'], correctIndex: 2),
      QuizQuestion(question: 'Wasabi hangi bitkiden elde edilir?', options: ['Zencefil', 'Turp', 'Japon turpu', 'Soğan'], correctIndex: 2),
      QuizQuestion(question: 'Dünyada en çok üretilen meyve hangisidir?', options: ['Elma', 'Portakal', 'Muz', 'Üzüm'], correctIndex: 2),
      QuizQuestion(question: 'Kimchi hangi ülkenin geleneksel yemeğidir?', options: ['Japonya', 'Çin', 'Güney Kore', 'Vietnam'], correctIndex: 2),
      QuizQuestion(question: 'Espresso hangi ülkede doğmuştur?', options: ['Fransa', 'Brezilya', 'İtalya', 'Türkiye'], correctIndex: 2),
      QuizQuestion(question: 'Türk kahvesinin özelliği nedir?', options: ['Süzülür', 'Telvesiyle pişer', 'Soğuk içilir', 'Sütle yapılır'], correctIndex: 1),
      QuizQuestion(question: 'Guacamole\'nin ana malzemesi nedir?', options: ['Domates', 'Avokado', 'Biber', 'Soğan'], correctIndex: 1),
      QuizQuestion(question: 'Hangi ülke çikolata üretiminde dünya lideridir?', options: ['İsviçre', 'Belçika', 'Fildişi Sahili', 'Gana'], correctIndex: 2),
      QuizQuestion(question: 'Mantı hangi yemek türüne girer?', options: ['Çorba', 'Hamur işi', 'Salata', 'Tatlı'], correctIndex: 1),
      QuizQuestion(question: 'Tofu hangi besinten yapılır?', options: ['Pirinç', 'Soya', 'Buğday', 'Mısır'], correctIndex: 1),
      QuizQuestion(question: 'Tiramisu hangi ülkenin tatlısıdır?', options: ['Fransa', 'İspanya', 'İtalya', 'Portekiz'], correctIndex: 2),
      QuizQuestion(question: 'Naan ekmeği hangi mutfağa aittir?', options: ['Arap', 'Türk', 'Hint', 'İran'], correctIndex: 2),
      QuizQuestion(question: 'Gazpacho nasıl bir çorbadır?', options: ['Sıcak', 'Soğuk', 'Tatlı', 'Baharatlı'], correctIndex: 1),
      // ─── Genişletilmiş havuz ───
      QuizQuestion(question: 'Lahmacun hangi mutfağa aittir?', options: ['Türk', 'Arap', 'Fars', 'Yunan'], correctIndex: 0),
      QuizQuestion(question: 'Hangi içecek Brezilya\'nın milli içeceğidir?', options: ['Tequila', 'Caipirinha', 'Mezcal', 'Rum'], correctIndex: 1),
      QuizQuestion(question: 'Hangi peynir İtalya\'nın "kralıdır"?', options: ['Mozzarella', 'Parmigiano Reggiano', 'Gorgonzola', 'Ricotta'], correctIndex: 1),
      QuizQuestion(question: 'Hangi yemek "İngiliz kahvaltısı"nın ana parçasıdır?', options: ['Croissant', 'Bacon', 'Bagel', 'Empanada'], correctIndex: 1),
      QuizQuestion(question: 'Bir maki sushi neye sarılır?', options: ['Yaprak', 'Yosun', 'Pirinç', 'Ekmek'], correctIndex: 1),
      QuizQuestion(question: 'Hangisi vegan değildir?', options: ['Tofu', 'Tempeh', 'Bal', 'Seitan'], correctIndex: 2),
      QuizQuestion(question: 'Hangi ülke meyhane kültürüyle ünlüdür?', options: ['Türkiye', 'Yunanistan', 'İspanya', 'Hepsi'], correctIndex: 3),
      QuizQuestion(question: 'Künefe hangi ilin meşhurudur?', options: ['Adana', 'Hatay', 'Gaziantep', 'Mersin'], correctIndex: 1),
      QuizQuestion(question: 'Karnıyarık hangi sebzeden yapılır?', options: ['Patlıcan', 'Kabak', 'Biber', 'Domates'], correctIndex: 0),
      QuizQuestion(question: 'Hangi tatlı Hindistan\'a özgüdür?', options: ['Baklava', 'Gulab Jamun', 'Tiramisu', 'Crème Brûlée'], correctIndex: 1),
      QuizQuestion(question: 'Bir cappuccino kaç shot espresso içerir?', options: ['1', '2', '3', '4'], correctIndex: 0),
      QuizQuestion(question: 'Hangi besinde en çok protein vardır (100gr için)?', options: ['Yumurta', 'Tavuk göğsü', 'Ton balığı', 'Mercimek'], correctIndex: 1),
      QuizQuestion(question: 'Soğan hangi alt sınıfa aittir?', options: ['Yumru', 'Sebze (soğanlı)', 'Meyve', 'Kök'], correctIndex: 1),
      QuizQuestion(question: 'Türkiye\'nin coğrafi işaretli ürünü değildir?', options: ['Antep fıstığı', 'Maraş dondurması', 'Gemlik zeytini', 'Bordo şarabı'], correctIndex: 3),
      QuizQuestion(question: 'Acılığın bilimsel adı nedir?', options: ['Capsaicin', 'Glutamat', 'Theobromin', 'Cafeine'], correctIndex: 0),
      QuizQuestion(question: 'Çikolata kaç tip vardır (ana tür)?', options: ['2', '3', '4', '5'], correctIndex: 1),
      QuizQuestion(question: 'Hangi ülke en çok pirinç tüketir?', options: ['Çin', 'Hindistan', 'Bangladeş', 'Endonezya'], correctIndex: 0),
      QuizQuestion(question: 'Pasta sosu "carbonara"da olmaması gereken nedir?', options: ['Yumurta', 'Domates', 'Pancetta', 'Pecorino'], correctIndex: 1),
      QuizQuestion(question: 'Hangi içecek alkollü değildir?', options: ['Şampanya', 'Sake', 'Boza', 'Cidre'], correctIndex: 2),
      QuizQuestion(question: 'Cay (Çay) sözcüğünün kökeni hangi dildedir?', options: ['Türkçe', 'Çince', 'Hintçe', 'Farsça'], correctIndex: 1),
      QuizQuestion(question: 'Ramen hangi ülkenin yemeğidir?', options: ['Çin', 'Japonya', 'Kore', 'Vietnam'], correctIndex: 1),
    ],
  ),
  QuizCategory(
    name: 'Hayvanlar & Doğa',
    icon: Icons.pets_rounded,
    color: const Color(0xFF14B8A6),
    questions: const [
      QuizQuestion(question: 'Dünyanın en büyük hayvanı hangisidir?', options: ['Fil', 'Mavi Balina', 'Zürafa', 'Köpekbalığı'], correctIndex: 1),
      QuizQuestion(question: 'Hangi hayvan en hızlı koşar?', options: ['Aslan', 'Çita', 'Leopar', 'At'], correctIndex: 1),
      QuizQuestion(question: 'Arılar bal yapmak için ne toplar?', options: ['Yaprak', 'Toprak', 'Nektar', 'Su'], correctIndex: 2),
      QuizQuestion(question: 'Kangurular hangi kıtada yaşar?', options: ['Afrika', 'G. Amerika', 'Avustralya', 'Asya'], correctIndex: 2),
      QuizQuestion(question: 'Hangi hayvan ters asılarak uyur?', options: ['Koala', 'Yarasa', 'Tembel hayvan', 'Maymun'], correctIndex: 1),
      QuizQuestion(question: 'Bir ahtapotun kaç kolu vardır?', options: ['6', '8', '10', '12'], correctIndex: 1),
      QuizQuestion(question: 'Hangi kuş uçamaz?', options: ['Kartal', 'Penguen', 'Şahin', 'Pelikan'], correctIndex: 1),
      QuizQuestion(question: 'Dünyanın en zehirli yılanı hangisidir?', options: ['Kobra', 'Karakol', 'İç Taipan', 'Piton'], correctIndex: 2),
      QuizQuestion(question: 'Kelebeklerin tat alma organı nerededir?', options: ['Ağız', 'Kanat', 'Ayak', 'Anten'], correctIndex: 2),
      QuizQuestion(question: 'Hangi hayvan süt veren tek uçan memeli?', options: ['Yarasa', 'Sincap', 'Uçan balık', 'Pelikan'], correctIndex: 0),
      QuizQuestion(question: 'Bir zürafanın dili yaklaşık kaç cm\'dir?', options: ['20', '35', '50', '65'], correctIndex: 2),
      QuizQuestion(question: 'Hangi böcek en çok türe sahiptir?', options: ['Karınca', 'Kelebek', 'Böcek (Beetle)', 'Sinek'], correctIndex: 2),
      QuizQuestion(question: 'Yunuslar hangi sınıfa aittir?', options: ['Balık', 'Sürüngen', 'Memeli', 'Kuş'], correctIndex: 2),
      QuizQuestion(question: 'Dünyanın en büyük çiçeği hangisidir?', options: ['Orkide', 'Gül', 'Rafflesia', 'Ayçiçeği'], correctIndex: 2),
      QuizQuestion(question: 'Kaç tür penguen vardır (yaklaşık)?', options: ['5', '10', '18', '30'], correctIndex: 2),
      QuizQuestion(question: 'Hangi hayvan en uzun yaşar?', options: ['Fil', 'Kaplumbağa', 'Balina', 'Papağan'], correctIndex: 1),
      QuizQuestion(question: 'Bukalemun ne yapabilir?', options: ['Uçabilir', 'Renk değiştirir', 'Suda yaşar', 'Zehir fırlatır'], correctIndex: 1),
      QuizQuestion(question: 'Hangi ağaç en uzun yaşar?', options: ['Meşe', 'Çam', 'Bristlecone', 'Baobab'], correctIndex: 2),
      QuizQuestion(question: 'Karıncalar vücut ağırlıklarının kaç katını taşıyabilir?', options: ['5', '10', '50', '100'], correctIndex: 2),
      QuizQuestion(question: 'Koalalar günde kaç saat uyur?', options: ['8-10', '12-14', '18-22', '6-8'], correctIndex: 2),
      // ─── Genişletilmiş havuz ───
      QuizQuestion(question: 'Hangi balık karada da kısa süreliğine yaşayabilir?', options: ['Sazan', 'Akciğerli balık', 'Yılan balığı', 'Sardalya'], correctIndex: 1),
      QuizQuestion(question: 'En küçük kuş türü hangisidir?', options: ['Çita kuşu', 'Sinek kuşu', 'Çalıkuşu', 'Sülün'], correctIndex: 1),
      QuizQuestion(question: 'Hangi hayvan kendi vücut ağırlığının birkaç katı yiyebilir?', options: ['Kedi', 'Köpek', 'Yılan (piton)', 'Tavşan'], correctIndex: 2),
      QuizQuestion(question: 'Bir köpekbalığının iskeleti hangi dokudan oluşur?', options: ['Kemik', 'Kıkırdak', 'Kabuk', 'Diş'], correctIndex: 1),
      QuizQuestion(question: 'Pandalar ağırlıklı olarak ne yer?', options: ['Et', 'Bambu', 'Meyve', 'Balık'], correctIndex: 1),
      QuizQuestion(question: 'Karasal en büyük yırtıcı kuş hangisidir?', options: ['Kel kartal', 'Kara akbaba', 'Andean Condor', 'Şahin'], correctIndex: 2),
      QuizQuestion(question: 'Bal arıları görmez ne renk?', options: ['Kırmızı', 'Mavi', 'Sarı', 'Mor'], correctIndex: 0),
      QuizQuestion(question: 'Bir denizyıldızının kaç kolu olabilir?', options: ['3-5', '5-50', '5-25', '7-15'], correctIndex: 1),
      QuizQuestion(question: 'Hangi hayvan "yavaş yaşar" şeklinde tabir edilir?', options: ['Tembel hayvan', 'Penguen', 'Kaplumbağa', 'Salyangoz'], correctIndex: 0),
      QuizQuestion(question: 'Kutup ayıları hangi kıtada yaşar?', options: ['Antarktika', 'Kuzey Kutbu', 'Kuzey Amerika', 'Sibirya'], correctIndex: 1),
      QuizQuestion(question: 'Penguenler hangi yarımkürede yaşar?', options: ['Kuzey', 'Güney', 'Her ikisi', 'Hiçbiri'], correctIndex: 1),
      QuizQuestion(question: 'Hangi hayvan elektriğiyle savunma yapar?', options: ['Yunus', 'Elektrikli yılan balığı', 'Mürekkep balığı', 'Vatoz'], correctIndex: 1),
      QuizQuestion(question: 'Dünyanın en hızlı yüzücü balığı hangisidir?', options: ['Köpek balığı', 'Yelken balığı', 'Marlin', 'Ton'], correctIndex: 1),
      QuizQuestion(question: 'Bir kelebek kaç aşamadan geçer (yaşam döngüsü)?', options: ['2', '3', '4', '5'], correctIndex: 2),
      QuizQuestion(question: 'Karıncalar hangi haşere ile mücadele etmez (genelde)?', options: ['Yaprak biti', 'Termit', 'Kelebek', 'Diğer karınca koloni'], correctIndex: 2),
      QuizQuestion(question: 'Yunusların gözleri kaç tarafa bakabilir?', options: ['1', '2', '3', '4'], correctIndex: 1),
      QuizQuestion(question: 'Bir kurbağa ne tür bir hayvandır?', options: ['Sürüngen', 'İki yaşamlı (amfibi)', 'Memeli', 'Balık'], correctIndex: 1),
      QuizQuestion(question: 'Kuyruk yüzgeci olan tek memeli hangisidir?', options: ['Yunus', 'Balina', 'Foklar', 'Hepsi'], correctIndex: 3),
      QuizQuestion(question: 'En zekâlı kuş türlerinden hangisi sayılır?', options: ['Karga', 'Güvercin', 'Serçe', 'Kuğu'], correctIndex: 0),
      QuizQuestion(question: 'Bir aslan kafilesine ne ad verilir?', options: ['Sürü', 'Kafile', 'Aile', 'Pride'], correctIndex: 3),
      QuizQuestion(question: 'Türkiye\'de "Kelaynak" hangi ilde korumaya alınmıştır?', options: ['Şanlıurfa', 'Mardin', 'Adıyaman', 'Diyarbakır'], correctIndex: 0),
    ],
  ),
  // ═══════════════════════════════════════════════════════
  // YENİ KATEGORİ: Gündem (2023-2025 güncel olaylar)
  // ═══════════════════════════════════════════════════════
  QuizCategory(
    name: 'Gündem',
    icon: Icons.newspaper_rounded,
    color: const Color(0xFF06B6D4),
    questions: const [
      // — 2024 ABD Seçimi —
      QuizQuestion(question: '2024 ABD başkanlık seçimini kim kazandı?', options: ['Joe Biden', 'Donald Trump', 'Kamala Harris', 'Robert F. Kennedy Jr.'], correctIndex: 1),
      QuizQuestion(question: '2024 seçiminde Trump\'ın yardımcısı (Vice President) kim oldu?', options: ['Mike Pence', 'JD Vance', 'Marco Rubio', 'Ted Cruz'], correctIndex: 1),
      QuizQuestion(question: 'Donald Trump kaçıncı ABD başkanıdır?', options: ['45 ve 47', '45', '46', '47'], correctIndex: 0),
      // — 2024 Türkiye —
      QuizQuestion(question: '2024 Türkiye yerel seçiminde İstanbul Büyükşehir Belediye Başkanı kim oldu?', options: ['Ekrem İmamoğlu', 'Murat Kurum', 'Mansur Yavaş', 'Tunç Soyer'], correctIndex: 0),
      QuizQuestion(question: '2024 yerel seçiminde Ankara Büyükşehir Belediye Başkanı kim oldu?', options: ['Mansur Yavaş', 'Ekrem İmamoğlu', 'Turgut Altınok', 'Cemil Çiçek'], correctIndex: 0),
      QuizQuestion(question: '2024 yerel seçiminde en çok il başkanlığını hangi parti aldı?', options: ['AK Parti', 'CHP', 'DEM', 'İYİ'], correctIndex: 1),
      QuizQuestion(question: 'Türkiye Cumhuriyet 100. yıl dönümünü hangi yıl kutladı?', options: ['2022', '2023', '2024', '2025'], correctIndex: 1),
      // — Spor 2024 —
      QuizQuestion(question: '2024 Paris Olimpiyatları\'nda madalya töreni hangi kült mekanın önünde yapıldı (atletizm)?', options: ['Eyfel', 'Versay', 'Stade de France', 'Trocadéro'], correctIndex: 0),
      QuizQuestion(question: '2024 Euro\'da Türkiye hangi turdan elendi?', options: ['Grup', 'Son 16', 'Çeyrek final', 'Yarı final'], correctIndex: 2),
      QuizQuestion(question: 'Yusuf Dikeç (Türk atış sporcusu) 2024 Paris\'te hangi kategoride madalya kazandı?', options: ['Hava tabancası karışık', 'Hava tüfeği', 'Trap', 'Skeet'], correctIndex: 0),
      QuizQuestion(question: 'Real Madrid 2023-24 Şampiyonlar Ligi\'ni hangi takımı yenerek kazandı?', options: ['Manchester City', 'Borussia Dortmund', 'Bayern Münih', 'PSG'], correctIndex: 1),
      QuizQuestion(question: '2024 Euro finalinde İspanya hangi takımı yendi?', options: ['Fransa', 'Almanya', 'İngiltere', 'Hollanda'], correctIndex: 2),
      // — Teknoloji 2024-2025 —
      QuizQuestion(question: 'OpenAI\'nin 2024\'te yayınladığı yeni amiral gemisi modelin adı nedir?', options: ['GPT-4', 'GPT-4o', 'GPT-5', 'GPT-Turbo'], correctIndex: 1),
      QuizQuestion(question: 'Apple\'ın AI sistemi "Apple Intelligence" hangi yıl tanıtıldı?', options: ['2022', '2023', '2024', '2025'], correctIndex: 2),
      QuizQuestion(question: '2024\'te yapay zeka piyasasında devleşen GPU üreticisi hangisidir?', options: ['AMD', 'Intel', 'NVIDIA', 'Qualcomm'], correctIndex: 2),
      QuizQuestion(question: 'TikTok hangi ülkenin merkezli ana şirkete aittir?', options: ['ABD', 'Çin', 'Güney Kore', 'Singapur'], correctIndex: 1),
      QuizQuestion(question: 'WhatsApp\'ı hangi şirket sahiplenir?', options: ['Google', 'Meta', 'Microsoft', 'Apple'], correctIndex: 1),
      // — Uzay —
      QuizQuestion(question: 'SpaceX Starship\'in 2024\'te ilk başarılı yumuşak inişini hangi araç gerçekleştirdi (booster yakaladı)?', options: ['Mechazilla kollar', 'Drone gemi', 'Karada platform', 'Suya iniş'], correctIndex: 0),
      QuizQuestion(question: '2024\'te Ay\'a iniş yapan ilk özel şirket hangisidir?', options: ['Blue Origin', 'SpaceX', 'Intuitive Machines', 'Astrobotic'], correctIndex: 2),
      QuizQuestion(question: 'James Webb Teleskobu hangi tip teleskoptur?', options: ['Optik', 'Kızılötesi', 'Mor ötesi', 'Radyo'], correctIndex: 1),
      // — Sinema/Müzik 2024 —
      QuizQuestion(question: '2024 Oscar\'da En İyi Yönetmen kim oldu?', options: ['Christopher Nolan', 'Martin Scorsese', 'Greta Gerwig', 'Yorgos Lanthimos'], correctIndex: 0),
      QuizQuestion(question: '2024\'te en çok hasılat yapan film hangisidir?', options: ['Inside Out 2', 'Deadpool & Wolverine', 'Wicked', 'Despicable Me 4'], correctIndex: 0),
      QuizQuestion(question: 'Taylor Swift Eras Tour\'u hangi yıl başladı?', options: ['2022', '2023', '2024', '2025'], correctIndex: 1),
      QuizQuestion(question: 'Beyoncé\'nin 2024\'te yayınladığı country albümünün adı nedir?', options: ['Renaissance', 'Cowboy Carter', 'Lemonade', 'Western Soul'], correctIndex: 1),
      // — Türkiye —
      QuizQuestion(question: '6 Şubat 2023 depreminin merkez üssü hangi ildi?', options: ['Hatay', 'Kahramanmaraş', 'Adıyaman', 'Gaziantep'], correctIndex: 1),
      QuizQuestion(question: '2023 Türkiye Cumhurbaşkanlığı seçimini kim kazandı?', options: ['Recep Tayyip Erdoğan', 'Kemal Kılıçdaroğlu', 'Sinan Oğan', 'Muharrem İnce'], correctIndex: 0),
      QuizQuestion(question: 'TOGG\'un ilk seri üretim aracının adı nedir?', options: ['T10X', 'C-SUV', 'Devrim', 'Karaoğlan'], correctIndex: 0),
      QuizQuestion(question: 'Gökdere Gözcüsü Türkiye\'nin hangi alandaki ilk yerli buluşudur?', options: ['Roket', 'Yapay zeka', 'İnsansız hava aracı (yer)', 'Uydu'], correctIndex: 2),
      QuizQuestion(question: 'Kanal İstanbul projesi hangi 2 denizi birleştirmeyi planlar?', options: ['Karadeniz-Marmara', 'Marmara-Ege', 'Karadeniz-Akdeniz', 'Ege-Akdeniz'], correctIndex: 0),
      // — Dünya —
      QuizQuestion(question: 'Ukrayna-Rusya savaşı hangi yıl başladı (büyük ölçekli işgal)?', options: ['2014', '2020', '2022', '2024'], correctIndex: 2),
      QuizQuestion(question: 'NATO\'ya 2023\'te katılan ülke hangisidir?', options: ['Finlandiya', 'İsveç', 'Ukrayna', 'Moldova'], correctIndex: 0),
      QuizQuestion(question: 'NATO\'ya 2024\'te katılan ülke hangisidir?', options: ['Finlandiya', 'İsveç', 'Ukrayna', 'Moldova'], correctIndex: 1),
      QuizQuestion(question: 'Hangi ülke 2024 BRICS genişlemesinde yeni üye olarak eklendi?', options: ['BAE', 'İran', 'Mısır', 'Hepsi'], correctIndex: 3),
      QuizQuestion(question: 'Pope Francis (Papa Francis) hangi ülkeden seçildi?', options: ['İtalya', 'Polonya', 'Almanya', 'Arjantin'], correctIndex: 3),
      QuizQuestion(question: 'King Charles III (III. Charles) hangi yılda taç giydi?', options: ['2022', '2023', '2024', '2025'], correctIndex: 1),
      QuizQuestion(question: 'Argentina\'nın 2023\'te seçilen popülist devlet başkanı kimdir?', options: ['Milei', 'Bolsonaro', 'Petro', 'Boric'], correctIndex: 0),
      // — Çevre —
      QuizQuestion(question: '2024\'te küresel sıcaklık ortalaması hangi eşiği aştı (ilk yıl)?', options: ['1.0°C', '1.5°C', '2.0°C', '2.5°C'], correctIndex: 1),
      QuizQuestion(question: 'Hangi 2024 küresel zirvesi iklim değişikliği için düzenlendi?', options: ['G20 Rio', 'COP29 Baku', 'WEF Davos', 'Hepsi (kısmen)'], correctIndex: 1),
      QuizQuestion(question: 'Avrupa\'da 2024\'te en sıcak yaz hangi ülkede çatladı?', options: ['Türkiye', 'Yunanistan', 'İtalya', 'İspanya'], correctIndex: 1),
      // — Eğlence —
      QuizQuestion(question: 'Hangi sosyal medya 2023\'te "Threads" adıyla çıktı?', options: ['Instagram/Meta', 'X', 'TikTok', 'Snap'], correctIndex: 0),
      QuizQuestion(question: '2024\'te en hızlı 1 milyar dolar geliri olan film hangisidir?', options: ['Inside Out 2', 'Deadpool 3', 'Avengers: Endgame', 'Barbie'], correctIndex: 0),
    ],
  ),
];

// ─── Kategori best score anahtarı ───
String get _uidPrefix {
  final uid = AuthService().uid;
  return uid != null ? '${uid}_' : '';
}
String _bestKey(String catName) => '${_uidPrefix}quiz_best_$catName';

Future<int> _loadBest(String catName) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(_bestKey(catName)) ?? 0;
}

Future<bool> _saveBest(String catName, int score) async {
  final prefs = await SharedPreferences.getInstance();
  final old = prefs.getInt(_bestKey(catName)) ?? 0;
  if (score > old) {
    await prefs.setInt(_bestKey(catName), score);
    return true;
  }
  return false;
}

// ═══════════════════════════════════════════════════════
// Kalıcı anti-repeat: kategori başına son görülen soruları takip et.
// Soru text'i ID olarak kullanılır (havuz değişse de sağlam).
// Havuz tükenince otomatik sıfırlanır.
// ═══════════════════════════════════════════════════════
String _seenKey(String catName) => '${_uidPrefix}quiz_seen_$catName';

/// Maksimum kaç soru "yakında görüldü" listesine alınır.
/// Bu sayıdan büyük havuzlarda bu sınır geçildikten sonra LRU mantığıyla
/// en eski sorular düşmeye başlar. Havuza göre adaptif: havuzun ~%70'i.
int _seenCapFor(int poolSize) {
  if (poolSize <= 12) return (poolSize * 0.5).floor().clamp(1, 6);
  return (poolSize * 0.7).floor().clamp(20, 80);
}

Future<List<String>> _loadSeenTexts(String catName) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(_seenKey(catName)) ?? const <String>[];
}

Future<void> _saveSeenTexts(String catName, List<String> texts) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(_seenKey(catName), texts);
}

/// Yeni round için soru indekslerini seç.
/// 1) Şu oturumda kullanılmamış olanları al
/// 2) Kalıcı "yakında görülen" listesindekileri hariç tut
/// 3) Eğer 10'dan az kaldıysa kalıcı listeyi sıfırla, baştan dene
List<int> _pickRoundIndices({
  required QuizCategory category,
  required List<int> usedThisSession,
  required List<String> persistentSeenTexts,
  required int needed,
  required Random rnd,
}) {
  final all = category.questions;
  final allIdx = List<int>.generate(all.length, (i) => i);

  bool isExcluded(int i) =>
      usedThisSession.contains(i) ||
      persistentSeenTexts.contains(all[i].question);

  var pool = allIdx.where((i) => !isExcluded(i)).toList()..shuffle(rnd);

  // Yeterli soru yoksa kalıcı seen listesini "boşaltıyormuş gibi" kullan
  // ama bu sefer tüm kategoriden çekelim (sadece session-used hariç).
  if (pool.length < needed) {
    pool = allIdx
        .where((i) => !usedThisSession.contains(i))
        .toList()
      ..shuffle(rnd);
    debugPrint('🔄 Quiz seen-list reset: ${category.name}');
  }
  return pool.take(needed).toList();
}

// ─── Quiz Ana Ekranı ───
class QuizGame extends StatefulWidget {
  const QuizGame({super.key});

  @override
  State<QuizGame> createState() => _QuizGameState();
}

class _QuizGameState extends State<QuizGame> {
  final Map<String, int> _bests = {};
  int _totalBest = 0;
  final Set<String> _unlockedByAd = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    for (final cat in _categories) {
      _bests[cat.name] = await _loadBest(cat.name);
    }
    _totalBest = _bests.values.fold(0, (a, b) => a + b);
    if (mounted) setState(() {});
  }

  void _showHowToPlay() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C1B4D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.white),
            SizedBox(width: 10),
            Text('Nasıl Oynanır?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          '• Oyuna 5 can (kalp) ile başlarsınız.\n\n'
          '• Her kategori 3 Tur (30 soru) sürer.\n\n'
          '• Yanlış cevap verdiğinizde veya süreniz bittiğinde 1 can kaybedersiniz.\n\n'
          '• 3 Turu tamamladığınızda otomatik olarak bir sonraki kategoriye geçersiniz ve +1 CAN kazanırsınız!\n\n'
          '• Canınız 0 olduğunda oyun biter. Bol şans!',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anladım', style: TextStyle(color: Color(0xFFF472B6), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _startMarathon(int startIndex) async {
    HapticFeedback.selectionClick();
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => _QuizPlayScreen(
          category: _categories[startIndex],
          categoryIndex: startIndex,
        )));
    _loadAll();
  }

  Future<void> _handlePremiumCategoryClick(QuizCategory cat, int index) async {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C1B4D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded, color: Color(0xFFF472B6), size: 40),
              const SizedBox(height: 12),
              Text('${cat.name} Kilitli', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Bu kategori Sleepora Plus üyelerine özeldir. Hemen Plus\'a geçebilir veya ödüllü bir reklam izleyerek bu kategorinin kilidini sadece bu seferlik açabilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    PaywallScreen.showIfNeeded(context, feature: '${cat.name} Kategorisi');
                  },
                  icon: const Icon(Icons.star_rounded, color: Colors.white, size: 20),
                  label: const Text('Sleepora Plus\'a Geç', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final earned = await AdService().showRewarded(slot: RewardedSlot.quizUnlock);
                    if (earned && mounted) {
                      setState(() => _unlockedByAd.add(cat.name));
                      _startMarathon(index);
                    }
                  },
                  icon: const Icon(Icons.play_circle_outline_rounded, color: Colors.white),
                  label: const Text('Reklam İzle ve Aç', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Bilgi Yarışması', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700)),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const LeaderboardScreen(initialGameId: 'quiz'))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // ── BANNER GÖRSELİ ──
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 1080 / 600,
                child: Image.asset(
                  'assets/images/1080x600-banner_bilgiyarismasi.png',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ── BUTONLAR VE SKOR ──
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showHowToPlay,
                  icon: const Icon(Icons.help_outline_rounded, color: Colors.white, size: 18),
                  label: const Text('Nasıl Oynanır?', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _startMarathon(0),
                  icon: const Icon(Icons.play_arrow_rounded, color: Color(0xFF7C3AED), size: 20),
                  label: const Text('Oyuna Başla', style: TextStyle(color: Color(0xFF7C3AED), fontSize: 14, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 6,
                  ),
                ),
              ),
            ],
          ),
          if (_totalBest > 0) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 16),
                  const SizedBox(width: 6),
                  Text('Toplam Skor: $_totalBest',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text('Kategoriler (İstediğinden Başla)', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),
          ...List.generate(_categories.length, (catIdx) {
            final cat = _categories[catIdx];
            final isPremiumCat =
                PremiumContent.premiumQuizCategories.contains(cat.name) && !SubscriptionService().isPremium && !_unlockedByAd.contains(cat.name);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CategoryCard(
                category: cat,
                isPremium: isPremiumCat,
                bestScore: _bests[cat.name] ?? 0,
                onTap: () {
                  if (isPremiumCat) {
                    _handlePremiumCategoryClick(cat, catIdx);
                  } else {
                    _startMarathon(catIdx);
                  }
                },
              ),
            );
          }),
          // ─── Banner Reklam (Plus değilse) ───
          if (AdService().adsEnabled) ...[
            const SizedBox(height: 16),
            Center(child: BannerAdWidget(slot: BannerSlot.quizMenu)),
          ],
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final QuizCategory category;
  final VoidCallback onTap;
  final bool isPremium;
  final int bestScore;
  const _CategoryCard({
    required this.category,
    required this.onTap,
    this.isPremium = false,
    this.bestScore = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isPremium
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1A1025),
                    category.color.withValues(alpha: 0.08),
                  ],
                ),
          color: isPremium ? const Color(0xFF1A1025) : null,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: isPremium
                  ? Colors.white.withValues(alpha: 0.06)
                  : category.color.withValues(alpha: 0.2)),
          boxShadow: isPremium
              ? null
              : [
                  BoxShadow(
                    color: category.color.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: isPremium
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          category.color.withValues(alpha: 0.3),
                          category.color.withValues(alpha: 0.1),
                        ],
                      ),
                color: isPremium ? Colors.white.withValues(alpha: 0.06) : null,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: isPremium
                        ? Colors.transparent
                        : category.color.withValues(alpha: 0.35),
                    width: 1),
              ),
              child: Icon(category.icon,
                  color: isPremium ? Colors.white.withValues(alpha: 0.3) : category.color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(category.name,
                          style: TextStyle(
                            color: isPremium ? Colors.white.withValues(alpha: 0.5) : Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          )),
                      if (isPremium) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.diamond_outlined, color: Colors.white, size: 12),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.help_outline_rounded,
                          size: 12, color: Colors.white.withValues(alpha: isPremium ? 0.2 : 0.45)),
                      const SizedBox(width: 4),
                      Text('${category.questions.length} soru',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: isPremium ? 0.2 : 0.45),
                              fontSize: 12)),
                      if (!isPremium && bestScore > 0) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.star_rounded, size: 12, color: const Color(0xFFFFD700)),
                        const SizedBox(width: 3),
                        Text('$bestScore',
                            style: const TextStyle(
                                color: Color(0xFFFFD700),
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(isPremium ? Icons.lock_rounded : Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: isPremium ? 0.15 : 0.3),
                size: isPremium ? 20 : 24),
          ],
        ),
      ),
    );
  }
}

// ─── Floating score veri modeli ───
class _FloatingScore {
  final int value;
  final int multiplier;
  final int id;
  _FloatingScore({required this.value, required this.multiplier, required this.id});
}

// ─── Quiz Oyun Ekranı ───
class _QuizPlayScreen extends StatefulWidget {
  final QuizCategory category;
  final int categoryIndex;
  final int initialScore;
  const _QuizPlayScreen({
    required this.category,
    required this.categoryIndex,
    this.initialScore = 0,
  });

  @override
  State<_QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<_QuizPlayScreen> with TickerProviderStateMixin {
  late QuizCategory _currentCategory;
  late int _currentCategoryIndex;

  late List<QuizQuestion> _questions;
  int _currentIndex = 0;
  int _score = 0;
  int _correctCount = 0;
  int? _selectedOption;
  bool _answered = false;
  bool _finished = false;

  // ── Maraton ve Can Sistemi ──
  int _lives = 5;
  
  // ── Wave/Tur sistemi ──
  int _round = 1;
  bool _showRoundBanner = false;
  bool _showCategoryTransition = false;
  bool _categoryCompleted = false;
  List<int> _usedQuestionIndices = [];
  List<Map<String, dynamic>> _roundStats = [];
  int _roundStartScore = 0;
  int _roundCorrectStart = 0;

  // ── Floating score animasyonları ──
  List<_FloatingScore> _floatingScores = [];
  int _floatingScoreId = 0;

  // ── Streak/combo ──
  int _streak = 0;
  int _bestStreak = 0;
  int _comboFlashAt = 0;

  // ── Jokerler ──
  bool _usedFiftyFifty = false;
  bool _usedSkip = false;
  bool _usedAdLifeBonus = false; // Rewarded reklam jokeri (+1 Can, maraton başına 1 kez)
  bool _usedContinueAd = false; // Oyun sonu "+1 Can için reklam izle" — oyun başına 1 kez
  bool _isShowingAd = false; // Üst üste tıklamayı önlemek için
  bool _bannerAdFailed = false; // Reklam yüklenemezse bottomNavigationBar'ı tamamen null yapmak için
  Set<int> _hiddenOptions = {};

  // ── Zaman ──
  static const int _timePerQuestion = 15;
  static const int _questionsPerRound = 10;
  int _timeLeft = _timePerQuestion;
  Timer? _timer;

  // ── Animasyon kontrolleri ──
  late AnimationController _progressCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _transitionCtrl;
  late AnimationController _comboCtrl;
  late AnimationController _confettiCtrl;
  late AnimationController _roundBannerCtrl;

  final _rnd = Random();
  List<_ConfettiParticle> _confetti = [];

  @override
  void initState() {
    super.initState();
    _currentCategory = widget.category;
    _currentCategoryIndex = widget.categoryIndex;
    _score = widget.initialScore;
    
    _bootstrapPersistentSeen().then((_) {
      if (_currentIndex == 0 && !_answered && _questions.isNotEmpty && mounted) {
        final firstAnswered = _selectedOption != null;
        if (!firstAnswered) {
          setState(() {
            _usedQuestionIndices = [];
            _loadRoundQuestions();
          });
        }
      }
    });
    _loadRoundQuestions();

    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _timePerQuestion),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _transitionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..forward();
    _comboCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          _confetti = [];
          if (mounted) setState(() {});
        }
      });
    _roundBannerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _startTimer();
  }

  /// Kalıcı "yakında görüldü" cache'i — initState'te bir kez yüklenir.
  /// `_loadRoundQuestions` bu listeden hariç tutarak soru seçer,
  /// `_finalize` çağrıldığında bu round'da gösterilen sorular eklenir.
  List<String> _persistentSeenTexts = const [];

  Future<void> _bootstrapPersistentSeen() async {
    _persistentSeenTexts = await _loadSeenTexts(_currentCategory.name);
  }

  Future<void> _persistRoundAsSeen() async {
    // Round bitince gösterilen tüm sorularını "seen" listesine ekle (LRU cap'li)
    final newSeen = List<String>.from(_persistentSeenTexts);
    for (final q in _questions) {
      if (!newSeen.contains(q.question)) newSeen.add(q.question);
    }
    final cap = _seenCapFor(widget.category.questions.length);
    while (newSeen.length > cap) {
      newSeen.removeAt(0); // en eski düşer
    }
    _persistentSeenTexts = newSeen;
    await _saveSeenTexts(_currentCategory.name, newSeen);
  }

  void _loadRoundQuestions() {
    final indices = _pickRoundIndices(
      category: _currentCategory,
      usedThisSession: _usedQuestionIndices,
      persistentSeenTexts: _persistentSeenTexts,
      needed: _questionsPerRound,
      rnd: _rnd,
    );
    _usedQuestionIndices.addAll(indices);
    _questions = indices.map((i) => _currentCategory.questions[i]).toList();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progressCtrl.dispose();
    _pulseCtrl.dispose();
    _transitionCtrl.dispose();
    _comboCtrl.dispose();
    _confettiCtrl.dispose();
    _roundBannerCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timeLeft = _timePerQuestion;
    // Joker tarafından değiştirilmiş olabilen duration'ı her soru başında sıfırla
    _progressCtrl.duration = const Duration(seconds: _timePerQuestion);
    _progressCtrl.forward(from: 0);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _timeLeft--;
        if (_timeLeft == 5) HapticFeedback.selectionClick();
        if (_timeLeft <= 0) _timeUp();
      });
    });
  }

  void _handleWrong() {
    setState(() {
      _streak = 0;
      _lives--;
      if (_lives <= 0) {
        _finished = true;
        _finalize();
      }
    });
  }

  void _timeUp() {
    _timer?.cancel();
    _progressCtrl.stop();
    HapticFeedback.heavyImpact();
    setState(() {
      _answered = true;
      _selectedOption = -1;
    });
    
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      _handleWrong();
      if (!_finished) {
        _nextQuestion();
      }
    });
  }

  void _selectOption(int index) {
    if (_answered) return;
    if (_hiddenOptions.contains(index)) return;
    _timer?.cancel();
    _progressCtrl.stop();
    final isCorrect = index == _questions[_currentIndex].correctIndex;

    if (isCorrect) {
      HapticFeedback.lightImpact();
      _streak++;
      if (_streak > _bestStreak) _bestStreak = _streak;
      final multi = 1.0 + (_streak - 1) * 0.5;
      final mLimited = multi.clamp(1.0, 3.0);
      final base = 10 + _timeLeft;
      final gained = (base * mLimited).round();
      _score += gained;
      _correctCount++;
      _spawnConfetti();
      _confettiCtrl.forward(from: 0);

      // Floating score göster
      final fs = _FloatingScore(value: gained, multiplier: _streak, id: _floatingScoreId++);
      _floatingScores.add(fs);
      Future.delayed(const Duration(milliseconds: 1300), () {
        if (!mounted) return;
        setState(() => _floatingScores.removeWhere((f) => f.id == fs.id));
      });

      if (_streak >= 3) {
        _comboFlashAt = _streak;
        _comboCtrl.forward(from: 0);
        HapticFeedback.mediumImpact();
      }
    } else {
      HapticFeedback.mediumImpact();
      _streak = 0;
    }

    setState(() {
      _selectedOption = index;
      _answered = true;
    });
    
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      if (!isCorrect) {
        _handleWrong();
      }
      if (!_finished) {
        _nextQuestion();
      }
    });
  }

  void _nextQuestion() {
    if (!mounted || _finished) return;

    if (_currentIndex + 1 >= _questions.length) {
      // Tur bitti — istatistikleri kaydet
      final roundCorrect = _correctCount - _roundCorrectStart;
      final roundScore = _score - _roundStartScore;
      _roundStats.add({
        'round': _round,
        'correct': roundCorrect,
        'score': roundScore,
        'total': _questionsPerRound,
      });

      // Bu kategoride daha tur var mı? (Her kategoride maksimum 3 Tur oynanır)
      if (_round < 3 && _usedQuestionIndices.length < _currentCategory.questions.length) {
        // Yeni tur başlat
        _round++;
        _roundStartScore = _score;
        _roundCorrectStart = _correctCount;
        _usedFiftyFifty = false; // Jokerler her turda sıfırlanır
        _usedSkip = false;
        // _usedAdLifeBonus oyun başına 1 kezdir, burada sıfırlanmaz.
        setState(() => _showRoundBanner = true);
        _roundBannerCtrl.forward(from: 0);
        
        // ignore: discarded_futures
        _persistRoundAsSeen();
        
        Future.delayed(const Duration(milliseconds: 2400), () {
          if (!mounted) return;
          _loadRoundQuestions();
          setState(() {
            _showRoundBanner = false;
            _currentIndex = 0;
            _selectedOption = null;
            _answered = false;
            _hiddenOptions = {};
          });
          _transitionCtrl.forward(from: 0);
          _startTimer();
        });
      } else {
        // Kategorideki 3 tur tamamlandı (veya tüm sorular bitti), sonraki kategoriye geç
        // ignore: discarded_futures
        _persistRoundAsSeen();
        _transitionToNextCategory();
      }
      return;
    }
    
    setState(() {
      _currentIndex++;
      _selectedOption = null;
      _answered = false;
      _hiddenOptions = {};
    });
    _transitionCtrl.forward(from: 0);
    _startTimer();
  }

  void _transitionToNextCategory() {
    final nextIdx = _nextAvailableCategoryIndex();
    if (nextIdx == null) {
      // Oyun tamamen bitti (tüm kategoriler bitti)
      setState(() => _categoryCompleted = true);
      _finalize();
      return;
    }

    // Geçiş efekti ve can hediyesi
    setState(() {
      _showCategoryTransition = true;
      _lives++; // ÖDÜL: Her yeni kategoride +1 Can
    });
    
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      setState(() {
        _currentCategoryIndex = nextIdx;
        _currentCategory = _categories[nextIdx];
        _round = 1;
        _usedQuestionIndices.clear();
        _roundStartScore = _score;
        _roundCorrectStart = _correctCount;
        _usedFiftyFifty = false;
        _usedSkip = false;
        // _usedAdLifeBonus oyun/maraton boyunca sadece 1 kez kullanılabileceği için sıfırlanmıyor.
      });
      _bootstrapPersistentSeen().then((_) {
        _loadRoundQuestions();
        setState(() {
          _showCategoryTransition = false;
          _currentIndex = 0;
          _selectedOption = null;
          _answered = false;
          _hiddenOptions = {};
        });
        _transitionCtrl.forward(from: 0);
        _startTimer();
      });
    });
  }

  int? _nextAvailableCategoryIndex() {
    for (int i = _currentCategoryIndex + 1; i < _categories.length; i++) {
      // Not: Maraton başladığında tüm kategorileri gezeceği için,
      // premium kontrolü yapılmadan sonraki kategoriye geçiriyoruz.
      // Maraton oynayana hediye. Eğer istenirse kilitliler atlanabilir:
      // final isPrem = PremiumContent.premiumQuizCategories.contains(_categories[i].name) && !SubscriptionService().isPremium;
      // if (!isPrem) return i;
      return i; // Hepsini gez
    }
    return null;
  }

  /// 50:50 jokeri — iki yanlış seçeneği kaldırır
  void _useFiftyFifty() {
    if (_usedFiftyFifty || _answered) return;
    HapticFeedback.mediumImpact();
    final correct = _questions[_currentIndex].correctIndex;
    final wrongIndices = [0, 1, 2, 3].where((i) => i != correct).toList()..shuffle(_rnd);
    setState(() {
      _hiddenOptions = {wrongIndices[0], wrongIndices[1]};
      _usedFiftyFifty = true;
    });
  }

  /// Soru Atla jokeri — mevcut soruyu puansız atla
  void _useSkip() {
    if (_usedSkip || _answered) return;
    HapticFeedback.mediumImpact();
    _timer?.cancel();
    _progressCtrl.stop();
    _usedSkip = true;
    _streak = 0;
    _nextQuestion();
  }

  /// +1 Can rewarded reklam jokeri — oyun başına 1 kez.
  /// Plus üyelerde reklam gösterilmez ama joker yine bedava verilir.
  Future<void> _useAdLifeBonus() async {
    if (_usedAdLifeBonus || _answered || _isShowingAd) return;
    HapticFeedback.mediumImpact();
    
    setState(() => _isShowingAd = true);

    // Reklam yüklenirken / izlenirken zamanı dondur
    final wasRunning = _timer?.isActive ?? false;
    _timer?.cancel();
    _progressCtrl.stop();
    
    final ok = await AdService().showRewarded(
      slot: RewardedSlot.quizJoker,
      onAdShown: () {
        // Reklam tam ekrana gelince timer zaten durdu — ek iş yok
      },
      onAdClosed: () {
        // Reklam kapandığında resume aşağıda yapılıyor
      },
    );
    
    if (!mounted) return;
    setState(() => _isShowingAd = false);

    if (ok) {
      // +1 Can ekle
      setState(() {
        _usedAdLifeBonus = true;
        _lives++;
      });
      // Reklam sonrası timer'ı resume et
      if (wasRunning && !_answered) {
        _restartTimerWithSeconds(_timeLeft.clamp(1, _timePerQuestion));
      }
    } else {
      // Reklam yüklenmediyse veya kapatıldıysa aynı kalan süreyle devam
      if (wasRunning && !_answered) {
        _restartTimerWithSeconds(_timeLeft.clamp(1, _timePerQuestion));
      }
    }
  }

  /// Oyun sonu — canlar bitince "+1 Can için reklam izle" akışı.
  /// Tek seferlik: kullanıldıktan sonra bir daha gösterilmez, oyun normal biter.
  Future<void> _useContinueAd() async {
    if (_usedContinueAd || _isShowingAd) return;
    HapticFeedback.mediumImpact();

    setState(() => _isShowingAd = true);

    final ok = await AdService().showRewarded(
      slot: RewardedSlot.quizJoker,
    );

    if (!mounted) return;
    setState(() => _isShowingAd = false);

    if (ok) {
      // +1 Can ver, oyunu kaldığı yerden bir sonraki soruyla sürdür
      setState(() {
        _usedContinueAd = true;
        _lives = 1;
        _finished = false;
        _selectedOption = null;
        _answered = false;
        _hiddenOptions = {};
      });
      _nextQuestion();
    }
    // Reklam yüklenmediyse / kullanıcı kapadıysa: sonuç ekranı aynen kalır,
    // _usedContinueAd false kalır ki kullanıcı tekrar deneyebilsin.
  }

  /// Reklam banner'ı — Plus değilse gösterilir, oyun ekranında sabit duruyor.
  /// Hem soru ekranı hem sonuç hem kategori-tamamlandı ekranlarında ortak.
  Widget? _buildAdBanner() {
    if (!AdService().adsEnabled || _bannerAdFailed) return null;
    return SafeArea(
      top: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: BannerAdWidget(
            slot: BannerSlot.quizMenu,
            onAdFailed: () {
              if (mounted) {
                setState(() {
                  _bannerAdFailed = true;
                });
              }
            },
          ),
        ),
      ),
    );
  }

  /// Belirtilen saniye sayısıyla timer + progress bar'ı yeniden başlatır.
  /// Joker veya pause/resume durumlarında kullanılır.
  void _restartTimerWithSeconds(int seconds) {
    _timer?.cancel();
    _progressCtrl.stop();
    _progressCtrl.duration = Duration(seconds: seconds);
    _progressCtrl.forward(from: 0);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _timeLeft--;
        if (_timeLeft == 5) HapticFeedback.selectionClick();
        if (_timeLeft <= 0) _timeUp();
      });
    });
  }

  void _spawnConfetti() {
    _confetti = [];
    final count = 24;
    final colors = [
      _currentCategory.color,
      const Color(0xFFFFD700),
      const Color(0xFF10B981),
      const Color(0xFFEC4899),
      Colors.white,
    ];
    for (int i = 0; i < count; i++) {
      final angle = -pi / 2 + (_rnd.nextDouble() - 0.5) * pi * 1.1;
      final speed = 280.0 + _rnd.nextDouble() * 260.0;
      _confetti.add(_ConfettiParticle(
        startX: 0.5,
        startY: 0.45,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        gravity: 680,
        color: colors[_rnd.nextInt(colors.length)],
        size: 6.0 + _rnd.nextDouble() * 6.0,
        rotation: _rnd.nextDouble() * 2 * pi,
        rotSpeed: (_rnd.nextDouble() - 0.5) * 10,
      ));
    }
  }

  void _finalize() async {
    final isNewBest = await _saveBest(_currentCategory.name, _score);
    if (isNewBest && mounted) {
      HapticFeedback.heavyImpact();
    }
    _submitScore();
    // Bu round'da gösterilen soruları "yakında görüldü" listesine yaz
    // (kategori başına LRU). Kullanıcı tekrar oynadığında hariç tutulur.
    // ignore: discarded_futures
    _persistRoundAsSeen();
  }

  Future<void> _submitScore() async {
    final auth = AuthService();
    if (!auth.isLoggedIn || auth.uid == null) return;
    try {
      await LeaderboardService().submitScore(
        gameId: 'quiz',
        uid: auth.uid!,
        displayName: auth.displayName ?? 'Anonim',
        score: _score,
        higherIsBetter: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocalizationService().t('ScoreSaved')),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.purple,
        ),
      );
    } catch (e) {
      debugPrint('❌ Quiz submitScore hatası: $e');
    }
  }

  Future<void> _promptLoginAndSubmit() async {
    HapticFeedback.selectionClick();
    final ok = await LoginScreen.show(context, feature: 'Skor Tablosu');
    if (!ok || !mounted) return;
    await _submitScore();
    if (mounted) setState(() {});
  }

  Color _optionColor(int index) {
    if (!_answered) return Colors.white.withValues(alpha: 0.04);
    if (index == _questions[_currentIndex].correctIndex) {
      return const Color(0xFF10B981).withValues(alpha: 0.28);
    }
    if (index == _selectedOption) return const Color(0xFFEF4444).withValues(alpha: 0.28);
    return Colors.white.withValues(alpha: 0.04);
  }

  Color _optionBorderColor(int index) {
    if (!_answered) return Colors.white.withValues(alpha: 0.08);
    if (index == _questions[_currentIndex].correctIndex) return const Color(0xFF10B981);
    if (index == _selectedOption) return const Color(0xFFEF4444);
    return Colors.white.withValues(alpha: 0.08);
  }

  IconData? _optionIcon(int index) {
    if (!_answered) return null;
    if (index == _questions[_currentIndex].correctIndex) return Icons.check_circle_rounded;
    if (index == _selectedOption) return Icons.cancel_rounded;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🎯 [QUIZ_DEBUG] build çağrıldı: category=${_currentCategory.name}, '
        '_questions.length=${_questions.length}, _currentIndex=$_currentIndex, '
        '_categoryCompleted=$_categoryCompleted, _finished=$_finished, '
        '_lives=$_lives, _transitionCtrl.value=${_transitionCtrl.value.toStringAsFixed(2)}');

    if (_categoryCompleted) return _buildCategoryCompleteScreen();
    if (_finished) return _buildResultScreen();

    // Safety: _questions boşsa bile crash etmesin, açıklayıcı placeholder göster
    if (_questions.isEmpty) {
      debugPrint('⚠️ [QUIZ_DEBUG] _questions BOŞ! _loadRoundQuestions başarısız');
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(_currentCategory.name,
              style: const TextStyle(color: Colors.white)),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Soru havuzu yüklenemedi.\nLütfen tekrar deneyin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ),
      );
    }

    final q = _questions[_currentIndex];

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: _buildAdBanner(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_currentCategory.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
            Text('➡️ Tur $_round',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
          ],
        ),
        centerTitle: true,
        actions: [
          // ── CAN Göstergesi ──
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite_rounded, color: Color(0xFFEF4444), size: 16),
                    const SizedBox(width: 4),
                    Text('$_lives',
                        style: const TextStyle(color: Color(0xFFEF4444), fontSize: 14, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: Container(
                  key: ValueKey('score_$_score'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _currentCategory.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _currentCategory.color.withValues(alpha: 0.35)),
                  ),
                  child: Text('$_score',
                      style: TextStyle(
                          color: _currentCategory.color, fontSize: 14, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ),
        ],
      ),
      // ÖNEMLİ: Ana içeriği Positioned.fill ile sarıyoruz — bu Stack'in
      // hangi fit mode'da olduğundan bağımsız olarak child'a TIGHT constraints
      // verir (top:0, left:0, right:0, bottom:0). Önceki StackFit.expand
      // yaklaşımı bazı iPhone'larda hala boş ekran veriyordu. Bu garantili çözüm.
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Ana içerik
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // İlerleme barı (noktalar)
                  Row(
                    children: List.generate(_questions.length, (i) {
                      Color dotColor;
                      if (i < _currentIndex) {
                        dotColor = AppColors.purple;
                      } else if (i == _currentIndex) {
                        dotColor = _currentCategory.color;
                      } else {
                        dotColor = Colors.white.withValues(alpha: 0.1);
                      }
                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                              color: dotColor, borderRadius: BorderRadius.circular(2)),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 14),
  
                  // Üst bilgi çubuğu: Soru numarası + streak + dairesel timer
                  Row(
                    children: [
                      Text('Soru ${_currentIndex + 1}/${_questions.length}',
                          style:
                              TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
                      const Spacer(),
                      if (_streak >= 2)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B6B), Color(0xFFFFD700)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6B6B).withValues(alpha: 0.4),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Text('🔥', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 3),
                            Text('$_streak',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                          ]),
                        ),
                    ],
                  ),
  
                  const SizedBox(height: 18),
  
                  // Dairesel timer
                  SizedBox(
                    height: 92,
                    width: 92,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_progressCtrl, _pulseCtrl]),
                      builder: (context, _) {
                        final danger = _timeLeft <= 5;
                        final pulse = danger ? 1.0 + 0.08 * _pulseCtrl.value : 1.0;
                        final tColor = danger ? const Color(0xFFEF4444) : widget.category.color;
                        return Transform.scale(
                          scale: pulse,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 92,
                                height: 92,
                                child: CircularProgressIndicator(
                                  value: 1 - _progressCtrl.value,
                                  strokeWidth: 6,
                                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                                  valueColor: AlwaysStoppedAnimation<Color>(tColor),
                                  strokeCap: StrokeCap.round,
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('$_timeLeft',
                                      style: TextStyle(
                                        color: tColor,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                        height: 1,
                                      )),
                                  Text('sn',
                                      style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.5),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
  
                  const SizedBox(height: 18),
  
                  // Jokerler
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _JokerChip(
                        icon: '50:50',
                        label: '50:50',
                        used: _usedFiftyFifty,
                        color: widget.category.color,
                        onTap: _useFiftyFifty,
                      ),
                      const SizedBox(width: 10),
                      _JokerChip(
                        icon: null,
                        iconData: Icons.skip_next_rounded,
                        label: 'Atla',
                        used: _usedSkip,
                        color: widget.category.color,
                        onTap: _useSkip,
                      ),
                      const SizedBox(width: 10),
                      _JokerChip(
                        icon: null,
                        iconData: Icons.favorite_rounded,
                        label: '+1 Can',
                        used: _usedAdLifeBonus,
                        color: _currentCategory.color,
                        onTap: _useAdLifeBonus,
                      ),
                    ],
                  ),
  
                  const SizedBox(height: 18),
  
                  // Soru kartı — fade+slide geçiş
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _transitionCtrl,
                      builder: (context, _) {
                        final t = Curves.easeOutCubic.transform(_transitionCtrl.value);
                        return Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, 28 * (1 - t)),
                            child: Column(
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(22),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        const Color(0xFF1A1025),
                                        widget.category.color.withValues(alpha: 0.08),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: widget.category.color.withValues(alpha: 0.22)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: widget.category.color.withValues(alpha: 0.1),
                                        blurRadius: 18,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Text(q.question,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        height: 1.4,
                                      ),
                                      textAlign: TextAlign.center),
                                ),
                                const SizedBox(height: 18),
                                ...List.generate(q.options.length, (i) {
                                  return _AnswerOption(
                                    index: i,
                                    text: q.options[i],
                                    hidden: _hiddenOptions.contains(i),
                                    backgroundColor: _optionColor(i),
                                    borderColor: _optionBorderColor(i),
                                    icon: _optionIcon(i),
                                    isCorrect: _answered &&
                                        i == _questions[_currentIndex].correctIndex,
                                    isWrong: _answered && i == _selectedOption && i != _questions[_currentIndex].correctIndex,
                                    onTap: () => _selectOption(i),
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
  
            // Confetti overlay
            if (_confetti.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _confettiCtrl,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _ConfettiPainter(
                          particles: _confetti,
                          progress: _confettiCtrl.value,
                          totalDurationSec: 1.1,
                        ),
                      );
                    },
                  ),
                ),
              ),
  
            // Combo rozeti
            if (_streak >= 3)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _comboCtrl,
                    builder: (context, _) {
                      if (!_comboCtrl.isAnimating && _comboCtrl.value == 0) {
                        return const SizedBox.shrink();
                      }
                      final t = _comboCtrl.value;
                      final inT = (t / 0.25).clamp(0.0, 1.0);
                      final outT = ((t - 0.7) / 0.3).clamp(0.0, 1.0);
                      final scale = 0.4 + 0.7 * Curves.easeOutBack.transform(inT);
                      final opacity = (1 - outT).clamp(0.0, 1.0);
                      return Center(
                        child: Transform.translate(
                          offset: Offset(0, -40 * inT - 20 * outT),
                          child: Opacity(
                            opacity: opacity,
                            child: Transform.scale(
                              scale: scale,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFFD700), Color(0xFFFF6B6B)],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF6B6B).withValues(alpha: 0.6),
                                      blurRadius: 24,
                                    ),
                                  ],
                                ),
                                child: Text('🔥 COMBO x$_comboFlashAt',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                      shadows: [Shadow(color: Colors.black38, blurRadius: 6)],
                                    )),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            // Floating score overlay
            ...(_floatingScores.map((fs) => Positioned(
              top: 110,
              left: 0,
              right: 0,
              child: _FloatingScoreWidget(floatingScore: fs),
            ))),
  
            // Round banner overlay
            if (_showRoundBanner)
              Positioned.fill(
                child: _buildRoundBannerOverlay(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundBannerOverlay() {
    return AnimatedBuilder(
      animation: _roundBannerCtrl,
      builder: (context, _) {
        final t = _roundBannerCtrl.value;
        final scale = 0.5 + 0.5 * Curves.elasticOut.transform(t.clamp(0.0, 1.0));
        final opacity = t < 0.8 ? 1.0 : 1.0 - (t - 0.8) / 0.2;
        return Container(
          color: Colors.black.withValues(alpha: 0.72),
          child: Center(
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🌊', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [widget.category.color, widget.category.color.withValues(alpha: 0.6)],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: widget.category.color.withValues(alpha: 0.5),
                            blurRadius: 28,
                          ),
                        ],
                      ),
                      child: Text('TUR $_round BAŞLİYOR!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          )),
                    ),
                    const SizedBox(height: 10),
                    Text('Devam ediyor...', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultScreen() {
    // Tur bitmeden süre dolarsa _roundStats boş olabilir; o durumda
    // şu ana kadar sorulan soru sayısını (_currentIndex + 1) kullan.
    final completedFromStats = _roundStats.fold(0, (s, r) => s + (r['total'] as int));
    final totalQuestions = completedFromStats > 0 ? completedFromStats : (_currentIndex + 1);
    final percentage = totalQuestions > 0 ? (_correctCount / totalQuestions * 100).round() : 0;
    String emoji;
    String message;
    int starCount;
    if (percentage >= 90) {
      emoji = '🏆';
      message = 'Efsane! Mükemmel skor!';
      starCount = 3;
    } else if (percentage >= 70) {
      emoji = '🌟';
      message = 'Harika iş! Çok iyisin!';
      starCount = 3;
    } else if (percentage >= 50) {
      emoji = '👏';
      message = 'İyi gidiyorsun, devam!';
      starCount = 2;
    } else if (percentage >= 30) {
      emoji = '💪';
      message = 'Fena değil, gelişiyorsun!';
      starCount = 1;
    } else {
      emoji = '📚';
      message = 'Biraz daha çalışmalısın!';
      starCount = 0;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: _buildAdBanner(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Yıldızlar — sıralı animasyonla belirir
              _StarsRow(starCount: starCount, color: widget.category.color),
              const SizedBox(height: 18),
              Text(emoji, style: const TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              const Text('Yarışma Bitti!',
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(message,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 15),
                  textAlign: TextAlign.center),
              const SizedBox(height: 26),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1A1025),
                      widget.category.color.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: widget.category.color.withValues(alpha: 0.25)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _ResultStat(label: LocalizationService().t('Score'), value: '$_score', color: widget.category.color),
                        _ResultStat(
                            label: LocalizationService().t('QuizCorrect'),
                            value: '$_correctCount/$totalQuestions',
                            color: const Color(0xFF10B981)),
                        _ResultStat(
                            label: LocalizationService().t('QuizSuccess'),
                            value: '%$percentage',
                            color: const Color(0xFFF59E0B)),
                      ],
                    ),
                    if (_roundStats.length > 1) ...[
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: Colors.white12),
                      const SizedBox(height: 10),
                      Text('Tur Detayları',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12)),
                      const SizedBox(height: 8),
                      ..._roundStats.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('🌊 Tur ${r['round']}',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                            Text('${r['correct']}/${r['total']} doğru',
                                style: TextStyle(color: const Color(0xFF10B981).withValues(alpha: 0.8), fontSize: 12)),
                            Text('+${r['score']} puan',
                                style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      )),
                    ],
                    if (_bestStreak >= 2) ...[
                      const SizedBox(height: 10),
                      const Divider(height: 1, color: Colors.white12),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 6),
                          Text('En uzun streak: ',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
                          Text('$_bestStreak',
                              style: const TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              // ── "+1 Can için Reklam İzle" — sadece canlar bittiyse ve henüz kullanılmadıysa ──
              if (!_usedContinueAd && _lives <= 0) ...[
                GestureDetector(
                  onTap: _isShowingAd ? null : _useContinueAd,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFF97316)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isShowingAd
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.play_circle_fill_rounded,
                                    color: Colors.white, size: 22),
                                SizedBox(width: 8),
                                Text('Reklam İzle, +1 Can Kazan',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800)),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(children: [
                Expanded(
                    child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16)),
                    child: const Center(
                        child: Text('Kategoriler',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600))),
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                     setState(() {
                      _usedQuestionIndices = [];
                      _roundStats = [];
                      _round = 1;
                      _roundStartScore = 0;
                      _roundCorrectStart = 0;
                      _currentIndex = 0;
                      _score = widget.initialScore;
                      _correctCount = 0;
                      _streak = 0;
                      _bestStreak = 0;
                      _lives = 5; // ⬅️ Canları sıfırla — Tekrar Oyna basıldığında 5 cana geri dön
                      _usedFiftyFifty = false;
                      _usedSkip = false;
                      _usedAdLifeBonus = false;
                      _usedContinueAd = false; // Yeni oyun → reklam hakkı tekrar açık
                      _bannerAdFailed = false; // Reklam durumunu sıfırla
                      _hiddenOptions = {};
                      _selectedOption = null;
                      _answered = false;
                      _finished = false;
                      _categoryCompleted = false;
                    });
                    _loadRoundQuestions();
                    _startTimer(); // ⬅️ Timer'ı yeniden başlat (oyun sonunda iptal edilmişti)
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        widget.category.color,
                        widget.category.color.withValues(alpha: 0.7)
                      ]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: widget.category.color.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                        child: Text('Tekrar Oyna',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700))),
                  ),
                )),
              ]),
              const SizedBox(height: 12),
              // ─── Giriş yapılmamışsa: skor kaydetme CTA'sı ───
              if (!AuthService().isLoggedIn)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: _promptLoginAndSubmit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFFBBF24)
                              .withValues(alpha: 0.55),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_outline_rounded,
                              color: Color(0xFFFBBF24), size: 18),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              LocalizationService()
                                  .t('LeaderboardLoginRequired'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded,
                              color: Colors.white70, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const LeaderboardScreen(initialGameId: 'quiz'))),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(LocalizationService().t('Leaderboard'),
                          style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCompleteScreen() {
    final nextImmediateIdx = widget.categoryIndex + 1 < _categories.length ? widget.categoryIndex + 1 : null;
    final nextImmediateCat = nextImmediateIdx != null ? _categories[nextImmediateIdx] : null;
    final isNextImmediatePremium = nextImmediateCat != null && 
        PremiumContent.premiumQuizCategories.contains(nextImmediateCat.name) && 
        !SubscriptionService().isPremium;

    final nextFreeIdx = _nextAvailableCategoryIndex();
    final nextFreeCat = nextFreeIdx != null ? _categories[nextFreeIdx] : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: _buildAdBanner(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Text('🎉', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text(widget.category.name,
                  style: TextStyle(
                      color: widget.category.color,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('Kategoriyi Tamamladın!',
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('$_round tur oynadın, ${_correctCount} soru doğru!',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              // Toplam skor kutusu
              Container(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF1A1025), widget.category.color.withValues(alpha: 0.12)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: widget.category.color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ResultStat(label: LocalizationService().t('Score'), value: '$_score', color: widget.category.color),
                    _ResultStat(label: LocalizationService().t('Round'), value: '$_round', color: const Color(0xFFFFD700)),
                    _ResultStat(label: LocalizationService().t('QuizCorrect'), value: '$_correctCount', color: const Color(0xFF10B981)),
                  ],
                ),
              ),
              const Spacer(),
              // Premium Yönlendirme VEYA Sonraki Kategori Butonları
              if (isNextImmediatePremium) ...[
                GestureDetector(
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    final purchased = await PaywallScreen.showIfNeeded(context, feature: '${nextImmediateCat.name} Kategorisi');
                    if (purchased == true && mounted) {
                      Navigator.pushReplacement(context, MaterialPageRoute(
                          builder: (_) => _QuizPlayScreen(
                            category: nextImmediateCat,
                            categoryIndex: nextImmediateIdx!,
                            initialScore: _score,
                          )));
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFC084FC)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text('Plus\'a Geç ve Oyna: ${nextImmediateCat.name}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (nextFreeCat != null)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.pushReplacement(context, MaterialPageRoute(
                          builder: (_) => _QuizPlayScreen(
                            category: nextFreeCat,
                            categoryIndex: nextFreeIdx!,
                            initialScore: _score,
                          )));
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(nextFreeCat.icon, color: Colors.white70, size: 18),
                          const SizedBox(width: 8),
                          Text('Ücretsiz Devam Et: ${nextFreeCat.name}',
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 16),
                        ],
                      ),
                    ),
                  ),
              ] else if (nextImmediateCat != null) ...[
                // Standart Sonraki Kategori Butonu (Eğer premium kısıtlaması yoksa)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pushReplacement(context, MaterialPageRoute(
                        builder: (_) => _QuizPlayScreen(
                          category: nextImmediateCat,
                          categoryIndex: nextImmediateIdx!,
                          initialScore: _score,
                        )));
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        nextImmediateCat.color,
                        nextImmediateCat.color.withValues(alpha: 0.7)
                      ]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: nextImmediateCat.color.withValues(alpha: 0.4),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(nextImmediateCat.icon, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Text('Sonraki: ${nextImmediateCat.name}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                          child: Text('Bitir',
                              style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600))),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const LeaderboardScreen(initialGameId: 'quiz'))),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('🏆', style: TextStyle(fontSize: 16)),
                          SizedBox(width: 8),
                          Text('Liderlik',
                              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Floating score animasyon widget'i ───
class _FloatingScoreWidget extends StatefulWidget {
  final _FloatingScore floatingScore;
  const _FloatingScoreWidget({required this.floatingScore});

  @override
  State<_FloatingScoreWidget> createState() => _FloatingScoreWidgetState();
}

class _FloatingScoreWidgetState extends State<_FloatingScoreWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slideY;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _slideY = Tween<double>(begin: 0, end: -60).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: 1), weight: 20),
      TweenSequenceItem(tween: Tween<double>(begin: 1, end: 1), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1, end: 0), weight: 30),
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final multi = widget.floatingScore.multiplier;
    final val = widget.floatingScore.value;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: _opacity.value,
        child: Transform.translate(
          offset: Offset(0, _slideY.value),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFF6B6B)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Text(
                multi >= 2 ? '+$val 🔥x$multi' : '+$val',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }}

class _ResultStat extends StatelessWidget {
  final String label; final String value; final Color color;
  const _ResultStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha:0.4), fontSize: 12)),
    ]);
  }
}

// ─── Joker chip (50:50 + Atla) ───
class _JokerChip extends StatelessWidget {
  final String? icon;
  final IconData? iconData;
  final String label;
  final bool used;
  final Color color;
  final VoidCallback onTap;
  const _JokerChip({
    this.icon,
    this.iconData,
    required this.label,
    required this.used,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: used ? 0.35 : 1.0,
      child: GestureDetector(
        onTap: used ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: used
                ? null
                : LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.25),
                      color.withValues(alpha: 0.1),
                    ],
                  ),
            color: used ? Colors.white.withValues(alpha: 0.05) : null,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: color.withValues(alpha: used ? 0.1 : 0.45), width: 1.2),
            boxShadow: used
                ? null
                : [
                    BoxShadow(
                      color: color.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (iconData != null)
              Icon(iconData, color: Colors.white, size: 18)
            else if (icon != null)
              Text(icon!,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

// ─── Cevap seçeneği (hidden + shake animasyonu) ───
class _AnswerOption extends StatefulWidget {
  final int index;
  final String text;
  final bool hidden;
  final Color backgroundColor;
  final Color borderColor;
  final IconData? icon;
  final bool isCorrect;
  final bool isWrong;
  final VoidCallback onTap;
  const _AnswerOption({
    required this.index,
    required this.text,
    required this.hidden,
    required this.backgroundColor,
    required this.borderColor,
    required this.icon,
    required this.isCorrect,
    required this.isWrong,
    required this.onTap,
  });

  @override
  State<_AnswerOption> createState() => _AnswerOptionState();
}

class _AnswerOptionState extends State<_AnswerOption>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeCtrl;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void didUpdateWidget(covariant _AnswerOption old) {
    super.didUpdateWidget(old);
    if (widget.isWrong && !old.isWrong) {
      _shakeCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final letter = String.fromCharCode(65 + widget.index);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 260),
      opacity: widget.hidden ? 0.15 : 1.0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 260),
        offset: widget.hidden ? const Offset(-0.1, 0) : Offset.zero,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: widget.hidden ? null : widget.onTap,
            child: AnimatedBuilder(
              animation: _shakeCtrl,
              builder: (context, child) {
                final v = _shakeCtrl.value;
                final dx = v == 0 ? 0.0 : sin(v * pi * 5) * 8 * (1 - v);
                return Transform.translate(
                  offset: Offset(dx, 0),
                  child: child,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: widget.borderColor, width: 1.5),
                  boxShadow: widget.isCorrect
                      ? [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.45),
                            blurRadius: 16,
                          ),
                        ]
                      : null,
                ),
                child: Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(letter,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(widget.text,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500)),
                  ),
                  if (widget.icon != null)
                    Icon(widget.icon,
                        color: widget.isCorrect
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                        size: 22),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sonuç ekranı yıldızları ───
class _StarsRow extends StatefulWidget {
  final int starCount; // 0..3
  final Color color;
  const _StarsRow({required this.starCount, required this.color});

  @override
  State<_StarsRow> createState() => _StarsRowState();
}

class _StarsRowState extends State<_StarsRow> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              // Her yıldız gecikmeli belirir
              final start = i * 0.25;
              final localT = ((_ctrl.value - start) / 0.45).clamp(0.0, 1.0);
              final filled = i < widget.starCount;
              final scale = filled
                  ? 0.4 + 0.6 * Curves.elasticOut.transform(localT.clamp(0.0, 1.0))
                  : 0.3 + 0.7 * localT;
              final opacity = localT;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 52,
                      color: filled
                          ? const Color(0xFFFFD700)
                          : Colors.white.withValues(alpha: 0.2),
                      shadows: filled
                          ? [
                              Shadow(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.55),
                                blurRadius: 18,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

// ─── Confetti ───
class _ConfettiParticle {
  final double startX; // ekran oranı (0..1)
  final double startY; // ekran oranı (0..1)
  final double vx;
  final double vy;
  final double gravity;
  final Color color;
  final double size;
  final double rotation;
  final double rotSpeed;
  _ConfettiParticle({
    required this.startX,
    required this.startY,
    required this.vx,
    required this.vy,
    required this.gravity,
    required this.color,
    required this.size,
    required this.rotation,
    required this.rotSpeed,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;
  final double totalDurationSec;
  _ConfettiPainter({
    required this.particles,
    required this.progress,
    required this.totalDurationSec,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final tSec = progress * totalDurationSec;
    for (final p in particles) {
      final x = p.startX * size.width + p.vx * tSec;
      final y = p.startY * size.height + p.vy * tSec + 0.5 * p.gravity * tSec * tSec;
      final alpha = (1 - progress).clamp(0.0, 1.0);
      final sz = p.size * (1 - progress * 0.25);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + p.rotSpeed * tSec);

      final paint = Paint()..color = p.color.withValues(alpha: alpha);
      // Dikdörtgen konfeti parçası
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: sz * 1.4, height: sz * 0.7),
          Radius.circular(sz * 0.2),
        ),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.progress != progress || old.particles != particles;
}
