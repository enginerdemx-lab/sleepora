import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      ),
    );
  } catch (e) {
    debugPrint('Audio init error: $e');
  }

  // ───── 7. Uygulamayı Başlat ─────
  runApp(const SleeporaApp());

  // ───── 8. Abonelik Servisi (IAP) arka planda başlasın ─────
  SubscriptionService().init();
}

class SleeporaApp extends StatelessWidget {
  const SleeporaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocalizationService(),
      builder: (context, _) {
        return MaterialApp(
          title: 'Sleepora',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: const SplashScreen(),
        );
      },
    );
  }
}
