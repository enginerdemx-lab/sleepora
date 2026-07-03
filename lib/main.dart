import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/subscription_service.dart';
import 'services/localization_service.dart';
import 'services/sleep_audio_handler.dart';
import 'services/auth_service.dart';
import 'screens/sounds_screen.dart';
import 'games/minesweeper/minesweeper_progress_service.dart';
import 'services/ad_service.dart';
import 'services/remote_config_service.dart';

/// Kritik servisler (Firebase + Auth + Lokalizasyon) hazır olduğunda tamamlanır.
/// SplashScreen, ana ekrana geçmeden önce bunu (kısa bir üst sınırla) bekler.
final Completer<void> appCriticalReady = Completer<void>();

void main() async {
  // ───── 1. Flutter Engine Binding (HER ŞEYDEN ÖNCE) ─────
  WidgetsFlutterBinding.ensureInitialized();

  // ───── 2. Platform ve yönelim ayarları (hızlı) ─────
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // ───── 3. UI'YI HEMEN BAŞLAT ─────
  // KRİTİK: Tüm ağır servis başlatmaları (Firebase, Auth, Audio, RemoteConfig,
  // Favoriler...) artık runApp'TAN SONRA, arka planda yapılıyor. Eskiden hepsi
  // runApp'tan önce sırayla await ediliyordu; bu yüzden native açılış (renk)
  // ekranı 5-8 sn donuk bekliyordu. Şimdi splash + logo neredeyse anında
  // görünüyor, servisler splash gösterilirken yükleniyor.
  runApp(const SleeporaApp());

  // Servisleri arka planda başlat — first frame'i bloklamaz.
  unawaited(_initServices());
}

/// Tüm servis başlatmaları. runApp'tan sonra arka planda koşar.
/// Kritik üçlü (Firebase + Auth + Lokalizasyon) bitince [appCriticalReady]
/// tamamlanır ve splash ana ekrana geçebilir; kalan servisler geçişi bloklamaz.
Future<void> _initServices() async {
  // ───── Kritik: Firebase ─────
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase başarıyla başlatıldı.');
  } catch (e) {
    debugPrint('❌ Firebase init HATA: $e');
  }

  // ───── Kritik: Auth (Firebase'den sonra) ─────
  try {
    await AuthService().init();
    debugPrint('✅ AuthService başarıyla başlatıldı.');
  } catch (e) {
    debugPrint('❌ AuthService init HATA: $e');
  }

  // ───── Kritik: Lokalizasyon ─────
  try {
    await LocalizationService().init();
  } catch (_) {}

  // Kritik üçlü hazır — splash artık ana ekrana geçebilir.
  if (!appCriticalReady.isCompleted) appCriticalReady.complete();

  // ───── Bundan sonrası splash geçişini BLOKLAMAZ ─────

  // Bildirim servisi
  try {
    await NotificationService().init();
  } catch (_) {}

  // Ses ve arka plan servisleri
  try {
    final session = await AudioSession.instance;
    // Açılışta mixWithOthers: app açılınca başka uygulamanın müziği KESİLMESİN.
    // Sleepora kendi sesini çaldığında oturum exclusive yapılıp dış ses
    // durdurulur (bkz. home_screen _activateSleeporaAudio).
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ),
    );

    await AudioService.init(
      builder: () => SleepAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.sleepora.audio',
        androidNotificationChannelName: 'Sleepora',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        notificationColor: Color(0xFF8B5CF6),
        androidNotificationIcon: 'drawable/ic_notification', // Beyaz/şeffaf bildirim ikonu
      ),
    );

    // iOS Now Playing için artwork'leri temp klasöre hazırla:
    // varsayılan logo + her sesin kendi resmi (artworkPath tanımlı olanlar).
    final soundArtworkPaths = allSounds
        .map((s) => s.artworkPath)
        .whereType<String>()
        .toList();
    await SleepAudioHandler.initArtwork(assetPaths: soundArtworkPaths);
  } catch (e) {
    debugPrint('Audio init error: $e');
  }

  // Minesweeper Progress Servisi (coin / level / tema)
  try {
    await MinesweeperProgressService().init();
    debugPrint('✅ MinesweeperProgressService başarıyla başlatıldı.');
  } catch (e) {
    debugPrint('❌ MinesweeperProgressService init HATA: $e');
  }

  // AdMob
  try {
    await AdService().initialize();
  } catch (e) {
    debugPrint('❌ AdService başlatılamadı: $e');
  }

  // Uzaktan yapılandırma (Admin panel → config/app)
  try {
    await RemoteConfigService().init().timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint('⚠️ RemoteConfig yüklenemedi, varsayılanlar kullanılacak: $e');
  }

  // Favorileri geri yükle (yerel + Firestore)
  try {
    await loadFavoritesIntoAllSounds().timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint('⚠️ Favoriler yüklenemedi: $e');
  }

  // Abonelik Servisi (IAP) arka planda
  SubscriptionService().init();

  // iOS App Tracking dialog (kısa gecikmeyle, Apple önerisi)
  Future.delayed(const Duration(seconds: 3), () {
    AdService().requestTrackingIfNeeded();
  });
}

class SleeporaApp extends StatelessWidget {
  const SleeporaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocalizationService(),
      builder: (context, _) {
        final loc = LocalizationService();
        final langCode = loc.currentLanguageCode;
        return MaterialApp(
          title: 'Sleepora',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          locale: Locale(langCode),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('tr'),
            Locale('en'),
            Locale('es'),
            Locale('fr'),
            Locale('de'),
            Locale('ru'),
            Locale('ar'),
          ],
          // Arapça için sağdan sola (RTL) düzen
          builder: (context, child) {
            return Directionality(
              textDirection: loc.isRtl ? TextDirection.rtl : TextDirection.ltr,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}
