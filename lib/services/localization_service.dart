import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService extends ChangeNotifier {
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  int _selectedLang = 0; // 0: TR, 1: EN, 2: ES, 3: FR, 4: DE
  int get selectedLang => _selectedLang;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedLang = prefs.getInt('app_lang') ?? 0;
    notifyListeners();
  }

  Future<void> setLanguage(int langIndex) async {
    _selectedLang = langIndex;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_lang', langIndex);
    notifyListeners();
  }

  String t(String key) {
    if (!_translations.containsKey(key)) return key;
    final list = _translations[key]!;
    if (_selectedLang < 0 || _selectedLang >= list.length) return list[1]; // Fallback to EN
    return list[_selectedLang];
  }

  static const Map<String, List<String>> _translations = {
    // Common / General
    'AppName': ['Sleepora', 'Sleepora', 'Sleepora', 'Sleepora', 'Sleepora'],
    'AppSubtitle': ['Bebek Uyku Sesleri', 'Baby Sleep Sounds', 'Sonidos para dormir bebé', 'Sons de sommeil bébé', 'Baby-Schlafgeräusche'],
    'Plus': ['Plus', 'Plus', 'Plus', 'Plus', 'Plus'],
    'Cancel': ['İptal', 'Cancel', 'Cancelar', 'Annuler', 'Abbrechen'],
    'Ok': ['Tamam', 'OK', 'OK', 'OK', 'OK'],
    
    // Navigation
    'NavSounds': ['Sesler', 'Sounds', 'Sonidos', 'Sons', 'Geräusche'],
    'NavFavorites': ['Favoriler', 'Favorites', 'Favoritos', 'Favoris', 'Favoriten'],
    'NavRecord': ['Kaydet', 'Record', 'Grabar', 'Enregistrer', 'Aufnehmen'],
    'NavGames': ['Oyunlar', 'Games', 'Juegos', 'Jeux', 'Spiele'],
    'NavSettings': ['Ayarlar', 'Settings', 'Ajustes', 'Paramètres', 'Einstellungen'],

    // Home / Sounds Screen
    'GoodNight': ['İyi uykular', 'Good night', 'Buenas noches', 'Bonne nuit', 'Gute Nacht'],
    'MixerTitle': ['Karıştırıcı', 'Mixer', 'Mezclador', 'Mélangeur', 'Mixer'],
    'Shuffle': ['Karışık Çal', 'Shuffle', 'Aleatorio', 'Aléatoire', 'Zufall'],
    'SleepGuide': ['Uyku Rehberi', 'Sleep Guide', 'Guía de sueño', 'Guide du sommeil', 'Schlafratgeber'],
    
    // Paywall
    'Restore': ['Geri Yükle', 'Restore', 'Restablecer', 'Restaurer', 'Wiederherstellen'],
    'Yearly': ['Yıllık', 'Yearly', 'Anual', 'Annuel', 'Jährlich'],
    'Monthly': ['Aylık', 'Monthly', 'Mensual', 'Mensuel', 'Monatlich'],
    'Lifetime': ['Ömür Boyu', 'Lifetime', 'De por vida', 'À vie', 'Lebenslang'],
    'Popular': ['EN POPÜLER', 'MOST POPULAR', 'MÁS POPULAR', 'PLUS POPULAIRE', 'BELIEBTEST'],
    'BestValue': ['EN AVANTAJLI', 'BEST VALUE', 'MEJOR PRECIO', 'MEILLEUR PRIX', 'BESTER PREIS'],
    'Purchase': ['Satın Al', 'Purchase', 'Comprar', 'Acheter', 'Kaufen'],
    'TryFree': ['Ücretsiz Deneyin', 'Try for Free', 'Prueba gratis', 'Essayer gratuitement', 'Kostenlos testen'],
    'Terms': ['Şartlar', 'Terms', 'Términos', 'Conditions', 'Bedingungen'],
    'Privacy': ['Gizlilik', 'Privacy', 'Privacidad', 'Confidentialité', 'Datenschutz'],
    'SecureApple': ['Apple ile Güvenli', 'Secure with Apple', 'Seguro con Apple', 'Sécurisé avec Apple', 'Sicher mit Apple'],
    'StartingToday': ['Bugünden itibaren', 'Starting today', 'A partir de hoy', 'À partir d\'aujourd\'hui', 'Ab heute'],
    'Free7Days': ['7 gün ücretsiz', '7 days free', '7 días gratis', '7 jours gratuits', '7 Tage kostenlos'],
    'After7Days': ['7 gün sonra', 'After 7 days', 'Después de 7 días', 'Après 7 jours', 'Nach 7 Tagen'],
    'CancelAnytime': ['Otomatik Yenileme, Her Zaman İptal Edilebilir', 'Auto-renew, cancel anytime', 'Renovación automática, cancela en cualquier momento', 'Renouvellement automatique, annulez à tout moment', 'Autom. Verlängerung, jederzeit kündbar'],
    'LifetimeDesc': ['Tek seferlik ödeme — sonsuza kadar Premium', 'One-time payment — forever Premium', 'Pago único — Premium para siempre', 'Paiement unique — Premium pour toujours', 'Einmalige Zahlung — für immer Premium'],
    'PremiumActive': ['Plus Aktif', 'Plus Active', 'Plus Activo', 'Plus Actif', 'Plus Aktiv'],
    'AllUnlocked': ['Tüm özellikler açık', 'All features unlocked', 'Todas las funciones desbloqueadas', 'Toutes les fonctions débloquées', 'Alle Funktionen freigeschaltet'],
    'NoActiveSub': ['Aktif abonelik bulunamadı', 'No active subscription found', 'No se encontró suscripción activa', 'Aucun abonnement actif trouvé', 'Kein aktives Abonnement gefunden'],
    'UnlockAllFeatures': ['Tüm özellikleri aç — 7 gün ücretsiz dene', 'Unlock all features — 7 day free trial', 'Desbloquea todo — prueba gratis de 7 días', 'Débloquez tout — essai gratuit de 7 jours', 'Alles freischalten — 7 Tage kostenlos testen'],

    // Settings
    'BabyNameDesc': ['Ana ekrandaki iyi geceler mesajını kişiselleştirmek için...', 'To personalize the good night message on the home screen...', 'Para personalizar el mensaje de buenas noches en la pantalla de inicio...', 'Pour personnaliser le message de bonne nuit sur l\'écran d\'accueil...', 'Um die Gute-Nacht-Nachricht auf dem Startbildschirm zu personalisieren...'],
    'BabyNameTitle': ['BEBEĞİN ADI', 'BABY NAME', 'NOMBRE DEL BEBÉ', 'NOM DU BÉBÉ', 'BABYNAME'],
    'BabyNameHint': ['Bebeğin adını yaz...', 'Enter baby name...', 'Escribe el nombre del bebé...', 'Entrez le nom du bébé...', 'Babynamen eingeben...'],
    'PlaybackTitle': ['Oynatma ve Hatırlatıcı', 'Playback & Reminders', 'Reproducción y Recordatorios', 'Lecture et Rappels', 'Wiedergabe & Erinnerungen'],
    'StopTimer': ['Zamanlayıcı Bitince Durdur', 'Stop When Timer Ends', 'Detener al terminar el temporizador', 'Arrêter à la fin du minuteur', 'Stoppen, wenn der Timer endet'],
    'StopTimerSub': ['Süre dolunca sesleri otomatik kapat', 'Auto-stop sounds when time is up', 'Detener sonidos automáticamente cuando se acabe el tiempo', 'Arrêter automatiquement les sons à la fin du temps', 'Töne otomatis stoppen, wenn die Zeit abgelaufen ist'],
    'FadeOut': ['Yavaşça Kapat (Fade Out)', 'Fade Out', 'Desvanecimiento (Fade Out)', 'Fondu en fermeture (Fade Out)', 'Ausblenden (Fade Out)'],
    'FadeOutSub': ['Sesi kademeli olarak azaltarak kapat', 'Gradually reduce volume before stopping', 'Reducir gradualmente el volumen antes de detener', 'Réduire progressivement le volume avant d\'arrêter', 'Lautstärke vor dem Stoppen schrittweise verringern'],
    'BackgroundPlay': ['Arka Planda Çalma', 'Background Playback', 'Reproducción en segundo plano', 'Lecture en arrière-plan', 'Hintergrundwiedergabe'],
    'BackgroundPlaySub': ['Uygulama kapatılınca da ses çalmaya devam etsin', 'Continue playing when app is closed', 'Continuar reproduciendo al cerrar la aplicación', 'Continuer la lecture quand l\'application est fermée', 'Weiter abspielen, wenn App geschlossen wird'],
    'SleepReminder': ['Uyku Hatırlatıcısı', 'Sleep Reminder', 'Recordatorio de sueño', 'Rappel de sommeil', 'Schlaferinnerung'],
    'SleepReminderSub': ['Her gece belirlenen saatte bildirim gönder', 'Send a notification at the set time every night', 'Enviar una notificación a la hora establecida cada noche', 'Envoyer une notification à l\'heure fixée chaque nuit', 'Jede Nacht zur eingestellten Zeit eine Benachrichtigung senden'],
    'ReminderTime': ['Hatırlatma Saati', 'Reminder Time', 'Hora del recordatorio', 'Heure du rappel', 'Erinnerungszeit'],
    'LanguageTitle': ['Dil Seçimi', 'Language Setting', 'Ajuste de idioma', 'Choix de la langue', 'Spracheinstellung'],
    'SupportContact': ['Destek & İletişim', 'Support & Contact', 'Soporte y Contacto', 'Support et Contact', 'Support & Kontakt'],
    'RateApp': ['Uygulamayı Puanla', 'Rate the App', 'Calificar la aplicación', 'Évaluer l\'application', 'App bewerten'],
    'FollowInsta': ['Instagram\'da Takip Et', 'Follow on Instagram', 'Síguenos en Instagram', 'Suivre sur Instagram', 'Auf Instagram folgen'],
    'YouTubeChannel': ['YouTube Kanalımız', 'Our YouTube Channel', 'Nuestro canal de YouTube', 'Notre chaîne YouTube', 'Unser YouTube-Kanal'],
    'ContactFeed': ['İletişim & Öneri', 'Contact & Feedback', 'Contacto y Sugerencias', 'Contact et Retours', 'Kontakt & Feedback'],
    'PrivacyPolicy': ['Gizlilik Politikası', 'Privacy Policy', 'Política de Privacidad', 'Politique de confidentialité', 'Datenschutzrichtlinie'],
    'PeacefulSleep': ['Bebeğiniz için huzurlu uykular', 'Peaceful sleep for your baby', 'Sueño tranquilo para su bebé', 'Sommeil paisible pour votre bébé', 'Ruhiger Schlaf für Ihr Baby'],

    // Favorites / Mixer
    'LimitTitle': ['💡 Kayıt Sınırı', '💡 Save Limit', '💡 Límite de guardado', '💡 Limite d\'enregistrement', '💡 Speicherlimit'],
    'LimitDesc': [
      'Ücretsiz sürümde en fazla 2 Mix kaydedebilirsiniz. Sınırsız miks kaydetmek için Sleepora Plus\'a geçin!',
      'You can save up to 2 Mixes in the free version. Upgrade to Sleepora Plus for unlimited mixes!',
      'Puedes guardar hasta 2 mezclas en la versión gratuita. ¡Mejora a Sleepora Plus para mezclas ilimitadas!',
      'Vous pouvez enregistrer jusqu\'à 2 mixes dans la version gratuite. Passez à Sleepora Plus pour des mixes illimités !',
      'In der kostenlosen Version können Sie bis zu 2 Mixe speichern. Upgrade auf Sleepora Plus für unbegrenzte Mixe!'
    ],
    'SeePlus': ['Plus\'ı Gör', 'See Plus', 'Ver Plus', 'Voir Plus', 'Plus ansehen'],
    'SaveMix': ['Miksi Kaydet', 'Save Mix', 'Guardar mezcla', 'Enregistrer le mix', 'Mix speichern'],
    'MixNameHint': ['Mix ismini yaz...', 'Enter mix name...', 'Escribe el nombre del mix...', 'Entrez le nom du mix...', 'Mix-Namen eingeben...'],
    'Save': ['Kaydet', 'Save', 'Guardar', 'Enregistrer', 'Speichern'],
    'MixSaved': ['Mix favorilere kaydedildi!', 'Mix saved to favorites!', '¡Mezcla guardada en favoritos!', 'Mix enregistré dans les favoris !', 'Mix in Favoriten gespeichert!'],
    'EmptyFavorites': ['Henüz favori sesin yok', 'No favorite sounds yet', 'Aún no hay sonidos favoritos', 'Pas encore de sons favoris', 'Noch keine Favoriten'],
    'FavoritesDesc': ['Beğendiğin sesleri burada görebilirsin', 'You can see your liked sounds here', 'Puedes ver tus sonidos favoritos aquí', 'Vous pouvez voir vos sons préférés ici', 'Hier siehst du deine Lieblingsgeräusche'],
    'SavedMixesTitle': ['KAYDEDİLEN MİKSLER', 'SAVED MIXES', 'MEZCLAS GUARDADAS', 'MIX ENREGISTRÉS', 'GESPEICHERTE MIXE'],

    // Sleep Guide Sections
    'GuideTitle_1': ['0-3 Ay: Yenidoğan ve Güven', '0-3 Months: Newborn and Trust', '0-3 meses: Recién nacido y confianza', '0-3 mois : Nouveau-né et confiance', '0-3 Monate: Neugeborene und Vertrauen'],
    'GuideContent_1': [
      'Yenidoğan bebekler günde 14-17 saat uyurlar ama bu uyku genellikle 2-4 saatlik periyotlar halinde olur. Beyaz gürültü ve kundaklama bebeğinizin kendini güvende hissetmesini sağlar.',
      'Newborns sleep 14-17 hours a day, but this sleep is usually in 2-4 hour periods. White noise and swaddling make your baby feel safe.',
      'Los recién nacidos duermen de 14 a 17 horas al día, pero este sueño suele ser en periodos de 2 a 4 horas. El ruido blanco y el envolver al bebé lo hacen sentir seguro.',
      'Les nouveau-nés dorment 14-17 heures par jour, mais ce sommeil se fait généralement par périodes de 2-4 heures. Le bruit blanc et l\'emmaillotage permettent à votre bébé de se sentir en sécurité.',
      'Neugeborene schlafen 14-17 Stunden am Tag, aber dieser Schlaf erfolgt normalerweise in 2-4-Stunden-Perioden. Weißes Rauschen und Pucken geben Ihrem Baby Sicherheit.'
    ],
    'GuideTitle_2': ['4-6 Ay: Uyku Gerilemesi', '4-6 Months: Sleep Regression', '4-6 meses: Regresión del sueño', '4-6 mois : Régression du sommeil', '4-6 Monate: Schlafregression'],
    'GuideContent_2': [
      '4. ay civarında uyku döngüleri değişir, bu da sık uyanmalara neden olabilir. Tutarlı bir uyku rutini oluşturmak çok önemlidir.',
      'Around the 4th month, sleep cycles change, which can cause frequent awakenings. It is very important to create a consistent sleep routine.',
      'Alrededor del cuarto mes, los ciclos de sueño cambian, lo que puede causar despertares frecuentes. Es muy importante crear una rutina de sueño constante.',
      'Vers le 4ème mois, les cycles de sommeil changent, ce qui peut provoquer des réveils fréquents. Il est très important de créer une routine de sommeil cohérente.',
      'Etwa im 4. Monat ändern sich die Schlafzyklen, was zu häufigem Aufwachen führen kann. Es ist sehr wichtig, eine konsequente Schlafroutine zu schaffen.'
    ],
    'GuideTitle_3': ['6-12 Ay: Ayrılık Kaygısı', '6-12 Months: Separation Anxiety', '6-12 meses: Ansiedad por separación', '6-12 mois : Anxiété de séparation', '6-12 Monate: Trennungsangst'],
    'GuideContent_3': [
      'Bebeğiniz artık daha hareketli. Gece uyanıp sizi yanında göremeyince ağlayabilir. Ona dokunarak orada olduğunuzu hissettirin.',
      'Your baby is more active now. They may cry when they wake up at night and don\'t see you. Make them feel you are there by touching them.',
      'Tu bebé está más activo ahora. Puede llorar cuando se despierta por la noche y no te ve. Hazle sentir que estás allí tocándolo.',
      'Votre bébé est plus actif maintenant. Il peut pleurer lorsqu\'il se réveille la nuit et ne vous voit pas. Faites-lui sentir que vous êtes là en le touchant.',
      'Ihr Baby ist jetzt aktiver. Es kann weinen, wenn es nachts aufwacht und Sie nicht sieht. Geben Sie ihm das Gefühl, dass Sie da sind, indem Sie es berühren.'
    ],
    'GuideTitle_4': ['12-24 Ay: Tek Uykuya Geçiş', '12-24 Months: Transition to One Nap', '12-24 meses: Transición a una siesta', '12-24 mois : Transition vers une sieste', '12-24 Monate: Übergang zu einem Schläfchen'],
    'GuideContent_4': [
      'Bebekler genellikle günde iki kez uyumaktan bir kez uyumaya geçiş yaparlar. Yatma saati rutinini kısa ve öngörülebilir tutun.',
      'Babies usually transition from napping twice a day to once a day. Keep the bedtime routine short and predictable.',
      'Los bebés suelen pasar de dormir dos siestas al día a una sola. Mantén la rutina de la hora de acostarse corta y predecible.',
      'Les bébés passent généralement de deux siestes par jour à une seule. Gardez la routine du coucher courte et prévisible.',
      'Babys wechseln normalerweise von zwei Schläfchen pro Tag zu einem. Halten Sie die Schlafenszeit-Routine kurz und vorhersehbar.'
    ],
    'GuideWarning': [
      'Bu bilgiler yalnızca genel bilgilendirme amaçlıdır. Endişeleriniz varsa bir sağlık uzmanına danışın.',
      'This information is for general information purposes only. Consult a healthcare professional if you have concerns.',
      'Esta información es sólo para fines de información general. Consulte a un profesional de la salud si tiene inquietudes.',
      'Ces informations sont fournies à titre indicatif uniquement. Consultez un professionnel de la santé si vous avez des inquiétudes.',
      'Diese Informationen dienen nur der allgemeinen Information. Wenden Sie sich bei Bedenken an einen Arzt.'
    ],

    // ─── Buttons ───
    'BtnCancel': ['İptal', 'Cancel', 'Cancelar', 'Annuler', 'Abbrechen'],
    'BtnGoPremium': ['Premium\'a Geç', 'Go Premium', 'Hazte Premium', 'Passer Premium', 'Premium werden'],
    'PremiumSoundTitle': ['Premium Ses', 'Premium Sound', 'Sonido Premium', 'Son Premium', 'Premium Sound'],
    'PremiumSoundDesc': ['Bu ses Premium üyelere özel. Premium\'a geçerek tüm seslerin keyfini çıkar!', 'This sound is exclusive to Premium members. Go Premium to enjoy all sounds!', 'Este sonido es exclusivo para miembros Premium. ¡Hazte Premium para disfrutar todos los sonidos!', 'Ce son est réservé aux membres Premium. Passez Premium pour profiter de tous les sons !', 'Dieser Sound ist exklusiv für Premium-Mitglieder. Werde Premium und genieße alle Sounds!'],
    'FeatPremiumSounds': ['Premium Sesler', 'Premium Sounds', 'Sonidos Premium', 'Sons Premium', 'Premium Sounds'],
    'BtnSave': ['Kaydet', 'Save', 'Guardar', 'Enregistrer', 'Speichern'],
    'BtnDone': ['Tamam', 'Done', 'Hecho', 'Terminé', 'Fertig'],
    'BtnDelete': ['Sil', 'Delete', 'Eliminar', 'Supprimer', 'Löschen'],
    'BtnEditCaps': ['DÜZENLE', 'EDIT', 'EDITAR', 'MODIFIER', 'BEARBEITEN'],
    'BtnSeePlus': ['Plus\'ı Gör', 'See Plus', 'Ver Plus', 'Voir Plus', 'Plus ansehen'],
    'BtnSelectAll': ['Tümünü Seç', 'Select All', 'Seleccionar todo', 'Tout sélectionner', 'Alle auswählen'],
    'BtnClearAll': ['Temizle', 'Clear All', 'Limpiar todo', 'Tout effacer', 'Alles löschen'],
    'BtnTryFree': ['Ücretsiz Deneyin', 'Try for Free', 'Prueba gratis', 'Essayer gratuitement', 'Kostenlos testen'],
    'BtnBuyNow': ['Satın Al', 'Buy Now', 'Comprar ahora', 'Acheter maintenant', 'Jetzt kaufen'],
    'BtnUpgrade': ['Yükselt', 'Upgrade', 'Mejorar', 'Mettre à niveau', 'Upgrade'],
    'BtnCancelTimer': ['Zamanlayıcıyı İptal Et', 'Cancel Timer', 'Cancelar temporizador', 'Annuler le minuteur', 'Timer abbrechen'],

    // ─── Tabs ───
    'TabFavorite': ['Favoriler', 'Favorites', 'Favoritos', 'Favoris', 'Favoriten'],
    'TabMyMixes': ['Mikslerim', 'My Mixes', 'Mis mezclas', 'Mes mix', 'Meine Mixe'],
    'TabMixer': ['Karıştırıcı', 'Mixer', 'Mezclador', 'Mélangeur', 'Mixer'],
    'TabGames': ['Oyunlar', 'Games', 'Juegos', 'Jeux', 'Spiele'],
    'TabRecord': ['Kayıt', 'Record', 'Grabación', 'Enregistrement', 'Aufnahme'],

    // ─── Favorites / Mixer dialogs ───
    'DialogEdit': ['Düzenle', 'Edit', 'Editar', 'Modifier', 'Bearbeiten'],
    'EditMixTitle': ['Düzenle', 'Edit', 'Editar', 'Modifier', 'Bearbeiten'],
    'EditMixDesc': ['Her bir sesin seviyesini kişisel tercihinize göre ayarlayın.', 'Adjust the volume level of each sound to your preference.', 'Ajusta el nivel de volumen de cada sonido a tu gusto.', 'Ajustez le niveau de volume de chaque son selon vos préférences.', 'Passen Sie die Lautstärke jedes Sounds nach Ihren Wünschen an.'],
    'SaveAsMix': ['Mix Olarak Kaydet', 'Save as Mix', 'Guardar como mezcla', 'Enregistrer comme mix', 'Als Mix speichern'],
    'HintNewMix': ['Mix ismi girin...', 'Enter mix name...', 'Nombre de la mezcla...', 'Nom du mix...', 'Mix-Name eingeben...'],
    'MixLimitTitle': ['Mix Kayıt Sınırı', 'Mix Save Limit', 'Límite de mezclas', 'Limite de mix', 'Mix-Speicherlimit'],
    'MixLimitDesc': [
      'Ücretsiz sürümde en fazla 2 Mix kaydedebilirsiniz. Sınırsız kayıt için Plus\'a geçin!',
      'You can save up to 2 mixes in the free version. Upgrade to Plus for unlimited!',
      'Puedes guardar hasta 2 mezclas en la versión gratuita. ¡Mejora a Plus!',
      'Vous pouvez enregistrer jusqu\'à 2 mix dans la version gratuite. Passez à Plus !',
      'In der kostenlosen Version können Sie bis zu 2 Mixe speichern. Upgrade auf Plus!'
    ],
    'FavLimitTitle': ['Favori Sınırı', 'Favorite Limit', 'Límite de favoritos', 'Limite de favoris', 'Favoriten-Limit'],
    'FavLimitDesc': [
      'Ücretsiz sürümde en fazla 3 favori ekleyebilirsiniz. Sınırsız favori için Plus\'a geçin!',
      'You can add up to 3 favorites in the free version. Upgrade to Plus for unlimited!',
      'Puedes añadir hasta 3 favoritos en la versión gratuita. ¡Mejora a Plus!',
      'Vous pouvez ajouter jusqu\'à 3 favoris dans la version gratuite. Passez à Plus !',
      'In der kostenlosen Version können Sie bis zu 3 Favoriten hinzufügen. Upgrade auf Plus!'
    ],

    // ─── Record Screen ───
    'RecordSub': ['Bebeğiniz için ninni kaydedin', 'Record a lullaby for your baby', 'Graba una canción de cuna para tu bebé', 'Enregistrez une berceuse pour votre bébé', 'Nehmen Sie ein Schlaflied für Ihr Baby auf'],
    'DefaultRecordName': ['Kayıt', 'Recording', 'Grabación', 'Enregistrement', 'Aufnahme'],
    'MyRecords': ['Kayıtlarım', 'My Recordings', 'Mis grabaciones', 'Mes enregistrements', 'Meine Aufnahmen'],
    'NoRecords': ['Henüz kayıt yok', 'No recordings yet', 'Aún no hay grabaciones', 'Pas encore d\'enregistrements', 'Noch keine Aufnahmen'],
    'StatusRecording': ['Kayıt yapılıyor...', 'Recording...', 'Grabando...', 'Enregistrement...', 'Aufnahme läuft...'],
    'StatusPaused': ['Duraklatıldı', 'Paused', 'Pausado', 'En pause', 'Pausiert'],
    'StatusStartRecord': ['Kayda başlamak için dokunun', 'Tap to start recording', 'Toca para grabar', 'Appuyez pour enregistrer', 'Tippen zum Aufnehmen'],
    'MicPermissionRequired': ['Kayıt için mikrofon izni gerekli', 'Microphone permission required for recording', 'Se requiere permiso de micrófono', 'Permission du microphone requise', 'Mikrofonberechtigung erforderlich'],
    'RenameRecordTitle': ['Yeniden Adlandır', 'Rename', 'Renombrar', 'Renommer', 'Umbenennen'],
    'HintNewName': ['Yeni isim girin...', 'Enter new name...', 'Nuevo nombre...', 'Nouveau nom...', 'Neuer Name...'],
    'DeleteRecordTitle': ['Kaydı Sil', 'Delete Recording', 'Eliminar grabación', 'Supprimer l\'enregistrement', 'Aufnahme löschen'],
    'DeleteRecordConfirm': ['silinecek. Emin misiniz?', 'will be deleted. Are you sure?', 'se eliminará. ¿Estás seguro?', 'sera supprimé. Êtes-vous sûr ?', 'wird gelöscht. Sind Sie sicher?'],

    // ─── Games Screen ───
    'GamesSub': ['Eğlenceli beyin oyunları', 'Fun brain games', 'Juegos mentales divertidos', 'Jeux cérébraux amusants', 'Lustige Denkspiele'],
    'GameMinesweeper': ['Mayın Tarlası', 'Minesweeper', 'Buscaminas', 'Démineur', 'Minesweeper'],
    'GameMinesweeperSub': ['Klasik mayın bulma oyunu', 'Classic mine finding game', 'Juego clásico de buscar minas', 'Jeu classique de recherche de mines', 'Klassisches Minenspiel'],
    'Game2048': ['2048', '2048', '2048', '2048', '2048'],
    'Game2048Sub': ['Sayıları birleştir, 2048\'e ulaş', 'Merge numbers, reach 2048', 'Combina números, llega a 2048', 'Fusionnez les nombres, atteignez 2048', 'Zahlen zusammenführen, 2048 erreichen'],
    'GameQuiz': ['Bilgi Yarışması', 'Quiz', 'Cuestionario', 'Quiz', 'Quiz'],
    'GameQuizSub': ['Bilgini test et', 'Test your knowledge', 'Pon a prueba tus conocimientos', 'Testez vos connaissances', 'Teste dein Wissen'],

    // ─── Paywall / Plans ───
    'PlanYearly': ['Yıllık', 'Yearly', 'Anual', 'Annuel', 'Jährlich'],
    'PlanMonthly': ['Aylık', 'Monthly', 'Mensual', 'Mensuel', 'Monatlich'],
    'PlanLifetime': ['Ömür Boyu', 'Lifetime', 'De por vida', 'À vie', 'Lebenslang'],
    'perYear': ['yıl', 'year', 'año', 'an', 'Jahr'],
    'perMonth': ['ay', 'month', 'mes', 'mois', 'Monat'],
    'perSingle': ['tek sefer', 'one-time', 'único pago', 'unique', 'einmalig'],
    'BadgePopular': ['EN POPÜLER', 'MOST POPULAR', 'MÁS POPULAR', 'PLUS POPULAIRE', 'BELIEBTEST'],
    'BadgeBestValue': ['EN AVANTAJLI', 'BEST VALUE', 'MEJOR PRECIO', 'MEILLEUR PRIX', 'BESTER PREIS'],
    'RestorePurchases': ['Satın Alımları Geri Yükle', 'Restore Purchases', 'Restaurar compras', 'Restaurer les achats', 'Käufe wiederherstellen'],
    'RestoreNoActive': ['Aktif abonelik bulunamadı', 'No active subscription found', 'No se encontró suscripción activa', 'Aucun abonnement actif trouvé', 'Kein aktives Abonnement gefunden'],
    'LifetimeInfo': ['Tek seferlik ödeme — sonsuza kadar Premium', 'One-time payment — forever Premium', 'Pago único — Premium para siempre', 'Paiement unique — Premium pour toujours', 'Einmalige Zahlung — für immer Premium'],
    'TrialStarting': ['Bugünden itibaren', 'Starting today', 'A partir de hoy', 'À partir d\'aujourd\'hui', 'Ab heute'],
    'TrialDuration': ['7 gün ücretsiz', '7 days free', '7 días gratis', '7 jours gratuits', '7 Tage kostenlos'],
    'TrialAfter': ['7 gün sonra', 'After 7 days', 'Después de 7 días', 'Après 7 jours', 'Nach 7 Tagen'],
    'TrialCancelAnytime': ['Otomatik Yenileme, Her Zaman İptal Edilebilir', 'Auto-renew, cancel anytime', 'Renovación automática, cancela en cualquier momento', 'Renouvellement automatique, annulez à tout moment', 'Autom. Verlängerung, jederzeit kündbar'],

    // ─── Feature Labels ───
    'FeatAllSounds': ['Tüm Sesler', 'All Sounds', 'Todos los sonidos', 'Tous les sons', 'Alle Geräusche'],
    'FeatAllGames': ['Tüm Oyunlar', 'All Games', 'Todos los juegos', 'Tous les jeux', 'Alle Spiele'],
    'FeatUnlimitedTimer': ['Sınırsız Zamanlayıcı', 'Unlimited Timer', 'Temporizador ilimitado', 'Minuteur illimité', 'Unbegrenzter Timer'],
    'FeatVoiceRecord': ['Ses Kaydı', 'Voice Recording', 'Grabación de voz', 'Enregistrement vocal', 'Sprachaufnahme'],
    'FeatMixer': ['Gelişmiş Karıştırıcı', 'Advanced Mixer', 'Mezclador avanzado', 'Mélangeur avancé', 'Erweiterter Mixer'],
    'FeatUnlimitedMix': ['Sınırsız Mix', 'Unlimited Mixes', 'Mezclas ilimitadas', 'Mix illimités', 'Unbegrenzte Mixe'],
    'FeatUnlimitedFavorite': ['Sınırsız Favori', 'Unlimited Favorites', 'Favoritos ilimitados', 'Favoris illimités', 'Unbegrenzte Favoriten'],
    'FeatUnlimitedRecord': ['Sınırsız Kayıt', 'Unlimited Recordings', 'Grabaciones ilimitadas', 'Enregistrements illimités', 'Unbegrenzte Aufnahmen'],
    'FeatLongTimer': ['Uzun Zamanlayıcı', 'Long Timer', 'Temporizador largo', 'Minuteur long', 'Langer Timer'],

    // ─── Shuffle Settings ───
    'ShuffleSettingsTitle': ['Karışık Çalma Ayarları', 'Shuffle Settings', 'Ajustes de aleatorio', 'Paramètres aléatoires', 'Zufallswiedergabe-Einstellungen'],
    'ShuffleChangeInterval': ['Ses Değişim Süresi', 'Sound Change Interval', 'Intervalo de cambio', 'Intervalle de changement', 'Wechselintervall'],
    'ShuffleCrossfade': ['Geçişli Çalma', 'Crossfade', 'Transición suave', 'Fondu enchaîné', 'Überblendung'],
    'ShuffleCrossfadeDuration': ['Geçiş Süresi', 'Crossfade Duration', 'Duración de transición', 'Durée du fondu', 'Überblendungsdauer'],
    'ShufflePlayDuration': ['Çalma Süresi', 'Play Duration', 'Duración de reproducción', 'Durée de lecture', 'Wiedergabedauer'],
    'ShufflePlayUnlimited': ['Sınırsız', 'Unlimited', 'Ilimitado', 'Illimité', 'Unbegrenzt'],
    'ShuffleStatusPlaying': ['Çalıyor', 'Playing', 'Reproduciendo', 'En cours', 'Spielt'],
    'ShuffleStatusStopped': ['Durdu', 'Stopped', 'Detenido', 'Arrêté', 'Gestoppt'],
    'ShuffleFavoritesTitle': ['Favorileri Karıştır', 'Shuffle Favorites', 'Mezclar favoritos', 'Mélanger les favoris', 'Favoriten mischen'],
    'NoFavoritesTitle': ['Henüz Favori Yok', 'No Favorites Yet', 'Aún no hay favoritos', 'Pas encore de favoris', 'Noch keine Favoriten'],
    'NoFavoritesDesc': ['Beğendiğin sesleri favorilere ekleyerek buradan hızlıca ulaşabilirsin.', 'Add your favorite sounds to access them quickly here.', 'Añade tus sonidos favoritos para acceder rápidamente.', 'Ajoutez vos sons préférés pour y accéder rapidement.', 'Füge deine Lieblingssounds hinzu, um schnell darauf zuzugreifen.'],
    'MyMixesHeader': ['Mixlerim', 'My Mixes', 'Mis mezclas', 'Mes mix', 'Meine Mixe'],
    'MyMixesSub': ['Kaydettiğiniz ses kombinasyonları', 'Your saved sound combinations', 'Tus combinaciones de sonido guardadas', 'Vos combinaisons de sons enregistrées', 'Ihre gespeicherten Soundkombinationen'],
    'BtnNewMix': ['Yeni Mix Oluştur', 'Create New Mix', 'Crear nueva mezcla', 'Créer un nouveau mix', 'Neuen Mix erstellen'],
    'NoMixesTitle': ['Henüz Mix Yok', 'No Mixes Yet', 'Aún no hay mezclas', 'Pas encore de mix', 'Noch keine Mixe'],
    'NoMixesDesc': ['Karıştırıcıdan sesler seçip kaydedin.', 'Select sounds from the mixer and save them.', 'Selecciona sonidos del mezclador y guárdalos.', 'Sélectionnez des sons du mixeur et enregistrez-les.', 'Wählen Sie Sounds aus dem Mixer und speichern Sie sie.'],
    'soundsCount': ['ses', 'sounds', 'sonidos', 'sons', 'Sounds'],
    'FavSoundsPlaying': ['Favori Ses Çalınıyor', 'Favorite Sounds Playing', 'Sonidos favoritos reproduciéndose', 'Sons favoris en lecture', 'Lieblingssounds werden gespielt'],

    // ─── Timer / Mini Player ───
    'TimerDialogTitle': ['Zamanlayıcı', 'Timer', 'Temporizador', 'Minuteur', 'Timer'],
    'TimerDialogDesc': ['Seslerin ne kadar çalacağını seçin', 'Choose how long sounds will play', 'Elige cuánto tiempo sonarán', 'Choisissez la durée de lecture', 'Wählen Sie die Wiedergabedauer'],
    'timerHour': ['sa', 'hr', 'hr', 'hr', 'Std'],
    'timerMin': ['dk', 'min', 'min', 'min', 'Min'],
    'sec': ['sn', 'sec', 'seg', 'sec', 'Sek'],
    'min': ['dk', 'min', 'min', 'min', 'Min'],

    // ─── Recent Sounds ───
    'RecentSounds': ['Son Kullanılanlar', 'Recent Sounds', 'Sonidos recientes', 'Sons récents', 'Zuletzt verwendet'],

    // ─── Errors ───
    'ProductNotFound': ['Ürün bulunamadı. Lütfen daha sonra tekrar deneyin.', 'Product not found. Please try again later.', 'Producto no encontrado. Inténtalo más tarde.', 'Produit introuvable. Veuillez réessayer plus tard.', 'Produkt nicht gefunden. Bitte versuchen Sie es später erneut.'],

    // ─── Sound Names ───
    'Sound_Pış Pış': ['Pış Pış', 'Shush Shush', 'Shh Shh', 'Chut Chut', 'Psch Psch'],
    'Sound_Eee Eee': ['Eee Eee', 'Eee Eee', 'Eee Eee', 'Eee Eee', 'Eee Eee'],
    'Sound_Dandini': ['Dandini', 'Lullaby', 'Canción de cuna', 'Berceuse', 'Schlaflied'],
    'Sound_Süpürge': ['Süpürge', 'Vacuum', 'Aspiradora', 'Aspirateur', 'Staubsauger'],
    'Sound_Kolik': ['Kolik', 'Colic', 'Cólico', 'Colique', 'Kolik'],
    'Sound_Pış Pış 2': ['Pış Pış 2', 'Shush Shush 2', 'Shh Shh 2', 'Chut Chut 2', 'Psch Psch 2'],
    'Sound_Kabin Sesi': ['Kabin Sesi', 'Cabin Sound', 'Sonido de cabina', 'Son de cabine', 'Kabinengeräusch'],
    'Sound_Yıldız Tozu': ['Yıldız Tozu', 'Stardust', 'Polvo de estrellas', 'Poussière d\'étoiles', 'Sternenstaub'],
    'Sound_Konuşma': ['Konuşma', 'Talking', 'Conversación', 'Conversation', 'Gespräch'],
    'Sound_Uyusunda Büyüsün': ['Uyusunda Büyüsün', 'Sleep & Grow', 'Duerme y crece', 'Dors et grandis', 'Schlaf und wachse'],
    'Sound_Pış Pış + Süpürge': ['Pış Pış + Süpürge', 'Shush + Vacuum', 'Shh + Aspiradora', 'Chut + Aspirateur', 'Psch + Staubsauger'],
    'Sound_Beyaz Gürültü': ['Beyaz Gürültü', 'White Noise', 'Ruido blanco', 'Bruit blanc', 'Weißes Rauschen'],
    'Sound_Yol Sesi': ['Yol Sesi', 'Road Sound', 'Sonido de carretera', 'Bruit de route', 'Straßengeräusch'],
    'Sound_Yağmur': ['Yağmur', 'Rain', 'Lluvia', 'Pluie', 'Regen'],
    'Sound_Saç Kurutma': ['Saç Kurutma', 'Hair Dryer', 'Secador de pelo', 'Sèche-cheveux', 'Haartrockner'],
    'Sound_Rüzgar': ['Rüzgar', 'Wind', 'Viento', 'Vent', 'Wind'],
    'Sound_Dalga': ['Dalga', 'Waves', 'Olas', 'Vagues', 'Wellen'],
    'Sound_Duş': ['Duş', 'Shower', 'Ducha', 'Douche', 'Dusche'],
    'Sound_Helikopter': ['Helikopter', 'Helicopter', 'Helicóptero', 'Hélicoptère', 'Hubschrauber'],
    'Sound_Tren': ['Tren', 'Train', 'Tren', 'Train', 'Zug'],
    'Sound_Vantilatör': ['Vantilatör', 'Fan', 'Ventilador', 'Ventilateur', 'Ventilator'],
    'Sound_Kalp Atışı': ['Kalp Atışı', 'Heartbeat', 'Latido del corazón', 'Battement de cœur', 'Herzschlag'],
    'Sound_Kuş Sesi': ['Kuş Sesi', 'Bird Sound', 'Sonido de pájaros', 'Chant d\'oiseaux', 'Vogelgesang'],
    'Sound_Su Sesi': ['Su Sesi', 'Water Sound', 'Sonido de agua', 'Bruit d\'eau', 'Wassergeräusch'],
    'Sound_Çamaşır Makinesi': ['Çamaşır Makinesi', 'Washing Machine', 'Lavadora', 'Machine à laver', 'Waschmaschine'],
    'Sound_Trafik': ['Trafik', 'Traffic', 'Tráfico', 'Trafic', 'Verkehr'],
  };
}
