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

void main() async {
  // ───── 1. Flutter Engine Binding (HER ŞEYDEN ÖNCE) ─────
  WidgetsFlutterBinding.ensureInitialized();

  // ───── 2. Platform ve yönelim ayarları ─────
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // ───── 3. Firebase Başlat (Açık konfigürasyon ile) ─────
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase başarıyla başlatıldı.');
  } catch (e) {
    debugPrint('❌ Firebase init HATA: $e');
  }

  // ───── 4. Auth Servisi Başlat (Firebase'den sonra) ─────
  try {
    await AuthService().init();
    debugPrint('✅ AuthService başarıyla başlatıldı.');
  } catch (e) {
    debugPrint('❌ AuthService init HATA: $e');
  }

  // ───── 5. Lokalizasyon ve Bildirim Servisleri ─────
  try {
    await LocalizationService().init();
  } catch (_) {}
  try {
    await NotificationService().init();
  } catch (_) {}

  // ───── 6. Ses ve Arka Plan Servisleri ─────
  try {
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
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

  // ───── 7. Minesweeper Progress Servisi (coin / level / tema) ─────
  try {
    await MinesweeperProgressService().init();
    debugPrint('✅ MinesweeperProgressService başarıyla başlatıldı.');
  } catch (e) {
    debugPrint('❌ MinesweeperProgressService init HATA: $e');
  }

  // ───── 8. AdMob başlat ─────
  try {
    await AdService().initialize();
  } catch (e) {
    debugPrint('❌ AdService başlatılamadı: $e');
  }

  // ───── 9. Uygulamayı Başlat ─────
  runApp(const SleeporaApp());

  // ───── 10. Abonelik Servisi (IAP) arka planda başlasın ─────
  SubscriptionService().init();

  // ───── 11. iOS App Tracking dialog (kısa gecikmeyle, Apple önerisi) ─────
  // ignore: discarded_futures
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
