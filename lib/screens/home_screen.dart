import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../models/shuffle_settings.dart';
import '../widgets/mini_player.dart';
import '../widgets/liquid_glass_tab_bar.dart';
import '../services/review_service.dart';
import '../services/subscription_service.dart';
import '../services/sleep_audio_handler.dart';
import '../services/auth_service.dart';
import '../widgets/plus_dialog.dart';
import '../screens/sounds_screen.dart';
import 'favorites_screen.dart';
import 'record_screen.dart';
import 'games_screen.dart';
import 'settings_screen.dart';
import 'paywall_screen.dart';
import '../services/localization_service.dart';
import '../services/sleep_tracking_service.dart';
import '../services/remote_config_service.dart';

// Hangi oynatıcının şu an "ön planda" (aktif) olduğunu takip eden enum.
enum ActivePlayer { none, single, mixer, shuffle }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _loc = LocalizationService();
  int _currentIndex = 0;
  Sound? _playingSound;
  bool _isPlaying = false;
  List<Sound> _mixerSelected = [];
  bool _mixerPlaying = false;
  String? _mixerLabel;
  VoidCallback? _mixerOnClear;
  VoidCallback? _mixerOnVolume;
  VoidCallback? _mixerOnSave;
  bool _miniPlayerCollapsed = false;
  String _babyName = '';

  // Tek ses player'lar (Crossfade loop için iki tane)
  //
  // handleInterruptions: false — ÇOK ÖNEMLİ.
  // just_audio varsayılan olarak interruption'ları kendi ele alır:
  // interruption.begin'de pause(), interruption.end'de (pause tipi ise)
  // otomatik play() çağırır. Bu, bizim manuel interruption handler'ımızla
  // çakışıp state desync yaratıyor — Instagram videosu bitince ses
  // arka planda devam ediyor ama UI "durdu" zannediyordu, sonuçta
  // pause butonu (idempotent guard nedeniyle) işlevsiz hale geliyordu.
  // Tüm interruption yönetimi _initAudioSessionListener tarafından yapılıyor.
  final AudioPlayer _audioPlayer1 = AudioPlayer(handleInterruptions: false);
  final AudioPlayer _audioPlayer2 = AudioPlayer(handleInterruptions: false);
  int _activePlayerIndex = 1; // 1 veya 2
  StreamSubscription? _positionSub;
  StreamSubscription? _completionSub; // Ses bitince fallback için
  bool _isCrossfading = false;
  // 5 saniyelik crossfade — kabin sesi gibi loop'u belli olan ambiyans
  // dosyalarında geçişi tamamen örter. Equal-power eğrisi ile birlikte
  // dinleyici "tek sürekli ses" hissi alır.
  static const int _crossfadeDurationMs = 5000;

  // Fade operasyonlarını iptal etmek için nesil sayacı
  // Her yeni ses başladığında/durduğunda artırılır.
  // Eski fade coroutine'leri bu sayacı kontrol edip kendini iptal eder.
  int _audioGen = 0;

  // Mixer player'lar — her ses için ayrı player
  final List<AudioPlayer> _mixerPlayers = [];
  // Her mixer player için completed event listener'ı.
  // Bazı MP3'lerde (kabin sesi, yol sesi gibi başında/sonunda az silence
  // olan dosyalar) native LoopMode.one gap bırakıyor — ses bir an kapanıp
  // yeniden başlıyor. completed yakalanınca volume'ü düşürüp başa sarıyor
  // ve hızlıca fade-in yapıyoruz: kesinti çok daha az fark ediliyor.
  final List<StreamSubscription> _mixerLoopSubs = [];

  // FavoritesScreen'e erişim için GlobalKey
  final GlobalKey<FavoritesScreenState> _favoritesKey = GlobalKey<FavoritesScreenState>();

  // RecordScreen'e erişim için GlobalKey — playback'i durdurabilmek için
  final GlobalKey<RecordScreenState> _recordKey = GlobalKey<RecordScreenState>();

  // Shuffle (Karışık Çalma) state'leri
  bool _isShufflePlaying = false;
  ShuffleSettings _shuffleSettings = ShuffleSettings();
  Timer? _shuffleChangeTimer;
  Timer? _shuffleMasterTimer;
  List<Sound> _activeShuffleList = [];

  // Kilit ekranı handler'ına kısa yol — singleton üzerinden
  SleepAudioHandler? get _audioHandler => SleepAudioHandler.instance;

  // AudioSession interruption listener
  StreamSubscription? _interruptionSub;

  // ─── Audio watchdog ───
  // Bazı durumlarda (iOS audio route sessizce düşmesi, native LoopMode.one'ın
  // tetiklenmemesi, başka uygulamadan gelen "sessiz" ses çakışmaları)
  // UI çalıyor görünür ama hoparlörden ses çıkmaz. Periyodik bekçi
  // her 5 saniyede mevcut modu kontrol eder: UI "çalıyor" diyorsa ama
  // ilgili player gerçekten çalmıyorsa otomatik olarak kurtarır.
  Timer? _watchdogTimer;
  // Watchdog'un aynı saniyede ardışık reload yapmasını engellemek için
  // son kurtarma denemesinin zamanı.
  DateTime? _lastWatchdogRecovery;

  // Kesinti başlamadan önceki çalma durumu — kesinti bitince otomatik
  // devam ettirmek için saklanır (ör: Instagram videosu kapandığında
  // ses kaldığı yerden devam etsin).
  bool _wasPlayingBeforeInterruption = false;
  ActivePlayer _modeBeforeInterruption = ActivePlayer.none;


  // ─── Premium ses önizleme (Preview) ───
  bool _isPreviewMode = false;
  Timer? _previewTimer;
  int _previewRemainingSeconds = 0;

  // Plus süresi doldu pop-up'ı aynı anda iki kez açılmasın diye.
  bool _plusExpiredDialogVisible = false;

  @override
  void initState() {
    super.initState();
    _loadBabyName();
    _loc.addListener(_onLanguageChanged);
    SubscriptionService().addListener(_onSubscriptionChanged);
    // Plus süresi zaten dolmuşsa (init önbellekten erken set etmiş olabilir)
    // ilk frame'de kontrol et.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowPlusExpiredDialog());
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowAnnouncement());
    // Puanlama: uygulama açıldıktan 5 saniye sonra (onboarding/login sırasında değil).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 5), () {
        if (!mounted) return;
        ReviewService.showReviewDialog(
          context,
          isPremium: SubscriptionService().isPremium,
        );
      });
    });
    _initAudioSessionListener();
    _startWatchdog();
    // App background/foreground geçişlerini dinle — iOS bazen background'dan
    // dönerken AVAudioSession'ı sessizce düşürür; resumed'de zorla reaktive
    // ediyoruz ve watchdog'u hemen tetikleyerek sessiz player'ları kurtarıyoruz.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    }
  }

  /// App background'dan foreground'a döndüğünde çağrılır.
  ///
  /// iOS özelinde: AVAudioSession bazen background'da sessizce deactive
  /// edilebiliyor (başka uygulamadan dönüş, kısa süreli sistem sesleri,
  /// Control Center açıp kapatma, vs.). UI hâlâ "çalıyor" gösterirken
  /// hoparlörden ses gelmez. Burada:
  ///   1) Audio session'ı yeniden aktive et
  ///   2) Watchdog'u zaman beklemeden hemen tetikle (cooldown'u bypass et)
  Future<void> _onAppResumed() async {
    // Audio session'ı yeniden aktive et — YALNIZCA Sleepora kendi sesini
    // çalıyorsa. Çalmıyorsa kullanıcı başka uygulamadan müzik dinliyor olabilir;
    // bu durumda oturuma dokunma ki dış müzik kesilmesin.
    if (_isPlaying || _mixerPlaying || _isShufflePlaying) {
      try {
        await _activateSleeporaAudio();
      } catch (e) {
        debugPrint('⚠️ AppLifecycle resumed → session reaktive hatası: $e');
      }
    }

    if (!mounted) return;
    // Watchdog'u cooldown beklemeden tetikle — eğer UI playing ama player
    // sessizse anında kurtar.
    _lastWatchdogRecovery = null; // cooldown reset
    try {
      await _runWatchdogCheck();
    } catch (e) {
      debugPrint('⚠️ AppLifecycle resumed → watchdog hatası: $e');
    }
  }

  /// Başka bir uygulama ses aldığında (iOS interruption) hem UI'ı hem de
  /// gerçek player'ları senkronize eder.
  ///
  /// Mantık:
  /// 1) Kesinti başladığında: ne çalıyorsa hatırla, TÜM player'lara fiziksel
  ///    pause() çağır, UI state'i kapat.
  /// 2) Kesinti bittiğinde: eğer iOS "pause" tipinde kesinti raporladıysa
  ///    (yani devam etmeye izin var — örn. Instagram videosu kapandı),
  ///    daha önce çalan modu otomatik yeniden başlat.
  ///    `AudioInterruptionType.unknown` geldiğinde devam ettirme (sistem
  ///    kesin bir hint vermemiş).
  ///
  /// NOT: `handleInterruptions: false` ile oluşturulan `AudioPlayer`'lar
  /// just_audio'nun kendi auto-resume mekanizmasını kullanmıyor, bu yüzden
  /// buradaki manuel kontrol state desync'e yol açmıyor.

  // ── Ses oturumu modları ────────────────────────────────────────────────
  // Sleepora kendi sesini ÇALMADIĞINDA başka uygulamaların müziğini KESMEMELİ
  // (kullanıcı Spotify vb. dinlerken sadece oyun oynamak için girebilir). Bu
  // yüzden boştayken oturum `mixWithOthers` ile yapılandırılır → dış ses devam
  // eder. Sleepora kendi sesini çaldığı an oturum `none` (mixsiz) yapılıp
  // aktive edilir → dış müzik o anda durdurulur. Böylece dış ses YALNIZCA
  // Sleepora'dan ses açıldığında kesilir.
  static const AudioSessionConfiguration _idleMixAudioConfig =
      AudioSessionConfiguration(
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
  );

  static const AudioSessionConfiguration _exclusiveAudioConfig =
      AudioSessionConfiguration(
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
  );

  /// Sleepora kendi sesini çalmaya başlamadan HEMEN ÖNCE çağrılır.
  /// Oturumu mixsiz (exclusive) `playback` yapıp aktive eder → dış uygulamanın
  /// müziği o an durdurulur. Bu, dış sesin SADECE Sleepora çaldığında
  /// kesilmesini garanti eder.
  Future<void> _activateSleeporaAudio() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(_exclusiveAudioConfig);
      await session.setActive(true);
    } catch (e) {
      debugPrint('⚠️ _activateSleeporaAudio hata: $e');
    }
  }

  void _initAudioSessionListener() {
    AudioSession.instance.then((session) async {
      // Boşta (henüz Sleepora'dan ses çalınmadı): mixWithOthers ile yapılandır
      // ki app açılınca / ana ekran yüklenince dış müzik kesilmesin. Kullanıcı
      // bir ses çaldığında `_activateSleeporaAudio()` oturumu exclusive yapıp
      // dış sesi durdurur; o an iOS Now Playing kontrolleri de görünür olur.
      try {
        await session.configure(_idleMixAudioConfig);
      } catch (_) {}
      _interruptionSub = session.interruptionEventStream.listen((event) async {
        if (!mounted) return;
        if (event.begin) {
          final wasPlaying = _isPlaying || _mixerPlaying || _isShufflePlaying;
          if (!wasPlaying) return;

          // Kesinti öncesi durumu sakla — end'de otomatik devam için.
          _wasPlayingBeforeInterruption = true;
          _modeBeforeInterruption = _activePlayer;

          // Crossfade ve shuffle zamanlayıcılarını durdur — arka planda
          // tetiklenip pause sonrası player'ları uyandırmasınlar.
          _stopCrossfadeLoop();
          _shuffleChangeTimer?.cancel();
          _shuffleMasterTimer?.cancel();

          // Tek ses / crossfade player'larını fiziksel olarak duraklat.
          try { await _audioPlayer1.pause(); } catch (_) {}
          try { await _audioPlayer2.pause(); } catch (_) {}

          // Mixer player'larının her birini duraklat.
          for (final p in _mixerPlayers) {
            try { await p.pause(); } catch (_) {}
          }

          if (!mounted) return;
          setState(() {
            _isPlaying = false;
            _mixerPlaying = false;
            _isShufflePlaying = false;
            if (_playingSound != null) _playingSound!.isPlaying = false;
          });
          _syncNowPlaying();
        } else {
          // event.end — kesinti bitti (ör: Instagram videosu kapandı).
          if (!_wasPlayingBeforeInterruption) return;

          // iOS "pause" tipinde kesinti bildirmişse resume güvenli.
          // "unknown"/"duck" durumunda sistem hint vermediği için
          // otomatik devam ettirmiyoruz (kullanıcı yine de Play'e basabilir).
          if (event.type != AudioInterruptionType.pause) {
            _wasPlayingBeforeInterruption = false;
            _modeBeforeInterruption = ActivePlayer.none;
            return;
          }

          final savedMode = _modeBeforeInterruption;
          _wasPlayingBeforeInterruption = false;
          _modeBeforeInterruption = ActivePlayer.none;

          // iOS'ta resume öncesi session'ı yeniden aktive et.
          try {
            await session.setActive(true);
          } catch (_) {}

          // Kesinti öncesi hangi mod çalıyorsa onu devam ettir.
          // AWAIT şart — resume async olduğu için awaitsiz çağırsak callback
          // hemen "tamam" sayılır, hata silently yutulur.
          try {
            switch (savedMode) {
              case ActivePlayer.single:
                await _resumePlayback();
                break;
              case ActivePlayer.mixer:
                await _resumeMixerPlayback();
                break;
              case ActivePlayer.shuffle:
                await _resumeShufflePlayback();
                break;
              case ActivePlayer.none:
                break;
            }
          } catch (e) {
            debugPrint('⚠️ Interruption sonrası resume hatası: $e');
          }
        }
      });
    });
  }

  // ─── Audio Watchdog ───
  // UI "çalıyor" gösterdiği halde gerçekte hoparlörden ses çıkmıyorsa
  // periyodik olarak kurtarma uygular. Sebepler:
  //  • iOS AVPlayer audio route'unun sessizce düşmesi (telefon görüşmesi,
  //    Siri, başka uygulama ile çakışma)
  //  • just_audio'nun bazı MP3'lerde processingState=completed sonrası
  //    yeniden tetiklenmemesi
  //  • Crossfade race condition'ları
  //
  // 5 saniyede bir tetiklenir. Hiçbir şey çalmıyorsa no-op.
  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;
      try { await _runWatchdogCheck(); } catch (e) {
        debugPrint('Watchdog hatası: $e');
      }
    });
  }

  Future<void> _runWatchdogCheck() async {
    // Kesinti aktifken ya da preview modunda iken karışma —
    // o yollar zaten kendi state'lerini yönetiyor.
    if (_isPreviewMode) return;
    if (_wasPlayingBeforeInterruption) return;

    // Cooldown: 3sn (eskiden 8sn idi). Çok kısa olursa hard reload'lar
    // birbirini izler ve ses tamamen kesilir; çok uzun olursa sessizlik
    // hissedilir. 3sn pratik denge.
    final now = DateTime.now();
    if (_lastWatchdogRecovery != null &&
        now.difference(_lastWatchdogRecovery!).inSeconds < 3) {
      return;
    }

    // ── Tek ses modu ──
    if (_activePlayer == ActivePlayer.single && _isPlaying && !_isCrossfading) {
      final active = _activePlayerIndex == 1 ? _audioPlayer1 : _audioPlayer2;
      final ps = active.processingState;
      final actuallyPlaying = active.playing;

      // İzin verilen geçici durumlar — bekçi karışmaz
      if (ps == ProcessingState.loading || ps == ProcessingState.buffering) return;

      if (!actuallyPlaying || ps == ProcessingState.completed || ps == ProcessingState.idle) {
        debugPrint('🐶 Watchdog: tek ses sessiz (state=$ps, playing=$actuallyPlaying) — hard reload');
        _lastWatchdogRecovery = now;
        try {
          await _hardResumePlaybackAfterAd();
        } catch (e) {
          debugPrint('Watchdog tek ses kurtarma hatası: $e');
          // Hard reload başarısızsa cooldown'ı sıfırla — bir sonraki tick
          // hemen tekrar denesin.
          _lastWatchdogRecovery = null;
        }
      }
      return;
    }

    // ── Mixer modu ──
    if (_activePlayer == ActivePlayer.mixer && _mixerPlaying && _mixerPlayers.isNotEmpty) {
      bool needRecover = false;
      for (final p in _mixerPlayers) {
        final ps = p.processingState;
        if (ps == ProcessingState.loading || ps == ProcessingState.buffering) continue;
        if (!p.playing || ps == ProcessingState.idle) {
          needRecover = true;
          break;
        }
      }
      if (needRecover) {
        debugPrint('🐶 Watchdog: mixer player(lar)ı sessiz — yeniden başlatma');
        _lastWatchdogRecovery = now;
        // Önce yumuşak deneme: tek tek play() çağır
        bool stillBroken = false;
        for (final p in _mixerPlayers) {
          if (!p.playing) {
            try { await p.play(); } catch (_) { stillBroken = true; }
          }
        }
        // Hâlâ düzelmediyse hard reload — audio session + tam yeniden kurulum.
        if (stillBroken && _mixerSelected.isNotEmpty) {
          try {
            await _hardResumeMixerAfterAd();
          } catch (e) {
            debugPrint('Watchdog mixer hard reload hatası: $e');
            _lastWatchdogRecovery = null;
          }
        }
      }
      return;
    }

    // ── Shuffle modu ──
    if (_activePlayer == ActivePlayer.shuffle && _isShufflePlaying) {
      final active = _activePlayerIndex == 1 ? _audioPlayer1 : _audioPlayer2;
      final ps = active.processingState;
      if (ps == ProcessingState.loading || ps == ProcessingState.buffering) return;
      if (!active.playing || ps == ProcessingState.idle) {
        debugPrint('🐶 Watchdog: shuffle player sessiz — kurtarma');
        _lastWatchdogRecovery = now;
        try {
          try {
            final session = await AudioSession.instance;
            await session.setActive(true);
          } catch (_) {}
          // Önce yumuşak play denemesi
          await active.play();
          // Hâlâ çalmıyorsa hard reload (yeni şarkıya geç)
          await Future.delayed(const Duration(milliseconds: 200));
          if (!active.playing) {
            await _hardResumeShuffleAfterAd();
          }
        } catch (e) {
          debugPrint('Watchdog shuffle kurtarma hatası: $e');
          _lastWatchdogRecovery = null;
        }
      }
    }
  }

  /// Kilit ekranı / Kontrol Merkezi'ni günceller.
  /// Her ses durum değişiminden sonra çağrılır.
  void _syncNowPlaying() {
    final h = _audioHandler;
    if (h == null) return;

    switch (_activePlayer) {
      case ActivePlayer.single:
        if (_playingSound != null) {
          h.onPlay = _resumePlayback;
          h.onPause = _pausePlayback;
          h.onStop = _closePlayer;
          h.onSkipToNext = _playNextSound;
          h.onSkipToPrevious = _playPreviousSound;
          // Reklam sonrası hard reload — tek ses modunda iOS audio
          // route'unu zorla yeniden kuruyor (bkz. _hardResumePlaybackAfterAd).
          h.onResumeAfterAd = _hardResumePlaybackAfterAd;
          h.updateNowPlaying(
            title: _playingSound!.localizedName,
            isPlaying: _isPlaying,
            artworkAssetPath: _playingSound!.artworkPath,
          );
        }
      case ActivePlayer.mixer:
        h.onPlay = _resumeMixerPlayback;
        h.onPause = _pauseMixerPlayback;
        h.onStop = _closeMixerPlayer;
        h.onSkipToNext = null;
        h.onSkipToPrevious = null;
        // Mixer için ÖZEL hard-resume — _resumeMixerPlayback `if (_mixerPlaying)
        // return` guard'ına sahip; reklam sonrası iOS audio route düşmüşse
        // sadece setActive+play yetmez. _hardResumeMixerAfterAd guard'ı bypass
        // edip tam yeniden başlatma yapar.
        h.onResumeAfterAd = _hardResumeMixerAfterAd;
        h.updateNowPlaying(
          title: _mixerLabel ?? _loc.t('MixerTitle'),
          isPlaying: _mixerPlaying,
          // Mixer için varsayılan logo (artworkAssetPath: null)
        );
      case ActivePlayer.shuffle:
        h.onPlay = _resumeShufflePlayback;
        h.onPause = _pauseShufflePlayback;
        h.onStop = _stopShuffle;
        h.onSkipToNext = null;
        h.onSkipToPrevious = null;
        // Shuffle için de hard-resume — yeni şarkıya geçerek audio route'u
        // sıfırlar; reklam sonrası sessizlik yaşanmaz.
        h.onResumeAfterAd = _hardResumeShuffleAfterAd;
        // Shuffle modunda o an çalan sesin kendi artwork'ünü göster
        h.updateNowPlaying(
          title: _loc.t('ShufflePlay'),
          isPlaying: _isShufflePlaying,
          artworkAssetPath: _playingSound?.artworkPath,
        );
      case ActivePlayer.none:
        h.onPlay = null;
        h.onPause = null;
        h.onStop = null;
        h.onSkipToNext = null;
        h.onSkipToPrevious = null;
        h.onResumeAfterAd = null;
        h.updateNowPlaying(title: '', isPlaying: false);
    }
  }

  /// Kilit ekranından sonraki sese geç
  Future<void> _playNextSound() async {
    if (_playingSound == null) return;
    final currentIdx = allSounds.indexOf(_playingSound!);
    if (currentIdx < 0) return;
    // Sonraki sesi bul (döngüsel)
    final nextIdx = (currentIdx + 1) % allSounds.length;
    final nextSound = allSounds[nextIdx];
    // Premium kontrolü — premium sesi atla
    if (SubscriptionService().isSoundPremium(nextSound.name)) {
      // Premium ise bir sonrakine geç
      final skipIdx = (nextIdx + 1) % allSounds.length;
      _updatePlayer(allSounds[skipIdx]);
    } else {
      _updatePlayer(nextSound);
    }
  }

  /// Kilit ekranından önceki sese dön
  Future<void> _playPreviousSound() async {
    if (_playingSound == null) return;
    final currentIdx = allSounds.indexOf(_playingSound!);
    if (currentIdx < 0) return;
    final prevIdx = (currentIdx - 1 + allSounds.length) % allSounds.length;
    final prevSound = allSounds[prevIdx];
    if (SubscriptionService().isSoundPremium(prevSound.name)) {
      final skipIdx = (prevIdx - 1 + allSounds.length) % allSounds.length;
      _updatePlayer(allSounds[skipIdx]);
    } else {
      _updatePlayer(prevSound);
    }
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  /// SubscriptionService değişiminde: UI'ı yenile + Plus süresi dolduysa pop-up göster.
  void _onSubscriptionChanged() {
    if (!mounted) return;
    setState(() {});
    _maybeShowPlusExpiredDialog();
  }

  /// Plus süresi yeni dolduysa bir kerelik "yeniden Plus'a geç" dialogu gösterir.
  void _maybeShowPlusExpiredDialog() {
    final sub = SubscriptionService();
    if (!sub.hasPendingExpiryNotice || _plusExpiredDialogVisible) return;
    sub.clearExpiryNotice();
    _plusExpiredDialogVisible = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _plusExpiredDialogVisible = false;
        return;
      }
      PlusDialog.show(
        context,
        title: _loc.t('PlusExpiredTitle'),
        description: _loc.t('PlusExpiredDesc'),
        secondaryIcon: Icons.lock_clock_rounded,
      ).whenComplete(() => _plusExpiredDialogVisible = false);
    });
  }

  /// Admin panelden gelen duyuruyu (varsa) metin başına bir kez gösterir.
  Future<void> _maybeShowAnnouncement() async {
    final rc = RemoteConfigService();
    if (!rc.announcementEnabled) return;
    final text = rc.announcementText.trim();
    if (text.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('announcement_seen') == text) return;
    await prefs.setString('announcement_seen', text);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1025),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.campaign_rounded, color: AppColors.purple, size: 22),
            const SizedBox(width: 8),
            const Text('Sleepora', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(text, style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 14, height: 1.45)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_loc.t('BtnDone'), style: const TextStyle(color: AppColors.purpleLight, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadBabyName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _babyName = prefs.getString('baby_name') ?? '';
    });
  }

  void _onBabyNameChanged(String name) {
    setState(() => _babyName = name);
  }

  // Hangi player türünün alt barda (MiniPlayer) gösterileceği
  ActivePlayer _activePlayer = ActivePlayer.none;

  AudioPlayer get _primaryPlayer => _activePlayerIndex == 1 ? _audioPlayer1 : _audioPlayer2;
  AudioPlayer get _secondaryPlayer => _activePlayerIndex == 1 ? _audioPlayer2 : _audioPlayer1;
  bool get _isPlayingSavedMix {
    // Mixer auto-generated label'larından (her dilde) farklıysa kayıtlı bir mix çalınıyor demektir.
    if (_mixerLabel == null) return false;
    final mixerBase = _loc.t('MixerTitle');
    return !_mixerLabel!.startsWith(mixerBase);
  }
  // FavoritesScreen içindeki sekme 2 (Karıştırıcı) açık mı?
  bool get _isMixerTabActive => _currentIndex == 1 && (_favoritesKey.currentState?.isMixerTab ?? false);

  @override
  void dispose() {
    _loc.removeListener(_onLanguageChanged);
    SubscriptionService().removeListener(_onSubscriptionChanged);
    _positionSub?.cancel();
    _completionSub?.cancel();
    _interruptionSub?.cancel();
    _previewTimer?.cancel();
    _shuffleChangeTimer?.cancel();
    _shuffleMasterTimer?.cancel();
    _watchdogTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer1.dispose();
    _audioPlayer2.dispose();
    for (final p in _mixerPlayers) {
      try { p.dispose(); } catch (_) {}
    }
    super.dispose();
  }

  // ─── Tüm sesleri temizle (ortak yardımcı) ───
  //
  // ÖNEMLİ: Bu fonksiyon `Future<void>` döner — çağıran yer await ETMELİ.
  // Eskiden `void async` idi ve çoğu yerde await edilmiyordu, bu da yarış
  // durumuna yol açıyordu: mixer player'lar arka planda silinirken yeni
  // setAsset/play çağrılıyordu → ses gelmiyor, watchdog 5sn sonra fark
  // ediyordu.
  Future<void> _clearAllSounds() async {
    _stopCrossfadeLoop();
    _playingSound?.isPlaying = false;
    _playingSound = null;
    _isPlaying = false;

    // Mixeri kapat
    if (_mixerPlaying) {
      await _stopMixerPlayers();
      _mixerPlaying = false;
    }

    // Shuffle'ı kapat
    if (_isShufflePlaying) {
      await _stopShuffle();
    }
  }

  // ─── Tek ses oynatma (SoundsScreen'den çağrılır) ───
  void _updatePlayer(Sound? sound, {bool isPreview = false}) async {
    _stopCrossfadeLoop();
    _cancelPreviewTimer();

    // Premium ses kontrolü — Plus değilse her zaman preview modunda çal
    if (sound != null && !isPreview && !SubscriptionService().isPremium &&
        SubscriptionService().isSoundPremium(sound.name)) {
      isPreview = true;
    }

    // Ses başlayacaksa RecordScreen'deki geri dinlemeyi durdur
    if (sound != null) {
      _recordKey.currentState?.stopPlayback();
    }

    // Tüm diğer modları temizle — AWAIT şart, yoksa mixer dispose ile yeni
    // setAsset paralel koşar → ses gelmeyebilir.
    if (sound != null) {
      await _clearAllSounds();
    }

    setState(() {
      _playingSound?.isPlaying = false; // eski seçili kartı hemen bırak
      _playingSound = sound;
      _isPlaying = sound != null;
      _miniPlayerCollapsed = false;
      _isPreviewMode = isPreview;
      _activePlayer = sound != null ? ActivePlayer.single : ActivePlayer.none;
      if (sound != null) sound.isPlaying = true;
    });

    _syncNowPlaying();

    if (sound != null) {
      // Sleepora kendi sesini çalmaya başlıyor → oturumu exclusive yapıp dış
      // müziği şimdi durdur (yalnızca buradan ses açılınca).
      await _activateSleeporaAudio();
      // Uyku takibini başlat (sadece gerçek oturumlar — preview hariç)
      if (!isPreview) {
        // Ses geçişinde önce mevcut oturumu kapat — yoksa üzerine yazılıp kaybolur
        await SleepTrackingService().endSession();
        SleepTrackingService().startSession(sound.name);
      }
      // Preview timer'ı hemen başlat — async ses yüklenmesini bekleme,
      // böylece popup anında açılır ve geri sayım doğru çalışır.
      if (isPreview) {
        _startPreviewTimer(sound);
      }
      try {
        // Her iki player'ı da kesin durdur — crossfade sonucu player2
        // aktif kalmış olabilir, yeni ses yüklenirken arka planda çalmasın.
        try { await _audioPlayer1.stop(); } catch (_) {}
        try { await _audioPlayer2.stop(); } catch (_) {}
        _activePlayerIndex = 1;
        if (sound.assetPath.startsWith('assets/')) {
          await _audioPlayer1.setAsset(sound.assetPath);
        } else {
          await _audioPlayer1.setFilePath(sound.assetPath);
        }
        // LoopMode.one: Native gapless loop güvenlik ağı.
        // Crossfade başarılı olursa outgoing player durdurulur,
        // başarısız olursa LoopMode.one sessiz geçiş sağlar.
        // Preview modunda da one — timer zaten durduruyor.
        await _audioPlayer1.setLoopMode(LoopMode.one);
        final playGen = ++_audioGen; // yeni nesil — eski fade'leri iptal eder
        // iOS sorunu: fade-out sonrası player volume=0'da kalır.
        // play() 0 volume ile çağrılırsa iOS audio graph'ı aktive etmez → setVolume çalışmaz.
        // Çözüm: play() öncesi volume'ü 1.0'a resetle → iOS düzgün aktive olur,
        // hemen ardından 0.0'a çek → fade-in sorunsuz çalışır.
        await _audioPlayer1.setVolume(1.0); // reset: iOS session'ı zorla aktive et
        await _audioPlayer1.play();
        await _audioPlayer1.setVolume(0.0); // hemen mute, fade-in halleder
        // Döngü stratejisi:
        //  • crossfadeLoop=true → crossfade loop (yumuşak ambiyans sesleri).
        //  • crossfadeLoop=false → crossfade KAPALI; native gapless loop
        //    (LoopMode.one zaten yukarıda set edildi). İnsan sesi/ninni
        //    seslerinde crossfade iki kopyayı üst üste bindirip cırlatıyordu.
        if (!isPreview) {
          if (sound.crossfadeLoop) {
            _startCrossfadeLoop(sound);
          } else {
            // Önceki sesten kalan crossfade dinleyicilerini temizle.
            _stopCrossfadeLoop();
          }
        }
        // Fade-in: arka planda sesi aç
        _fadeInPlayer(_audioPlayer1, gen: playGen, durationMs: 300);
      } catch (e) {
        debugPrint('Ses hatası: $e');
      }
    } else {
      // Ses durduruldu — önce fade-out, sonra durdur
      SleepTrackingService().endSession();
      final stopGen = ++_audioGen; // eski fade-in varsa iptal et
      await Future.wait([
        _fadeOutAndStop(_audioPlayer1, gen: stopGen),
        _fadeOutAndStop(_audioPlayer2, gen: stopGen),
      ]);
    }
  }

  // ─── Preview Timer ───
  void _startPreviewTimer(Sound sound) {
    _previewRemainingSeconds = PremiumContent.previewDurationSeconds;
    _previewTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() => _previewRemainingSeconds--);
      if (_previewRemainingSeconds <= 2 && _previewRemainingSeconds > 0) {
        // Son 2 saniyede fade-out
        final vol = _previewRemainingSeconds / 2.0;
        _audioPlayer1.setVolume(vol.clamp(0.0, 1.0));
        _audioPlayer2.setVolume(vol.clamp(0.0, 1.0));
      }
      if (_previewRemainingSeconds <= 0) {
        timer.cancel();
        // Her iki player'ı da kesin durdur
        _audioPlayer1.stop();
        _audioPlayer2.stop();
        _stopCrossfadeLoop();
        setState(() {
          sound.isPlaying = false;
          _playingSound = null;
          _isPlaying = false;
          _isPreviewMode = false;
          _activePlayer = ActivePlayer.none;
        });
        _syncNowPlaying();
        // Önizleme bitti — premium dialog göster (uyku takibi KAYDETME, preview)
        _showPreviewEndDialog(sound);
      }
    });
  }

  void _cancelPreviewTimer() {
    _previewTimer?.cancel();
    _previewTimer = null;
    _isPreviewMode = false;
  }

  // ─── Premium Önizleme Bitti Dialogu ───
  void _showPreviewEndDialog(Sound sound) {
    if (!mounted) return;
    PlusDialog.show(
      context,
      title: _loc.t('PreviewEndTitle'),
      description: _loc.t('PreviewEndDesc'),
      featureTitle: sound.localizedName,
      secondaryIcon: sound.icon,
    );
  }

  void _stopCrossfadeLoop() {
    _positionSub?.cancel();
    _positionSub = null;
    _completionSub?.cancel();
    _completionSub = null;
    _isCrossfading = false;
  }

  // ─── Fade-in: ses yavaşça açılır (fire-and-forget) ───
  // [gen] parametresi nesil sayacıdır; mevcut nesille eşleşmezse iptal olur.
  Future<void> _fadeInPlayer(AudioPlayer player, {int durationMs = 300, required int gen}) async {
    const steps = 15;
    final stepMs = durationMs ~/ steps;
    for (int i = 1; i <= steps; i++) {
      if (!mounted || _audioGen != gen) return; // iptal: yeni ses başladı
      await Future.delayed(Duration(milliseconds: stepMs));
      if (!mounted || _audioGen != gen) return;
      try {
        await player.setVolume((i / steps).clamp(0.0, 1.0));
      } catch (_) { /* Bir adım başarısız olsa da devam et */ }
    }
    // Fade bittiğinde volume kesin olarak 1.0 olsun
    if (mounted && _audioGen == gen) {
      try { await player.setVolume(1.0); } catch (_) {}
    }
  }

  // ─── Fade-out + stop: ses yavaşça kapanır sonra durur ───
  // [gen] parametresi nesil sayacıdır; mevcut nesille eşleşmezse stop çağırmadan çıkar.
  Future<void> _fadeOutAndStop(AudioPlayer player, {int durationMs = 700, required int gen}) async {
    const steps = 12;
    final stepMs = durationMs ~/ steps;
    final startVol = player.volume;
    if (startVol <= 0.01) {
      if (_audioGen == gen) try { await player.stop(); } catch (_) {}
      return;
    }
    for (int i = 1; i <= steps; i++) {
      if (_audioGen != gen) return; // iptal: yeni ses başladı, stop çağırma
      await Future.delayed(Duration(milliseconds: stepMs));
      if (_audioGen != gen) return;
      try {
        await player.setVolume((startVol * (1.0 - i / steps)).clamp(0.0, 1.0));
      } catch (_) { break; }
    }
    if (_audioGen == gen) try { await player.stop(); } catch (_) {}
  }

  /// Crossfade loop: aktif player'ın pozisyonunu dinle, bitmesine yakın crossfade yap.
  /// LoopMode.one aktif olduğundan, crossfade kaçırılırsa native loop devralır (sessiz geçiş).
  void _startCrossfadeLoop(Sound sound) {
    _positionSub?.cancel();
    _completionSub?.cancel();
    final active = _activePlayerIndex == 1 ? _audioPlayer1 : _audioPlayer2;

    _positionSub = active.positionStream.listen((position) async {
      if (!_isPlaying || _playingSound != sound || _isCrossfading) return;
      // İlk 3 saniyede crossfade tetikleme — henüz yükleniyor olabilir
      if (position.inMilliseconds < 3000) return;

      final duration = active.duration;
      if (duration == null) return;

      final remaining = duration - position;
      if (remaining.inMilliseconds <= _crossfadeDurationMs && remaining.inMilliseconds > 100) {
        await _doCrossfade(sound, remaining.inMilliseconds);
      }
    });

    // Fallback: native LoopMode.one bazı MP3'lerde (özellikle uzun / yüksek
    // metadata içeren dosyalarda) tetiklenmeyebiliyor veya crossfade
    // setAsset beklerken outgoing natural olarak bitebiliyor. Bu durumda
    // playerStateStream completed event'ini yakalayıp elle başa sarıyoruz.
    _completionSub = active.playerStateStream.listen((state) async {
      if (state.processingState != ProcessingState.completed) return;
      if (!_isPlaying || _playingSound != sound) return;
      if (_isCrossfading) return; // crossfade halindeyse karışma
      // Aktif player bitti ama crossfade devralmadı — elle baştan başlat.
      try {
        await active.seek(Duration.zero);
        await active.setLoopMode(LoopMode.one);
        await active.setVolume(1.0);
        await active.play();
      } catch (_) { /* sessizce */ }
    });
  }

  Future<void> _doCrossfade(Sound sound, int remainingMs) async {
    if (_isCrossfading || !_isPlaying || _playingSound != sound) return;
    _isCrossfading = true;
    _positionSub?.cancel();
    _completionSub?.cancel(); // Crossfade başladı — fallback tetiklenmesin

    final outgoing = _activePlayerIndex == 1 ? _audioPlayer1 : _audioPlayer2;
    final incoming = _activePlayerIndex == 1 ? _audioPlayer2 : _audioPlayer1;

    try {
      // Önce incoming'i hazırla — setAsset uzun sürebiliyor (büyük dosya
      // / yavaş cihaz). Outgoing'in LoopMode'u hâlâ `.one` — bu süre içinde
      // outgoing doğal olarak biterse kendi kendine başa sararak sessizliği
      // önler. Hazırlık tamamlanınca LoopMode.off'a çekeceğiz.
      if (sound.assetPath.startsWith('assets/')) {
        await incoming.setAsset(sound.assetPath);
      } else {
        await incoming.setFilePath(sound.assetPath);
      }
      // Incoming player'a LoopMode.one ver — crossfade sonrası o aktif olacak
      await incoming.setLoopMode(LoopMode.one);

      // Incoming hazır — şimdi outgoing'in auto-loop'unu kapatmak güvenli.
      await outgoing.setLoopMode(LoopMode.off);

      // iOS fix: play() önce çağrılmalı — audio session aktif olmadan
      // setVolume(0) iOS tarafından görmezden geliniyor.
      await incoming.play();
      await incoming.setVolume(0.0);

      // Volume crossfade — 40 adım, equal-power (cos/sin) eğrisi.
      //
      // Linear crossfade (1-p, p) ortada toplam algılanan ses düzeyini düşürür
      // → kullanıcı "boşluk" gibi algılar. Equal-power eğrisinde:
      //   outgoing = cos(p · π/2)   incoming = sin(p · π/2)
      // her noktada cos² + sin² = 1 olduğu için algılanan toplam güç sabittir,
      // geçiş "tek sürekli ses" olarak duyulur.
      const steps = 40;
      final stepMs = remainingMs ~/ steps;

      for (int i = 1; i <= steps; i++) {
        if (!_isPlaying || _playingSound != sound) break;
        await Future.delayed(Duration(milliseconds: stepMs));
        final progress = i / steps;
        final outVol = cos(progress * pi / 2).clamp(0.0, 1.0);
        final inVol = sin(progress * pi / 2).clamp(0.0, 1.0);
        try {
          await outgoing.setVolume(outVol);
          await incoming.setVolume(inVol);
        } catch (_) {}
      }
      // Geçiş tamamlandı — incoming'i kesin olarak 1.0'a sabitle
      try { await incoming.setVolume(1.0); } catch (_) {}
      try { await outgoing.setVolume(0.0); } catch (_) {}

      // Player'ları değiştir
      if (_isPlaying && _playingSound == sound) {
        try { await outgoing.stop(); } catch (_) {}
        _activePlayerIndex = _activePlayerIndex == 1 ? 2 : 1;
        _isCrossfading = false;
        _startCrossfadeLoop(sound);
      } else {
        _isCrossfading = false;
      }
    } catch (_) {
      // Crossfade bir yerde çuvalladı — outgoing'in loop'unu geri ver ki
      // ses sonuna gelince baştan başlasın, kullanıcı sessizlik yaşamasın.
      try { await outgoing.setLoopMode(LoopMode.one); } catch (_) {}
      _isCrossfading = false;
      // Completion fallback yeniden devreye girsin
      if (_isPlaying && _playingSound == sound) {
        _startCrossfadeLoop(sound);
      }
    }
  }

  // ─── Mixer seçim değişikliği ───
  void _onMixerChanged(List<Sound> selected, VoidCallback? onClear, VoidCallback? onVolume, VoidCallback? onSave) async {
    final wasEmpty = _mixerSelected.isEmpty;
    final nowEmpty = selected.isEmpty;

    setState(() {
      _mixerSelected = selected;
      if (selected.isNotEmpty) {
        _activePlayer = ActivePlayer.mixer; // Mixer UI öncelikli
      } else if (_activePlayer == ActivePlayer.mixer) {
        _activePlayer = ActivePlayer.none;
      }
      _mixerOnClear = onClear;
      _mixerOnVolume = onVolume;
      _mixerOnSave = onSave;
      _mixerLabel = selected.isNotEmpty
          ? _loc.t('MixerWithCount').replaceAll('{n}', '${selected.length}')
          : null;
      if (nowEmpty) {
        _mixerPlaying = false;
      }
    });

    // Ses seçildiğinde otomatik çal
    if (selected.isNotEmpty) {
      // Mixer başlarken RecordScreen geri dinlemesini durdur
      _recordKey.currentState?.stopPlayback();

      // Tek ses player'ı durdur
      if (_playingSound != null) {
        _playingSound!.isPlaying = false;
        _playingSound = null;
        _isPlaying = false;
        try { await _primaryPlayer.stop(); } catch (_) {}
        try { await _secondaryPlayer.stop(); } catch (_) {}
      }
      // Shuffle durdur
      if (_isShufflePlaying) {
        _stopShuffle();
      }

      // Mixer'ı otomatik başlat/güncelle
      await _stopMixerPlayers();
      await _startMixerPlayers(selected);
      setState(() {
        _mixerPlaying = true;
        _miniPlayerCollapsed = false;
      });
      _syncNowPlaying();
    } else {
      await _stopMixerPlayers();
      _syncNowPlaying();
    }
  }

  // ─── Kaydedilmiş mix'e tıklandı ───
  void _onSavedMixTapped(String mixName, List<Sound> sounds) async {
    // Mix başlarken RecordScreen geri dinlemesini durdur
    _recordKey.currentState?.stopPlayback();

    // Önce tek ses player'ı durdur
    try { await _audioPlayer1.stop(); } catch (_) {}
    try { await _audioPlayer2.stop(); } catch (_) {}

    // Önce eski mixer player'ları tamamen durdur ve temizle
    await _stopMixerPlayers();
    // Diğer modları (tek ses / shuffle) tam senkron temizle — setState'in
    // ÖNCESİNDE await ediyoruz ki yeni mixer setup ile yarış olmasın.
    await _clearAllSounds();

    setState(() {
      _mixerSelected = List.from(sounds);
      _mixerLabel = mixName;
      _mixerPlaying = true;
      _activePlayer = ActivePlayer.mixer;
      _miniPlayerCollapsed = false;
    });

    // Küçük bir gecikme ile yeni player'ları başlat
    await Future.delayed(const Duration(milliseconds: 100));
    await _startMixerPlayers(sounds);
  }

  // ─── Mixer player'ları başlat ───
  Future<void> _startMixerPlayers(List<Sound> sounds) async {
    // Önce temizle
    await _stopMixerPlayers();

    // Sleepora kendi sesini çalmaya başlıyor → oturumu exclusive yapıp dış
    // müziği şimdi durdur (yalnızca buradan ses açılınca).
    await _activateSleeporaAudio();

    // Ses sayısına göre volume ayarla
    for (final sound in sounds) {
      try {
        // handleInterruptions: false — tüm interruption kontrolü
        // _initAudioSessionListener'da yapılıyor. Bkz. _audioPlayer1/2 yorumu.
        final player = AudioPlayer(handleInterruptions: false);
        if (sound.assetPath.startsWith('assets/')) {
          await player.setAsset(sound.assetPath);
        } else {
          await player.setFilePath(sound.assetPath);
        }
        await player.setLoopMode(LoopMode.one);
        // Doğrudan sesin bellekteki/katalogdaki volume değerini kullan
        await player.setVolume(sound.volume);
        _mixerPlayers.add(player);

        // Seamless-loop fallback: native LoopMode.one bazı MP3'lerde
        // (kabin sesi, yol sesi gibi başında/sonunda az boşluk olanlar)
        // tetikten önce gap bırakıyor; ses bir an kapanıp yeniden başlıyor.
        // completed event'i yakalanırsa volume'ü hızlıca 0'a indir, başa sar
        // ve sin-curve ile ~400ms içinde fade-in yap. Tek başına çalan
        // dosyalarda kesinti hâlâ az da olsa hissedilebilir; karışımda
        // (mixer'da) diğer seslerin maskeleyici etkisiyle tamamen kaybolur.
        final loopSub = player.playerStateStream.listen((state) async {
          if (state.processingState != ProcessingState.completed) return;
          if (!_mixerPlayers.contains(player)) return; // dispose edilmişse iptal
          final targetVol = sound.volume;
          try {
            await player.setVolume(0);
            await player.seek(Duration.zero);
            await player.setLoopMode(LoopMode.one);
            if (!player.playing) await player.play();
            // Sin-curve fade-in (lineer'den daha doğal — başlangıç dik değil)
            const steps = 20;
            const stepDur = Duration(milliseconds: 20);
            for (int i = 1; i <= steps; i++) {
              await Future.delayed(stepDur);
              if (!_mixerPlayers.contains(player)) return;
              final p = i / steps;
              final gain = sin(p * pi / 2);
              try {
                await player.setVolume((targetVol * gain).clamp(0.0, 1.0));
              } catch (_) {
                return;
              }
            }
            // Garanti: tam hedef seviyeye otur
            if (_mixerPlayers.contains(player)) {
              try { await player.setVolume(targetVol); } catch (_) {}
            }
          } catch (e) {
            debugPrint('Mixer loop fade-fallback hatası: $e');
          }
        });
        _mixerLoopSubs.add(loopSub);

        // Her ses bağımsız başlatılsın
        player.play();
      } catch (e) {
        debugPrint('Mixer ses hatası: $e');
      }
    }
  }

  // ─── Mixer player'ları durdur ───
  Future<void> _stopMixerPlayers() async {
    final players = List<AudioPlayer>.from(_mixerPlayers);
    _mixerPlayers.clear();
    // Loop fallback listener'larını da kapat — aksi halde dispose edilmiş
    // player için completed event hâlâ geliyor olabilir.
    final subs = List<StreamSubscription>.from(_mixerLoopSubs);
    _mixerLoopSubs.clear();
    for (final s in subs) {
      try { await s.cancel(); } catch (_) {}
    }
    for (final p in players) {
      try {
        await p.stop();
        await p.dispose();
      } catch (e) {
        debugPrint('Player durdurma hatası: $e');
      }
    }
  }

  // ─── Mixer oynat/durdur ───
  void _toggleMixerPlay() async {
    if (_mixerPlaying) {
      _pauseMixerPlayback();
    } else {
      _resumeMixerPlayback();
    }
  }

  /// Reklam sonrası mixer "hard reload" — tam yeniden başlatma.
  ///
  /// AdService reklam kapandığında çağırır. `_resumeMixerPlayback`'ten farkı:
  /// • `_mixerPlaying == true` olsa bile zorla tüm player'ları siler+yeniden kurar
  /// • Audio session'ı garanti aktive eder
  /// • _resumeMixerPlayback'in `if (_mixerPlaying) return` guard'ı yok
  ///
  /// Tek ses modundaki `_hardResumePlaybackAfterAd`'ın mixer eşdeğeri.
  Future<void> _hardResumeMixerAfterAd() async {
    if (_mixerSelected.isEmpty) return;
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
    } catch (_) {}

    // Mixer'ı tamamen sil ve yeniden kur — iOS audio route'unu sıfırlar.
    await _stopMixerPlayers();
    if (!mounted) return;
    setState(() {
      _mixerPlaying = true;
    });
    try {
      await _startMixerPlayers(List<Sound>.from(_mixerSelected));
    } catch (e) {
      debugPrint('Hard mixer resume hatası: $e');
    }
    _syncNowPlaying();
  }

  /// Reklam sonrası shuffle "hard reload" — yeni şarkıya geçerek route'u sıfırlar.
  Future<void> _hardResumeShuffleAfterAd() async {
    if (!_isShufflePlaying && _activeShuffleList.isEmpty) return;
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
    } catch (_) {}
    // Mevcut player'ı tamamen durdur, yeni bir ses ile yeniden başla.
    try { await _audioPlayer1.stop(); } catch (_) {}
    try { await _audioPlayer2.stop(); } catch (_) {}
    if (!mounted) return;
    if (_activeShuffleList.isNotEmpty) {
      await _playNextShuffleSound(_activeShuffleList);
    }
  }

  /// Kilit ekranından: mixer devam ettir (idempotent)
  Future<void> _resumeMixerPlayback() async {
    if (_mixerPlaying) return; // Zaten çalıyor
    try { await _audioPlayer1.stop(); } catch (_) {}
    try { await _audioPlayer2.stop(); } catch (_) {}
    // Diğer modları async temizle (await ile) — setState ÖNCESİ.
    await _clearAllSounds();
    if (!mounted) return;
    setState(() {
      _mixerPlaying = true;
    });
    if (_mixerSelected.isNotEmpty) {
      await _startMixerPlayers(_mixerSelected);
    }
    _syncNowPlaying();
  }

  /// Kilit ekranından: mixer duraklat (idempotent)
  Future<void> _pauseMixerPlayback() async {
    if (!_mixerPlaying) return; // Zaten duraklatılmış
    await _stopMixerPlayers();
    if (!mounted) return;
    setState(() => _mixerPlaying = false);
    _syncNowPlaying();
  }

  // ─── Mixer player kapat ───
  Future<void> _closeMixerPlayer() async {
    await _stopMixerPlayers();
    setState(() {
      _mixerPlaying = false;
      _mixerSelected.clear();
      _mixerLabel = null;
    });
    _mixerOnClear?.call();
    _syncNowPlaying();
  }

  // ─── Volume değişikliği (düzenle dialog'undan) ───
  void _onVolumeChange(int index, double volume) {
    try {
      if (index >= 0 && index < _mixerPlayers.length) {
        _mixerPlayers[index].setVolume(volume);
        _mixerSelected[index].volume = volume;
      }
    } catch (e) {
      debugPrint('Volume hatası: $e');
    }
  }

  void _onMixLiveVolumeChange(String mixName, int index, double volume) {
    if (_mixerLabel == mixName) {
      _onVolumeChange(index, volume);
    }
  }

  // ─── Sesi mixten kaldır (düzenle dialog'undan) ───
  void _onRemoveFromMix(int index) {
    if (index >= 0 && index < _mixerPlayers.length) {
      try {
        final player = _mixerPlayers.removeAt(index);
        // İlgili loop fallback listener'ını da iptal et — aksi halde
        // dispose edilmiş player için completed event tetiklenip hata
        // fırlatabilir.
        if (index < _mixerLoopSubs.length) {
          try { _mixerLoopSubs.removeAt(index).cancel(); } catch (_) {}
        }
        player.stop();
        player.dispose();
      } catch (e) {
        debugPrint('Remove hatası: $e');
      }
    }
    if (_mixerPlayers.isEmpty) {
      setState(() {
        _mixerPlaying = false;
        _mixerLabel = null;
      });
    } else {
      setState(() {
        _mixerLabel = _loc.t('MixerWithCount').replaceAll('{n}', '${_mixerPlayers.length}');
      });
    }
  }

  // ─── Tekli ses oynat/duraklat (UI butonundan) ───
  void _togglePlayPause() async {
    if (_isPlaying) {
      _pausePlayback();
    } else {
      _resumePlayback();
    }
  }

  /// Kilit ekranından veya UI'dan: sadece devam ettir (idempotent)
  Future<void> _resumePlayback() async {
    if (_isPlaying) return; // Zaten çalıyor — çift ses önleme
    final active = _activePlayerIndex == 1 ? _audioPlayer1 : _audioPlayer2;
    setState(() {
      _isPlaying = true;
      if (_playingSound != null) _playingSound!.isPlaying = true;
    });
    _syncNowPlaying();
    try {
      // iOS'ta resume öncesi oturumu exclusive yapıp yeniden aktive et
      // (devam eden Sleepora sesi → dış müzik durmalı).
      await _activateSleeporaAudio();
      await active.play();
      // Resume sonrası crossfade loop'unu yeniden başlat
      if (_playingSound != null) {
        _startCrossfadeLoop(_playingSound!);
      }
    } catch (e) {
      debugPrint('Resume hatası: $e');
    }
  }

  /// Reklam sonrası "hard resume" — tek ses modunda audio route'u garanti
  /// olarak yeniden kurmak için kullanılan tam yeniden yükleme yolu.
  ///
  /// Sebep: AdMob iOS'ta AVAudioSession'ı kendi adına aktive ediyor; reklam
  /// kapandıktan sonra sadece `setActive(true) + play()` çağrısı, just_audio'nun
  /// alttaki AVPlayer'ının audio çıkışını yeniden bağlamasına yetmiyor. UI
  /// "çalıyor" gösteriyor ama hoparlörden ses çıkmıyor (Control Center'dan
  /// çıkış aygıtını değiştirince çözülmesinin nedeni de bu — iOS o anda
  /// audio route'u zorla yeniden kuruyor).
  ///
  /// Çözüm: stop → setAsset (tekrar) → play. Bu, AVPlayer'ı sıfırdan kurar
  /// ve audio route'u garantiler. İçerik aynı ses olduğu için kullanıcı
  /// için fark edilemeyecek hızda gerçekleşir.
  Future<void> _hardResumePlaybackAfterAd() async {
    final sound = _playingSound;
    if (sound == null) return;
    final active = _activePlayerIndex == 1 ? _audioPlayer1 : _audioPlayer2;

    setState(() {
      _isPlaying = true;
      sound.isPlaying = true;
    });
    _syncNowPlaying();

    try {
      // Oturumu exclusive yapıp garanti olarak aktive et (Sleepora sesi devam
      // ediyor → dış müzik durmalı).
      await _activateSleeporaAudio();

      // Önceki crossfade loop'unu temizle (varsa) — yeniden başlatacağız
      _stopCrossfadeLoop();

      // Hard reload: AVPlayer tamamen sıfırlansın
      try { await active.stop(); } catch (_) {}
      if (sound.assetPath.startsWith('assets/')) {
        await active.setAsset(sound.assetPath);
      } else {
        await active.setFilePath(sound.assetPath);
      }
      await active.setLoopMode(LoopMode.one);
      await active.setVolume(1.0);
      await active.play();

      if (mounted) {
        _startCrossfadeLoop(sound);
      }
    } catch (e) {
      debugPrint('Hard resume hatası: $e');
      // Fallback: en azından klasik resume'u dene
      try {
        await active.play();
      } catch (_) {}
    }
  }

  /// Kilit ekranından veya UI'dan: sadece duraklat (idempotent)
  Future<void> _pausePlayback() async {
    if (!_isPlaying) return; // Zaten duraklatılmış — çift çağrı önleme
    _stopCrossfadeLoop();
    setState(() {
      _isPlaying = false;
      if (_playingSound != null) _playingSound!.isPlaying = false;
    });
    _syncNowPlaying();
    try {
      // HER İKİ player'ı da duraklat — crossfade sırasında ikisi de aktif olabilir
      await _audioPlayer1.pause();
      await _audioPlayer2.pause();
    } catch (e) {
      debugPrint('Pause hatası: $e');
    }
  }

  /// RecordScreen tarafından çağrılır — tüm HomeScreen seslerini durdurur.
  void _stopAllAudio() {
    _stopCrossfadeLoop();
    SleepTrackingService().endSession();
    try { _audioPlayer1.pause(); } catch (_) {}
    try { _audioPlayer2.pause(); } catch (_) {}
    if (_mixerPlaying) {
      for (final p in _mixerPlayers) {
        try { p.pause(); } catch (_) {}
      }
    }
    if (_isShufflePlaying) {
      _shuffleChangeTimer?.cancel();
      _shuffleMasterTimer?.cancel();
      try { _audioPlayer1.pause(); } catch (_) {}
      try { _audioPlayer2.pause(); } catch (_) {}
    }
    setState(() {
      _isPlaying = false;
      _mixerPlaying = false;
      _isShufflePlaying = false;
      if (_playingSound != null) _playingSound!.isPlaying = false;
    });
    _syncNowPlaying();
  }

  // ─── Tekli ses kapat ───
  Future<void> _closePlayer() async {
    _stopCrossfadeLoop();
    // Uyku oturumunu sonlandır
    SleepTrackingService().endSession();
    // Fade-out sonra durdur
    final closeGen = ++_audioGen;
    await Future.wait([
      _fadeOutAndStop(_audioPlayer1, gen: closeGen),
      _fadeOutAndStop(_audioPlayer2, gen: closeGen),
    ]);
    // Diğer modların temizliği setState öncesi await edilsin
    await _clearAllSounds();
    if (!mounted) return;
    setState(() {
      if (_activePlayer == ActivePlayer.single) _activePlayer = ActivePlayer.none;
    });
    _syncNowPlaying();
  }

  // ─── Shuffle (Karışık Çalma) İşlemleri ───
  
  void _toggleShufflePlayPause() {
    if (_isShufflePlaying) {
      _stopShuffle();
    } else {
      _startShuffle(allSounds.where((s) => s.isFavorite).toList());
    }
  }

  /// Kilit ekranından: shuffle devam ettir
  Future<void> _resumeShufflePlayback() async {
    if (_isShufflePlaying) return;
    _startShuffle(allSounds.where((s) => s.isFavorite).toList());
  }

  /// Kilit ekranından: shuffle duraklat
  Future<void> _pauseShufflePlayback() async {
    if (!_isShufflePlaying) return;
    _stopShuffle();
  }
  
  void _onShuffleSettingsChanged(ShuffleSettings newSettings) {
    setState(() {
      _shuffleSettings = newSettings;
    });
    // Eğer çalarken ayar değiştiyse, uygulanması için durdurup baştan başlat
    if (_isShufflePlaying) {
      _stopShuffle();
      _startShuffle();
    }
  }
  
  Future<void> _stopShuffle() async {
    _shuffleChangeTimer?.cancel();
    _shuffleMasterTimer?.cancel();
    try { await _audioPlayer1.stop(); } catch (_) {}
    try { await _audioPlayer2.stop(); } catch (_) {}
    if (!mounted) return;
    setState(() {
      _isShufflePlaying = false;
      _playingSound = null;
      _isPlaying = false;
      if (_activePlayer == ActivePlayer.shuffle) _activePlayer = ActivePlayer.none;
    });
    _syncNowPlaying();
  }
  
  void _startShuffle([List<Sound>? sourceList]) {
    if (sourceList != null) {
      _activeShuffleList = sourceList;
    }
    final targetList = _activeShuffleList.isNotEmpty ? _activeShuffleList : allSounds.where((s) => s.isFavorite).toList();

    if (targetList.isEmpty) return;

    // Önceki modları temizle (shuffle'ı durdurmadan)
    _stopCrossfadeLoop();
    _cancelPreviewTimer();
    _shuffleChangeTimer?.cancel();
    _shuffleMasterTimer?.cancel();
    _playingSound?.isPlaying = false;
    if (_mixerPlaying) {
      _stopMixerPlayers();
      _mixerPlaying = false;
    }
    try { _audioPlayer1.stop(); } catch (_) {}
    try { _audioPlayer2.stop(); } catch (_) {}

    setState(() {
      _isShufflePlaying = true;
      _isPlaying = true;
      _activePlayer = ActivePlayer.shuffle;
      _miniPlayerCollapsed = false;
    });
    _syncNowPlaying();
    
    // Master timer varsa kur
    if (_shuffleSettings.playbackDurationMinutes != null) {
      _shuffleMasterTimer = Timer(Duration(minutes: _shuffleSettings.playbackDurationMinutes!), () {
        _stopShuffle();
      });
    }
    
    // İlk sesi çal
    _playNextShuffleSound(targetList);
    
    // Periyodik değişimi başlat
    _shuffleChangeTimer = Timer.periodic(Duration(seconds: _shuffleSettings.changeDurationSeconds), (timer) {
      _playNextShuffleSound(targetList);
    });
  }
  
  Future<void> _playNextShuffleSound(List<Sound> favorites) async {
    if (!_isShufflePlaying || favorites.isEmpty) return;
    
    final random = Random();
    Sound nextSound;
    // Aynı sesin üst üste gelmemesine çalış (1'den fazlaysa)
    if (favorites.length > 1) {
      do {
        nextSound = favorites[random.nextInt(favorites.length)];
      } while (nextSound == _playingSound);
    } else {
      nextSound = favorites.first;
    }
    
    setState(() {
      _playingSound = nextSound;
    });

    // Sleepora kendi sesini çalmaya başlıyor → oturumu exclusive yapıp dış
    // müziği şimdi durdur (yalnızca buradan ses açılınca).
    await _activateSleeporaAudio();

    final oldPlayer = _primaryPlayer;
    _activePlayerIndex = _activePlayerIndex == 1 ? 2 : 1;
    final newPlayer = _primaryPlayer;
    
    try {
      if (nextSound.assetPath.startsWith('assets/')) {
        await newPlayer.setAsset(nextSound.assetPath);
      } else {
        await newPlayer.setFilePath(nextSound.assetPath);
      }
      await newPlayer.setLoopMode(LoopMode.one);
      
      if (_shuffleSettings.crossfadeEnabled) {
        // Crossfade logic
        // iOS fix: play() önce — audio session aktif olmadan setVolume görmezden geliniyor
        await newPlayer.play();
        await newPlayer.setVolume(0.0);
        
        final crossfadeMs = _shuffleSettings.crossfadeDurationSeconds * 1000;
        final steps = 20; // 20 frame'lik animasyon
        final stepDuration = crossfadeMs ~/ steps;
        
        for (int i = 1; i <= steps; i++) {
          if (!_isShufflePlaying) break;
          await Future.delayed(Duration(milliseconds: stepDuration));
          final volume = i / steps;
          try {
            newPlayer.setVolume(volume);
            oldPlayer.setVolume(1.0 - volume);
          } catch (_) {}
        }
        oldPlayer.stop();
        newPlayer.setVolume(1.0); // Emin olmak için
      } else {
        // Normal geçiş
        await oldPlayer.stop();
        newPlayer.setVolume(1.0);
        await newPlayer.play();
      }
    } catch (e) {
      debugPrint('Shuffle oynatma hatası: $e');
    }
  }

  // ─── Mini player collapse/expand ───
  void _toggleMiniPlayerCollapse() {
    setState(() => _miniPlayerCollapsed = !_miniPlayerCollapsed);
  }

  // ─── Header butonları ───
  void _goToMixer() {
    setState(() => _currentIndex = 1);
    // Küçük gecikme ile TabController'a eriş
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _favoritesKey.currentState?.goToMixerTab();
    });
  }

  void _shufflePlay() {
    // Tüm sesler üzerinden karışık çalma modülünü başlat
    _startShuffle(allSounds);
  }

  void _showSleepGuide() {
    showDialog(
      context: context,
      builder: (_) => const _SleepGuideDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          SoundsScreen(
            onSoundChanged: _updatePlayer,
            currentPlayingSound: _playingSound,
            isPreviewMode: _isPreviewMode,
            onGoToMixer: _goToMixer,
            onShuffle: _shufflePlay,
            onSleepGuide: _showSleepGuide,
            babyName: _babyName,
          ),
          FavoritesScreen(
            key: _favoritesKey,
            onMixerChanged: _onMixerChanged,
            onSavedMixTapped: _onSavedMixTapped,
            onSoundTapped: _updatePlayer,
            onVolumeChange: _onVolumeChange,
            onMixLiveVolumeChange: _onMixLiveVolumeChange,
            onRemoveFromMix: _onRemoveFromMix,
            isShufflePlaying: _isShufflePlaying,
            shuffleSettings: _shuffleSettings,
            onShufflePlayPause: _toggleShufflePlayPause,
            onShuffleSettingsChanged: _onShuffleSettingsChanged,
          ),
          RecordScreen(
            key: _recordKey,
            onAudioStarted: _stopAllAudio,
            isMainAudioPlaying: () => _isPlaying || _mixerPlaying || _isShufflePlaying,
          ),
          const GamesScreen(),
          SettingsScreen(onBabyNameChanged: _onBabyNameChanged),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini player — Mixer modu
          if (_activePlayer == ActivePlayer.mixer)
            MiniPlayer(
              sound: Sound(name: _mixerLabel ?? _loc.t('MixerWithCount').replaceAll('{n}', '${_mixerSelected.length}'), icon: Icons.queue_music_rounded, assetPath: ''),
              isPlaying: _mixerPlaying,
              isCollapsed: _miniPlayerCollapsed,
              onPlayPause: _toggleMixerPlay,
              onClose: _closeMixerPlayer,
              onCollapse: _toggleMiniPlayerCollapse,
              onMixerVolume: (_isMixerTabActive && !_isPlayingSavedMix) ? () => _mixerOnVolume?.call() : null,
              onMixerSave: (_isMixerTabActive && !_isPlayingSavedMix) ? () => _mixerOnSave?.call() : null,
              onMixerClear: (_isMixerTabActive && !_isPlayingSavedMix) ? () => _mixerOnClear?.call() : null,
            )
          else if (_activePlayer == ActivePlayer.single && _playingSound != null) // Tekil Ses
            MiniPlayer(
              sound: _playingSound,
              isPlaying: _isPlaying,
              isCollapsed: _miniPlayerCollapsed,
              onPlayPause: _togglePlayPause,
              onClose: _closePlayer,
              onCollapse: _toggleMiniPlayerCollapse,
            )
          else if (_activePlayer == ActivePlayer.shuffle && _playingSound != null) // Karışık (Shuffle)
            MiniPlayer(
              sound: Sound(name: '${_activeShuffleList.length} ${_loc.t('FavSoundsPlaying')}', icon: Icons.shuffle_rounded, assetPath: ''),
              isPlaying: true,
              isCollapsed: _miniPlayerCollapsed,
              onPlayPause: _toggleShufflePlayPause,
              onClose: _stopShuffle,
              onCollapse: _toggleMiniPlayerCollapse,
            ),
          LiquidGlassTabBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            items: [
              LiquidGlassTabItem(icon: Icons.home_rounded, label: _loc.t('NavSounds')),
              LiquidGlassTabItem(icon: Icons.favorite_rounded, label: _loc.t('NavFavorites')),
              LiquidGlassTabItem(icon: Icons.mic_rounded, label: _loc.t('NavRecord')),
              LiquidGlassTabItem(icon: Icons.sports_esports_rounded, label: _loc.t('NavGames')),
              LiquidGlassTabItem(icon: Icons.settings_rounded, label: _loc.t('NavSettings')),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Uyku Rehberi Dialogu (yeni tasarım) ───
/// Her yaş bölümü kendi rengi/emojisi ile gradyan kart olarak gösterilir.
/// Kart açıldığında: süre + uyutma sayısı badge'leri, paragraf metin, ve
/// 3 madde "Önemli İpuçları" listesi belirir. Üstte hero başlık, altta
/// uyarı callout'u.
class _SleepGuideDialog extends StatefulWidget {
  const _SleepGuideDialog();
  @override
  State<_SleepGuideDialog> createState() => _SleepGuideDialogState();
}

class _SleepGuideDialogState extends State<_SleepGuideDialog> {
  int _expandedIndex = -1;
  final _loc = LocalizationService();

  // Her yaş bölümü için renk/emoji haritası — başlığa "kişilik" verir.
  static const _sectionAccents = <_GuideAccent>[
    _GuideAccent(emoji: '👶', primary: Color(0xFF60A5FA), secondary: Color(0xFF3B82F6)), // 0-3 ay  — bebek mavisi
    _GuideAccent(emoji: '🌙', primary: Color(0xFFA78BFA), secondary: Color(0xFF7C3AED)), // 4-6 ay  — uyku moru
    _GuideAccent(emoji: '🧸', primary: Color(0xFFF472B6), secondary: Color(0xFFDB2777)), // 6-12 ay — sıcak pembe
    _GuideAccent(emoji: '🌟', primary: Color(0xFFFBBF24), secondary: Color(0xFFD97706)), // 12-24 ay — kehribar
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
          maxWidth: 560,
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1B1240), Color(0xFF120A26)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ─── Hero Header ───
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 14, 16),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFFC084FC)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.nightlight_round, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _loc.t('SleepGuide'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _loc.t('GuideHeroSubtitle'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),

              // İnce ayraç çizgi
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                color: Colors.white.withValues(alpha: 0.06),
              ),

              // ─── Bölümler (scrollable) ───
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  child: Column(
                    children: [
                      for (int i = 1; i <= 4; i++) ...[
                        _SleepGuideSection(
                          index: i,
                          accent: _sectionAccents[i - 1],
                          title: _loc.t('GuideTitle_$i'),
                          content: _loc.t('GuideContent_$i'),
                          stat: _loc.t('GuideStat_$i'),
                          naps: _loc.t('GuideNaps_$i'),
                          tips: [
                            _loc.t('GuideTip_${i}_1'),
                            _loc.t('GuideTip_${i}_2'),
                            _loc.t('GuideTip_${i}_3'),
                          ],
                          dailyLabel: _loc.t('GuideSleepDuration'),
                          napsLabel: _loc.t('GuideNapsLabel'),
                          tipsTitle: _loc.t('GuideKeyTips'),
                          isExpanded: _expandedIndex == i,
                          onTap: () => setState(
                              () => _expandedIndex = _expandedIndex == i ? -1 : i),
                        ),
                        if (i < 4) const SizedBox(height: 10),
                      ],

                      // ─── Uyarı Callout'u ───
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBBF24).withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFFBBF24).withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: Color(0xFFFBBF24),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _loc.t('GuideWarning'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 11,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tek bir yaş bölümü için kart. Kapalıyken: emoji + başlık + süre badge'i;
/// açıldığında: paragraf + "Önemli İpuçları" listesi animasyonla belirir.
class _SleepGuideSection extends StatelessWidget {
  final int index;
  final _GuideAccent accent;
  final String title;
  final String content;
  final String stat;
  final String naps;
  final List<String> tips;
  final String dailyLabel;
  final String napsLabel;
  final String tipsTitle;
  final bool isExpanded;
  final VoidCallback onTap;

  const _SleepGuideSection({
    required this.index,
    required this.accent,
    required this.title,
    required this.content,
    required this.stat,
    required this.naps,
    required this.tips,
    required this.dailyLabel,
    required this.napsLabel,
    required this.tipsTitle,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isExpanded
                ? [
                    accent.primary.withValues(alpha: 0.18),
                    accent.secondary.withValues(alpha: 0.06),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.04),
                    Colors.white.withValues(alpha: 0.02),
                  ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isExpanded
                ? accent.primary.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.07),
            width: isExpanded ? 1.3 : 1,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Başlık satırı ───
            Row(
              children: [
                // Emoji rozeti
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.primary.withValues(alpha: 0.32),
                        accent.secondary.withValues(alpha: 0.18),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accent.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    accent.emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.15,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: isExpanded
                        ? accent.primary.withValues(alpha: 0.9)
                        : Colors.white.withValues(alpha: 0.55),
                    size: 22,
                  ),
                ),
              ],
            ),

            // ─── Süre + Uyutma badge'leri (kapalıyken de görünür) ───
            const SizedBox(height: 10),
            Row(
              children: [
                _GuideStatChip(
                  icon: Icons.access_time_rounded,
                  label: dailyLabel,
                  value: stat,
                  color: accent.primary,
                ),
                const SizedBox(width: 8),
                _GuideStatChip(
                  icon: Icons.bedtime_rounded,
                  label: napsLabel,
                  value: naps,
                  color: accent.secondary,
                ),
              ],
            ),

            // ─── Açılan içerik (paragraf + ipuçları) ───
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !isExpanded
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Paragraf metin
                          Text(
                            content,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 13,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: 14),
                          // İpuçları başlığı
                          Row(
                            children: [
                              Icon(
                                Icons.tips_and_updates_rounded,
                                size: 14,
                                color: accent.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                tipsTitle,
                                style: TextStyle(
                                  color: accent.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // 3 madde ipucu
                          ...List.generate(tips.length, (i) {
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: i == tips.length - 1 ? 0 : 8,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 6, right: 9),
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [accent.primary, accent.secondary],
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      tips[i],
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.78),
                                        fontSize: 12.5,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Yaş bölümlerine atanan renk/emoji paleti.
class _GuideAccent {
  final String emoji;
  final Color primary;
  final Color secondary;
  const _GuideAccent({
    required this.emoji,
    required this.primary,
    required this.secondary,
  });
}

/// Süre / uyutma sayısı için küçük bilgi çipi.
class _GuideStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _GuideStatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// _NavItem kaldırıldı — LiquidGlassTabBar widget'ına taşındı
