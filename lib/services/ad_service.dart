import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:audio_session/audio_session.dart';
import 'subscription_service.dart';
import 'sleep_audio_handler.dart';

/// AdMob servisi.
///
/// Tek prensip: **Plus kullanıcılara hiçbir reklam gösterilmez.**
/// Her API çağrısı önce `SubscriptionService().isPremium` kontrolü yapar.
///
/// **iOS:** Gerçek AdMob ID'leri konfigüre edilmiş durumda
/// (App ID `ca-app-pub-6124076415673164~2641577022`). Debug build'de otomatik
/// olarak test reklamı gösterilir, release build'de gerçek reklam.
///
/// **Android:** Henüz AdMob'da konfigüre edilmedi → her durumda Google'ın
/// resmi test reklamlarını gösterir. İleride Android için de gerçek ID'ler
/// alınınca [_RealIds] içindeki Android sabitlerini doldur.
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  bool _initialized = false;
  bool _trackingRequested = false;

  // ═══════════════════════════════════════════════════════
  // Test ID switch
  // ═══════════════════════════════════════════════════════
  /// `kDebugMode` true iken (yani `flutter run` ile test sırasında) HER ZAMAN
  /// Google'ın resmi test reklamları gösterilir — gerçek tıklama olmaz, hesap
  /// banlanmaz. Release build (TestFlight / App Store) çıktısında otomatik
  /// olarak gerçek ID'lere geçer.
  ///
  /// Force override için bunu true yapabilirsin (ör: TestFlight'ta da test
  /// reklamı görmek istersen geçici olarak true yap).
  static const bool _forceTestIds = false; // Release: gerçek reklam | Debug: kDebugMode otomatik test reklamı
  static bool get useTestIds => _forceTestIds || kDebugMode;

  // Google'ın resmi test ID'leri (her zaman çalışır, gerçek para üretmez)
  static const _testBanner = 'ca-app-pub-3940256099942544/2934735716'; // iOS banner
  static const _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const _testRewarded = 'ca-app-pub-3940256099942544/1712485313'; // iOS rewarded
  static const _testRewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';

  // ═══════════════════════════════════════════════════════
  // Init (main()'de bir kez çağır)
  // ═══════════════════════════════════════════════════════
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await MobileAds.instance.initialize();
      // Çocuk hedefli içerik için tag — sleepora bebek uygulaması ama
      // ANA kullanıcı yetişkin (anne-baba) olduğu için tagForChildDirected = false.
      // Yine de tagForUnderAgeOfConsent = false ile uyumluluk sağlanır.
      final config = RequestConfiguration(
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.no,
        tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.no,
      );
      MobileAds.instance.updateRequestConfiguration(config);
      _initialized = true;
      debugPrint('📺 AdService: initialized');
    } catch (e) {
      debugPrint('❌ AdService: initialize failed → $e');
    }
  }

  /// iOS 14.5+ App Tracking Transparency dialogu.
  /// Asıl ekranda kullanıcı en az 1 kez sohbet ettikten sonra çağırın
  /// (Apple'a göre cold-start'ta hemen sormak iyi pratik değil).
  Future<void> requestTrackingIfNeeded() async {
    if (_trackingRequested) return;
    _trackingRequested = true;
    if (!Platform.isIOS) return;
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await Future.delayed(const Duration(milliseconds: 400));
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (e) {
      debugPrint('❌ ATT request failed → $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // Banner ad unit ID seçimi
  // ═══════════════════════════════════════════════════════
  String bannerUnitId(BannerSlot slot) {
    // Debug build veya force override → test ID
    if (useTestIds) {
      return Platform.isAndroid ? _testBannerAndroid : _testBanner;
    }
    // Android henüz AdMob'da konfigüre edilmedi — test ID ile devam et
    if (Platform.isAndroid) return _testBannerAndroid;
    // iOS release → gerçek AdMob ID
    return _RealIds.banner(slot, isAndroid: false);
  }

  String rewardedUnitId(RewardedSlot slot) {
    if (useTestIds) {
      return Platform.isAndroid ? _testRewardedAndroid : _testRewarded;
    }
    if (Platform.isAndroid) return _testRewardedAndroid;
    return _RealIds.rewarded(slot, isAndroid: false);
  }

  // ═══════════════════════════════════════════════════════
  // Premium check helper
  // ═══════════════════════════════════════════════════════
  bool get adsEnabled => !SubscriptionService().isPremium;

  // ═══════════════════════════════════════════════════════
  // Rewarded ad loader + show wrapper
  // ═══════════════════════════════════════════════════════
  /// Rewarded reklam göster ve ödülü kazandı mı bilgisini döndür.
  /// [onAdShown] reklam ekranı açıldığı an çağrılır (oyunu pause etmek için).
  /// [onAdClosed] reklam kapandığı an çağrılır (oyunu resume etmek için).
  ///
  /// **NOT:** Rewarded reklamlar Plus üyelere DE gösterilir. Mantık şu:
  /// kullanıcı kendi tercihiyle "ek can / +10sn / geri al" istediği için
  /// reklam izleyip ödülü kazanır. Plus avantajı sadece "rahatsız edici
  /// banner reklamlardan kurtulma"dır; oyun içi opt-in rewarded değildir.
  Future<bool> showRewarded({
    required RewardedSlot slot,
    VoidCallback? onAdShown,
    VoidCallback? onAdClosed,
  }) async {
    // ── Reklam başlamadan ses kontrolünü güvene al ──
    // AdMob iOS'ta kendi AVAudioSession'ını aktive eder; Sleepora'nın çalan
    // sesi (uyku ve doğa sesleri) bu sırada interrupt olur. Sistem geri
    // verirken interruption.end her zaman `pause` tipinde gelmediği için,
    // home_screen'in oto-resume yolu tetiklenmeyebiliyor → kullanıcı UI'da
    // "çalıyor" görüyor ama hoparlörden ses çıkmıyor (Control Center'dan
    // çıkış aygıtını değiştirince çözülmesi bu yüzden).
    //
    // Çözüm: Reklam öncesi mevcut ses durumunu kaydet + manuel duraklat;
    // reklam kapanınca AVAudioSession'ı yeniden aktive et + manuel sürdür.
    final audioRestore = await _suspendSleepAudio();

    final completer = Completer<bool>();
    bool restored = false;
    Future<void> doRestore() async {
      if (restored) return;
      restored = true;
      await audioRestore();
    }

    try {
      await RewardedAd.load(
        adUnitId: rewardedUnitId(slot),
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            bool earned = false;
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (_) {
                onAdShown?.call();
              },
              onAdDismissedFullScreenContent: (RewardedAd a) async {
                a.dispose();
                await doRestore();
                onAdClosed?.call();
                // Ödül zaten kazanıldıysa dismiss false yapmasın
                if (!earned && !completer.isCompleted) completer.complete(false);
              },
              onAdFailedToShowFullScreenContent: (RewardedAd a, AdError err) async {
                debugPrint('❌ Rewarded show failed → $err');
                a.dispose();
                await doRestore();
                onAdClosed?.call();
                if (!completer.isCompleted) completer.complete(false);
              },
            );
            ad.show(onUserEarnedReward: (AdWithoutView _, RewardItem reward) {
              earned = true;
              if (!completer.isCompleted) completer.complete(true);
            });
            // Timeout: 90sn içinde tamamlanmazsa false
            Future.delayed(const Duration(seconds: 90), () async {
              if (!completer.isCompleted) {
                await doRestore();
                completer.complete(earned);
              }
            });
          },
          onAdFailedToLoad: (LoadAdError error) async {
            debugPrint('❌ Rewarded load failed → $error');
            // Reklam yüklenmediyse — sesi hiç durdurmamış gibi devam etsin.
            await doRestore();
            if (!completer.isCompleted) completer.complete(false);
          },
        ),
      );
    } catch (e) {
      debugPrint('❌ Rewarded show outer error → $e');
      await doRestore();
      if (!completer.isCompleted) completer.complete(false);
    }
    return completer.future;
  }

  // ═══════════════════════════════════════════════════════
  // Audio session koruması (reklam öncesi/sonrası)
  // ═══════════════════════════════════════════════════════
  /// Çalan uyku sesini geçici olarak duraklatır ve restore fonksiyonu döner.
  /// Restore çağrıldığında AVAudioSession yeniden aktive edilir ve ses devam
  /// ettirilir. Hiçbir ses çalmıyorsa restore no-op olur.
  ///
  /// **Tek ses modu (en yaygın senaryo):** AdMob'un kendi AVAudioSession'ı
  /// reklam boyunca aktif olduktan sonra just_audio'nun alttaki AVPlayer'ı
  /// audio route'unu kaybediyor — sadece `play()` çağırmak yetmiyor, hoparlör
  /// sessiz kalıyor. Bu yüzden reklam sonrası `onResumeAfterAd` (hard reload:
  /// stop + setAsset + play) tetikleniyor. Mixer/shuffle modlarında zaten tam
  /// yeniden başlatma var → fallback olarak `onPlay` çağrılır.
  Future<Future<void> Function()> _suspendSleepAudio() async {
    final handler = SleepAudioHandler.instance;
    if (handler == null) {
      return () async {};
    }

    final wasPlaying = handler.playbackState.value.playing;
    if (!wasPlaying) {
      return () async {};
    }

    // HomeScreen'in atadığı callback'leri sakla — reklam sırasında
    // HomeScreen yeniden assign ederse bile bizim referansımız doğru kalsın.
    final pauseCb = handler.onPause;
    final hardResumeCb = handler.onResumeAfterAd;
    final playCb = handler.onPlay;

    try {
      // pause callback artık Future<void> — await ile bittiğinden emin ol.
      if (pauseCb != null) await pauseCb();
    } catch (e) {
      debugPrint('⚠️ Audio pause-before-ad failed: $e');
    }

    return () async {
      // AdMob session'ının tamamen kapanması için biraz bekle. iOS'ta
      // çok hızlı setActive(true) çağrısı "Session deactivation failed"
      // hatasıyla sonuçlanabiliyor; ayrıca AVPlayer'ın audio route'u
      // resetlenmesi için zaman tanımak da iyi olur.
      await Future.delayed(const Duration(milliseconds: 450));

      // Önce session'ı zorla aktive et (defensif)
      try {
        final session = await AudioSession.instance;
        await session.setActive(true);
      } catch (e) {
        debugPrint('⚠️ AudioSession reactivate after ad failed: $e');
      }

      // Artık her mod (tek ses, mixer, shuffle) kendi `onResumeAfterAd`
      // Future'ına sahip → hard reload her zaman çalışır. Fallback olarak
      // sadece UI rezeti için playCb kalır (defensif).
      try {
        if (hardResumeCb != null) {
          await hardResumeCb();
        } else if (playCb != null) {
          await playCb();
        }
      } catch (e) {
        debugPrint('⚠️ Audio resume-after-ad failed: $e');
      }
    };
  }
}

// ═══════════════════════════════════════════════════════
// Slot enum'ları (her yere özel ID atama imkanı)
// ═══════════════════════════════════════════════════════

enum BannerSlot {
  settings,
  blockMenu,
  minesweeperMenu,
  game2048Menu,
  quizMenu,
}

enum RewardedSlot {
  blockContinue,
  minesweeperUndo,
  quizJoker,
  quizUnlock,
}

// ═══════════════════════════════════════════════════════
// Gerçek ID'ler — AdMob hesabından alınca buraya doldur
// ═══════════════════════════════════════════════════════
class _RealIds {
  // ─── iOS gerçek AdMob ID'leri (Sleepora — App ID: ca-app-pub-6124076415673164~2641577022) ───
  // Banner birimleri
  static const _iosBannerSettings    = 'ca-app-pub-6124076415673164/1148846583'; // settings_banner
  static const _iosBannerBlockMenu   = 'ca-app-pub-6124076415673164/6197678653'; // block_menu_banner
  static const _iosBannerMineMenu    = 'ca-app-pub-6124076415673164/3208033717'; // minesweeper_menu_banner
  static const _iosBanner2048Menu    = 'ca-app-pub-6124076415673164/4884596981'; // game2048_menu_banner
  static const _iosBannerQuizMenu    = 'ca-app-pub-6124076415673164/4896519900'; // quiz_menu_banner
  // Rewarded birimleri
  static const _iosRewBlock          = 'ca-app-pub-6124076415673164/3571515313'; // block_continue_rewarded
  static const _iosRewMine           = 'ca-app-pub-6124076415673164/5171852079'; // minesweeper_undo_rewarded
  static const _iosRewQuiz           = 'ca-app-pub-6124076415673164/5399602307'; // quiz_joker_rewarded
  static const _iosRewQuizUnlock     = 'ca-app-pub-6124076415673164/8129707421'; // quiz_category_unlock_rewarded

  // ─── Android gerçek ID'ler (henüz konfigüre edilmedi — bannerUnitId/rewardedUnitId
  //     Android için otomatik test ID döndürür, bu sabitler sadece ileride kullanılacak) ───
  static const _aBannerSettings = 'TODO_REPLACE_Android_banner_settings';
  static const _aBannerBlockMenu = 'TODO_REPLACE_Android_banner_block';
  static const _aBannerMineMenu = 'TODO_REPLACE_Android_banner_minesweeper';
  static const _aBanner2048Menu = 'TODO_REPLACE_Android_banner_2048';
  static const _aBannerQuizMenu = 'TODO_REPLACE_Android_banner_quiz';
  static const _aRewBlock = 'TODO_REPLACE_Android_rewarded_block';
  static const _aRewMine = 'TODO_REPLACE_Android_rewarded_mine';
  static const _aRewQuiz = 'TODO_REPLACE_Android_rewarded_quiz';
  static const _aRewQuizUnlock = 'TODO_REPLACE_Android_rewarded_quiz_unlock';

  static String banner(BannerSlot slot, {required bool isAndroid}) {
    switch (slot) {
      case BannerSlot.settings:
        return isAndroid ? _aBannerSettings : _iosBannerSettings;
      case BannerSlot.blockMenu:
        return isAndroid ? _aBannerBlockMenu : _iosBannerBlockMenu;
      case BannerSlot.minesweeperMenu:
        return isAndroid ? _aBannerMineMenu : _iosBannerMineMenu;
      case BannerSlot.game2048Menu:
        return isAndroid ? _aBanner2048Menu : _iosBanner2048Menu;
      case BannerSlot.quizMenu:
        return isAndroid ? _aBannerQuizMenu : _iosBannerQuizMenu;
    }
  }

  static String rewarded(RewardedSlot slot, {required bool isAndroid}) {
    switch (slot) {
      case RewardedSlot.blockContinue:
        return isAndroid ? _aRewBlock : _iosRewBlock;
      case RewardedSlot.minesweeperUndo:
        return isAndroid ? _aRewMine : _iosRewMine;
      case RewardedSlot.quizJoker:
        return isAndroid ? _aRewQuiz : _iosRewQuiz;
      case RewardedSlot.quizUnlock:
        return isAndroid ? _aRewQuizUnlock : _iosRewQuizUnlock;
    }
  }
}
