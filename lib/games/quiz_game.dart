import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/subscription_service.dart';
import '../screens/paywall_screen.dart';

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

// ─── Soru Bankası (100 soru — her kategoride 20) ───
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
    ],
  ),
];

// ─── Quiz Ana Ekranı ───
class QuizGame extends StatelessWidget {
  const QuizGame({super.key});

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
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 40),
                const SizedBox(height: 8),
                const Text('Kategori Seç', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Her kategoride 10 soru • 15 saniye süre', style: TextStyle(color: Colors.white.withValues(alpha:0.7), fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ..._categories.map((cat) {
            final isPremiumCat = PremiumContent.premiumQuizCategories.contains(cat.name) && !SubscriptionService().isPremium;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CategoryCard(
                category: cat,
                isPremium: isPremiumCat,
                onTap: () async {
                  if (isPremiumCat) {
                    await PaywallScreen.showIfNeeded(context, feature: '${cat.name} Kategorisi');
                    return;
                  }
                  Navigator.push(context,
                    MaterialPageRoute(builder: (_) => _QuizPlayScreen(category: cat)));
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final QuizCategory category;
  final VoidCallback onTap;
  final bool isPremium;
  const _CategoryCard({required this.category, required this.onTap, this.isPremium = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1025),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isPremium ? Colors.white.withValues(alpha:0.06) : category.color.withValues(alpha:0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: isPremium ? Colors.white.withValues(alpha:0.06) : category.color.withValues(alpha:0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(category.icon, color: isPremium ? Colors.white.withValues(alpha:0.3) : category.color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(category.name, style: TextStyle(
                        color: isPremium ? Colors.white.withValues(alpha:0.5) : Colors.white,
                        fontSize: 15, fontWeight: FontWeight.w600,
                      )),
                      if (isPremium) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha:0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.diamond_outlined, color: Colors.white, size: 12),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('${category.questions.length} soru', style: TextStyle(color: Colors.white.withValues(alpha:isPremium ? 0.2 : 0.4), fontSize: 12)),
                ],
              ),
            ),
            Icon(isPremium ? Icons.lock_rounded : Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha:isPremium ? 0.15 : 0.3), size: isPremium ? 20 : 24),
          ],
        ),
      ),
    );
  }
}

// ─── Quiz Oyun Ekranı ───
class _QuizPlayScreen extends StatefulWidget {
  final QuizCategory category;
  const _QuizPlayScreen({required this.category});

  @override
  State<_QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<_QuizPlayScreen> with SingleTickerProviderStateMixin {
  late List<QuizQuestion> _questions;
  int _currentIndex = 0;
  int _score = 0;
  int _correctCount = 0;
  int? _selectedOption;
  bool _answered = false;
  bool _finished = false;

  static const int _timePerQuestion = 15;
  static const int _questionsPerRound = 10;
  int _timeLeft = _timePerQuestion;
  Timer? _timer;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    // Tüm soruları karıştır ve 10 tanesini seç
    _questions = List.from(widget.category.questions)..shuffle(Random());
    _questions = _questions.take(_questionsPerRound).toList();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _timePerQuestion),
    );
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timeLeft = _timePerQuestion;
    _progressController.forward(from: 0);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _timeLeft--;
        if (_timeLeft <= 0) _timeUp();
      });
    });
  }

  void _timeUp() {
    _timer?.cancel();
    _progressController.stop();
    setState(() { _answered = true; _selectedOption = -1; });
    Future.delayed(const Duration(milliseconds: 1500), _nextQuestion);
  }

  void _selectOption(int index) {
    if (_answered) return;
    _timer?.cancel();
    _progressController.stop();
    final isCorrect = index == _questions[_currentIndex].correctIndex;
    setState(() {
      _selectedOption = index;
      _answered = true;
      if (isCorrect) { _score += 10 + _timeLeft; _correctCount++; }
    });
    Future.delayed(const Duration(milliseconds: 1500), _nextQuestion);
  }

  void _nextQuestion() {
    if (!mounted) return;
    if (_currentIndex + 1 >= _questions.length) {
      setState(() => _finished = true);
      return;
    }
    setState(() { _currentIndex++; _selectedOption = null; _answered = false; });
    _startTimer();
  }

  Color _optionColor(int index) {
    if (!_answered) return Colors.white.withValues(alpha:0.04);
    if (index == _questions[_currentIndex].correctIndex) return const Color(0xFF10B981).withValues(alpha:0.25);
    if (index == _selectedOption) return const Color(0xFFEF4444).withValues(alpha:0.25);
    return Colors.white.withValues(alpha:0.04);
  }

  Color _optionBorderColor(int index) {
    if (!_answered) return Colors.white.withValues(alpha:0.08);
    if (index == _questions[_currentIndex].correctIndex) return const Color(0xFF10B981);
    if (index == _selectedOption) return const Color(0xFFEF4444);
    return Colors.white.withValues(alpha:0.08);
  }

  IconData? _optionIcon(int index) {
    if (!_answered) return null;
    if (index == _questions[_currentIndex].correctIndex) return Icons.check_circle_rounded;
    if (index == _selectedOption) return Icons.cancel_rounded;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return _buildResultScreen();
    final q = _questions[_currentIndex];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: Text(widget.category.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
        centerTitle: true,
        actions: [
          Padding(padding: const EdgeInsets.only(right: 16), child: Center(
            child: Text('Skor: $_score', style: TextStyle(color: AppColors.purple, fontSize: 14, fontWeight: FontWeight.w700)),
          )),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            // İlerleme barı
            Row(
              children: List.generate(_questions.length, (i) {
                Color dotColor;
                if (i < _currentIndex) dotColor = AppColors.purple;
                else if (i == _currentIndex) dotColor = widget.category.color;
                else dotColor = Colors.white.withValues(alpha:0.1);
                return Expanded(child: Container(
                  height: 4, margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(color: dotColor, borderRadius: BorderRadius.circular(2)),
                ));
              }),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Soru ${_currentIndex + 1}/${_questions.length}', style: TextStyle(color: Colors.white.withValues(alpha:0.5), fontSize: 13)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _timeLeft <= 5 ? const Color(0xFFEF4444).withValues(alpha:0.2) : widget.category.color.withValues(alpha:0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.timer_rounded, color: _timeLeft <= 5 ? const Color(0xFFEF4444) : widget.category.color, size: 16),
                    const SizedBox(width: 4),
                    Text('${_timeLeft}s', style: TextStyle(color: _timeLeft <= 5 ? const Color(0xFFEF4444) : widget.category.color, fontSize: 14, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity, padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1025), borderRadius: BorderRadius.circular(20),
                border: Border.all(color: widget.category.color.withValues(alpha:0.15)),
              ),
              child: Text(q.question, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, height: 1.4), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 24),
            ...List.generate(q.options.length, (i) {
              final letter = String.fromCharCode(65 + i);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => _selectOption(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: _optionColor(i), borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _optionBorderColor(i), width: 1.5),
                    ),
                    child: Row(children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha:0.08), borderRadius: BorderRadius.circular(8)),
                        child: Center(child: Text(letter, style: TextStyle(color: Colors.white.withValues(alpha:0.6), fontSize: 14, fontWeight: FontWeight.w700))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Text(q.options[i], style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500))),
                      if (_optionIcon(i) != null)
                        Icon(_optionIcon(i), color: i == _questions[_currentIndex].correctIndex ? const Color(0xFF10B981) : const Color(0xFFEF4444), size: 22),
                    ]),
                  ),
                ),
              );
            }),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    final percentage = (_correctCount / _questions.length * 100).round();
    String emoji; String message;
    if (percentage >= 80) { emoji = '\u{1F3C6}'; message = 'Harika! Mükemmel bilgi!'; }
    else if (percentage >= 60) { emoji = '\u{1F44F}'; message = 'İyi iş! Devam et!'; }
    else if (percentage >= 40) { emoji = '\u{1F4AA}'; message = 'Fena değil, gelişiyorsun!'; }
    else { emoji = '\u{1F4DA}'; message = 'Biraz daha çalışmalısın!'; }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Text(emoji, style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              const Text('Yarışma Bitti!', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(message, style: TextStyle(color: Colors.white.withValues(alpha:0.6), fontSize: 16)),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1025), borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: widget.category.color.withValues(alpha:0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ResultStat(label: 'Skor', value: '$_score', color: widget.category.color),
                    _ResultStat(label: 'Doğru', value: '$_correctCount/${_questions.length}', color: const Color(0xFF10B981)),
                    _ResultStat(label: 'Başarı', value: '%$percentage', color: const Color(0xFFF59E0B)),
                  ],
                ),
              ),
              const Spacer(),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha:0.06), borderRadius: BorderRadius.circular(16)),
                    child: const Center(child: Text('Kategoriler', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))),
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(
                  onTap: () {
                    setState(() {
                      // Yeni 10 soru seç (havuzdan rastgele)
                      _questions = List.from(widget.category.questions)..shuffle(Random());
                      _questions = _questions.take(_questionsPerRound).toList();
                      _currentIndex = 0; _score = 0; _correctCount = 0;
                      _selectedOption = null; _answered = false; _finished = false;
                    });
                    _startTimer();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [widget.category.color, widget.category.color.withValues(alpha:0.7)]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(child: Text('Tekrar Oyna', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))),
                  ),
                )),
              ]),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

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
