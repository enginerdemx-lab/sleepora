import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/subscription_service.dart';
import 'services/localization_service.dart';
import 'services/sleep_audio_handler.dart';

void main() async {
  // 1. Flutter engine binding (Zorunlu)
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Platform ve yönelim ayarları
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // 3. Kritik olmayan lokalizasyon ve bildirim servisleri
  try { await LocalizationService().init(); } catch (_) {}
  try { NotificationService().init(); } catch (_) {} // Await etmiyoruz, arka planda başlasın

  // 4. KRİTİK: Uygulamayı HEMEN başlat.
  // İlk ekranın render edilmesini engellememek ve iOS Watchdog (20sn) crash'ini önlemek için
  // ağır ses ve arka plan servislerini runApp() sonrasında başlatıyoruz.
  runApp(const SleeporaApp());

  // 5. IAP (Abonelik) servisi başlat (runApp'ten önce tetiklenir ama bloklamaz)
  SubscriptionService().init(); 

  // 6. Ağır platform servislerini asenkron başlat (UI'ı dondurmaz)
  Future.microtask(() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));
    } catch (e) {
      debugPrint("AudioSession error: $e");
    }

    try {
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
      debugPrint("AudioService error: $e");
    }
  });
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
