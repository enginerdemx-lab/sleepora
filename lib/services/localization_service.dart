import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService extends ChangeNotifier {
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  int _selectedLang = 0; // 0: TR, 1: EN, 2: ES, 3: FR, 4: DE, 5: RU, 6: AR
  int get selectedLang => _selectedLang;

  /// Arapça için sağdan sola düzen (RTL) gerekir.
  bool get isRtl => _selectedLang == 6;

  String get currentLanguageCode {
    switch (_selectedLang) {
      case 0: return 'tr';
      case 1: return 'en';
      case 2: return 'es';
      case 3: return 'fr';
      case 4: return 'de';
      case 5: return 'ru';
      case 6: return 'ar';
      default: return 'en';
    }
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('app_lang');
    if (saved != null) {
      // Kullanıcı daha önce manuel seçim yapmış — onu kullan
      _selectedLang = saved;
    } else {
      // İlk açılış: cihazın sistem dilini algıla
      final systemLang =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      switch (systemLang) {
        case 'tr':
          _selectedLang = 0;
          break;
        case 'en':
          _selectedLang = 1;
          break;
        case 'es':
          _selectedLang = 2;
          break;
        case 'fr':
          _selectedLang = 3;
          break;
        case 'de':
          _selectedLang = 4;
          break;
        case 'ru':
          _selectedLang = 5;
          break;
        case 'ar':
          _selectedLang = 6;
          break;
        default:
          // Desteklenmeyen diller için İngilizce'ye düş
          _selectedLang = 1;
      }
    }
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
    'AppName': ['Sleepora', 'Sleepora', 'Sleepora', 'Sleepora', 'Sleepora', 'Sleepora', 'Sleepora'],
    'AppSubtitle': ['Bebek Uyku Sesleri', 'Baby Sleep Sounds', 'Sonidos para dormir bebé', 'Sons de sommeil bébé', 'Baby-Schlafgeräusche', 'Звуки для сна малыша', 'أصوات نوم الطفل'],
    'Plus': ['Plus', 'Plus', 'Plus', 'Plus', 'Plus', 'Plus', 'Plus'],
    'Cancel': ['İptal', 'Cancel', 'Cancelar', 'Annuler', 'Abbrechen', 'Отмена', 'إلغاء'],
    'Continue': ['Devam Et', 'Continue', 'Continuar', 'Continuer', 'Fortfahren', 'Продолжить', 'متابعة'],
    // ── Apple Guideline 5.1.1(v) — Hesap Silme metinleri
    'DeleteAccountTitle': ['Hesabı Sil', 'Delete Account', 'Eliminar cuenta', 'Supprimer le compte', 'Konto löschen', 'Удалить аккаунт', 'حذف الحساب'],
    'DeleteAccountSubtitle': [
      'Hesabınızı ve tüm verilerinizi kalıcı olarak silin',
      'Permanently delete your account and all data',
      'Elimina tu cuenta y todos los datos permanentemente',
      'Supprimez votre compte et toutes vos données',
      'Konto und alle Daten dauerhaft löschen',
      'Удалите аккаунт и все данные навсегда',
      'احذف حسابك وجميع بياناتك نهائياً'
    ],
    'DeleteAccountWarning': [
      'Hesabınızı silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.',
      'Are you sure you want to delete your account? This action cannot be undone.',
      '¿Seguro que quieres eliminar tu cuenta? Esta acción no se puede deshacer.',
      'Voulez-vous vraiment supprimer votre compte ? Cette action est irréversible.',
      'Möchten Sie Ihr Konto wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.',
      'Вы уверены, что хотите удалить аккаунт? Это действие необратимо.',
      'هل أنت متأكد أنك تريد حذف حسابك؟ لا يمكن التراجع عن هذا الإجراء.'
    ],
    'DeleteAccountConsequences': [
      'Silinecekler:\n• Profil bilgileriniz\n• Uyku istatistikleriniz ve geçmişiniz\n• Favori sesleriniz ve mikslemeleriniz\n• Tüm hesap verileriniz\n\nNot: Mevcut aboneliğiniz Apple Kimliği ayarlarınızdan ayrıca iptal edilmelidir.',
      'Will be deleted:\n• Your profile information\n• Sleep stats and history\n• Favorite sounds and mixes\n• All account data\n\nNote: Any active subscription must be cancelled separately from your Apple ID settings.',
      'Se eliminarán:\n• Tu información de perfil\n• Estadísticas y historial de sueño\n• Sonidos y mezclas favoritos\n• Todos los datos de la cuenta\n\nNota: Una suscripción activa debe cancelarse por separado en los ajustes de tu ID de Apple.',
      'Seront supprimés :\n• Vos informations de profil\n• Statistiques et historique de sommeil\n• Sons et mixages favoris\n• Toutes les données du compte\n\nNote : Un abonnement actif doit être annulé séparément dans les réglages de l\'identifiant Apple.',
      'Wird gelöscht:\n• Profilinformationen\n• Schlafstatistiken und Verlauf\n• Lieblings-Sounds und Mixe\n• Alle Kontodaten\n\nHinweis: Ein aktives Abo muss separat in den Apple-ID-Einstellungen gekündigt werden.',
      'Будет удалено:\n• Информация профиля\n• Статистика и история сна\n• Любимые звуки и миксы\n• Все данные аккаунта\n\nПримечание: активную подписку нужно отменить отдельно в настройках Apple ID.',
      'سيتم حذف:\n• معلومات ملفك الشخصي\n• إحصائيات النوم والسجل\n• الأصوات والمكسات المفضلة\n• جميع بيانات الحساب\n\nملاحظة: يجب إلغاء أي اشتراك نشط بشكل منفصل من إعدادات معرف Apple.'
    ],
    'DeleteAccountConfirmTitle': ['Son Onay', 'Final Confirmation', 'Confirmación final', 'Confirmation finale', 'Letzte Bestätigung', 'Окончательное подтверждение', 'التأكيد النهائي'],
    'DeleteAccountTypeToConfirm': [
      'Onaylamak için aşağıya {keyword} yazın:',
      'Type {keyword} below to confirm:',
      'Escribe {keyword} abajo para confirmar:',
      'Tapez {keyword} ci-dessous pour confirmer :',
      'Geben Sie {keyword} unten ein, um zu bestätigen:',
      'Введите {keyword} ниже для подтверждения:',
      'اكتب {keyword} أدناه للتأكيد:'
    ],
    'DeleteConfirmKeyword': ['SİL', 'DELETE', 'ELIMINAR', 'SUPPRIMER', 'LÖSCHEN', 'УДАЛИТЬ', 'حذف'],
    'DeleteAccountSuccess': [
      'Hesabınız başarıyla silindi.',
      'Your account has been deleted.',
      'Tu cuenta ha sido eliminada.',
      'Votre compte a été supprimé.',
      'Ihr Konto wurde gelöscht.',
      'Ваш аккаунт удалён.',
      'تم حذف حسابك.'
    ],
    'DeleteAccountError': [
      'Hesap silinemedi. Lütfen tekrar deneyin.',
      'Could not delete account. Please try again.',
      'No se pudo eliminar la cuenta. Inténtalo de nuevo.',
      'Impossible de supprimer le compte. Veuillez réessayer.',
      'Konto konnte nicht gelöscht werden. Bitte erneut versuchen.',
      'Не удалось удалить аккаунт. Попробуйте ещё раз.',
      'تعذر حذف الحساب. حاول مرة أخرى.'
    ],
    'DeleteAccountReauthNeeded': [
      'Güvenlik için lütfen tekrar giriş yapın ve sonra hesabınızı silin.',
      'For security, please sign in again and then delete your account.',
      'Por seguridad, vuelve a iniciar sesión y luego elimina tu cuenta.',
      'Pour des raisons de sécurité, reconnectez-vous puis supprimez votre compte.',
      'Aus Sicherheitsgründen melden Sie sich erneut an und löschen Sie dann Ihr Konto.',
      'В целях безопасности войдите ещё раз и затем удалите аккаунт.',
      'لأسباب أمنية، يرجى تسجيل الدخول مرة أخرى ثم حذف حسابك.'
    ],
    'Ok': ['Tamam', 'OK', 'OK', 'OK', 'OK', 'OK', 'حسناً'],
    
    // Navigation
    'NavSounds': ['Sesler', 'Sounds', 'Sonidos', 'Sons', 'Geräusche', 'Звуки', 'الأصوات'],
    'NavFavorites': ['Favoriler', 'Favorites', 'Favoritos', 'Favoris', 'Favoriten', 'Избранное', 'المفضلة'],
    'NavRecord': ['Kaydet', 'Record', 'Grabar', 'Enregistrer', 'Aufnehmen', 'Запись', 'تسجيل'],
    'NavGames': ['Oyunlar', 'Games', 'Juegos', 'Jeux', 'Spiele', 'Игры', 'ألعاب'],
    'NavSettings': ['Ayarlar', 'Settings', 'Ajustes', 'Paramètres', 'Einstellungen', 'Настройки', 'الإعدادات'],
    // Home / Sounds Screen
    'GoodNight': ['İyi uykular', 'Good night', 'Buenas noches', 'Bonne nuit', 'Gute Nacht', 'Спокойной ночи', 'تصبح على خير'],
    'MixerTitle': ['Karıştırıcı', 'Mixer', 'Mezclador', 'Mélangeur', 'Mixer', 'Микшер', 'الخلاط'],
    'Shuffle': ['Karışık Çal', 'Shuffle', 'Aleatorio', 'Aléatoire', 'Zufall', 'Перемешать', 'عشوائي'],
    'SleepGuide': ['Uyku Rehberi', 'Sleep Guide', 'Guía de sueño', 'Guide du sommeil', 'Schlafratgeber', 'Гид по сну', 'دليل النوم'],
    'ShufflePlay': ['Karışık Çalma', 'Shuffle Play', 'Reproducción aleatoria', 'Lecture aléatoire', 'Zufallswiedergabe', 'Случайное воспроизведение', 'تشغيل عشوائي'],
    'MixerWithCount': ['Karıştırıcı ({n} ses)', 'Mixer ({n} sounds)', 'Mezclador ({n} sonidos)', 'Mélangeur ({n} sons)', 'Mixer ({n} Sounds)', 'Микшер ({n} звуков)', 'الخلاط ({n} أصوات)'],
    'UpgradeToPlus': ['Plus\'a Geç', 'Upgrade to Plus', 'Cambiar a Plus', 'Passer à Plus', 'Auf Plus upgraden', 'Перейти на Plus', 'الترقية إلى Plus'],
    'ActiveBadge': ['AKTİF', 'ACTIVE', 'ACTIVO', 'ACTIF', 'AKTIV', 'АКТИВЕН', 'نشط'],
    'ErrorPrefix': ['Hata', 'Error', 'Error', 'Erreur', 'Fehler', 'Ошибка', 'خطأ'],
    'PurchaseError': ['Satın alma hatası', 'Purchase error', 'Error de compra', 'Erreur d\'achat', 'Kauf fehlgeschlagen', 'Ошибка покупки', 'خطأ في الشراء'],
    'PurchaseTimeout': ['Satın alma tamamlanamadı. Lütfen tekrar deneyin.', 'Purchase could not be completed. Please try again.', 'No se pudo completar la compra. Inténtalo de nuevo.', 'L\'achat n\'a pas pu être finalisé. Veuillez réessayer.', 'Kauf konnte nicht abgeschlossen werden. Bitte versuchen Sie es erneut.', 'Не удалось завершить покупку. Попробуйте снова.', 'تعذّر إتمام عملية الشراء. حاول مرة أخرى.'],

    // Record Screen — uyarı diyaloğu
    'RecordSoundPlayingTitle': ['🎵 Ses Çalıyor', '🎵 Sound Playing', '🎵 Reproduciendo sonido', '🎵 Son en cours', '🎵 Sound läuft', '🎵 Звук воспроизводится', '🎵 الصوت قيد التشغيل'],
    'RecordSoundPlayingMsg': [
      'Şu anda bir ses çalınıyor. Kayda başladığınızda ses duracak. Devam etmek istiyor musunuz?',
      'A sound is currently playing. It will stop when you start recording. Do you want to continue?',
      'Hay un sonido reproduciéndose. Se detendrá al comenzar a grabar. ¿Quieres continuar?',
      'Un son est en cours de lecture. Il s\'arrêtera lorsque vous commencerez à enregistrer. Continuer ?',
      'Ein Sound wird gerade abgespielt. Er stoppt, wenn Sie aufnehmen. Möchten Sie fortfahren?',
      'Сейчас воспроизводится звук. Он остановится при начале записи. Продолжить?',
      'يتم تشغيل صوت حاليًا. سيتوقف عند بدء التسجيل. هل تريد المتابعة؟'
    ],
    'RecordCancelBtn': ['Vazgeç', 'Cancel', 'Cancelar', 'Annuler', 'Abbrechen', 'Отмена', 'إلغاء'],
    'RecordStartBtn': ['Kayda Başla', 'Start Recording', 'Comenzar a grabar', 'Démarrer l\'enregistrement', 'Aufnahme starten', 'Начать запись', 'بدء التسجيل'],

    // Feedback Screen
    'FeedbackTitle': ['Geri Bildirim Gönder', 'Send Feedback', 'Enviar comentarios', 'Envoyer un commentaire', 'Feedback senden', 'Отправить отзыв', 'إرسال ملاحظات'],
    'FeedbackSubtitle': ['Her yorumunuz değerlidir', 'Every comment matters', 'Cada comentario importa', 'Chaque commentaire compte', 'Jeder Kommentar zählt', 'Каждый отзыв важен', 'كل تعليق مهم'],
    'FeedbackCategoryLabel': ['Kategori', 'Category', 'Categoría', 'Catégorie', 'Kategorie', 'Категория', 'الفئة'],
    'FeedbackMessageLabel': ['Mesajınız', 'Your message', 'Tu mensaje', 'Votre message', 'Ihre Nachricht', 'Ваше сообщение', 'رسالتك'],
    'FeedbackMessageHint': [
      'Uygulamayı nasıl daha iyi yapabiliriz? Bir hata mı buldunuz?',
      'How can we make the app better? Did you find a bug?',
      '¿Cómo podemos mejorar la aplicación? ¿Encontraste un error?',
      'Comment pouvons-nous améliorer l\'application ? Avez-vous trouvé un bug ?',
      'Wie können wir die App verbessern? Haben Sie einen Fehler gefunden?',
      'Как нам улучшить приложение? Нашли ошибку?',
      'كيف يمكننا تحسين التطبيق؟ هل وجدت خطأ؟'
    ],
    'FeedbackMinChars': ['Lütfen en az 10 karakter yazın.', 'Please type at least 10 characters.', 'Escribe al menos 10 caracteres.', 'Veuillez saisir au moins 10 caractères.', 'Bitte mindestens 10 Zeichen eingeben.', 'Введите хотя бы 10 символов.', 'يرجى كتابة 10 أحرف على الأقل.'],
    'FeedbackSendError': ['Gönderim başarısız, lütfen tekrar deneyin.', 'Sending failed, please try again.', 'Error al enviar, inténtalo de nuevo.', 'Échec de l\'envoi, réessayez.', 'Senden fehlgeschlagen, bitte erneut versuchen.', 'Не удалось отправить, попробуйте ещё раз.', 'فشل الإرسال، حاول مرة أخرى.'],
    'FeedbackThanks': ['Teşekkür ederiz! 🎉', 'Thank you! 🎉', '¡Gracias! 🎉', 'Merci ! 🎉', 'Danke! 🎉', 'Спасибо! 🎉', 'شكراً لك! 🎉'],
    'FeedbackSuccess': [
      'Geri bildiriminiz başarıyla iletildi.\nHer yorum Sleepora\'yı daha iyi yapıyor.',
      'Your feedback was sent successfully.\nEvery comment makes Sleepora better.',
      'Tu comentario se envió correctamente.\nCada comentario hace mejor a Sleepora.',
      'Votre commentaire a été envoyé avec succès.\nChaque commentaire améliore Sleepora.',
      'Ihr Feedback wurde erfolgreich gesendet.\nJeder Kommentar macht Sleepora besser.',
      'Ваш отзыв успешно отправлен.\nКаждый отзыв делает Sleepora лучше.',
      'تم إرسال ملاحظاتك بنجاح.\nكل تعليق يجعل Sleepora أفضل.'
    ],
    'FeedbackSendBtn': ['Gönder', 'Send', 'Enviar', 'Envoyer', 'Senden', 'Отправить', 'إرسال'],
    'FeedbackSendingAs': ['olarak gönderilecek', 'will be sent as', 'se enviará como', 'sera envoyé en tant que', 'wird gesendet als', 'будет отправлено как', 'سيتم الإرسال باسم'],
    'FeedbackAnonymous': ['Anonim olarak gönderilecek', 'Will be sent anonymously', 'Se enviará de forma anónima', 'Sera envoyé anonymement', 'Wird anonym gesendet', 'Будет отправлено анонимно', 'سيتم الإرسال بشكل مجهول'],
    'FeedbackYou': ['Sen', 'You', 'Tú', 'Vous', 'Du', 'Вы', 'أنت'],
    'FeedbackCatBug': ['Hata Raporu', 'Bug Report', 'Reporte de error', 'Rapport de bug', 'Fehlerbericht', 'Сообщение об ошибке', 'تقرير خطأ'],
    'FeedbackCatSuggestion': ['Öneri', 'Suggestion', 'Sugerencia', 'Suggestion', 'Vorschlag', 'Предложение', 'اقتراح'],
    'FeedbackCatGeneral': ['Genel', 'General', 'General', 'Général', 'Allgemein', 'Общее', 'عام'],

    // ── Game UI (common) ──
    'GameHowToPlay': ['Nasıl Oynanır', 'How to Play', 'Cómo jugar', 'Comment jouer', 'Wie man spielt', 'Как играть', 'كيفية اللعب'],
    'GameHowToPlayQ': ['Nasıl Oynanır?', 'How to Play?', '¿Cómo jugar?', 'Comment jouer ?', 'Wie spielt man?', 'Как играть?', 'كيف تلعب؟'],
    'GameRestart': ['Yeniden Başlat', 'Restart', 'Reiniciar', 'Recommencer', 'Neu starten', 'Заново', 'إعادة'],
    'GameNext': ['İleri', 'Next', 'Siguiente', 'Suivant', 'Weiter', 'Далее', 'التالي'],
    'GameGotIt': ['Anladım', 'Got it', 'Entendido', 'Compris', 'Verstanden', 'Понял', 'فهمت'],
    'GameStart': ['Başlat', 'Start', 'Iniciar', 'Démarrer', 'Starten', 'Старт', 'ابدأ'],
    'GameCancel': ['İptal', 'Cancel', 'Cancelar', 'Annuler', 'Abbrechen', 'Отмена', 'إلغاء'],
    'GameBuy': ['Satın Al', 'Buy', 'Comprar', 'Acheter', 'Kaufen', 'Купить', 'شراء'],
    'GameSelect': ['Seç', 'Select', 'Seleccionar', 'Sélectionner', 'Auswählen', 'Выбрать', 'اختر'],
    'GameMenu': ['Menü', 'Menu', 'Menú', 'Menu', 'Menü', 'Меню', 'القائمة'],
    'GameMainMenu': ['Ana Menüye Dön', 'Back to Main Menu', 'Volver al menú principal', 'Retour au menu principal', 'Zurück zum Hauptmenü', 'Вернуться в главное меню', 'العودة إلى القائمة الرئيسية'],
    'GameWatchAdContinue': ['Reklam İzle, Devam Et', 'Watch Ad to Continue', 'Ver anuncio para continuar', 'Regarder une pub pour continuer', 'Werbung ansehen, fortfahren', 'Смотреть рекламу, чтобы продолжить', 'شاهد إعلاناً للمتابعة'],
    'GameBest': ['EN İYİ', 'BEST', 'MEJOR', 'MEILLEUR', 'BESTE', 'ЛУЧШИЙ', 'الأفضل'],
    'Game2048Reached': ['2048\'e Ulaştın!', 'You reached 2048!', '¡Llegaste a 2048!', 'Vous avez atteint 2048 !', '2048 erreicht!', 'Вы достигли 2048!', 'وصلت إلى 2048!'],
    'GameLight': ['Aydınlık', 'Light', 'Claro', 'Clair', 'Hell', 'Светлая', 'فاتح'],
    'GameVibration': ['Titreşim', 'Vibration', 'Vibración', 'Vibration', 'Vibration', 'Вибрация', 'الاهتزاز'],
    'GameVibrationOn': ['Açık — dokunma ve eşleşmelerde', 'On — on taps and matches', 'Activado — al tocar y emparejar', 'Activée — au toucher et aux correspondances', 'Ein — bei Tipps und Treffern', 'Включено — при касании и совпадениях', 'مفعّل — عند اللمس والمطابقات'],
    'GameVibrationOff': ['Kapalı — sessiz oyna', 'Off — play silently', 'Apagado — juega en silencio', 'Désactivée — jouez silencieusement', 'Aus — leise spielen', 'Выключено — играть тихо', 'مغلق — العب بصمت'],

    // Minesweeper specific
    'MSTimeUp': ['Süre doldu!', 'Time\'s up!', '¡Tiempo agotado!', 'Temps écoulé !', 'Zeit abgelaufen!', 'Время вышло!', 'انتهى الوقت!'],
    'MSMineHit': ['Mayına bastın!', 'You hit a mine!', '¡Pisaste una mina!', 'Vous avez touché une mine !', 'Sie haben eine Mine getroffen!', 'Вы попали на мину!', 'وقعت على لغم!'],
    'MSTimeLabel': ['Süre', 'Time', 'Tiempo', 'Temps', 'Zeit', 'Время', 'الوقت'],
    'MSThemeShop': ['Tema Dükkanı', 'Theme Shop', 'Tienda de temas', 'Boutique de thèmes', 'Theme-Shop', 'Магазин тем', 'متجر السمات'],
    'MSDailyReward': ['Günlük Ödül', 'Daily Reward', 'Recompensa diaria', 'Récompense quotidienne', 'Tägliche Belohnung', 'Ежедневная награда', 'مكافأة يومية'],
    'MSThemePurchased': ['{name} satın alındı ve aktif edildi', '{name} purchased and activated', '{name} comprado y activado', '{name} acheté et activé', '{name} gekauft und aktiviert', '{name} куплено и активировано', 'تم شراء {name} وتفعيله'],
    'MSPurchaseFailed': ['Satın alma başarısız', 'Purchase failed', 'Compra fallida', 'Achat échoué', 'Kauf fehlgeschlagen', 'Ошибка покупки', 'فشل الشراء'],
    'MSCoinsEarned': ['+{n} coin kazandın!', '+{n} coins earned!', '¡+{n} monedas ganadas!', '+{n} pièces gagnées !', '+{n} Münzen verdient!', '+{n} монет получено!', 'كسبت +{n} عملة!'],
    'MSBuyConfirm': ['Bu temayı satın almak için {n} coin harcayacaksın.', 'You will spend {n} coins to buy this theme.', 'Gastarás {n} monedas para comprar este tema.', 'Vous dépenserez {n} pièces pour acheter ce thème.', 'Sie geben {n} Münzen aus, um dieses Theme zu kaufen.', 'Вы потратите {n} монет на покупку этой темы.', 'ستنفق {n} عملة لشراء هذه السمة.'],
    'MSLevelSkipped': ['Seviye atlandı! (-50 coin)', 'Level skipped! (-50 coins)', '¡Nivel saltado! (-50 monedas)', 'Niveau passé ! (-50 pièces)', 'Level übersprungen! (-50 Münzen)', 'Уровень пропущен! (-50 монет)', 'تم تخطي المستوى! (-50 عملة)'],
    'MSTutOpenTitle': ['Aç', 'Open', 'Abrir', 'Ouvrir', 'Öffnen', 'Открыть', 'افتح'],
    'MSTutOpenDesc': ['Bir kareye dokunarak açabilirsin. Çıkan sayı o karenin etrafındaki mayın sayısını gösterir.', 'Tap a tile to open it. The number shown is the count of mines around that tile.', 'Toca una casilla para abrirla. El número muestra cuántas minas hay alrededor.', 'Touchez une case pour l\'ouvrir. Le nombre indique les mines autour.', 'Tippen Sie auf ein Feld, um es zu öffnen. Die Zahl zeigt die Minen drumherum.', 'Коснитесь клетки, чтобы открыть её. Число показывает количество мин вокруг.', 'انقر على المربع لفتحه. الرقم يظهر عدد الألغام حوله.'],
    'MSTutFlagTitle': ['Bayrak', 'Flag', 'Bandera', 'Drapeau', 'Flagge', 'Флаг', 'علم'],
    'MSTutFlagDesc': ['Bir karede mayın olduğundan eminsen uzun basarak bayrak koyabilirsin. Böylece yanlışlıkla basmazsın.', 'Long-press a tile to place a flag if you\'re sure it has a mine. This prevents accidental taps.', 'Mantén pulsada una casilla para colocar una bandera si crees que tiene mina.', 'Maintenez une case appuyée pour placer un drapeau si vous êtes sûr qu\'elle contient une mine.', 'Halten Sie ein Feld gedrückt, um eine Flagge zu setzen, wenn Sie sich sicher sind.', 'Удерживайте клетку, чтобы поставить флаг, если уверены, что там мина.', 'اضغط مطولاً على المربع لوضع علم إذا كنت متأكداً من وجود لغم.'],
    'MSTutMineTitle': ['Mayına Dikkat', 'Watch the Mines', 'Cuidado con las minas', 'Attention aux mines', 'Pass auf die Minen auf', 'Осторожно с минами', 'احذر الألغام'],
    'MSTutMineDesc': ['Mayına bastığında oyun biter ve bulunmayan bütün mayınlar gösterilir. Amacın tüm güvenli kareleri açmak.', 'If you hit a mine the game ends and all unflagged mines are revealed. Open all safe tiles to win.', 'Si pisas una mina el juego termina y se revelan todas las minas. Abre todas las casillas seguras.', 'Si vous touchez une mine la partie est perdue. Ouvrez toutes les cases sûres.', 'Wenn Sie eine Mine treffen, ist das Spiel vorbei. Öffnen Sie alle sicheren Felder.', 'Если попадёте на мину — игра окончена. Откройте все безопасные клетки.', 'إذا ضربت لغماً تنتهي اللعبة. افتح كل المربعات الآمنة.'],
    'MSTutTimeTitle': ['Süreye Karşı', 'Beat the Clock', 'Contra el reloj', 'Contre la montre', 'Gegen die Uhr', 'Против часов', 'ضد الساعة'],
    'MSTutTimeDesc': ['Her seviyenin bir süre limiti vardır. Ne kadar hızlı bitirirsen o kadar çok yıldız ve coin kazanırsın.', 'Each level has a time limit. The faster you finish the more stars and coins you earn.', 'Cada nivel tiene un límite de tiempo. Cuanto más rápido termines, más estrellas y monedas ganarás.', 'Chaque niveau a une limite de temps. Plus vite vous finissez, plus vous gagnez d\'étoiles et de pièces.', 'Jedes Level hat ein Zeitlimit. Je schneller Sie fertig sind, desto mehr Sterne und Münzen.', 'У каждого уровня есть лимит времени. Чем быстрее, тем больше звёзд и монет.', 'لكل مستوى وقت محدد. كلما انتهيت أسرع كسبت نجوماً وعملات أكثر.'],

    // Block puzzle
    'BPSelectPieceTitle': ['Parça Seç', 'Pick a Piece', 'Elige una pieza', 'Choisir une pièce', 'Stück wählen', 'Выберите фигуру', 'اختر قطعة'],
    'BPSelectPieceDesc': ['Alt kısımdaki 3 parçadan birini parmağınla tut ve tahtanın üzerine doğru sürükle. Tıkladığın anda parçayı yakalar.', 'Hold one of the 3 pieces at the bottom and drag it onto the board. It grabs the piece as you tap.', 'Mantén una de las 3 piezas inferiores y arrástrala al tablero.', 'Maintenez une des 3 pièces du bas et glissez-la sur le plateau.', 'Halten Sie eines der 3 Stücke unten und ziehen Sie es auf das Brett.', 'Удерживайте одну из 3 фигур внизу и тащите её на доску.', 'امسك إحدى القطع الثلاث في الأسفل واسحبها إلى اللوحة.'],
    'BPPlacePieceTitle': ['Tahtaya Yerleştir', 'Place on Board', 'Coloca en el tablero', 'Placer sur le plateau', 'Aufs Brett legen', 'Поставить на доску', 'ضع على اللوحة'],
    'BPPlacePieceDesc': ['Parça uygun bir alana denk geldiğinde renkli bir önizleme belirir. Parmağını kaldırınca parça oraya kilitlenir.', 'When the piece fits a valid area a colored preview appears. Lift your finger to lock it.', 'Cuando la pieza encaja en un área válida aparece una vista previa coloreada.', 'Quand la pièce s\'adapte une prévisualisation colorée apparaît.', 'Wenn das Stück passt, erscheint eine farbige Vorschau.', 'Когда фигура помещается, появляется цветной предпросмотр.', 'عند ملاءمة القطعة لمكان صالح، تظهر معاينة ملوّنة.'],
    'BPClearTitle': ['Satır veya Sütun Doldur', 'Fill a Row or Column', 'Llena fila o columna', 'Remplir ligne ou colonne', 'Reihe oder Spalte füllen', 'Заполнить ряд или колонку', 'املأ صفاً أو عموداً'],
    'BPClearDesc': ['Tam bir satır ya da sütun doldurduğunda o çizgi parlayarak temizlenir ve bonus puan kazanırsın.', 'When you fill a full row or column it glows and clears, earning you bonus points.', 'Cuando llenas una fila o columna completa se ilumina y desaparece dando puntos bonus.', 'Quand vous remplissez une ligne ou colonne complète elle s\'illumine et disparaît.', 'Wenn Sie eine volle Reihe oder Spalte füllen, leuchtet sie und verschwindet.', 'Когда вы заполняете полный ряд или колонку, они светятся и исчезают.', 'عندما تملأ صفاً أو عموداً كاملاً يلمع ويختفي.'],
    'BPComboDesc': ['Aynı hamlede birden fazla satır/sütun temizlersen combo bonusu kazanırsın. Parça yerleştirecek yer kalmadığında oyun biter.', 'Clear multiple rows/columns in one move for a combo bonus. The game ends when no piece can be placed.', 'Limpia varias filas/columnas en una jugada para bonus combo. El juego termina cuando no hay espacio.', 'Effacez plusieurs lignes/colonnes en un coup pour un combo. La partie se termine quand aucune pièce ne peut être placée.', 'Räumen Sie mehrere Reihen/Spalten gleichzeitig für Combo-Bonus. Das Spiel endet, wenn kein Platz mehr ist.', 'Очистите несколько рядов/колонок одним ходом для бонуса. Игра заканчивается когда нет места.', 'امسح عدة صفوف/أعمدة بحركة واحدة للحصول على مكافأة كومبو. تنتهي اللعبة عند عدم وجود مكان.'],

    // Quiz
    'QuizCatGeneral': ['Genel Kültür', 'General Knowledge', 'Cultura general', 'Culture générale', 'Allgemeinwissen', 'Общие знания', 'الثقافة العامة'],
    'GameCongrats': ['Tebrikler!', 'Congratulations!', '¡Felicidades!', 'Félicitations !', 'Glückwunsch!', 'Поздравляем!', 'تهانينا!'],
    'QuizCorrect': ['Doğru', 'Correct', 'Correctas', 'Correctes', 'Richtig', 'Верно', 'صحيح'],
    'QuizSuccess': ['Başarı', 'Success', 'Éxito', 'Réussite', 'Erfolg', 'Успех', 'النجاح'],
    'Round': ['Tur', 'Round', 'Ronda', 'Tour', 'Runde', 'Раунд', 'جولة'],

    // Notification Service
    'NotifReminderChannel': ['Uyku Hatırlatıcısı', 'Sleep Reminder', 'Recordatorio de sueño', 'Rappel de sommeil', 'Schlaferinnerung', 'Напоминание о сне', 'تذكير النوم'],
    'NotifReminderChannelDesc': ['Bebeğinizin uyku saati geldi.', 'Time for your baby to sleep.', 'Hora de dormir para tu bebé.', 'C\'est l\'heure de dormir pour votre bébé.', 'Schlafenszeit für Ihr Baby.', 'Время сна вашего малыша.', 'حان وقت نوم طفلك.'],
    'NotifReminderTitle': ['Uyku Vakti!', 'Sleep Time!', '¡Hora de dormir!', 'L\'heure de dormir !', 'Schlafenszeit!', 'Время сна!', 'وقت النوم!'],
    'NotifReminderBody': ['Bebeğinizin uyku rutinini başlatma saati geldi.', 'Time to start your baby\'s sleep routine.', 'Es hora de iniciar la rutina de sueño de tu bebé.', 'Il est temps de commencer la routine de sommeil de votre bébé.', 'Es ist Zeit, die Schlafroutine Ihres Babys zu starten.', 'Пора начать ритуал отхода ко сну.', 'حان الوقت لبدء روتين نوم طفلك.'],
    'NotifPreChannel': ['Hazırlık Hatırlatıcısı', 'Preparation Reminder', 'Recordatorio de preparación', 'Rappel de préparation', 'Vorbereitungserinnerung', 'Напоминание о подготовке', 'تذكير التحضير'],
    'NotifPreChannelDesc': ['Uyku rutini öncesi hazırlık bildirimi.', 'Notification before sleep routine.', 'Notificación antes de la rutina de sueño.', 'Notification avant la routine de sommeil.', 'Benachrichtigung vor der Schlafroutine.', 'Уведомление перед ритуалом сна.', 'إشعار قبل روتين النوم.'],
    'NotifPreTitle': ['Hazırlık Vakti 🌙', 'Preparation Time 🌙', 'Hora de prepararse 🌙', 'Préparation 🌙', 'Vorbereitungszeit 🌙', 'Время подготовки 🌙', 'وقت التحضير 🌙'],
    'NotifPreBody': [
      '{n} dakika sonra uyku saati. Banyo, loş ışık ve sakin rutin için hazırlanın.',
      'Sleep time in {n} minutes. Prepare for bath, dim lights, and a calm routine.',
      'Hora de dormir en {n} minutos. Prepara baño, luz tenue y rutina tranquila.',
      'Heure de coucher dans {n} minutes. Préparez le bain, lumière tamisée et routine calme.',
      'Schlafenszeit in {n} Minuten. Vorbereiten: Bad, gedämpftes Licht, ruhige Routine.',
      'Сон через {n} минут. Подготовьте ванну, приглушённый свет и спокойный ритуал.',
      'وقت النوم بعد {n} دقيقة. تحضّر للحمام والإضاءة الخافتة وروتين هادئ.'
    ],
    'NotifTrialChannel': ['Deneme Hatırlatıcısı', 'Trial Reminder', 'Recordatorio de prueba', 'Rappel d\'essai', 'Testphase-Erinnerung', 'Напоминание о пробном периоде', 'تذكير التجربة'],
    'NotifTrialChannelDesc': ['Sleepora Plus deneme süresi hatırlatıcısı.', 'Sleepora Plus trial reminder.', 'Recordatorio de prueba de Sleepora Plus.', 'Rappel d\'essai Sleepora Plus.', 'Sleepora Plus Testphasen-Erinnerung.', 'Напоминание о пробном периоде Sleepora Plus.', 'تذكير تجربة Sleepora Plus.'],
    'NotifTrialTitle': ['⏰ Deneme süreniz bitiyor!', '⏰ Your trial is ending!', '⏰ ¡Tu prueba está terminando!', '⏰ Votre essai se termine !', '⏰ Ihre Testphase endet!', '⏰ Ваш пробный период заканчивается!', '⏰ تنتهي فترة تجربتك!'],
    'NotifTrialBody': ['Sleepora Plus denemenizin bitmesine 2 gün kaldı. Tüm özelliklere erişmeye devam etmek için abone olun.', '2 days left in your Sleepora Plus trial. Subscribe to keep all features.', 'Quedan 2 días de tu prueba de Sleepora Plus. Suscríbete para conservar todas las funciones.', 'Il reste 2 jours à votre essai Sleepora Plus. Abonnez-vous pour garder toutes les fonctionnalités.', '2 Tage verbleibend in Ihrer Sleepora Plus Testphase. Abonnieren Sie, um alle Funktionen zu behalten.', 'Осталось 2 дня пробного периода Sleepora Plus. Подпишитесь, чтобы сохранить все функции.', 'تبقى يومان من تجربة Sleepora Plus. اشترك للاحتفاظ بجميع الميزات.'],

    // Review Service
    'ReviewTitle': ['Sleepora\'yı Beğendiniz mi?', 'Do you like Sleepora?', '¿Te gusta Sleepora?', 'Aimez-vous Sleepora ?', 'Gefällt Ihnen Sleepora?', 'Вам нравится Sleepora?', 'هل تحب Sleepora؟'],
    'ReviewDesc': ['Uygulamayı puanlayarak diğer ailelere yardımcı olabilirsiniz.', 'Rate the app to help other families.', 'Califica la app para ayudar a otras familias.', 'Notez l\'application pour aider d\'autres familles.', 'Bewerten Sie die App, um anderen Familien zu helfen.', 'Оцените приложение, чтобы помочь другим семьям.', 'قيّم التطبيق لمساعدة العائلات الأخرى.'],
    'ReviewRate': ['Uygulamayı Puanla', 'Rate the App', 'Califica la app', 'Noter l\'application', 'App bewerten', 'Оценить приложение', 'قيّم التطبيق'],
    'ReviewLater': ['Şimdi Değil', 'Not Now', 'Ahora no', 'Pas maintenant', 'Nicht jetzt', 'Не сейчас', 'ليس الآن'],

    // Paywall
    'Restore': ['Geri Yükle', 'Restore', 'Restablecer', 'Restaurer', 'Wiederherstellen', 'Восстановить', 'استعادة'],
    'Yearly': ['Yıllık', 'Yearly', 'Anual', 'Annuel', 'Jährlich', 'Год', 'سنوي'],
    'Monthly': ['Aylık', 'Monthly', 'Mensual', 'Mensuel', 'Monatlich', 'Месяц', 'شهري'],
    'Lifetime': ['Ömür Boyu', 'Lifetime', 'De por vida', 'À vie', 'Lebenslang', 'Навсегда', 'مدى الحياة'],
    'DaysLeft': ['{n} gün kaldı', '{n} days left', 'Quedan {n} días', 'Il reste {n} jours', 'Noch {n} Tage', 'Осталось {n} дн.', 'متبقي {n} يوم'],
    'MonthlyPlan': ['Aylık Abone', 'Monthly Plan', 'Plan mensual', 'Plan mensuel', 'Monatsabo', 'Месячная подписка', 'اشتراك شهري'],
    'YearlyPlan': ['Yıllık Abone', 'Yearly Plan', 'Plan anual', 'Plan annuel', 'Jahresabo', 'Годовая подписка', 'اشتراك سنوي'],
    'ManageSubscription': ['Aboneliği Yönet', 'Manage Subscription', 'Gestionar suscripción', 'Gérer l\'abonnement', 'Abo verwalten', 'Управление подпиской', 'إدارة الاشتراك'],
    'PlusActiveTitle': ['Sleepora Plus Aktif', 'Sleepora Plus Active', 'Sleepora Plus activo', 'Sleepora Plus actif', 'Sleepora Plus aktiv', 'Sleepora Plus активен', 'Sleepora Plus نشط'],
    'Popular': ['EN POPÜLER', 'MOST POPULAR', 'MÁS POPULAR', 'PLUS POPULAIRE', 'BELIEBTEST', 'САМЫЙ ПОПУЛЯРНЫЙ', 'الأكثر شعبية'],
    'BestValue': ['EN AVANTAJLI', 'BEST VALUE', 'MEJOR PRECIO', 'MEILLEUR PRIX', 'BESTER PREIS', 'ЛУЧШАЯ ЦЕНА', 'أفضل قيمة'],
    'Purchase': ['Satın Al', 'Purchase', 'Comprar', 'Acheter', 'Kaufen', 'Купить', 'شراء'],
    'TryFree': ['Ücretsiz Deneyin', 'Try for Free', 'Prueba gratis', 'Essayer gratuitement', 'Kostenlos testen', 'Попробовать бесплатно', 'جرب مجاناً'],
    'Terms': ['Şartlar', 'Terms', 'Términos', 'Conditions', 'Bedingungen', 'Условия', 'الشروط'],
    'Privacy': ['Gizlilik', 'Privacy', 'Privacidad', 'Confidentialité', 'Datenschutz', 'Конфиденциальность', 'الخصوصية'],
    'SecureApple': ['Apple ile Güvenli', 'Secure with Apple', 'Seguro con Apple', 'Sécurisé avec Apple', 'Sicher mit Apple', 'Защищено Apple', 'آمن مع Apple'],
    'SubscriptionDisclosure': [
      'Abonelik otomatik yenilenir. Mevcut dönem bitiminden 24 saat öncesine kadar iptal edilmezse aynı fiyattan yenilenir. İptali Apple Kimliği ayarlarınızdan yapabilirsiniz.',
      'Subscription auto-renews. Unless cancelled at least 24 hours before the end of the current period, it renews at the same price. You can manage or cancel anytime in your Apple ID settings.',
      'La suscripción se renueva automáticamente. Si no se cancela al menos 24 horas antes del final del período actual, se renueva al mismo precio. Puedes cancelarla en los ajustes de tu ID de Apple.',
      'L\'abonnement se renouvelle automatiquement. Sauf annulation au moins 24h avant la fin de la période en cours, il est renouvelé au même tarif. Annulation possible dans les réglages de l\'identifiant Apple.',
      'Das Abo verlängert sich automatisch. Wenn es nicht mindestens 24 Stunden vor Ende der laufenden Periode gekündigt wird, verlängert es sich zum gleichen Preis. Kündigung jederzeit in den Apple-ID-Einstellungen.',
      'Подписка продлевается автоматически. Если не отменить минимум за 24 часа до конца текущего периода, она будет продлена по той же цене. Управление — в настройках Apple ID.',
      'يتم تجديد الاشتراك تلقائيًا. ما لم يتم الإلغاء قبل 24 ساعة على الأقل من نهاية الفترة الحالية، فسيتم تجديده بنفس السعر. يمكنك الإلغاء من إعدادات معرف Apple.'
    ],
    'StartingToday': ['Bugünden itibaren', 'Starting today', 'A partir de hoy', 'À partir d\'aujourd\'hui', 'Ab heute', 'С сегодняшнего дня', 'بدءاً من اليوم'],
    'Free7Days': ['7 gün ücretsiz', '7 days free', '7 días gratis', '7 jours gratuits', '7 Tage kostenlos', '7 дней бесплатно', '7 أيام مجاناً'],
    'After7Days': ['7 gün sonra', 'After 7 days', 'Después de 7 días', 'Après 7 jours', 'Nach 7 Tagen', 'После 7 дней', 'بعد 7 أيام'],
    'CancelAnytime': ['Otomatik Yenileme, Her Zaman İptal Edilebilir', 'Auto-renew, cancel anytime', 'Renovación automática, cancela en cualquier momento', 'Renouvellement automatique, annulez à tout moment', 'Autom. Verlängerung, jederzeit kündbar', 'Автопродление, отмена в любое время', 'تجديد تلقائي، يمكن الإلغاء في أي وقت'],
    'LifetimeDesc': ['Tek seferlik ödeme — sonsuza kadar Plus', 'One-time payment — forever Plus', 'Pago único — Plus para siempre', 'Paiement unique — Plus pour toujours', 'Einmalige Zahlung — für immer Plus', 'Единовременная оплата — Plus навсегда', 'دفعة واحدة — Plus للأبد'],
    'PremiumActive': ['Plus Aktif', 'Plus Active', 'Plus Activo', 'Plus Actif', 'Plus Aktiv', 'Plus активен', 'Plus نشط'],
    'AllUnlocked': ['Tüm özellikler açık', 'All features unlocked', 'Todas las funciones desbloqueadas', 'Toutes les fonctions débloquées', 'Alle Funktionen freigeschaltet', 'Все функции открыты', 'تم فتح جميع الميزات'],
    'NoActiveSub': ['Aktif abonelik bulunamadı', 'No active subscription found', 'No se encontró suscripción activa', 'Aucun abonnement actif trouvé', 'Kein aktives Abonnement gefunden', 'Активная подписка не найдена', 'لم يتم العثور على اشتراك نشط'],
    'UnlockAllFeatures': ['Tüm özellikleri aç — 7 gün ücretsiz dene', 'Unlock all features — 7 day free trial', 'Desbloquea todo — prueba gratis de 7 días', 'Débloquez tout — essai gratuit de 7 jours', 'Alles freischalten — 7 Tage kostenlos testen', 'Откройте все функции — 7 дней бесплатно', 'افتح جميع الميزات — 7 أيام مجاناً'],

    // Settings
    'BabyNameDesc': ['Ana ekrandaki iyi geceler mesajını kişiselleştirmek için...', 'To personalize the good night message on the home screen...', 'Para personalizar el mensaje de buenas noches en la pantalla de inicio...', 'Pour personnaliser le message de bonne nuit sur l\'écran d\'accueil...', 'Um die Gute-Nacht-Nachricht auf dem Startbildschirm zu personalisieren...', 'Чтобы персонализировать сообщение спокойной ночи на главном экране...', 'لتخصيص رسالة تصبح على خير على الشاشة الرئيسية...'],
    'BabyNameTitle': ['BEBEĞİN ADI', 'BABY NAME', 'NOMBRE DEL BEBÉ', 'NOM DU BÉBÉ', 'BABYNAME', 'ИМЯ МАЛЫША', 'اسم الطفل'],
    'BabyNameHint': ['Bebeğin adını yaz...', 'Enter baby name...', 'Escribe el nombre del bebé...', 'Entrez le nom du bébé...', 'Babynamen eingeben...', 'Введите имя малыша...', 'أدخل اسم الطفل...'],
    'PlaybackTitle': ['Oynatma ve Hatırlatıcı', 'Playback & Reminders', 'Reproducción y Recordatorios', 'Lecture et Rappels', 'Wiedergabe & Erinnerungen', 'Воспроизведение и напоминания', 'التشغيل والتذكيرات'],
    'StopTimer': ['Zamanlayıcı Bitince Durdur', 'Stop When Timer Ends', 'Detener al terminar el temporizador', 'Arrêter à la fin du minuteur', 'Stoppen, wenn der Timer endet', 'Остановить по окончании таймера', 'إيقاف عند انتهاء المؤقت'],
    'StopTimerSub': ['Süre dolunca sesleri otomatik kapat', 'Auto-stop sounds when time is up', 'Detener sonidos automáticamente cuando se acabe el tiempo', 'Arrêter automatiquement les sons à la fin du temps', 'Töne otomatis stoppen, wenn die Zeit abgelaufen ist', 'Автоматическая остановка звуков по истечении времени', 'إيقاف الأصوات تلقائياً عند انتهاء الوقت'],
    'FadeOut': ['Yavaşça Kapat (Fade Out)', 'Fade Out', 'Desvanecimiento (Fade Out)', 'Fondu en fermeture (Fade Out)', 'Ausblenden (Fade Out)', 'Постепенное затухание', 'تلاشي'],
    'FadeOutSub': ['Sesi kademeli olarak azaltarak kapat', 'Gradually reduce volume before stopping', 'Reducir gradualmente el volumen antes de detener', 'Réduire progressivement le volume avant d\'arrêter', 'Lautstärke vor dem Stoppen schrittweise verringern', 'Постепенно уменьшать громкость перед остановкой', 'تقليل الصوت تدريجياً قبل الإيقاف'],
    'BackgroundPlay': ['Arka Planda Çalma', 'Background Playback', 'Reproducción en segundo plano', 'Lecture en arrière-plan', 'Hintergrundwiedergabe', 'Воспроизведение в фоне', 'التشغيل في الخلفية'],
    'BackgroundPlaySub': ['Uygulama kapatılınca da ses çalmaya devam etsin', 'Continue playing when app is closed', 'Continuar reproduciendo al cerrar la aplicación', 'Continuer la lecture quand l\'application est fermée', 'Weiter abspielen, wenn App geschlossen wird', 'Продолжать воспроизведение при закрытом приложении', 'متابعة التشغيل عند إغلاق التطبيق'],
    'SleepReminder': ['Uyku Hatırlatıcısı', 'Sleep Reminder', 'Recordatorio de sueño', 'Rappel de sommeil', 'Schlaferinnerung', 'Напоминание о сне', 'تذكير النوم'],
    'SleepReminderSub': ['Her gece belirlenen saatte bildirim gönder', 'Send a notification at the set time every night', 'Enviar una notificación a la hora establecida cada noche', 'Envoyer une notification à l\'heure fixée chaque nuit', 'Jede Nacht zur eingestellten Zeit eine Benachrichtigung senden', 'Отправлять уведомление в заданное время каждую ночь', 'إرسال إشعار في الوقت المحدد كل ليلة'],
    'ReminderTime': ['Hatırlatma Saati', 'Reminder Time', 'Hora del recordatorio', 'Heure du rappel', 'Erinnerungszeit', 'Время напоминания', 'وقت التذكير'],
    'ReminderMain': ['Ana Hatırlatma', 'Main Reminder', 'Recordatorio principal', 'Rappel principal', 'Haupterinnerung', 'Основное напоминание', 'التذكير الرئيسي'],
    'ReminderMainDesc': [
      'Tam uyku saatinde gönderilir — uyku rutinine başla.',
      'Sent right at bedtime — time to start the sleep routine.',
      'Se envía a la hora exacta — empieza la rutina de sueño.',
      'Envoyé à l\'heure exacte — démarrez la routine du coucher.',
      'Wird genau zur Schlafenszeit gesendet — starten Sie die Schlafroutine.',
      'Отправляется прямо перед сном — пора начинать ритуал.',
      'يتم إرساله عند موعد النوم — حان وقت بدء روتين النوم.',
    ],
    'PreReminder': ['Ön Hatırlatma', 'Pre-Reminder', 'Recordatorio previo', 'Rappel préliminaire', 'Vorerinnerung', 'Предварительное напоминание', 'تذكير مسبق'],
    'PreReminderDesc': [
      'Uyku saatinden önce hazırlık hatırlatması gönderir (banyo, loş ışık, sakin rutin).',
      'Sends a prep reminder before bedtime (bath, dim lights, calm routine).',
      'Envía un recordatorio de preparación antes de dormir (baño, luz tenue, rutina tranquila).',
      'Envoie un rappel de préparation avant le coucher (bain, lumière tamisée, routine calme).',
      'Sendet eine Vorbereitungserinnerung vor dem Schlafen (Bad, gedämpftes Licht, ruhige Routine).',
      'Отправляет напоминание о подготовке перед сном (ванна, приглушённый свет, спокойный ритуал).',
      'يرسل تذكير التحضير قبل النوم (الاستحمام، الإضاءة الخافتة، الروتين الهادئ).',
    ],
    'PreReminderOffset': ['Kaç dakika önce', 'How many minutes before', 'Cuántos minutos antes', 'Combien de minutes avant', 'Wie viele Minuten vorher', 'За сколько минут до', 'كم دقيقة قبل'],
    'MinutesBefore': ['dk önce', 'min before', 'min antes', 'min avant', 'Min vorher', 'мин до', 'د قبل'],
    'ReminderInfoTitle': ['Hatırlatıcı nasıl çalışır?', 'How does the reminder work?', '¿Cómo funciona el recordatorio?', 'Comment fonctionne le rappel ?', 'Wie funktioniert die Erinnerung?', 'Как работает напоминание?', 'كيف يعمل التذكير؟'],
    'ReminderInfoDesc': [
      'Hatırlatıcılar her gün aynı saatte tekrarlanır. Telefonunuz sessiz modda olsa da bildirim alırsınız (sistem ayarlarınıza bağlı).',
      'Reminders repeat every day at the same time. You\'ll receive notifications even in silent mode (depends on system settings).',
      'Los recordatorios se repiten cada día a la misma hora. Recibirás notificaciones incluso en modo silencio (según los ajustes del sistema).',
      'Les rappels se répètent chaque jour à la même heure. Vous recevrez des notifications même en mode silencieux (selon les paramètres système).',
      'Erinnerungen wiederholen sich jeden Tag zur selben Zeit. Sie erhalten Benachrichtigungen auch im stumm-Modus (abhängig von den Systemeinstellungen).',
      'Напоминания повторяются каждый день в одно и то же время. Уведомления приходят даже в беззвучном режиме (зависит от системных настроек).',
      'تتكرر التذكيرات كل يوم في نفس الوقت. ستتلقى الإشعارات حتى في الوضع الصامت (يعتمد على إعدادات النظام).',
    ],
    'LanguageTitle': ['Dil Seçimi', 'Language Setting', 'Ajuste de idioma', 'Choix de la langue', 'Spracheinstellung', 'Язык', 'إعداد اللغة'],
    'SupportContact': ['Destek & İletişim', 'Support & Contact', 'Soporte y Contacto', 'Support et Contact', 'Support & Kontakt', 'Поддержка и контакты', 'الدعم والاتصال'],
    'RateApp': ['Uygulamayı Puanla', 'Rate the App', 'Calificar la aplicación', 'Évaluer l\'application', 'App bewerten', 'Оценить приложение', 'قيّم التطبيق'],
    'FollowInsta': ['Instagram\'da Takip Et', 'Follow on Instagram', 'Síguenos en Instagram', 'Suivre sur Instagram', 'Auf Instagram folgen', 'Подписаться в Instagram', 'تابعنا على Instagram'],
    'YouTubeChannel': ['YouTube Kanalımız', 'Our YouTube Channel', 'Nuestro canal de YouTube', 'Notre chaîne YouTube', 'Unser YouTube-Kanal', 'Наш YouTube канал', 'قناتنا على YouTube'],
    'ContactFeed': ['İletişim & Öneri', 'Contact & Feedback', 'Contacto y Sugerencias', 'Contact et Retours', 'Kontakt & Feedback', 'Контакты и отзывы', 'الاتصال والتعليقات'],
    'PrivacyPolicy': ['Gizlilik Politikası', 'Privacy Policy', 'Política de Privacidad', 'Politique de confidentialité', 'Datenschutzrichtlinie', 'Политика конфиденциальности', 'سياسة الخصوصية'],
    'PeacefulSleep': ['Bebeğiniz için huzurlu uykular', 'Peaceful sleep for your baby', 'Sueño tranquilo para su bebé', 'Sommeil paisible pour votre bébé', 'Ruhiger Schlaf für Ihr Baby', 'Спокойный сон для вашего малыша', 'نوم هادئ لطفلك'],

    // Favorites / Mixer
    'LimitTitle': ['💡 Kayıt Sınırı', '💡 Save Limit', '💡 Límite de guardado', '💡 Limite d\'enregistrement', '💡 Speicherlimit', '💡 Лимит сохранения', '💡 حد الحفظ'],
    'LimitDesc': [
      'Ücretsiz sürümde en fazla 2 Mix kaydedebilirsiniz. Sınırsız miks kaydetmek için Sleepora Plus\'a geçin!',
      'You can save up to 2 Mixes in the free version. Upgrade to Sleepora Plus for unlimited mixes!',
      'Puedes guardar hasta 2 mezclas en la versión gratuita. ¡Mejora a Sleepora Plus para mezclas ilimitadas!',
      'Vous pouvez enregistrer jusqu\'à 2 mixes dans la version gratuite. Passez à Sleepora Plus pour des mixes illimités !',
      'In der kostenlosen Version können Sie bis zu 2 Mixe speichern. Upgrade auf Sleepora Plus für unbegrenzte Mixe!',
      'В бесплатной версии можно сохранить до 2 миксов. Перейдите на Sleepora Plus для безлимита!',
      'يمكنك حفظ ما يصل إلى 2 مزيج في الإصدار المجاني. قم بالترقية إلى Sleepora Plus للحصول على مزيج غير محدود!',
    ],
    'SeePlus': ['Plus\'ı Gör', 'See Plus', 'Ver Plus', 'Voir Plus', 'Plus ansehen', 'Открыть Plus', 'عرض Plus'],
    'SaveMix': ['Miksi Kaydet', 'Save Mix', 'Guardar mezcla', 'Enregistrer le mix', 'Mix speichern', 'Сохранить микс', 'حفظ المزيج'],
    'MixNameHint': ['Mix ismini yaz...', 'Enter mix name...', 'Escribe el nombre del mix...', 'Entrez le nom du mix...', 'Mix-Namen eingeben...', 'Введите название микса...', 'أدخل اسم المزيج...'],
    'Save': ['Kaydet', 'Save', 'Guardar', 'Enregistrer', 'Speichern', 'Сохранить', 'حفظ'],
    'MixSaved': ['Mix favorilere kaydedildi!', 'Mix saved to favorites!', '¡Mezcla guardada en favoritos!', 'Mix enregistré dans les favoris !', 'Mix in Favoriten gespeichert!', 'Микс сохранён в избранное!', 'تم حفظ المزيج في المفضلة!'],
    'EmptyFavorites': ['Henüz favori sesin yok', 'No favorite sounds yet', 'Aún no hay sonidos favoritos', 'Pas encore de sons favoris', 'Noch keine Favoriten', 'Пока нет избранных звуков', 'لا توجد أصوات مفضلة بعد'],
    'FavoritesDesc': ['Beğendiğin sesleri burada görebilirsin', 'You can see your liked sounds here', 'Puedes ver tus sonidos favoritos aquí', 'Vous pouvez voir vos sons préférés ici', 'Hier siehst du deine Lieblingsgeräusche', 'Здесь вы найдёте любимые звуки', 'يمكنك رؤية أصواتك المفضلة هنا'],
    'SavedMixesTitle': ['KAYDEDİLEN MİKSLER', 'SAVED MIXES', 'MEZCLAS GUARDADAS', 'MIX ENREGISTRÉS', 'GESPEICHERTE MIXE', 'СОХРАНЁННЫЕ МИКСЫ', 'المزيج المحفوظ'],

    // Sleep Guide Sections
    'GuideTitle_1': ['0-3 Ay: Yenidoğan ve Güven', '0-3 Months: Newborn and Trust', '0-3 meses: Recién nacido y confianza', '0-3 mois : Nouveau-né et confiance', '0-3 Monate: Neugeborene und Vertrauen', '0-3 месяца: Новорождённый и доверие', '0-3 أشهر: حديث الولادة والثقة'],
    'GuideContent_1': [
      'Yenidoğan bebekler günde 14-17 saat uyurlar ama bu uyku genellikle 2-4 saatlik periyotlar halinde olur. Beyaz gürültü ve kundaklama bebeğinizin kendini güvende hissetmesini sağlar.',
      'Newborns sleep 14-17 hours a day, but this sleep is usually in 2-4 hour periods. White noise and swaddling make your baby feel safe.',
      'Los recién nacidos duermen de 14 a 17 horas al día, pero este sueño suele ser en periodos de 2 a 4 horas. El ruido blanco y el envolver al bebé lo hacen sentir seguro.',
      'Les nouveau-nés dorment 14-17 heures par jour, mais ce sommeil se fait généralement par périodes de 2-4 heures. Le bruit blanc et l\'emmaillotage permettent à votre bébé de se sentir en sécurité.',
      'Neugeborene schlafen 14-17 Stunden am Tag, aber dieser Schlaf erfolgt normalerweise in 2-4-Stunden-Perioden. Weißes Rauschen und Pucken geben Ihrem Baby Sicherheit.',
      'Новорождённые спят 14-17 часов в сутки, обычно периодами по 2-4 часа. Белый шум и пеленание дают чувство безопасности.',
      'ينام حديثو الولادة من 14 إلى 17 ساعة يومياً، عادة في فترات من 2 إلى 4 ساعات. الضوضاء البيضاء والتقميط تجعل طفلك يشعر بالأمان.',
    ],
    'GuideTitle_2': ['4-6 Ay: Uyku Gerilemesi', '4-6 Months: Sleep Regression', '4-6 meses: Regresión del sueño', '4-6 mois : Régression du sommeil', '4-6 Monate: Schlafregression', '4-6 месяцев: Регресс сна', '4-6 أشهر: تراجع النوم'],
    'GuideContent_2': [
      '4. ay civarında uyku döngüleri değişir, bu da sık uyanmalara neden olabilir. Tutarlı bir uyku rutini oluşturmak çok önemlidir.',
      'Around the 4th month, sleep cycles change, which can cause frequent awakenings. It is very important to create a consistent sleep routine.',
      'Alrededor del cuarto mes, los ciclos de sueño cambian, lo que puede causar despertares frecuentes. Es muy importante crear una rutina de sueño constante.',
      'Vers le 4ème mois, les cycles de sommeil changent, ce qui peut provoquer des réveils fréquents. Il est très important de créer une routine de sommeil cohérente.',
      'Etwa im 4. Monat ändern sich die Schlafzyklen, was zu häufigem Aufwachen führen kann. Es ist sehr wichtig, eine konsequente Schlafroutine zu schaffen.',
      'Около 4-го месяца циклы сна меняются, что может вызывать частые пробуждения. Очень важно создать стабильный ритуал.',
      'في الشهر الرابع تقريباً، تتغير دورات النوم مما قد يسبب استيقاظاً متكرراً. من المهم جداً وضع روتين نوم ثابت.',
    ],
    'GuideTitle_3': ['6-12 Ay: Ayrılık Kaygısı', '6-12 Months: Separation Anxiety', '6-12 meses: Ansiedad por separación', '6-12 mois : Anxiété de séparation', '6-12 Monate: Trennungsangst', '6-12 месяцев: Тревога разлуки', '6-12 شهراً: قلق الانفصال'],
    'GuideContent_3': [
      'Bebeğiniz artık daha hareketli. Gece uyanıp sizi yanında göremeyince ağlayabilir. Ona dokunarak orada olduğunuzu hissettirin.',
      'Your baby is more active now. They may cry when they wake up at night and don\'t see you. Make them feel you are there by touching them.',
      'Tu bebé está más activo ahora. Puede llorar cuando se despierta por la noche y no te ve. Hazle sentir que estás allí tocándolo.',
      'Votre bébé est plus actif maintenant. Il peut pleurer lorsqu\'il se réveille la nuit et ne vous voit pas. Faites-lui sentir que vous êtes là en le touchant.',
      'Ihr Baby ist jetzt aktiver. Es kann weinen, wenn es nachts aufwacht und Sie nicht sieht. Geben Sie ihm das Gefühl, dass Sie da sind, indem Sie es berühren.',
      'Ваш малыш стал активнее. Ночью при пробуждении он может плакать, не видя вас. Дайте ему почувствовать ваше присутствие прикосновением.',
      'أصبح طفلك أكثر نشاطاً الآن. قد يبكي عند الاستيقاظ ليلاً ولا يراك. اجعله يشعر بوجودك من خلال لمسه.',
    ],
    'GuideTitle_4': ['12-24 Ay: Tek Uykuya Geçiş', '12-24 Months: Transition to One Nap', '12-24 meses: Transición a una siesta', '12-24 mois : Transition vers une sieste', '12-24 Monate: Übergang zu einem Schläfchen', '12-24 месяца: Переход на один дневной сон', '12-24 شهراً: الانتقال إلى قيلولة واحدة'],
    'GuideContent_4': [
      'Bebekler genellikle günde iki kez uyumaktan bir kez uyumaya geçiş yaparlar. Yatma saati rutinini kısa ve öngörülebilir tutun.',
      'Babies usually transition from napping twice a day to once a day. Keep the bedtime routine short and predictable.',
      'Los bebés suelen pasar de dormir dos siestas al día a una sola. Mantén la rutina de la hora de acostarse corta y predecible.',
      'Les bébés passent généralement de deux siestes par jour à une seule. Gardez la routine du coucher courte et prévisible.',
      'Babys wechseln normalerweise von zwei Schläfchen pro Tag zu einem. Halten Sie die Schlafenszeit-Routine kurz und vorhersehbar.',
      'Малыши обычно переходят с двух дневных снов к одному. Ритуал перед сном должен быть коротким и предсказуемым.',
      'ينتقل الأطفال عادة من القيلولة مرتين يومياً إلى مرة واحدة. اجعل روتين النوم قصيراً ومتوقعاً.',
    ],
    'GuideWarning': [
      'Bu bilgiler yalnızca genel bilgilendirme amaçlıdır. Endişeleriniz varsa bir sağlık uzmanına danışın.',
      'This information is for general information purposes only. Consult a healthcare professional if you have concerns.',
      'Esta información es sólo para fines de información general. Consulte a un profesional de la salud si tiene inquietudes.',
      'Ces informations sont fournies à titre indicatif uniquement. Consultez un professionnel de la santé si vous avez des inquiétudes.',
      'Diese Informationen dienen nur der allgemeinen Information. Wenden Sie sich bei Bedenken an einen Arzt.',
      'Эта информация носит общий характер. При сомнениях обратитесь к специалисту.',
      'هذه المعلومات لأغراض المعلومات العامة فقط. استشر متخصصاً صحياً إذا كان لديك مخاوف.',
    ],

    // ─── Sleep Guide — yeni içerik (hero, süre/uyku bilgisi, ipuçları) ───
    'GuideHeroSubtitle': [
      'Bebeğinizin yaşına göre uyku rehberi',
      'A sleep guide tailored to your baby\'s age',
      'Una guía de sueño adaptada a la edad de tu bebé',
      'Un guide du sommeil adapté à l\'âge de votre bébé',
      'Ein auf das Alter Ihres Babys abgestimmter Schlafratgeber',
      'Гид по сну с учётом возраста вашего малыша',
      'دليل نوم مصمم خصيصاً لعمر طفلك',
    ],
    'GuideKeyTips': ['Önemli İpuçları', 'Key Tips', 'Consejos Clave', 'Conseils Clés', 'Wichtige Tipps', 'Важные советы', 'نصائح أساسية'],
    'GuideSleepDuration': ['Günlük Uyku', 'Daily Sleep', 'Sueño Diario', 'Sommeil Quotidien', 'Täglicher Schlaf', 'Дневной сон', 'النوم اليومي'],
    'GuideNapsLabel': ['Uyutma', 'Naps', 'Siestas', 'Siestes', 'Schläfchen', 'Дрёма', 'قيلولات'],

    // 0-3 Ay
    'GuideStat_1': ['14-17 sa', '14-17 h', '14-17 h', '14-17 h', '14-17 Std', '14-17 ч', '14-17 س'],
    'GuideNaps_1': ['4-5', '4-5', '4-5', '4-5', '4-5', '4-5', '4-5'],
    'GuideTip_1_1': [
      'Gece ve gündüzü ayırt edebilmesi için gündüz aydınlık, gece loş bir ortam yaratın.',
      'Create a bright daytime and dim nighttime so your baby learns day from night.',
      'Crea un ambiente luminoso de día y tenue de noche para que distinga día y noche.',
      'Créez un environnement lumineux le jour et tamisé la nuit pour distinguer jour et nuit.',
      'Schaffen Sie tagsüber Helligkeit und nachts Dämmerung, damit Tag und Nacht unterschieden werden.',
      'Создайте яркий день и приглушённую ночь, чтобы малыш различал их.',
      'اخلق نهاراً مضيئاً وليلاً معتماً حتى يميز طفلك بين النهار والليل.',
    ],
    'GuideTip_1_2': [
      'Uyku işaretlerini (esneme, gözleri ovalama) kaçırmadan yatırın.',
      'Watch for sleep cues (yawning, eye-rubbing) and put them down promptly.',
      'Atento a las señales (bostezos, frotarse los ojos) y acuéstalo enseguida.',
      'Surveillez les signes de fatigue (bâillements, frottement des yeux) et couchez-le rapidement.',
      'Achten Sie auf Schlafzeichen (Gähnen, Augenreiben) und legen Sie das Baby sofort hin.',
      'Следите за сигналами сна (зевота, потирание глаз) и сразу укладывайте.',
      'راقب علامات النوم (التثاؤب، فرك العينين) وضعه للنوم فوراً.',
    ],
    'GuideTip_1_3': [
      'Beyaz gürültü, ten temasıyla emzirme ve hafif sallama güvenlik hissini artırır.',
      'White noise, skin-to-skin feeding and gentle rocking boost a sense of safety.',
      'El ruido blanco, el contacto piel con piel y el balanceo suave dan seguridad.',
      'Le bruit blanc, le peau-à-peau et un léger bercement renforcent le sentiment de sécurité.',
      'Weißes Rauschen, Hautkontakt und sanftes Wiegen geben Sicherheit.',
      'Белый шум, кормление кожа к коже и мягкое укачивание усиливают чувство безопасности.',
      'الضوضاء البيضاء، الرضاعة بملامسة الجلد، والهز اللطيف تعزز الشعور بالأمان.',
    ],

    // 4-6 Ay
    'GuideStat_2': ['12-16 sa', '12-16 h', '12-16 h', '12-16 h', '12-16 Std', '12-16 ч', '12-16 س'],
    'GuideNaps_2': ['3-4', '3-4', '3-4', '3-4', '3-4', '3-4', '3-4'],
    'GuideTip_2_1': [
      'Tutarlı bir yatma rutini kurun: banyo → loş ışık → ses → kucak.',
      'Set a consistent bedtime routine: bath → dim lights → sound → cuddle.',
      'Establece una rutina constante: baño → luz tenue → sonido → mimos.',
      'Mettez en place une routine cohérente : bain → lumière tamisée → son → câlin.',
      'Etablieren Sie eine feste Routine: Bad → gedämpftes Licht → Geräusch → Kuscheln.',
      'Создайте постоянный ритуал: купание → приглушённый свет → звук → объятия.',
      'ضع روتيناً ثابتاً للنوم: حمام → إضاءة خافتة → صوت → عناق.',
    ],
    'GuideTip_2_2': [
      'Bebeği uykulu ama uyanıkken yatağa koyun — kendi kendine uykuya dalma şansı verin.',
      'Put baby down drowsy but awake so they learn to fall asleep on their own.',
      'Acuéstalo somnoliento pero despierto para que aprenda a dormirse solo.',
      'Couchez bébé somnolent mais éveillé pour qu\'il apprenne à s\'endormir seul.',
      'Legen Sie das Baby müde, aber wach hin, damit es allein einschläft.',
      'Укладывайте малыша сонным, но бодрствующим, чтобы он учился засыпать сам.',
      'ضع الطفل نائساً لكن مستيقظاً ليتعلم النوم بمفرده.',
    ],
    'GuideTip_2_3': [
      'Gerileme dönemleri 2-6 hafta sürebilir; rutini bozmamak en iyisidir.',
      'Regressions can last 2-6 weeks; keeping the routine is the best response.',
      'Las regresiones pueden durar 2-6 semanas; lo mejor es mantener la rutina.',
      'Les régressions peuvent durer 2-6 semaines ; mieux vaut garder la routine.',
      'Regressionen können 2-6 Wochen dauern; die Routine beizubehalten ist am besten.',
      'Регрессии могут длиться 2-6 недель; сохранение ритуала — лучший ответ.',
      'قد يستمر التراجع من 2 إلى 6 أسابيع؛ الحفاظ على الروتين هو أفضل استجابة.',
    ],

    // 6-12 Ay
    'GuideStat_3': ['12-15 sa', '12-15 h', '12-15 h', '12-15 h', '12-15 Std', '12-15 ч', '12-15 س'],
    'GuideNaps_3': ['2-3', '2-3', '2-3', '2-3', '2-3', '2-3', '2-3'],
    'GuideTip_3_1': [
      'Geceleri yanına gidin, ama mümkünse kucağa almadan sesinizle sakinleştirin.',
      'Go to them at night, but soothe with your voice rather than picking them up if possible.',
      'Acude por la noche, pero si es posible calma con la voz sin levantarlo.',
      'Allez vers lui la nuit, mais apaisez-le avec votre voix sans le prendre si possible.',
      'Gehen Sie nachts zu ihm, beruhigen Sie aber möglichst nur mit der Stimme.',
      'Подходите к нему ночью, но успокаивайте голосом, по возможности не беря на руки.',
      'اذهب إليه ليلاً، ولكن هدّئه بصوتك بدلاً من حمله إن أمكن.',
    ],
    'GuideTip_3_2': [
      'Yumuşak bir geçiş objesi (örn. bezi, küçük peluş) ayrılığı kolaylaştırır.',
      'A soft transition object (lovey, small plush) eases separation.',
      'Un objeto de transición suave (mantita, peluche) ayuda con la separación.',
      'Un doudou ou petit objet de transition facilite la séparation.',
      'Ein Übergangsobjekt (Tuch, kleines Plüschtier) erleichtert die Trennung.',
      'Мягкий переходный предмет (платок, маленькая игрушка) облегчает разлуку.',
      'كائن انتقالي ناعم (لعبة محببة، دمية صغيرة) يخفف من الانفصال.',
    ],
    'GuideTip_3_3': [
      'Gündüz "ce-e" oyunu oynayarak "anne/baba geri gelir" güvenini pekiştirin.',
      'Playing peek-a-boo during the day reinforces "caregiver returns" trust.',
      'Jugar al cucú durante el día refuerza la confianza de que volverás.',
      'Jouer à coucou la journée renforce la confiance « papa/maman revient ».',
      'Tagsüber Guck-Guck spielen stärkt das Vertrauen, dass Sie wiederkommen.',
      'Игра в «ку-ку» днём укрепляет доверие, что родители возвращаются.',
      'لعب "بيكابو" خلال النهار يعزز الثقة بأن مقدم الرعاية سيعود.',
    ],

    // 12-24 Ay
    'GuideStat_4': ['11-14 sa', '11-14 h', '11-14 h', '11-14 h', '11-14 Std', '11-14 ч', '11-14 س'],
    'GuideNaps_4': ['1-2', '1-2', '1-2', '1-2', '1-2', '1-2', '1-2'],
    'GuideTip_4_1': [
      'Tek uykuya geçişi 4-6 hafta zaman tanıyarak yapın; bazı günler iki uyku gerekebilir.',
      'Allow 4-6 weeks for the one-nap transition; some days will still need two naps.',
      'Da 4-6 semanas para la transición a una siesta; algunos días harán falta dos.',
      'Comptez 4-6 semaines pour passer à une sieste ; certains jours, deux siestes restent utiles.',
      'Geben Sie 4-6 Wochen für den Übergang zu einem Schläfchen; manche Tage brauchen noch zwei.',
      'Дайте 4-6 недель на переход к одному сну; в некоторые дни потребуются два.',
      'اسمح بـ 4-6 أسابيع للانتقال إلى قيلولة واحدة؛ ستحتاج بعض الأيام إلى قيلولتين.',
    ],
    'GuideTip_4_2': [
      'Yatma saatini sabitleyin: kısa kitap + ışık kapatma + aynı şarkı/ses ideal kombinasyondur.',
      'Anchor bedtime: short book + lights off + the same song/sound is the ideal combo.',
      'Fija la hora de dormir: libro corto + luces apagadas + misma canción es el combo ideal.',
      'Fixez l\'heure du coucher : court livre + lumière éteinte + même musique, combo idéal.',
      'Festes Zubettgehen: kurzes Buch + Licht aus + gleiches Lied/Geräusch — die ideale Kombi.',
      'Закрепите время сна: короткая книга + выключенный свет + одна и та же песня — идеальная связка.',
      'ثبّت وقت النوم: كتاب قصير + إطفاء الأنوار + نفس الأغنية/الصوت هي المزيج المثالي.',
    ],
    'GuideTip_4_3': [
      'Uyku sırasında huzursuzluk varsa odanın sıcaklığını 18-20°C, nemini %50-60 tutun.',
      'For restless sleep keep the room at 18-20°C with 50-60% humidity.',
      'Si duerme inquieto, mantén la habitación a 18-20°C y 50-60% de humedad.',
      'Pour un sommeil agité, gardez la chambre à 18-20°C et 50-60% d\'humidité.',
      'Bei unruhigem Schlaf den Raum bei 18-20°C und 50-60% Luftfeuchte halten.',
      'При беспокойном сне держите комнату на 18-20°C и влажности 50-60%.',
      'للنوم المضطرب، حافظ على الغرفة بدرجة حرارة 18-20°م ورطوبة 50-60%.',
    ],

    // ─── Buttons ───
    'BtnCancel': ['İptal', 'Cancel', 'Cancelar', 'Annuler', 'Abbrechen', 'Отмена', 'إلغاء'],
    'BtnGoPremium': ['Plus\'a Geç', 'Go Plus', 'Hazte Plus', 'Passer Plus', 'Plus werden', 'Перейти на Plus', 'احصل على Plus'],
    'PlusExpiredTitle': ['Plus üyeliğin sona erdi', 'Your Plus has ended', 'Tu Plus ha finalizado', 'Votre Plus a expiré', 'Dein Plus ist abgelaufen', 'Срок Plus истёк', 'انتهى اشتراك Plus'],
    'PlusExpiredDesc': ['Plus süren doldu. Tüm Plus seslerine ve özelliklerine yeniden erişmek için Plus\'a geç.', 'Your Plus period has ended. Go Plus again to unlock all Plus sounds and features.', 'Tu periodo Plus ha finalizado. Hazte Plus de nuevo para desbloquear todos los sonidos y funciones Plus.', 'Votre période Plus est terminée. Repassez Plus pour débloquer tous les sons et fonctionnalités Plus.', 'Dein Plus-Zeitraum ist abgelaufen. Werde wieder Plus, um alle Plus-Sounds und -Funktionen freizuschalten.', 'Период Plus истёк. Перейдите на Plus снова, чтобы разблокировать все звуки и функции Plus.', 'انتهت فترة Plus. احصل على Plus مجددًا لفتح جميع أصوات وميزات Plus.'],
    'PremiumSoundTitle': ['Plus Ses', 'Plus Sound', 'Sonido Plus', 'Son Plus', 'Plus Sound', 'Plus звук', 'صوت Plus'],
    'PremiumSoundDesc': ['Bu ses Plus üyelere özel. Plus\'a geçerek tüm seslerin keyfini çıkar!', 'This sound is exclusive to Plus members. Go Plus to enjoy all sounds!', 'Este sonido es exclusivo para miembros Plus. ¡Hazte Plus para disfrutar todos los sonidos!', 'Ce son est réservé aux membres Plus. Passez Plus pour profiter de tous les sons !', 'Dieser Sound ist exklusiv für Plus-Mitglieder. Werde Plus und genieße alle Sounds!', 'Этот звук доступен только для Plus. Перейдите на Plus для всех звуков!', 'هذا الصوت حصري لأعضاء Plus. احصل على Plus للاستمتاع بجميع الأصوات!'],
    'FeatPremiumSounds': ['Plus Sesler', 'Plus Sounds', 'Sonidos Plus', 'Sons Plus', 'Plus Sounds', 'Plus звуки', 'أصوات Plus'],
    'BtnSave': ['Kaydet', 'Save', 'Guardar', 'Enregistrer', 'Speichern', 'Сохранить', 'حفظ'],
    'BtnDone': ['Tamam', 'Done', 'Hecho', 'Terminé', 'Fertig', 'Готово', 'تم'],
    'BtnDelete': ['Sil', 'Delete', 'Eliminar', 'Supprimer', 'Löschen', 'Удалить', 'حذف'],
    'BtnEditCaps': ['DÜZENLE', 'EDIT', 'EDITAR', 'MODIFIER', 'BEARBEITEN', 'ИЗМЕНИТЬ', 'تحرير'],
    'BtnSeePlus': ['Plus\'ı Gör', 'See Plus', 'Ver Plus', 'Voir Plus', 'Plus ansehen', 'Открыть Plus', 'عرض Plus'],
    'BtnSelectAll': ['Tümünü Seç', 'Select All', 'Seleccionar todo', 'Tout sélectionner', 'Alle auswählen', 'Выбрать всё', 'تحديد الكل'],
    'BtnClearAll': ['Temizle', 'Clear All', 'Limpiar todo', 'Tout effacer', 'Alles löschen', 'Очистить', 'مسح الكل'],
    'BtnTryFree': ['Ücretsiz Deneyin', 'Try for Free', 'Prueba gratis', 'Essayer gratuitement', 'Kostenlos testen', 'Попробовать бесплатно', 'جرب مجاناً'],
    'BtnBuyNow': ['Satın Al', 'Buy Now', 'Comprar ahora', 'Acheter maintenant', 'Jetzt kaufen', 'Купить сейчас', 'اشترِ الآن'],
    'BtnUpgrade': ['Yükselt', 'Upgrade', 'Mejorar', 'Mettre à niveau', 'Upgrade', 'Улучшить', 'ترقية'],
    'BtnCancelTimer': ['Zamanlayıcıyı İptal Et', 'Cancel Timer', 'Cancelar temporizador', 'Annuler le minuteur', 'Timer abbrechen', 'Отменить таймер', 'إلغاء المؤقت'],

    // ─── Tabs ───
    'TabFavorite': ['Favoriler', 'Favorites', 'Favoritos', 'Favoris', 'Favoriten', 'Избранное', 'المفضلة'],
    'TabMyMixes': ['Mikslerim', 'My Mixes', 'Mis mezclas', 'Mes mix', 'Meine Mixe', 'Мои миксы', 'مزيجي'],
    'TabMixer': ['Karıştırıcı', 'Mixer', 'Mezclador', 'Mélangeur', 'Mixer', 'Микшер', 'الخلاط'],
    'TabGames': ['Oyunlar', 'Games', 'Juegos', 'Jeux', 'Spiele', 'Игры', 'ألعاب'],
    'TabRecord': ['Kayıt', 'Record', 'Grabación', 'Enregistrement', 'Aufnahme', 'Запись', 'تسجيل'],

    // ─── Favorites / Mixer dialogs ───
    'DialogEdit': ['Düzenle', 'Edit', 'Editar', 'Modifier', 'Bearbeiten', 'Изменить', 'تحرير'],
    'EditMixTitle': ['Düzenle', 'Edit', 'Editar', 'Modifier', 'Bearbeiten', 'Изменить', 'تحرير'],
    'EditMixDesc': ['Her bir sesin seviyesini kişisel tercihinize göre ayarlayın.', 'Adjust the volume level of each sound to your preference.', 'Ajusta el nivel de volumen de cada sonido a tu gusto.', 'Ajustez le niveau de volume de chaque son selon vos préférences.', 'Passen Sie die Lautstärke jedes Sounds nach Ihren Wünschen an.', 'Настройте громкость каждого звука по своему вкусу.', 'اضبط مستوى صوت كل صوت حسب تفضيلاتك.'],
    'SaveAsMix': ['Mix Olarak Kaydet', 'Save as Mix', 'Guardar como mezcla', 'Enregistrer comme mix', 'Als Mix speichern', 'Сохранить как микс', 'حفظ كمزيج'],
    'HintNewMix': ['Mix ismi girin...', 'Enter mix name...', 'Nombre de la mezcla...', 'Nom du mix...', 'Mix-Name eingeben...', 'Введите название микса...', 'أدخل اسم المزيج...'],
    'MixLimitTitle': ['Mix Kayıt Sınırı', 'Mix Save Limit', 'Límite de mezclas', 'Limite de mix', 'Mix-Speicherlimit', 'Лимит сохранения миксов', 'حد حفظ المزيج'],
    'MixLimitDesc': [
      'Ücretsiz sürümde en fazla 2 Mix kaydedebilirsiniz. Sınırsız kayıt için Plus\'a geçin!',
      'You can save up to 2 mixes in the free version. Upgrade to Plus for unlimited!',
      'Puedes guardar hasta 2 mezclas en la versión gratuita. ¡Mejora a Plus!',
      'Vous pouvez enregistrer jusqu\'à 2 mix dans la version gratuite. Passez à Plus !',
      'In der kostenlosen Version können Sie bis zu 2 Mixe speichern. Upgrade auf Plus!',
      'В бесплатной версии можно сохранить до 2 миксов. Перейдите на Plus!',
      'يمكنك حفظ ما يصل إلى 2 مزيج مجاناً. قم بالترقية إلى Plus!',
    ],
    'FavLimitTitle': ['Favori Sınırı', 'Favorite Limit', 'Límite de favoritos', 'Limite de favoris', 'Favoriten-Limit', 'Лимит избранного', 'حد المفضلة'],
    'FavLimitDesc': [
      'Ücretsiz sürümde en fazla 3 favori ekleyebilirsiniz. Sınırsız favori için Plus\'a geçin!',
      'You can add up to 3 favorites in the free version. Upgrade to Plus for unlimited!',
      'Puedes añadir hasta 3 favoritos en la versión gratuita. ¡Mejora a Plus!',
      'Vous pouvez ajouter jusqu\'à 3 favoris dans la version gratuite. Passez à Plus !',
      'In der kostenlosen Version können Sie bis zu 3 Favoriten hinzufügen. Upgrade auf Plus!',
      'В бесплатной версии можно добавить до 3 избранных. Перейдите на Plus!',
      'يمكنك إضافة ما يصل إلى 3 مفضلة مجاناً. قم بالترقية إلى Plus!',
    ],

    // ─── Record Screen ───
    'RecordSub': ['Bebeğiniz için ninni kaydedin', 'Record a lullaby for your baby', 'Graba una canción de cuna para tu bebé', 'Enregistrez une berceuse pour votre bébé', 'Nehmen Sie ein Schlaflied für Ihr Baby auf', 'Запишите колыбельную для малыша', 'سجل تهويدة لطفلك'],
    'DefaultRecordName': ['Kayıt', 'Recording', 'Grabación', 'Enregistrement', 'Aufnahme', 'Запись', 'تسجيل'],
    'MyRecords': ['Kayıtlarım', 'My Recordings', 'Mis grabaciones', 'Mes enregistrements', 'Meine Aufnahmen', 'Мои записи', 'تسجيلاتي'],
    'NoRecords': ['Henüz kayıt yok', 'No recordings yet', 'Aún no hay grabaciones', 'Pas encore d\'enregistrements', 'Noch keine Aufnahmen', 'Пока нет записей', 'لا توجد تسجيلات بعد'],
    'StatusRecording': ['Kayıt yapılıyor...', 'Recording...', 'Grabando...', 'Enregistrement...', 'Aufnahme läuft...', 'Запись...', 'جارٍ التسجيل...'],
    'StatusPaused': ['Duraklatıldı', 'Paused', 'Pausado', 'En pause', 'Pausiert', 'Пауза', 'متوقف مؤقتاً'],
    'StatusStartRecord': ['Kayda başlamak için dokunun', 'Tap to start recording', 'Toca para grabar', 'Appuyez pour enregistrer', 'Tippen zum Aufnehmen', 'Нажмите, чтобы начать запись', 'اضغط لبدء التسجيل'],
    'MicPermissionRequired': ['Kayıt için mikrofon izni gerekli', 'Microphone permission required for recording', 'Se requiere permiso de micrófono', 'Permission du microphone requise', 'Mikrofonberechtigung erforderlich', 'Требуется разрешение на использование микрофона', 'إذن الميكروفون مطلوب للتسجيل'],
    'RenameRecordTitle': ['Yeniden Adlandır', 'Rename', 'Renombrar', 'Renommer', 'Umbenennen', 'Переименовать', 'إعادة تسمية'],
    'HintNewName': ['Yeni isim girin...', 'Enter new name...', 'Nuevo nombre...', 'Nouveau nom...', 'Neuer Name...', 'Введите новое имя...', 'أدخل اسماً جديداً...'],
    'DeleteRecordTitle': ['Kaydı Sil', 'Delete Recording', 'Eliminar grabación', 'Supprimer l\'enregistrement', 'Aufnahme löschen', 'Удалить запись', 'حذف التسجيل'],
    'DeleteRecordConfirm': ['silinecek. Emin misiniz?', 'will be deleted. Are you sure?', 'se eliminará. ¿Estás seguro?', 'sera supprimé. Êtes-vous sûr ?', 'wird gelöscht. Sind Sie sicher?', 'будет удалено. Вы уверены?', 'سيتم حذفه. هل أنت متأكد؟'],

    // ─── Games Screen ───
    'GamesSub': ['Eğlenceli beyin oyunları', 'Fun brain games', 'Juegos mentales divertidos', 'Jeux cérébraux amusants', 'Lustige Denkspiele', 'Весёлые игры для ума', 'ألعاب ذهنية ممتعة'],
    // Oyun kartı kategori etiketleri (Strateji / Bulmaca / Bilgi)
    'TagStrategy': ['Strateji', 'Strategy', 'Estrategia', 'Stratégie', 'Strategie', 'Стратегия', 'استراتيجية'],
    'TagPuzzle': ['Bulmaca', 'Puzzle', 'Rompecabezas', 'Casse-tête', 'Rätsel', 'Головоломка', 'لغز'],
    'TagKnowledge': ['Bilgi', 'Trivia', 'Trivia', 'Culture G', 'Wissen', 'Эрудиция', 'معلومات'],
    'GameMinesweeper': ['Mayın Tarlası', 'Minesweeper', 'Buscaminas', 'Démineur', 'Minesweeper', 'Сапёр', 'كاسحة الألغام'],
    'GameMinesweeperSub': ['Klasik mayın bulma oyunu', 'Classic mine finding game', 'Juego clásico de buscar minas', 'Jeu classique de recherche de mines', 'Klassisches Minenspiel', 'Классическая игра поиска мин', 'لعبة كلاسيكية للعثور على الألغام'],
    'Game2048': ['2048 Puzzle', '2048 Puzzle', '2048 Puzzle', '2048 Puzzle', '2048 Puzzle', '2048 Пазл', 'لغز 2048'],
    'Game2048Sub': ['Sayıları birleştir, 2048\'e ulaş', 'Merge numbers, reach 2048', 'Combina números, llega a 2048', 'Fusionnez les nombres, atteignez 2048', 'Zahlen zusammenführen, 2048 erreichen', 'Объединяйте числа, достигните 2048', 'ادمج الأرقام، اصل إلى 2048'],
    'GameBlockPuzzle': ['Block Dreams', 'Block Dreams', 'Block Dreams', 'Block Dreams', 'Block Dreams', 'Block Dreams', 'أحلام البلوك'],
    'GameBlockPuzzleSub': ['Blokları yerleştir, satırları temizle', 'Place blocks, clear lines', 'Coloca bloques, limpia líneas', 'Placez des blocs, videz des lignes', 'Blöcke platzieren, Linien löschen', 'Размещайте блоки, очищайте линии', 'ضع الكتل، امسح الصفوف'],
    'GameQuiz': ['Bilgi Yarışması', 'Quiz', 'Cuestionario', 'Quiz', 'Quiz', 'Викторина', 'اختبار'],
    'GameQuizSub': ['Bilgini test et', 'Test your knowledge', 'Pon a prueba tus conocimientos', 'Testez vos connaissances', 'Teste dein Wissen', 'Проверьте свои знания', 'اختبر معلوماتك'],
    'Score': ['Skor', 'Score', 'Puntuación', 'Score', 'Punktzahl', 'Счёт', 'النتيجة'],
    'Best': ['En İyi', 'Best', 'Mejor', 'Meilleur', 'Bestleistung', 'Лучший', 'الأفضل'],
    'GameOver': ['Oyun Bitti!', 'Game Over!', '¡Fin del juego!', 'Partie terminée !', 'Spiel vorbei!', 'Игра окончена!', 'انتهت اللعبة!'],
    'PlayAgain': ['Tekrar Oyna', 'Play Again', 'Jugar de nuevo', 'Rejouer', 'Nochmal spielen', 'Играть снова', 'العب مرة أخرى'],

    // ─── Paywall / Plans ───
    'PlanYearly': ['Yıllık', 'Yearly', 'Anual', 'Annuel', 'Jährlich', 'Год', 'سنوي'],
    'PlanMonthly': ['Aylık', 'Monthly', 'Mensual', 'Mensuel', 'Monatlich', 'Месяц', 'شهري'],
    'PlanLifetime': ['Ömür Boyu', 'Lifetime', 'De por vida', 'À vie', 'Lebenslang', 'Навсегда', 'مدى الحياة'],
    'perYear': ['yıl', 'year', 'año', 'an', 'Jahr', 'год', 'سنة'],
    'perMonth': ['ay', 'month', 'mes', 'mois', 'Monat', 'месяц', 'شهر'],
    'perSingle': ['tek sefer', 'one-time', 'único pago', 'unique', 'einmalig', 'разово', 'مرة واحدة'],
    'BadgePopular': ['EN POPÜLER', 'MOST POPULAR', 'MÁS POPULAR', 'PLUS POPULAIRE', 'BELIEBTEST', 'САМЫЙ ПОПУЛЯРНЫЙ', 'الأكثر شعبية'],
    'BadgeBestValue': ['EN AVANTAJLI', 'BEST VALUE', 'MEJOR PRECIO', 'MEILLEUR PRIX', 'BESTER PREIS', 'ЛУЧШАЯ ЦЕНА', 'أفضل قيمة'],
    'RestorePurchases': ['Satın Alımları Geri Yükle', 'Restore Purchases', 'Restaurar compras', 'Restaurer les achats', 'Käufe wiederherstellen', 'Восстановить покупки', 'استعادة المشتريات'],
    'RestoreNoActive': ['Aktif abonelik bulunamadı', 'No active subscription found', 'No se encontró suscripción activa', 'Aucun abonnement actif trouvé', 'Kein aktives Abonnement gefunden', 'Активная подписка не найдена', 'لم يتم العثور على اشتراك نشط'],
    'LifetimeInfo': ['Tek seferlik ödeme — sonsuza kadar Plus', 'One-time payment — forever Plus', 'Pago único — Plus para siempre', 'Paiement unique — Plus pour toujours', 'Einmalige Zahlung — für immer Plus', 'Единовременная оплата — Plus навсегда', 'دفعة واحدة — Plus للأبد'],
    'TrialStarting': ['Bugünden itibaren', 'Starting today', 'A partir de hoy', 'À partir d\'aujourd\'hui', 'Ab heute', 'С сегодняшнего дня', 'بدءاً من اليوم'],
    'TrialDuration': ['7 gün ücretsiz', '7 days free', '7 días gratis', '7 jours gratuits', '7 Tage kostenlos', '7 дней бесплатно', '7 أيام مجاناً'],
    'TrialAfter': ['7 gün sonra', 'After 7 days', 'Después de 7 días', 'Après 7 jours', 'Nach 7 Tagen', 'После 7 дней', 'بعد 7 أيام'],
    'TrialCancelAnytime': ['Otomatik Yenileme, Her Zaman İptal Edilebilir', 'Auto-renew, cancel anytime', 'Renovación automática, cancela en cualquier momento', 'Renouvellement automatique, annulez à tout moment', 'Autom. Verlängerung, jederzeit kündbar', 'Автопродление, отмена в любое время', 'تجديد تلقائي، يمكن الإلغاء في أي وقت'],

    // ─── Feature Labels ───
    'FeatAllSounds': ['Tüm Sesler', 'All Sounds', 'Todos los sonidos', 'Tous les sons', 'Alle Geräusche', 'Все звуки', 'جميع الأصوات'],
    'FeatAllGames': ['Tüm Oyunlar', 'All Games', 'Todos los juegos', 'Tous les jeux', 'Alle Spiele', 'Все игры', 'جميع الألعاب'],
    'FeatUnlimitedTimer': ['Sınırsız Zamanlayıcı', 'Unlimited Timer', 'Temporizador ilimitado', 'Minuteur illimité', 'Unbegrenzter Timer', 'Безлимитный таймер', 'مؤقت غير محدود'],
    'FeatVoiceRecord': ['Ses Kaydı', 'Voice Recording', 'Grabación de voz', 'Enregistrement vocal', 'Sprachaufnahme', 'Запись голоса', 'تسجيل صوتي'],
    'FeatMixer': ['Gelişmiş Karıştırıcı', 'Advanced Mixer', 'Mezclador avanzado', 'Mélangeur avancé', 'Erweiterter Mixer', 'Продвинутый микшер', 'خلاط متقدم'],
    'FeatUnlimitedMix': ['Sınırsız Mix', 'Unlimited Mixes', 'Mezclas ilimitadas', 'Mix illimités', 'Unbegrenzte Mixe', 'Безлимитные миксы', 'مزيج غير محدود'],
    'FeatUnlimitedFavorite': ['Sınırsız Favori', 'Unlimited Favorites', 'Favoritos ilimitados', 'Favoris illimités', 'Unbegrenzte Favoriten', 'Безлимит избранного', 'مفضلة غير محدودة'],
    'FeatUnlimitedRecord': ['Sınırsız Kayıt', 'Unlimited Recordings', 'Grabaciones ilimitadas', 'Enregistrements illimités', 'Unbegrenzte Aufnahmen', 'Безлимит записей', 'تسجيلات غير محدودة'],
    'FeatLongTimer': ['Uzun Zamanlayıcı', 'Long Timer', 'Temporizador largo', 'Minuteur long', 'Langer Timer', 'Длинный таймер', 'مؤقت طويل'],

    // ─── Shuffle Settings ───
    'ShuffleSettingsTitle': ['Karışık Çalma Ayarları', 'Shuffle Settings', 'Ajustes de aleatorio', 'Paramètres aléatoires', 'Zufallswiedergabe-Einstellungen', 'Настройки перемешивания', 'إعدادات العشوائي'],
    'ShuffleChangeInterval': ['Ses Değişim Süresi', 'Sound Change Interval', 'Intervalo de cambio', 'Intervalle de changement', 'Wechselintervall', 'Интервал смены звука', 'فاصل تغيير الصوت'],
    'ShuffleCrossfade': ['Geçişli Çalma', 'Crossfade', 'Transición suave', 'Fondu enchaîné', 'Überblendung', 'Кросс-фейд', 'تلاشي عرضي'],
    'ShuffleCrossfadeDuration': ['Geçiş Süresi', 'Crossfade Duration', 'Duración de transición', 'Durée du fondu', 'Überblendungsdauer', 'Длительность кросс-фейда', 'مدة التلاشي العرضي'],
    'ShufflePlayDuration': ['Çalma Süresi', 'Play Duration', 'Duración de reproducción', 'Durée de lecture', 'Wiedergabedauer', 'Длительность', 'مدة التشغيل'],
    'ShufflePlayUnlimited': ['Sınırsız', 'Unlimited', 'Ilimitado', 'Illimité', 'Unbegrenzt', 'Безлимит', 'غير محدود'],
    'ShuffleStatusPlaying': ['Çalıyor', 'Playing', 'Reproduciendo', 'En cours', 'Spielt', 'Играет', 'قيد التشغيل'],
    'ShuffleStatusStopped': ['Durdu', 'Stopped', 'Detenido', 'Arrêté', 'Gestoppt', 'Остановлено', 'متوقف'],
    'ShuffleFavoritesTitle': ['Favorileri Karıştır', 'Shuffle Favorites', 'Mezclar favoritos', 'Mélanger les favoris', 'Favoriten mischen', 'Перемешать избранное', 'خلط المفضلة'],
    'NoFavoritesTitle': ['Henüz Favori Yok', 'No Favorites Yet', 'Aún no hay favoritos', 'Pas encore de favoris', 'Noch keine Favoriten', 'Пока нет избранного', 'لا توجد مفضلة بعد'],
    'NoFavoritesDesc': ['Beğendiğin sesleri favorilere ekleyerek buradan hızlıca ulaşabilirsin.', 'Add your favorite sounds to access them quickly here.', 'Añade tus sonidos favoritos para acceder rápidamente.', 'Ajoutez vos sons préférés pour y accéder rapidement.', 'Füge deine Lieblingssounds hinzu, um schnell darauf zuzugreifen.', 'Добавляйте любимые звуки для быстрого доступа.', 'أضف أصواتك المفضلة للوصول إليها بسرعة هنا.'],
    'MyMixesHeader': ['Mixlerim', 'My Mixes', 'Mis mezclas', 'Mes mix', 'Meine Mixe', 'Мои миксы', 'مزيجي'],
    'MyMixesSub': ['Kaydettiğiniz ses kombinasyonları', 'Your saved sound combinations', 'Tus combinaciones de sonido guardadas', 'Vos combinaisons de sons enregistrées', 'Ihre gespeicherten Soundkombinationen', 'Ваши сохранённые комбинации', 'تركيبات الأصوات المحفوظة'],
    'BtnNewMix': ['Yeni Mix Oluştur', 'Create New Mix', 'Crear nueva mezcla', 'Créer un nouveau mix', 'Neuen Mix erstellen', 'Создать новый микс', 'إنشاء مزيج جديد'],
    'NoMixesTitle': ['Henüz Mix Yok', 'No Mixes Yet', 'Aún no hay mezclas', 'Pas encore de mix', 'Noch keine Mixe', 'Пока нет миксов', 'لا توجد مزيج بعد'],
    'NoMixesDesc': ['Karıştırıcıdan sesler seçip kaydedin.', 'Select sounds from the mixer and save them.', 'Selecciona sonidos del mezclador y guárdalos.', 'Sélectionnez des sons du mixeur et enregistrez-les.', 'Wählen Sie Sounds aus dem Mixer und speichern Sie sie.', 'Выберите звуки в микшере и сохраните.', 'حدد الأصوات من الخلاط واحفظها.'],
    'soundsCount': ['ses', 'sounds', 'sonidos', 'sons', 'Sounds', 'звуки', 'أصوات'],
    'FavSoundsPlaying': ['Favori Ses Çalınıyor', 'Favorite Sounds Playing', 'Sonidos favoritos reproduciéndose', 'Sons favoris en lecture', 'Lieblingssounds werden gespielt', 'Воспроизводятся любимые звуки', 'تشغيل الأصوات المفضلة'],

    // ─── Timer / Mini Player ───
    'TimerDialogTitle': ['Zamanlayıcı', 'Timer', 'Temporizador', 'Minuteur', 'Timer', 'Таймер', 'مؤقت'],
    'TimerDialogDesc': ['Seslerin ne kadar çalacağını seçin', 'Choose how long sounds will play', 'Elige cuánto tiempo sonarán', 'Choisissez la durée de lecture', 'Wählen Sie die Wiedergabedauer', 'Выберите, как долго будут играть звуки', 'اختر مدة تشغيل الأصوات'],
    'timerHour': ['sa', 'hr', 'hr', 'hr', 'Std', 'ч', 'س'],
    'timerMin': ['dk', 'min', 'min', 'min', 'Min', 'мин', 'د'],
    'sec': ['sn', 'sec', 'seg', 'sec', 'Sek', 'сек', 'ث'],
    'min': ['dk', 'min', 'min', 'min', 'Min', 'мин', 'د'],

    // ─── Recent Sounds ───
    'RecentSounds': ['Son Kullanılanlar', 'Recent Sounds', 'Sonidos recientes', 'Sons récents', 'Zuletzt verwendet', 'Недавние звуки', 'الأصوات الأخيرة'],

    // ─── Login Screen ───
    'LoginWelcome': ['Hoş Geldiniz', 'Welcome', 'Bienvenido', 'Bienvenue', 'Willkommen', 'Добро пожаловать', 'مرحباً'],
    'LoginSubtitle': ['Giriş yaparak verilerinizi yedekleyin ve\ncihazlar arası senkronize edin.', 'Sign in to back up your data and\nsync across devices.', 'Inicia sesión para respaldar tus datos\ny sincronizar entre dispositivos.', 'Connectez-vous pour sauvegarder vos données\net synchroniser entre appareils.', 'Melden Sie sich an, um Ihre Daten zu sichern\nund geräteübergreifend zu synchronisieren.', 'Sign in to back up your data and\\nsync across devices.', 'Sign in to back up your data and\\nsync across devices.'],
    'LoginApple': ['Apple ile Giriş Yap', 'Sign in with Apple', 'Iniciar sesión con Apple', 'Se connecter avec Apple', 'Mit Apple anmelden', 'Войти через Apple', 'تسجيل الدخول بـ Apple'],
    'LoginGoogle': ['Google ile Giriş Yap', 'Sign in with Google', 'Iniciar sesión con Google', 'Se connecter avec Google', 'Mit Google anmelden', 'Войти через Google', 'تسجيل الدخول بـ Google'],
    'LoginGuest': ['Misafir olarak devam et', 'Continue as guest', 'Continuar como invitado', 'Continuer en tant qu\'invité', 'Als Gast fortfahren', 'Продолжить как гость', 'متابعة كضيف'],
    'LoginOr': ['veya', 'or', 'o', 'ou', 'oder', 'или', 'أو'],
    'LoginPrivacy': ['Giriş yaparak Gizlilik Politikası\'nı kabul edersiniz.', 'By signing in you accept the Privacy Policy.', 'Al iniciar sesión acepta la Política de Privacidad.', 'En vous connectant, vous acceptez la Politique de confidentialité.', 'Mit der Anmeldung akzeptieren Sie die Datenschutzrichtlinie.', 'Входя, вы принимаете Политику конфиденциальности.', 'بتسجيل الدخول، فأنت توافق على سياسة الخصوصية.'],
    'LoginRequired': ['Bu özellik için giriş gereklidir', 'Sign in required for this feature', 'Se requiere inicio de sesión para esta función', 'Connexion requise pour cette fonctionnalité', 'Anmeldung für diese Funktion erforderlich', 'Для этой функции требуется вход', 'تسجيل الدخول مطلوب لهذه الميزة'],
    'LoginForPurchase': ['Satın alma işlemi için giriş yapmanız gerekmektedir.', 'You need to sign in to make a purchase.', 'Necesitas iniciar sesión para realizar una compra.', 'Vous devez vous connecter pour effectuer un achat.', 'Sie müssen sich anmelden, um einen Kauf zu tätigen.', 'Для покупки необходимо войти.', 'يجب تسجيل الدخول لإجراء عملية شراء.'],
    'AccountTitle': ['Hesap', 'Account', 'Cuenta', 'Compte', 'Konto', 'Аккаунт', 'الحساب'],
    'AccountSignedIn': ['ile giriş yapıldı', 'signed in with', 'inicio sesión con', 'connecté avec', 'angemeldet mit', 'вход выполнен через', 'تم تسجيل الدخول عبر'],
    'AccountSignOut': ['Çıkış Yap', 'Sign Out', 'Cerrar sesión', 'Se déconnecter', 'Abmelden', 'Выйти', 'تسجيل الخروج'],
    'AccountBackup': ['Verileri Yedekle', 'Back Up Data', 'Respaldar datos', 'Sauvegarder les données', 'Daten sichern', 'Резервное копирование данных', 'احتياطي البيانات'],
    'AccountPrompt': ['Giriş yaparak verilerinizi yedekleyin ve cihazlar arası senkronize edin.', 'Sign in to back up your data and sync across devices.', 'Inicia sesión para respaldar tus datos y sincronizar.', 'Connectez-vous pour sauvegarder et synchroniser.', 'Anmelden zum Sichern und Synchronisieren.', 'Войдите, чтобы создать резервную копию данных и синхронизировать их между устройствами.', 'سجّل الدخول لإجراء نسخ احتياطي لبياناتك ومزامنتها عبر الأجهزة.'],
    'SignOutConfirmTitle': ['Çıkış Yap', 'Sign Out', 'Cerrar sesión', 'Se déconnecter', 'Abmelden', 'Выйти', 'تسجيل الخروج'],
    'SignOutConfirmMsg': ['Hesabınızdan çıkış yapmak istediğinize emin misiniz?', 'Are you sure you want to sign out?', '¿Estás seguro de que quieres cerrar sesión?', 'Êtes-vous sûr de vouloir vous déconnecter ?', 'Sind Sie sicher, dass Sie sich abmelden möchten?', 'Вы уверены, что хотите выйти?', 'هل أنت متأكد أنك تريد تسجيل الخروج؟'],
    'SignOutSuccess': ['Başarıyla çıkış yapıldı', 'Successfully signed out', 'Sesión cerrada correctamente', 'Déconnexion réussie', 'Erfolgreich abgemeldet', 'Выход выполнен успешно', 'تم تسجيل الخروج بنجاح'],

    // ─── Errors ───
    'ProductNotFound': ['Ürün bulunamadı. Lütfen daha sonra tekrar deneyin.', 'Product not found. Please try again later.', 'Producto no encontrado. Inténtalo más tarde.', 'Produit introuvable. Veuillez réessayer plus tard.', 'Produkt nicht gefunden. Bitte versuchen Sie es später erneut.', 'Продукт не найден. Попробуйте позже.', 'لم يتم العثور على المنتج. حاول مرة أخرى لاحقاً.'],

    // ─── Login Gating ───
    'LoginFavoriteMsg': ['Favorilerinizi kaydetmek için giriş yapın', 'Sign in to save your favorites', 'Inicia sesión para guardar tus favoritos', 'Connectez-vous pour enregistrer vos favoris', 'Melden Sie sich an, um Ihre Favoriten zu speichern', 'Войдите, чтобы сохранить избранное', 'سجّل الدخول لحفظ المفضلة'],
    'LoginFavoriteDesc': ['Favori sesleriniz tüm cihazlarınızda senkronize edilir.', 'Your favorite sounds sync across all your devices.', 'Tus sonidos favoritos se sincronizan en todos tus dispositivos.', 'Vos sons favoris se synchronisent sur tous vos appareils.', 'Ihre Lieblingssounds werden auf allen Geräten synchronisiert.', 'Ваши любимые звуки синхронизируются на всех устройствах.', 'تتم مزامنة الأصوات المفضلة عبر جميع أجهزتك.'],
    'LoginSleepTrackMsg': ['Bebeğinizin uyku geçmişini takip etmek için giriş yapın', 'Sign in to track your baby\'s sleep history', 'Inicia sesión para seguir el historial de sueño de tu bebé', 'Connectez-vous pour suivre l\'historique de sommeil de votre bébé', 'Melden Sie sich an, um den Schlafverlauf Ihres Babys zu verfolgen', 'Войдите, чтобы отслеживать историю сна малыша', 'سجّل الدخول لتتبع تاريخ نوم طفلك'],
    'LoginSleepTrackDesc': ['Uyku sürelerini ve alışkanlıklarını takip edin.', 'Track sleep durations and habits.', 'Sigue las duraciones y hábitos del sueño.', 'Suivez les durées et habitudes de sommeil.', 'Verfolgen Sie Schlafdauer und Gewohnheiten.', 'Отслеживайте продолжительность сна и привычки.', 'تتبع مدد النوم والعادات.'],
    'SyncDevicesMsg': ['Telefonunuz ve tabletinizde aynı ayarlarla devam edin', 'Continue with the same settings on your phone and tablet', 'Continúa con los mismos ajustes en tu teléfono y tableta', 'Continuez avec les mêmes paramètres sur votre téléphone et tablette', 'Fahren Sie mit denselben Einstellungen auf Ihrem Telefon und Tablet fort', 'Продолжайте с теми же настройками на телефоне и планшете', 'استمر بنفس الإعدادات على هاتفك وجهازك اللوحي'],
    'SyncDevicesDesc': ['Tüm cihazlarınızda aynı favori sesler, ayarlar ve mix\'ler.', 'Same favorites, settings, and mixes across all devices.', 'Los mismos favoritos, ajustes y mezclas en todos los dispositivos.', 'Mêmes favoris, paramètres et mix sur tous les appareils.', 'Gleiche Favoriten, Einstellungen und Mixe auf allen Geräten.', 'Одинаковые избранные, настройки и миксы на всех устройствах.', 'نفس المفضلات والإعدادات والمزجات عبر جميع الأجهزة.'],
    'BtnSignIn': ['Giriş Yap', 'Sign In', 'Iniciar Sesión', 'Se Connecter', 'Anmelden', 'Войти', 'تسجيل الدخول'],
    'BtnLater': ['Daha Sonra', 'Later', 'Más tarde', 'Plus tard', 'Später', 'Позже', 'لاحقاً'],

    // ─── Ad Düzenleme ───
    'EditNameTitle': ['Adını Düzenle', 'Edit Name', 'Editar nombre', 'Modifier le nom', 'Namen bearbeiten', 'Изменить имя', 'تعديل الاسم'],
    'EditNameHint': ['Yeni adını gir...', 'Enter new name...', 'Escribe tu nuevo nombre...', 'Entrez votre nouveau nom...', 'Neuen Namen eingeben...', 'Введите новое имя...', 'أدخل اسماً جديداً...'],
    'EditNameSuccess': ['Ad güncellendi ✓', 'Name updated ✓', 'Nombre actualizado ✓', 'Nom mis à jour ✓', 'Name aktualisiert ✓', 'Имя обновлено ✓', 'تم تحديث الاسم ✓'],
    'EditNameError': ['Güncelleme başarısız', 'Update failed', 'Error al actualizar', 'Échec de la mise à jour', 'Update fehlgeschlagen', 'Не удалось обновить', 'فشل التحديث'],
    'ProfanityWarning': ['Uygunsuz ifade tespit edildi. Lütfen farklı bir isim girin.', 'Inappropriate language detected. Please choose a different name.', 'Lenguaje inapropiado detectado. Elija otro nombre.', 'Langage inapproprié détecté. Veuillez choisir un autre nom.', 'Unangemessene Sprache erkannt. Bitte wählen Sie einen anderen Namen.', 'Обнаружена ненормативная лексика. Выберите другое имя.', 'تم اكتشاف لغة غير لائقة. يرجى اختيار اسم آخر.'],
    'NameChangeCooldownInfo': ['Adını değiştirdikten sonra 3 gün boyunca tekrar değiştiremezsin.', 'After changing your name, you can\'t change it again for 3 days.', 'Después de cambiar tu nombre, no podrás cambiarlo de nuevo durante 3 días.', 'Après avoir changé votre nom, vous ne pourrez plus le modifier pendant 3 jours.', 'Nach dem Ändern deines Namens kannst du ihn 3 Tage lang nicht erneut ändern.', 'После изменения имени вы не сможете изменить его снова в течение 3 дней.', 'بعد تغيير اسمك، لا يمكنك تغييره مرة أخرى لمدة 3 أيام.'],
    'NameChangeCooldownError': ['Adını tekrar değiştirmek için {n} gün daha beklemelisin.', 'You need to wait {n} more day(s) to change your name again.', 'Debes esperar {n} día(s) más para volver a cambiar tu nombre.', 'Vous devez attendre encore {n} jour(s) pour modifier à nouveau votre nom.', 'Du musst noch {n} Tag(e) warten, um deinen Namen erneut zu ändern.', 'Чтобы снова изменить имя, подождите ещё {n} дн.', 'يجب أن تنتظر {n} يوم (أيام) أخرى لتغيير اسمك مرة أخرى.'],

    // ─── Onboarding ───
    'OnbTitle1': ['Tatlı {rüyalar} başlasın', 'Let the sweet {dreams} begin', 'Que empiecen los {sueños}', 'Que les {rêves} commencent', 'Süße {Träume} beginnen', 'Пусть начнутся сладкие {сны}', 'لتبدأ {الأحلام} الجميلة'],
    'OnbSub1': ['Bebeğinizin uyku rutinini sakinleştirici seslerle destekleyin.', 'Support your baby\'s sleep routine with soothing sounds.', 'Apoya la rutina de sueño de tu bebé con sonidos relajantes.', 'Accompagnez le rituel de sommeil de votre bébé avec des sons apaisants.', 'Unterstütze den Schlafrhythmus deines Babys mit beruhigenden Klängen.', 'Поддержите режим сна малыша успокаивающими звуками.', 'ادعم روتين نوم طفلك بأصوات مهدئة.'],
    'OnbTitle2': ['Her bebeğe {uygun} bir ses var', 'A {sound} for every baby', 'Un {sonido} para cada bebé', 'Un {son} pour chaque bébé', 'Ein {Klang} für jedes Baby', 'Звук, {подходящий} каждому малышу', 'صوت {مناسب} لكل طفل'],
    'OnbSub2': ['Ninni, beyaz gürültü, pış pış ve rahatlatıcı sesleri keşfedin.', 'Discover lullabies, white noise, shushing and soothing sounds.', 'Descubre nanas, ruido blanco, arrullos y sonidos relajantes.', 'Découvrez berceuses, bruit blanc, chuchotements et sons apaisants.', 'Entdecke Schlaflieder, weißes Rauschen, Pst-Geräusche und beruhigende Klänge.', 'Откройте колыбельные, белый шум, «тшш» и успокаивающие звуки.', 'اكتشف التهويدات والضوضاء البيضاء وأصوات الهمس والتهدئة.'],
    'OnbTitle3': ['Kendi {uyku karışımını} oluştur', 'Create your own {sleep mix}', 'Crea tu propia {mezcla de sueño}', 'Créez votre propre {mix de sommeil}', 'Erstelle deinen eigenen {Schlaf-Mix}', 'Создайте свой {микс для сна}', 'أنشئ {مزيج نومك} الخاص'],
    'OnbSub3': ['Sevdiğiniz sesleri birleştirip bebeğiniz için özel mixler hazırlayın.', 'Blend your favorite sounds into custom mixes for your baby.', 'Combina tus sonidos favoritos en mezclas personalizadas para tu bebé.', 'Combinez vos sons préférés en mix personnalisés pour votre bébé.', 'Kombiniere deine Lieblingsklänge zu eigenen Mixes für dein Baby.', 'Смешивайте любимые звуки в персональные миксы для малыша.', 'امزج أصواتك المفضلة في مزيجات مخصصة لطفلك.'],
    'OnbTitle4': ['Uyku saatini birlikte {hatırlayalım}', 'Let\'s {remember} bedtime together', '{Recordemos} juntos la hora de dormir', '{Rappelons}-nous l\'heure du coucher', 'Lass uns gemeinsam an die Schlafenszeit {denken}', 'Давайте вместе {помнить} о времени сна', 'لنتذكر معاً {موعد النوم}'],
    'OnbSub4': ['Her gece belirlediğiniz saatte nazik bir bildirim alın ve rutini kolayca başlatın.', 'Get a gentle reminder every night at your chosen time and start the routine easily.', 'Recibe un aviso suave cada noche a la hora que elijas e inicia la rutina fácilmente.', 'Recevez un rappel doux chaque soir à l\'heure choisie et lancez le rituel facilement.', 'Erhalte jede Nacht zur gewählten Zeit eine sanfte Erinnerung und starte die Routine ganz einfach.', 'Получайте мягкое напоминание каждую ночь в выбранное время и легко начинайте режим.', 'احصل على تذكير لطيف كل ليلة في الوقت الذي تختاره وابدأ الروتين بسهولة.'],
    'OnbTitle5': ['Bebeğinizin {adı} ne?', 'What\'s your baby\'s {name}?', '¿Cómo se llama tu {bebé}?', 'Quel est le {prénom} de votre bébé ?', 'Wie heißt dein {Baby}?', 'Как зовут вашего {малыша}?', 'ما {اسم} طفلك؟'],
    'OnbSub5': ['İyi geceler mesajını ona özel hale getirelim.', 'Let\'s make the goodnight message just for them.', 'Personalicemos el mensaje de buenas noches para él.', 'Personnalisons le message de bonne nuit pour lui.', 'Machen wir die Gute-Nacht-Botschaft ganz persönlich.', 'Сделаем пожелание спокойной ночи особенным.', 'لنجعل رسالة تصبح على خير خاصة به.'],
    'OnbSkip': ['Atla', 'Skip', 'Saltar', 'Passer', 'Überspringen', 'Пропустить', 'تخطّي'],
    'OnbStart': ['Sleepora\'yı Başlat', 'Start Sleepora', 'Iniciar Sleepora', 'Démarrer Sleepora', 'Sleepora starten', 'Запустить Sleepora', 'ابدأ Sleepora'],
    'OnbLater': ['Şimdilik Geç', 'Skip for now', 'Omitir por ahora', 'Plus tard', 'Später', 'Пока пропустить', 'تخطّي الآن'],
    'OnbSnd1': ['Pış Pış', 'Shush', 'Arrullo', 'Chut', 'Pst-Pst', 'Тшш', 'هَس هَس'],
    'OnbSnd2': ['Eee Eee', 'Eee Eee', 'Eee Eee', 'Eee Eee', 'Eee Eee', 'Eee Eee', 'Eee Eee'],
    'OnbSnd3': ['Beyaz Gürültü', 'White Noise', 'Ruido Blanco', 'Bruit Blanc', 'Weißes Rauschen', 'Белый шум', 'ضوضاء بيضاء'],
    'OnbSnd4': ['Yıldız Tozu', 'Stardust', 'Polvo de Estrellas', 'Poussière d\'Étoiles', 'Sternenstaub', 'Звёздная пыль', 'غبار النجوم'],
    'OnbSndCabin': ['Kabin Sesi', 'Cabin', 'Cabina', 'Cabine', 'Kabine', 'Кабина', 'صوت الكابينة'],
    'OnbMixTitle': ['Özel Uyku Mix\'in', 'Your custom sleep mix', 'Tu mezcla de sueño', 'Votre mix de sommeil', 'Dein Schlaf-Mix', 'Ваш микс для сна', 'مزيج نومك الخاص'],
    'OnbMixSub': ['Sadece size özel', 'Just for you', 'Solo para ti', 'Rien que pour vous', 'Nur für dich', 'Только для вас', 'لك وحدك'],
    'OnbSndLullaby': ['Ninni', 'Lullaby', 'Nana', 'Berceuse', 'Schlaflied', 'Колыбельная', 'تهويدة'],
    'OnbMixNight': ['Gece Mix\'i', 'Night Mix', 'Mezcla Nocturna', 'Mix de Nuit', 'Nacht-Mix', 'Ночной микс', 'مزيج الليل'],
    'OnbMixCount': ['{n} ses seçildi', '{n} sounds selected', '{n} sonidos elegidos', '{n} sons choisis', '{n} Sounds gewählt', 'Выбрано: {n}', 'تم اختيار {n}'],
    'OnbMixSelectedTitle': ['Seçilen Sesler', 'Selected Sounds', 'Sonidos seleccionados', 'Sons sélectionnés', 'Ausgewählte Sounds', 'Выбранные звуки', 'الأصوات المختارة'],
    'OnbMixCreate': ['Miximi Oluştur', 'Create My Mix', 'Crear mi mezcla', 'Créer mon mix', 'Meinen Mix erstellen', 'Создать микс', 'أنشئ مزيجي'],
    'OnbMixVolTitle': ['Ses Düzeyleri', 'Sound Levels', 'Niveles de sonido', 'Niveaux sonores', 'Lautstärken', 'Уровни звука', 'مستويات الصوت'],
    'OnbMixEmptyHint': ['Mikse ses eklemek için yukarıdaki dairelere dokun.', 'Tap the circles above to add sounds to your mix.', 'Toca los círculos de arriba para añadir sonidos.', 'Touchez les cercles ci-dessus pour ajouter des sons.', 'Tippe oben auf die Kreise, um Sounds hinzuzufügen.', 'Нажмите на круги выше, чтобы добавить звуки.', 'انقر على الدوائر أعلاه لإضافة أصوات.'],
    'OnbReminderTitle': ['Ana Hatırlatma', 'Main reminder', 'Recordatorio principal', 'Rappel principal', 'Haupterinnerung', 'Основное напоминание', 'التذكير الرئيسي'],
    'OnbReminderSub': ['Uyku rutininin zamanı', 'Time for the sleep routine', 'Hora de la rutina de sueño', 'C\'est l\'heure du rituel', 'Zeit für die Schlafroutine', 'Время режима сна', 'حان وقت روتين النوم'],
    'OnbEveryDay': ['Her gün', 'Every day', 'Cada día', 'Chaque jour', 'Täglich', 'Каждый день', 'كل يوم'],
    'OnbTapToSetTime': ['Saati değiştirmek için dokun', 'Tap to change the time', 'Toca para cambiar la hora', 'Touchez pour changer l\'heure', 'Zum Ändern der Zeit tippen', 'Нажмите, чтобы изменить время', 'اضغط لتغيير الوقت'],
    'OnbBabyNameLabel': ['Bebeğin adı', 'Baby\'s name', 'Nombre del bebé', 'Prénom du bébé', 'Name des Babys', 'Имя малыша', 'اسم الطفل'],
    'OnbBabyNameHint': ['Örneğin: Duru', 'e.g. Duru', 'Ej.: Duru', 'Ex. : Duru', 'z. B. Duru', 'Напр.: Дуру', 'مثال: درو'],
    'OnbBabyNameNote': ['İsterseniz bunu daha sonra da ekleyebilirsiniz.', 'You can add this later if you like.', 'Puedes añadirlo más tarde si quieres.', 'Vous pourrez l\'ajouter plus tard si vous le souhaitez.', 'Du kannst das später hinzufügen.', 'Вы можете добавить это позже.', 'يمكنك إضافته لاحقاً إذا أردت.'],
    'OnbTitle6': ['İlerlemeni {kaydet}', '{Save} your progress', '{Guarda} tu progreso', '{Sauvegardez} votre progression', 'Sichere deinen {Fortschritt}', '{Сохраните} свой прогресс', '{احفظ} تقدمك'],
    'OnbSub6': ['Giriş yap; favorilerin ve ayarların tüm cihazlarında senkronize olsun.', 'Sign in to sync your favorites and settings across devices.', 'Inicia sesión para sincronizar tus favoritos y ajustes en tus dispositivos.', 'Connectez-vous pour synchroniser vos favoris et réglages sur vos appareils.', 'Melde dich an, um Favoriten und Einstellungen geräteübergreifend zu synchronisieren.', 'Войдите, чтобы синхронизировать избранное и настройки на всех устройствах.', 'سجّل الدخول لمزامنة مفضّلاتك وإعداداتك عبر أجهزتك.'],
    'OnbGuest': ['Misafir olarak devam et', 'Continue as guest', 'Continuar como invitado', 'Continuer en tant qu\'invité', 'Als Gast fortfahren', 'Продолжить как гость', 'المتابعة كضيف'],
    'ReplayOnboarding': ['Tanıtımı tekrar izle', 'Replay intro', 'Volver a ver la introducción', 'Revoir l\'intro', 'Intro erneut ansehen', 'Посмотреть интро снова', 'إعادة مشاهدة المقدمة'],

    // ─── Leaderboard ───
    'Leaderboard': ['Skor Tablosu', 'Leaderboard', 'Tabla de puntuaciones', 'Classement', 'Bestenliste', 'Таблица лидеров', 'لوحة المتصدرين'],
    'LeaderboardSub': ['En iyi oyuncuları gör', 'See top players', 'Ver mejores jugadores', 'Voir les meilleurs joueurs', 'Beste Spieler sehen', 'Лучшие игроки', 'انظر إلى أفضل اللاعبين'],
    'LeaderboardEmpty': ['Henüz skor yok', 'No scores yet', 'Sin puntuaciones', 'Pas encore de scores', 'Noch keine Punkte', 'Пока нет результатов', 'لا توجد نتائج بعد'],
    'LeaderboardLoginRequired': ['Skorunuzu kaydetmek için giriş yapın', 'Sign in to save your score', 'Inicia sesión para guardar tu puntuación', 'Connectez-vous pour sauvegarder votre score', 'Melden Sie sich an, um Ihren Punktestand zu speichern', 'Войдите, чтобы сохранить результат', 'سجّل الدخول لحفظ نتيجتك'],
    'LeaderboardYourBest': ['En İyi Skorun', 'Your Best', 'Tu Mejor', 'Votre Meilleur', 'Ihr Bester', 'Ваш лучший', 'أفضل نتيجة لك'],
    'LeaderboardRank': ['Sıralama', 'Rank', 'Rango', 'Rang', 'Rang', 'Ранг', 'الترتيب'],
    'LeaderboardPlayer': ['Oyuncu', 'Player', 'Jugador', 'Joueur', 'Spieler', 'Игрок', 'اللاعب'],
    'LeaderboardScore': ['Skor', 'Score', 'Puntuación', 'Score', 'Punkte', 'Счёт', 'النتيجة'],
    'LeaderboardTime': ['Süre', 'Time', 'Tiempo', 'Temps', 'Zeit', 'Время', 'الوقت'],
    'ScoreSaved': ['Skorunuz kaydedildi! 🏆', 'Score saved! 🏆', '¡Puntuación guardada! 🏆', 'Score sauvegardé ! 🏆', 'Punktestand gespeichert! 🏆', 'Результат сохранён! 🏆', 'تم حفظ النتيجة! 🏆'],
    'NewHighScore': ['Yeni rekor! 🎉', 'New high score! 🎉', '¡Nuevo récord! 🎉', 'Nouveau record ! 🎉', 'Neuer Rekord! 🎉', 'Новый рекорд! 🎉', 'رقم قياسي جديد! 🎉'],

    // ─── Premium Preview ───
    'PreviewBadge': ['ÖN İZLEME', 'PREVIEW', 'VISTA PREVIA', 'APERÇU', 'VORSCHAU', 'ПРЕДПРОСМОТР', 'معاينة'],
    'PreviewEndTitle': ['Beğendiniz mi?', 'Did you like it?', '¿Te gustó?', 'Vous avez aimé ?', 'Hat es Ihnen gefallen?', 'Вам понравилось?', 'هل أعجبك؟'],
    'PreviewEndDesc': ['Bu sesin tamamını dinlemek için Plus\'a geçin.', 'Upgrade to Plus to listen to the full sound.', 'Mejora a Plus para escuchar el sonido completo.', 'Passez à Plus pour écouter le son en entier.', 'Upgrade auf Plus, um den vollständigen Sound zu hören.', 'Обновитесь до Plus, чтобы прослушать полностью.', 'الترقية إلى Plus للاستماع للصوت كاملاً.'],

    // ─── Mixer Limit ───
    'MixerLimitTitle': ['Karıştırıcı Sınırı', 'Mixer Limit', 'Límite del mezclador', 'Limite du mixeur', 'Mixer-Limit', 'Ограничение микшера', 'حد الخلاط'],
    'MixerLimitDesc': ['Ücretsiz sürümde en fazla 2 sesi karıştırabilirsiniz. Plus\'a geçerek sınırsız sesle mix yapın!', 'You can mix up to 2 sounds in the free version. Upgrade to Plus for unlimited mixing!', 'Puedes mezclar hasta 2 sonidos en la versión gratuita. ¡Mejora a Plus para mezclas ilimitadas!', 'Vous pouvez mélanger jusqu\'à 2 sons dans la version gratuite. Passez à Plus pour un mixage illimité !', 'In der kostenlosen Version können Sie bis zu 2 Sounds mischen. Upgrade auf Plus für unbegrenztes Mixen!', 'В бесплатной версии можно микшировать до 2 звуков. Обновитесь до Plus для безлимита!', 'يمكنك خلط حتى صوتين في النسخة المجانية. ترقية إلى Plus للخلط بلا حدود!'],
    'MixerLimitHint': ['Yağmur + Beyaz Gürültü + Kalp Atışı gibi kombinasyonlar oluşturun!', 'Create combinations like Rain + White Noise + Heartbeat!', '¡Crea combinaciones como Lluvia + Ruido Blanco + Latido!', 'Créez des combinaisons comme Pluie + Bruit Blanc + Battement de cœur !', 'Erstellen Sie Kombinationen wie Regen + Weißes Rauschen + Herzschlag!', 'Создавайте комбинации, например Дождь + Белый шум + Сердцебиение!', 'أنشئ توليفات مثل المطر + الضوضاء البيضاء + نبضات القلب!'],

    // ─── Sleep Stats ───
    'SleepStatsTitle': ['Uyku İstatistikleri', 'Sleep Statistics', 'Estadísticas de sueño', 'Statistiques de sommeil', 'Schlafstatistiken', 'Статистика сна', 'إحصائيات النوم'],
    'SleepStatsDesc': ['Bebeğinizin uyku alışkanlıklarını takip edin', 'Track your baby\'s sleep habits', 'Sigue los hábitos de sueño de tu bebé', 'Suivez les habitudes de sommeil de votre bébé', 'Verfolgen Sie die Schlafgewohnheiten Ihres Babys', 'Отслеживайте привычки сна малыша', 'تتبع عادات نوم طفلك'],

    // ─── Sleep Stats Info Dialog ───
    'StatsInfoTitle': ['İstatistikler Nasıl Çalışır?', 'How Do Statistics Work?', '¿Cómo funcionan las estadísticas?', 'Comment fonctionnent les statistiques ?', 'Wie funktionieren Statistiken?', 'Как работает статистика?', 'كيف تعمل الإحصائيات؟'],
    'StatsInfoClose': ['Anladım', 'Got it', 'Entendido', 'Compris', 'Verstanden', 'Понял', 'فهمت'],
    'StatsInfoItem1Title': ['📊 7 Günlük Grafik', '📊 7-Day Chart', '📊 Gráfico de 7 días', '📊 Graphique 7 jours', '📊 7-Tage-Diagramm', '📊 График за 7 дней', '📊 رسم بياني لـ 7 أيام'],
    'StatsInfoItem1Desc': ['Son 7 günün her biri için toplam uyku süresini gösterir. Barın yüksekliği o gün dinlenen süreye orantılıdır. Bugün ait bar parlak renkle gösterilir.', 'Shows total sleep time for each of the last 7 days. The bar height is proportional to the sleep duration that day. Today\'s bar is shown in a bright color.', 'Muestra el tiempo total de sueño de cada uno de los últimos 7 días. La altura de la barra es proporcional a la duración del sueño ese día. La barra de hoy se muestra en color brillante.', 'Affiche la durée totale de sommeil pour chacun des 7 derniers jours. La hauteur de la barre est proportionnelle à la durée de sommeil ce jour-là. La barre d\'aujourd\'hui est affichée en couleur vive.', 'Zeigt die gesamte Schlafdauer für jeden der letzten 7 Tage. Die Balkenhöhe ist proportional zur Schlafdauer an diesem Tag. Der heutige Balken wird in einer hellen Farbe angezeigt.', 'Показывает общее время сна за каждый из последних 7 дней', 'يعرض إجمالي وقت النوم لكل يوم من آخر 7 أيام'],
    'StatsInfoItem2Title': ['🌙 Oturum Sayısı', '🌙 Session Count', '🌙 Número de sesiones', '🌙 Nombre de séances', '🌙 Sitzungsanzahl', '🌙 Количество сессий', '🌙 عدد الجلسات'],
    'StatsInfoItem2Desc': ['Uygulamadan ses çaldığınızda otomatik olarak bir uyku oturumu başlar. Ses durdurulduğunda oturum kaydedilir. En az 1 dakika süren oturumlar istatistiklere eklenir.', 'A sleep session starts automatically when you play a sound from the app. The session is saved when the sound is stopped. Sessions lasting at least 1 minute are added to statistics.', 'Una sesión de sueño comienza automáticamente cuando reproduces un sonido desde la aplicación. La sesión se guarda cuando se detiene el sonido. Las sesiones de al menos 1 minuto se añaden a las estadísticas.', 'Une séance de sommeil démarre automatiquement lorsque vous lisez un son depuis l\'application. La séance est enregistrée à l\'arrêt du son. Les séances d\'au moins 1 minute sont ajoutées aux statistiques.', 'Eine Schlafsitzung beginnt automatisch, wenn Sie einen Sound aus der App abspielen. Die Sitzung wird beim Stoppen des Sounds gespeichert. Sitzungen von mindestens 1 Minute werden zur Statistik hinzugefügt.', 'Сессия сна начинается автоматически при воспроизведении звука', 'تبدأ جلسة النوم تلقائياً عند تشغيل صوت'],
    'StatsInfoItem3Title': ['⏱️ Ortalama Süre', '⏱️ Average Duration', '⏱️ Duración media', '⏱️ Durée moyenne', '⏱️ Durchschnittsdauer', '⏱️ Средняя длительность', '⏱️ متوسط المدة'],
    'StatsInfoItem3Desc': ['Son 7 günde dinlenen tüm oturumların dakika cinsinden ortalamasıdır. Bebeğinizin düzenli uyku örüntüsünü takip etmek için kullanışlıdır.', 'The average in minutes of all sessions listened to in the last 7 days. Useful for tracking your baby\'s regular sleep pattern.', 'La media en minutos de todas las sesiones escuchadas en los últimos 7 días. Útil para seguir el patrón de sueño regular de tu bebé.', 'La moyenne en minutes de toutes les séances écoutées au cours des 7 derniers jours. Utile pour suivre le schéma de sommeil régulier de votre bébé.', 'Der Durchschnitt in Minuten aller Sitzungen, die in den letzten 7 Tagen gehört wurden. Nützlich, um das regelmäßige Schlafmuster Ihres Babys zu verfolgen.', 'Среднее значение всех прослушанных сессий за последние 7 дней в минутах', 'متوسط جميع الجلسات المسموعة خلال آخر 7 أيام بالدقائق'],
    'StatsInfoItem4Title': ['🔥 Gün Serisi (Streak)', '🔥 Day Streak', '🔥 Racha de días', '🔥 Série de jours', '🔥 Tages-Serie', '🔥 Серия дней', '🔥 سلسلة الأيام'],
    'StatsInfoItem4Desc': ['Üst üste uyku kaydı olan ardışık gün sayısını gösterir. Düzenli uyku rutinini ödüllendiren bir motivasyon ölçütüdür.', 'Shows the number of consecutive days with sleep records in a row. It is a motivational metric that rewards a regular sleep routine.', 'Muestra el número de días consecutivos con registros de sueño seguidos. Es una métrica motivacional que recompensa una rutina de sueño regular.', 'Indique le nombre de jours consécutifs avec des enregistrements de sommeil d\'affilée. C\'est une mesure de motivation qui récompense une routine de sommeil régulière.', 'Zeigt die Anzahl der aufeinanderfolgenden Tage mit Schlafaufzeichnungen hintereinander. Es ist eine Motivationskennzahl, die eine regelmäßige Schlafroutine belohnt.', 'Показывает количество последовательных дней с записями сна', 'يظهر عدد الأيام المتتالية مع سجلات النوم'],
    'StatsInfoNote': ['💡 İstatistikler yalnızca giriş yapıldığında buluta kaydedilir. Misafir modunda veriler saklanmaz.', '💡 Statistics are only saved to the cloud when signed in. Data is not stored in guest mode.', '💡 Las estadísticas solo se guardan en la nube cuando estás conectado. Los datos no se almacenan en modo invitado.', '💡 Les statistiques ne sont sauvegardées dans le cloud que lorsque vous êtes connecté. Les données ne sont pas stockées en mode invité.', '💡 Statistiken werden nur in der Cloud gespeichert, wenn Sie angemeldet sind. Im Gastmodus werden keine Daten gespeichert.', '💡 Статистика сохраняется в облаке только при входе в систему', '💡 يتم حفظ الإحصائيات في السحابة فقط عند تسجيل الدخول'],

    // ─── Sound Names ───
    'Sound_Pış Pış': ['Pış Pış', 'Shush Shush', 'Shh Shh', 'Chut Chut', 'Psch Psch'],
    'Sound_Eee Eee': ['Eee Eee', 'Eee Eee', 'Eee Eee', 'Eee Eee', 'Eee Eee'],
    'Sound_Dandini': ['Dandini', 'Lullaby', 'Canción de cuna', 'Berceuse', 'Schlaflied', 'Колыбельная', 'تهويدة'],
    'Sound_Süpürge': ['Süpürge', 'Vacuum', 'Aspiradora', 'Aspirateur', 'Staubsauger'],
    'Sound_Kolik': ['Kolik', 'Colic', 'Cólico', 'Colique', 'Kolik', 'Колики', 'مغص'],
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
    'Sound_Dalga': ['Dalga', 'Waves', 'Olas', 'Vagues', 'Wellen', 'Волны', 'أمواج'],
    'Sound_Duş': ['Duş', 'Shower', 'Ducha', 'Douche', 'Dusche'],
    'Sound_Helikopter': ['Helikopter', 'Helicopter', 'Helicóptero', 'Hélicoptère', 'Hubschrauber', 'Вертолёт', 'مروحية'],
    'Sound_Tren': ['Tren', 'Train', 'Tren', 'Train', 'Zug', 'Поезд', 'قطار'],
    'Sound_Vantilatör': ['Vantilatör', 'Fan', 'Ventilador', 'Ventilateur', 'Ventilator'],
    'Sound_Kalp Atışı': ['Kalp Atışı', 'Heartbeat', 'Latido del corazón', 'Battement de cœur', 'Herzschlag'],
    'Sound_Kuş Sesi': ['Kuş Sesi', 'Bird Sound', 'Sonido de pájaros', 'Chant d\'oiseaux', 'Vogelgesang'],
    'Sound_Su Sesi': ['Su Sesi', 'Water Sound', 'Sonido de agua', 'Bruit d\'eau', 'Wassergeräusch'],
    'Sound_Çamaşır Makinesi': ['Çamaşır Makinesi', 'Washing Machine', 'Lavadora', 'Machine à laver', 'Waschmaschine'],
    'Sound_Trafik': ['Trafik', 'Traffic', 'Tráfico', 'Trafic', 'Verkehr', 'Трафик', 'حركة المرور'],

    // ─── Uyku Takibi / Sleep Stats ───
    'StatsWeekTitle': ['Son 7 Gün', 'Last 7 Days', 'Últimos 7 días', '7 derniers jours', 'Letzte 7 Tage', 'Последние 7 дней', 'آخر 7 أيام'],
    'StatsTotalTime': ['Toplam Süre', 'Total Time', 'Tiempo total', 'Temps total', 'Gesamtzeit', 'Всего', 'الإجمالي'],
    'StatsAvgDuration': ['Ortalama', 'Average', 'Promedio', 'Moyenne', 'Durchschnitt', 'Среднее', 'المتوسط'],
    'StatsSessionsCount': ['oturum', 'sessions', 'sesiones', 'séances', 'Sitzungen', 'сессий', 'جلسات'],
    'StatsNoData': ['Henüz uyku kaydı yok', 'No sleep records yet', 'Aún no hay registros', 'Aucun enregistrement', 'Noch keine Aufzeichnungen', 'Нет записей сна', 'لا توجد سجلات نوم بعد'],
    'StatsMinLabel': ['dk', 'min', 'min', 'min', 'Min', 'мин', 'د'],
    'StatsHoursShort': ['sa', 'h', 'h', 'h', 'Std', 'ч', 'س'],
    'StatsLastSession': ['Son Oturum', 'Last Session', 'Última sesión', 'Dernière séance', 'Letzte Sitzung', 'Последняя сессия', 'آخر جلسة'],
    'StatsStreak': ['Gün Serisi', 'Day Streak', 'Racha de días', 'Série de jours', 'Tages-Serie', 'Серия дней', 'سلسلة الأيام'],
    'StatsPreferredTime': ['Genelde Saat', 'Usual Time', 'Hora habitual', 'Heure habituelle', 'Übliche Zeit', 'Обычное время', 'الوقت المعتاد'],
    'StatsTopSound': ['Favori Ses', 'Top Sound', 'Sonido favorito', 'Son préféré', 'Lieblingston', 'Любимый звук', 'الصوت المفضل'],
    'StatsLoading': ['Yükleniyor...', 'Loading...', 'Cargando...', 'Chargement...', 'Laden...', 'Загрузка...', 'جارٍ التحميل...'],
    'StatsTonight': ['Bu Gece', 'Tonight', 'Esta noche', 'Ce soir', 'Heute Nacht', 'Сегодня вечером', 'الليلة'],
    'StatsDayShort_0': ['Pzt', 'Mon', 'Lun', 'Lun', 'Mo', 'Пн', 'إث'],
    'StatsDayShort_1': ['Sal', 'Tue', 'Mar', 'Mar', 'Di', 'Вт', 'ثل'],
    'StatsDayShort_2': ['Çar', 'Wed', 'Mie', 'Mer', 'Mi', 'Ср', 'أر'],
    'StatsDayShort_3': ['Per', 'Thu', 'Jue', 'Jeu', 'Do', 'Чт', 'خم'],
    'StatsDayShort_4': ['Cum', 'Fri', 'Vie', 'Ven', 'Fr', 'Пт', 'جم'],
    'StatsDayShort_5': ['Cmt', 'Sat', 'Sáb', 'Sam', 'Sa', 'Сб', 'سب'],
    'StatsDayShort_6': ['Paz', 'Sun', 'Dom', 'Dim', 'So', 'Вс', 'أح'],

    // ─── Bugünkü Uyutmalar / Today's Naps ───
    'StatsTodayNapsTitle': ['Bugünkü Uyutmalar', 'Today\'s Naps', 'Siestas de hoy', 'Siestes du jour', 'Schläfchen heute', 'Сегодняшние сны', 'قيلولات اليوم'],
    'StatsNoNapsToday': ['Bugün henüz uyutma yok', 'No naps yet today', 'Aún no hay siestas hoy', 'Aucune sieste aujourd\'hui', 'Heute noch kein Schläfchen', 'Сегодня ещё нет снов', 'لا توجد قيلولات اليوم'],
    'StatsNapStarted': ['başladı', 'started', 'iniciado', 'commencée', 'gestartet', 'начат', 'بدأ'],
    'StatsNapShort': ['kısa', 'short', 'corta', 'courte', 'kurz', 'коротко', 'قصير'],
    // ─── Saatlik Dağılım / Hourly Distribution ───
    'StatsHourlyTitle': ['Saatlik Dağılım', 'Hourly Distribution', 'Distribución horaria', 'Répartition horaire', 'Stündliche Verteilung', 'Почасовое распределение', 'التوزيع بالساعة'],
    'StatsHourlyDesc': ['Haftalık verilere göre uyutmaların başladığı saatler', 'Hours when naps usually start, based on weekly data', 'Horas en que suelen comenzar las siestas, según los datos semanales', 'Heures où les siestes commencent généralement, selon les données hebdomadaires', 'Stunden, in denen Schläfchen meist beginnen, basierend auf Wochendaten', 'Часы начала снов по недельным данным', 'الساعات التي تبدأ فيها القيلولات عادة، استناداً إلى البيانات الأسبوعية'],
    // ─── Stats Info Dialog yeni maddeler ───
    'StatsInfoItem5Title': ['🕐 Bugünkü Uyutmalar', '🕐 Today\'s Naps', '🕐 Siestas de hoy', '🕐 Siestes du jour', '🕐 Schläfchen heute', '🕐 Сегодняшние сны', '🕐 قيلولات اليوم'],
    'StatsInfoItem5Desc': ['Bugün başlayan tüm uyutma oturumlarını saatleriyle birlikte gösterir. Bebeğinizin gün içindeki uyku ritmini takip etmek için kullanışlıdır.', 'Shows all nap sessions started today with their start times. Useful for tracking your baby\'s daily sleep rhythm.', 'Muestra todas las sesiones de siesta iniciadas hoy con sus horas de inicio. Útil para seguir el ritmo de sueño diario de tu bebé.', 'Affiche toutes les séances de sieste commencées aujourd\'hui avec leurs heures de début. Utile pour suivre le rythme de sommeil quotidien de votre bébé.', 'Zeigt alle heute begonnenen Schläfchen mit ihren Startzeiten. Nützlich, um den täglichen Schlafrhythmus Ihres Babys zu verfolgen.', 'Показывает все начатые сегодня сессии сна с временем начала', 'يعرض جميع جلسات القيلولة التي بدأت اليوم مع وقت بدئها'],
    'StatsInfoItem6Title': ['📈 Saatlik Dağılım', '📈 Hourly Distribution', '📈 Distribución horaria', '📈 Répartition horaire', '📈 Stündliche Verteilung', '📈 Почасовое распределение', '📈 التوزيع بالساعة'],
    'StatsInfoItem6Desc': ['7 günlük veriye göre 24 saatlik mini grafik — bebeğinizin hangi saatlerde sıkça uyutulduğunu gösterir. Düzenli uyku rutinini görselleştirmek için.', '24-hour mini chart based on 7-day data — shows the hours when your baby is most frequently put to sleep. Helps visualize a regular sleep routine.', 'Mini gráfico de 24 horas basado en datos de 7 días — muestra las horas en que más se acuesta a tu bebé. Ayuda a visualizar una rutina de sueño regular.', 'Mini graphique de 24h basé sur 7 jours de données — montre les heures où votre bébé est le plus souvent endormi. Aide à visualiser une routine de sommeil régulière.', '24-Stunden-Mini-Diagramm basierend auf 7-Tage-Daten — zeigt die Stunden, in denen Ihr Baby am häufigsten schlafen gelegt wird. Hilft, eine regelmäßige Schlafroutine zu visualisieren.', '24-часовая мини-диаграмма на основе 7-дневных данных — показывает обычные часы сна малыша', 'رسم مصغر لـ 24 ساعة بناءً على بيانات 7 أيام — يعرض ساعات نوم الطفل المعتادة'],
  };
}
