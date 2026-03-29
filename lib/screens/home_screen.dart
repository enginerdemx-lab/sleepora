import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math';

import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../models/shuffle_settings.dart';
import '../widgets/mini_player.dart';
import '../widgets/liquid_glass_tab_bar.dart';
import '../services/review_service.dart';
import '../services/subscription_service.dart';
import '../services/sleep_audio_handler.dart';
import '../screens/sounds_screen.dart';
import 'favorites_screen.dart';
import 'record_screen.dart';
import 'games_screen.dart';
import 'settings_screen.dart';
import '../services/localization_service.dart';

// Hangi oynatıcının şu an "ön planda" (aktif) olduğunu takip eden enum.
enum ActivePlayer { none, single, mixer, shuffle }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
  final AudioPlayer _audioPlayer1 = AudioPlayer();
  final AudioPlayer _audioPlayer2 = AudioPlayer();
  int _activePlayerIndex = 1; // 1 veya 2
  StreamSubscription? _positionSub;
  bool _isCrossfading = false;
  static const int _crossfadeDurationMs = 2500; // 2.5 saniye crossfade

  // Mixer player'lar — her ses için ayrı player
  final List<AudioPlayer> _mixerPlayers = [];

  // FavoritesScreen'e erişim için GlobalKey
  final GlobalKey<FavoritesScreenState> _favoritesKey = GlobalKey<FavoritesScreenState>();

  // Shuffle (Karışık Çalma) state'leri
  bool _isShufflePlaying = false;
  ShuffleSettings _shuffleSettings = ShuffleSettings();
  Timer? _shuffleChangeTimer;
  Timer? _shuffleMasterTimer;
  List<Sound> _activeShuffleList = [];

  // Kilit ekranı handler'ına kısa yol — singleton üzerinden
  SleepAudioHandler? get _audioHandler => SleepAudioHandler.instance;

  @override
  void initState() {
    super.initState();
    _loadBabyName();
    _loc.addListener(_onLanguageChanged);
    SubscriptionService().addListener(_onLanguageChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ReviewService.showReviewDialog(context);
    });
  }

  /// Kilit ekranı / Kontrol Merkezi'ni günceller.
  /// Her ses durum değişiminden sonra çağrılır.
  void _syncNowPlaying() {
    final h = _audioHandler;
    if (h == null) return;

    switch (_activePlayer) {
      case ActivePlayer.single:
        if (_playingSound != null) {
          h.onPlayPause = _togglePlayPause;
          h.onStop = _closePlayer;
          h.onSkipToNext = _playNextSound;
          h.updateNowPlaying(
            title: _playingSound!.localizedName,
            isPlaying: _isPlaying,
          );
        }
      case ActivePlayer.mixer:
        h.onPlayPause = _toggleMixerPlay;
        h.onStop = _closeMixerPlayer;
        h.onSkipToNext = null;
        h.updateNowPlaying(
          title: _mixerLabel ?? 'Karıştırıcı',
          isPlaying: _mixerPlaying,
        );
      case ActivePlayer.shuffle:
        h.onPlayPause = _toggleShufflePlayPause;
        h.onStop = _stopShuffle;
        h.onSkipToNext = null;
        h.updateNowPlaying(title: 'Karışık Çalma', isPlaying: true);
      case ActivePlayer.none:
        h.onPlayPause = null;
        h.onStop = null;
        h.onSkipToNext = null;
        h.updateNowPlaying(title: '', isPlaying: false);
    }
  }

  /// Kilit ekranından sonraki sese geç
  void _playNextSound() {
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

  void _onLanguageChanged() {
    if (mounted) setState(() {});
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
  bool get _isPlayingSavedMix => _mixerLabel != null && !_mixerLabel!.startsWith('Karıştırıcı');
  // FavoritesScreen içindeki sekme 2 (Karıştırıcı) açık mı?
  bool get _isMixerTabActive => _currentIndex == 1 && (_favoritesKey.currentState?.isMixerTab ?? false);

  @override
  void dispose() {
    _loc.removeListener(_onLanguageChanged);
    SubscriptionService().removeListener(_onLanguageChanged);
    _positionSub?.cancel();
    _shuffleChangeTimer?.cancel();
    _shuffleMasterTimer?.cancel();
    _audioPlayer1.dispose();
    _audioPlayer2.dispose();
    for (final p in _mixerPlayers) {
      try { p.dispose(); } catch (_) {}
    }
    super.dispose();
  }

  // ─── Tüm sesleri temizle (ortak yardımcı) ───
  void _clearAllSounds() async {
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
      _stopShuffle();
    }
  }

  // ─── Tek ses oynatma (SoundsScreen'den çağrılır) ───
  void _updatePlayer(Sound? sound) async {
    _stopCrossfadeLoop();

    // Tüm diğer modları temizle
    if (sound != null) {
      _clearAllSounds();
    }

    setState(() {
      _playingSound = sound;
      _isPlaying = sound != null;
      _miniPlayerCollapsed = false;
      _activePlayer = sound != null ? ActivePlayer.single : ActivePlayer.none;
      if (sound != null) sound.isPlaying = true;
    });

    _syncNowPlaying();

    if (sound != null) {
      try {
        _activePlayerIndex = 1;
        await _audioPlayer1.setAsset(sound.assetPath);
        await _audioPlayer1.setLoopMode(LoopMode.off);
        await _audioPlayer1.setVolume(1.0);
        await _audioPlayer1.play();
        _startCrossfadeLoop(sound);
      } catch (e) {
        debugPrint('Ses hatası: $e');
      }
    } else {
      try { await _audioPlayer1.stop(); } catch (_) {}
      try { await _audioPlayer2.stop(); } catch (_) {}
    }
  }

  void _stopCrossfadeLoop() {
    _positionSub?.cancel();
    _positionSub = null;
    _isCrossfading = false;
  }

  /// Crossfade loop: aktif player'ın pozisyonunu dinle, bitmesine yakın crossfade yap
  void _startCrossfadeLoop(Sound sound) {
    _positionSub?.cancel();
    final active = _activePlayerIndex == 1 ? _audioPlayer1 : _audioPlayer2;

    _positionSub = active.positionStream.listen((position) async {
      if (!_isPlaying || _playingSound != sound || _isCrossfading) return;

      final duration = active.duration;
      if (duration == null) return;

      final remaining = duration - position;
      if (remaining.inMilliseconds <= _crossfadeDurationMs && remaining.inMilliseconds > 100) {
        await _doCrossfade(sound, remaining.inMilliseconds);
      }
    });
  }

  Future<void> _doCrossfade(Sound sound, int remainingMs) async {
    if (_isCrossfading || !_isPlaying || _playingSound != sound) return;
    _isCrossfading = true;
    _positionSub?.cancel();

    final outgoing = _activePlayerIndex == 1 ? _audioPlayer1 : _audioPlayer2;
    final incoming = _activePlayerIndex == 1 ? _audioPlayer2 : _audioPlayer1;

    try {
      // İkinci player'ı hazırla ve sessiz başlat
      await incoming.setAsset(sound.assetPath);
      await incoming.setLoopMode(LoopMode.off);
      await incoming.setVolume(0.0);
      await incoming.play();

      // Volume crossfade — 20 adımda
      const steps = 20;
      final stepMs = remainingMs ~/ steps;

      for (int i = 1; i <= steps; i++) {
        if (!_isPlaying || _playingSound != sound) break;
        await Future.delayed(Duration(milliseconds: stepMs));
        final progress = i / steps;
        try {
          await outgoing.setVolume((1.0 - progress).clamp(0.0, 1.0));
          await incoming.setVolume(progress.clamp(0.0, 1.0));
        } catch (_) {}
      }

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
      _isCrossfading = false;
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
      _mixerLabel = selected.isNotEmpty ? 'Karıştırıcı (${selected.length} ses)' : null;
      if (nowEmpty) {
        _mixerPlaying = false;
      }
    });

    // Ses seçildiğinde otomatik çal
    if (selected.isNotEmpty) {
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
    // Önce tek ses player'ı durdur
    try { await _audioPlayer1.stop(); } catch (_) {}
    try { await _audioPlayer2.stop(); } catch (_) {}

    // Önce eski mixer player'ları tamamen durdur ve temizle
    await _stopMixerPlayers();

    setState(() {
      _clearAllSounds();
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

    // Ses sayısına göre volume ayarla
    for (final sound in sounds) {
      try {
        final player = AudioPlayer();
        await player.setAsset(sound.assetPath);
        await player.setLoopMode(LoopMode.one);
        // Doğrudan sesin bellekteki/katalogdaki volume değerini kullan
        await player.setVolume(sound.volume);
        _mixerPlayers.add(player);
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
      await _stopMixerPlayers();
      setState(() => _mixerPlaying = false);
    } else {
      try { await _audioPlayer1.stop(); } catch (_) {}
      try { await _audioPlayer2.stop(); } catch (_) {}
      setState(() {
        _clearAllSounds();
        _mixerPlaying = true;
      });
      if (_mixerSelected.isNotEmpty) {
        await _startMixerPlayers(_mixerSelected);
      }
    }
    _syncNowPlaying();
  }

  // ─── Mixer player kapat ───
  void _closeMixerPlayer() async {
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
        _mixerLabel = 'Karıştırıcı (${_mixerPlayers.length} ses)';
      });
    }
  }

  // ─── Tekli ses oynat/duraklat ───
  void _togglePlayPause() async {
    final active = _activePlayerIndex == 1 ? _audioPlayer1 : _audioPlayer2;
    setState(() {
      _isPlaying = !_isPlaying;
      if (_playingSound != null) _playingSound!.isPlaying = _isPlaying;
    });
    _syncNowPlaying();
    try {
      if (_isPlaying) {
        await active.play();
        if (_playingSound != null) _startCrossfadeLoop(_playingSound!);
      } else {
        _stopCrossfadeLoop();
        await active.pause();
      }
    } catch (e) {
      debugPrint('Play/pause hatası: $e');
    }
  }

  // ─── Tekli ses kapat ───
  void _closePlayer() async {
    _stopCrossfadeLoop();
    try { await _audioPlayer1.stop(); } catch (_) {}
    try { await _audioPlayer2.stop(); } catch (_) {}
    setState(() {
      _clearAllSounds();
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
  
  void _stopShuffle() {
    _shuffleChangeTimer?.cancel();
    _shuffleMasterTimer?.cancel();
    _audioPlayer1.stop();
    _audioPlayer2.stop();
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

    _clearAllSounds();

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
    
    final oldPlayer = _primaryPlayer;
    _activePlayerIndex = _activePlayerIndex == 1 ? 2 : 1;
    final newPlayer = _primaryPlayer;
    
    try {
      await newPlayer.setAsset(nextSound.assetPath);
      await newPlayer.setLoopMode(LoopMode.one);
      
      if (_shuffleSettings.crossfadeEnabled) {
        // Crossfade logic
        newPlayer.setVolume(0.0);
        newPlayer.play();
        
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
          const RecordScreen(),
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
              sound: Sound(name: _mixerLabel ?? 'Karıştırıcı (${_mixerSelected.length} ses)', icon: Icons.queue_music_rounded, assetPath: ''),
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

// ─── Uyku Rehberi Dialogu ───
class _SleepGuideDialog extends StatefulWidget {
  const _SleepGuideDialog();
  @override
  State<_SleepGuideDialog> createState() => _SleepGuideDialogState();
}

class _SleepGuideDialogState extends State<_SleepGuideDialog> {
  int _expandedIndex = -1;
  final _loc = LocalizationService();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1035),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Text(_loc.t('SleepGuide'), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha:0.1)),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          Flexible(
            child: SingleChildScrollView(
              child: Column(children: [
                for (int i = 1; i <= 4; i++) ...[
                  _SleepGuideSection(
                    title: _loc.t('GuideTitle_$i'),
                    content: _loc.t('GuideContent_$i'),
                    isExpanded: _expandedIndex == i,
                    onTap: () => setState(() => _expandedIndex = _expandedIndex == i ? -1 : i),
                  ),
                  if (i < 4) const SizedBox(height: 12),
                ],
                const SizedBox(height: 16),
                Divider(color: Colors.white.withValues(alpha:0.08)),
                const SizedBox(height: 12),
                Text(
                  _loc.t('GuideWarning'),
                  style: TextStyle(color: Colors.white.withValues(alpha:0.4), fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SleepGuideSection extends StatelessWidget {
  final String title, content;
  final bool isExpanded;
  final VoidCallback onTap;
  const _SleepGuideSection({required this.title, required this.content, required this.isExpanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isExpanded ? AppColors.purple.withValues(alpha:0.15) : Colors.white.withValues(alpha:0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isExpanded ? AppColors.purple.withValues(alpha:0.3) : Colors.white.withValues(alpha:0.08)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))),
            Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: 24),
          ]),
          if (isExpanded) ...[
            const SizedBox(height: 14),
            Text(content, style: TextStyle(color: Colors.white.withValues(alpha:0.7), fontSize: 13, height: 1.5)),
          ],
        ]),
      ),
    );
  }
}

// _NavItem kaldırıldı — LiquidGlassTabBar widget'ına taşındı
