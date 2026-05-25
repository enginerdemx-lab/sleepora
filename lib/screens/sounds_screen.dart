import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;
import '../theme/app_theme.dart';
import '../widgets/sound_card.dart';
import '../services/subscription_service.dart';
import '../services/auth_service.dart';
import 'paywall_screen.dart';
import 'login_screen.dart';
import '../services/localization_service.dart';
import '../widgets/plus_dialog.dart';
import '../widgets/unlock_button.dart';

class Sound {
  final String name; // Dahili anahtar — değişmez (premium, favori, playCount için)
  final IconData icon;
  // Özel PNG ikon (assets/images/icon/…). null ise [icon] (IconData) kullanılır.
  final String? iconPath;
  final String assetPath;
  // Kilit ekranı / Now Playing için ses başına artwork asset yolu.
  // null ise SleepAudioHandler varsayılan logoyu gösterir.
  final String? artworkPath;
  bool isFavorite;
  bool isPlaying;
  double volume;
  final bool isRecord;

  Sound({
    required this.name,
    required this.icon,
    this.iconPath,
    required this.assetPath,
    this.artworkPath,
    this.isFavorite = false,
    this.isPlaying = false,
    this.volume = 0.5,
    this.isRecord = false,
  });

  /// Dil ayarına göre çevrilmiş ses adı (Sound_ prefix'i kullanıcıya gösterilmez)
  String get localizedName {
    final translated = LocalizationService().t('Sound_$name');
    // Eğer çeviri bulunamadıysa key döner — Sound_ prefix'ini kaldır
    return translated.startsWith('Sound_') ? translated.substring(6) : translated;
  }
}

final List<Sound> allSounds = [
  Sound(name: 'Pış Pış', icon: Icons.nightlight_round, iconPath: 'assets/images/icon/pispis.png', assetPath: 'assets/sounds/Pis Pis Sesi.mp3', artworkPath: 'assets/images/artwork/pis_pis.jpg'),
  Sound(name: 'Eee Eee', icon: Icons.child_care, iconPath: 'assets/images/icon/eee.png', assetPath: 'assets/sounds/Eee Eee.mp3', artworkPath: 'assets/images/artwork/Eee_eee.jpg'),
  Sound(name: 'Dandini', icon: Icons.nightlight_round, iconPath: 'assets/images/icon/dandini.png', assetPath: 'assets/sounds/Dandini-Dandini-Dastana.mp3', artworkPath: 'assets/images/artwork/Dandini.jpg'),
  Sound(name: 'Süpürge', icon: Icons.bolt, iconPath: 'assets/images/icon/supurge.png', assetPath: 'assets/sounds/süpürge-sesi.mp3', artworkPath: 'assets/images/artwork/supurge.jpg'),
  Sound(name: 'Kolik', icon: Icons.child_care, iconPath: 'assets/images/icon/kolik.png', assetPath: 'assets/sounds/Kolik.mp3', artworkPath: 'assets/images/artwork/Kolik.jpg'),           // premium
  Sound(name: 'Kabin Sesi', icon: Icons.airplanemode_active, iconPath: 'assets/images/icon/kabin.png', assetPath: 'assets/sounds/kabin-sesi.mp3', artworkPath: 'assets/images/artwork/kabin.jpg'),
  Sound(name: 'Uyusunda Büyüsün', icon: Icons.auto_awesome, iconPath: 'assets/images/icon/uyusundabuyusun.png', assetPath: 'assets/sounds/uyusunda-büyüsün-nini.mp3', artworkPath: 'assets/images/artwork/Uyusunda_Buyusun.jpg'),
  Sound(name: 'Yıldız Tozu', icon: Icons.star, iconPath: 'assets/images/icon/yildiztozu.png', assetPath: 'assets/sounds/Yildiz-Tozu-Ninnisi.mp3', artworkPath: 'assets/images/artwork/Yildiz_Tozu.jpg'), // premium
  Sound(name: 'Pış Pış + Süpürge', icon: Icons.bolt, iconPath: 'assets/images/icon/supurge_pispis.png', assetPath: 'assets/sounds/Pis-pis-ve-süpürge.mp3', artworkPath: 'assets/images/artwork/Pis_pis_supurge.jpg'),
  Sound(name: 'Beyaz Gürültü', icon: Icons.layers, iconPath: 'assets/images/icon/beyaz_gurultu.png', assetPath: 'assets/sounds/beyaz-gürültü.mp3', artworkPath: 'assets/images/artwork/Beyaz_Gurultu.jpg'),
  Sound(name: 'Konuşma', icon: Icons.record_voice_over, iconPath: 'assets/images/icon/konusma.png', assetPath: 'assets/sounds/Konusma.mp3', artworkPath: 'assets/images/artwork/Konusma.jpg'), // premium
  Sound(name: 'Yol Sesi', icon: Icons.directions_car, iconPath: 'assets/images/icon/yol.png', assetPath: 'assets/sounds/yol-sesi.mp3', artworkPath: 'assets/images/artwork/Yol.jpg'),
  Sound(name: 'Yağmur', icon: Icons.umbrella, iconPath: 'assets/images/icon/yagmur.png', assetPath: 'assets/sounds/yagmur.mp3', artworkPath: 'assets/images/artwork/Yagmur.jpg'),
  Sound(name: 'Saç Kurutma', icon: Icons.air, iconPath: 'assets/images/icon/sackurutma.png', assetPath: 'assets/sounds/sac-kurutma.mp3', artworkPath: 'assets/images/artwork/Sac_Kurutma.jpg'),
  Sound(name: 'Pış Pış 2', icon: Icons.nightlight_round, iconPath: 'assets/images/icon/pispis.png', assetPath: 'assets/sounds/Piş_piş2.mp3', artworkPath: 'assets/images/artwork/Pis_pis_2.jpg'), // premium
  Sound(name: 'Rüzgar', icon: Icons.air, iconPath: 'assets/images/icon/ruzgar.png', assetPath: 'assets/sounds/Rüzgar.mp3', artworkPath: 'assets/images/artwork/ruzgar.jpg'),
  Sound(name: 'Dalga', icon: Icons.water, iconPath: 'assets/images/icon/dalga.png', assetPath: 'assets/sounds/Dalga.mp3', artworkPath: 'assets/images/artwork/Dalga.jpg'),
  Sound(name: 'Duş', icon: Icons.shower, iconPath: 'assets/images/icon/dus.png', assetPath: 'assets/sounds/Dus.mp3', artworkPath: 'assets/images/artwork/Dus.jpg'),
  Sound(name: 'Helikopter', icon: Icons.flight, iconPath: 'assets/images/icon/helikopter.png', assetPath: 'assets/sounds/Helikopter.mp3', artworkPath: 'assets/images/artwork/Helikopter.jpg'),
  Sound(name: 'Tren', icon: Icons.train, iconPath: 'assets/images/icon/tren.png', assetPath: 'assets/sounds/Tren.mp3', artworkPath: 'assets/images/artwork/Tren.jpg'),
  Sound(name: 'Vantilatör', icon: Icons.toys_rounded, iconPath: 'assets/images/icon/vantilator.png', assetPath: 'assets/sounds/Vantilatör.mp3', artworkPath: 'assets/images/artwork/Vantilator.jpg'),
  Sound(name: 'Kalp Atışı', icon: Icons.favorite, iconPath: 'assets/images/icon/kalp.png', assetPath: 'assets/sounds/kalp-atisi.mp3', artworkPath: 'assets/images/artwork/Kalp_Atisi.jpg'),
  Sound(name: 'Kuş Sesi', icon: Icons.park, iconPath: 'assets/images/icon/kus.png', assetPath: 'assets/sounds/kus-sesi.mp3', artworkPath: 'assets/images/artwork/Kus_Sesi.jpg'),
  Sound(name: 'Su Sesi', icon: Icons.water_drop, iconPath: 'assets/images/icon/su.png', assetPath: 'assets/sounds/su.mp3', artworkPath: 'assets/images/artwork/Su_Sesi.jpg'),
  Sound(name: 'Çamaşır Makinesi', icon: Icons.local_laundry_service, iconPath: 'assets/images/icon/camasir_makinesi.png', assetPath: 'assets/sounds/Camasir-mak.mp3', artworkPath: 'assets/images/artwork/Camasir_makinesi.jpg'),
  Sound(name: 'Trafik', icon: Icons.traffic, iconPath: 'assets/images/icon/trafik.png', assetPath: 'assets/sounds/trafik.mp3', artworkPath: 'assets/images/artwork/Trafik.jpg'),
];

class SoundsScreen extends StatefulWidget {
  final Function(Sound?, {bool isPreview}) onSoundChanged;
  final Sound? currentPlayingSound;
  final bool isPreviewMode;
  final VoidCallback? onGoToMixer;
  final VoidCallback? onShuffle;
  final VoidCallback? onSleepGuide;
  final String babyName;

  const SoundsScreen({
    super.key,
    required this.onSoundChanged,
    this.currentPlayingSound,
    this.isPreviewMode = false,
    this.onGoToMixer,
    this.onShuffle,
    this.onSleepGuide,
    this.babyName = '',
  });

  @override
  State<SoundsScreen> createState() => _SoundsScreenState();
}

class _SoundsScreenState extends State<SoundsScreen> with SingleTickerProviderStateMixin {
  final _loc = LocalizationService();
  bool _isEditing = false;
  late AnimationController _jiggleController;
  List<Sound> _frequentSounds = [];
  Map<String, int> _playCounts = {};

  @override
  void initState() {
    super.initState();
    // IndexedStack içinde sabit instance olarak tutulduğumuz için
    // dil değişikliğinde otomatik rebuild olmuyoruz — kendimiz listen ediyoruz.
    _loc.addListener(_onLanguageChanged);
    _jiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _loadPlayCounts();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _loc.removeListener(_onLanguageChanged);
    _jiggleController.dispose();
    super.dispose();
  }

  Future<void> _loadPlayCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('sound_play_counts');
    if (data != null) {
      _playCounts = Map<String, int>.from(jsonDecode(data));
    }
    _updateFrequentSounds();
  }

  Future<void> _savePlayCounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sound_play_counts', jsonEncode(_playCounts));
  }

  void _updateFrequentSounds() {
    // En çok çalınan 5 sesi bul
    final sorted = _playCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topNames = sorted.take(5).where((e) => e.value > 0).map((e) => e.key).toList();
    setState(() {
      _frequentSounds = topNames
          .map((name) => allSounds.firstWhere((s) => s.name == name, orElse: () => allSounds.first))
          .where((s) => topNames.contains(s.name))
          .toList();
    });
  }

  void _incrementPlayCount(Sound sound) {
    _playCounts[sound.name] = (_playCounts[sound.name] ?? 0) + 1;
    _savePlayCounts();
    _updateFrequentSounds();
  }

  void _togglePlay(Sound sound) async {
    // Premium ses — ön izleme modunda çal
    if (SubscriptionService().isSoundPremium(sound.name)) {
      if (widget.currentPlayingSound == sound && sound.isPlaying) {
        widget.onSoundChanged(null);
      } else {
        _incrementPlayCount(sound);
        widget.onSoundChanged(sound, isPreview: true);
      }
      return;
    }
    if (widget.currentPlayingSound == sound && sound.isPlaying) {
      widget.onSoundChanged(null);
    } else {
      _incrementPlayCount(sound);
      widget.onSoundChanged(sound);
    }
  }

  void _toggleFavorite(Sound sound) async {
    // Favoriden çıkarma her zaman serbest
    if (sound.isFavorite) {
      setState(() => sound.isFavorite = false);
      return;
    }

    // Giriş kontrolü — favori eklemek için giriş gerekli
    if (!AuthService().isLoggedIn) {
      _showLoginRequiredForFavorites();
      return;
    }

    // Favori ekleme — limit kontrolü
    final currentFavCount = allSounds.where((s) => s.isFavorite).length;
    if (SubscriptionService().isFavoriteLimitReached(currentFavCount)) {
      _showFavoriteLimitDialog();
      return;
    }

    setState(() => sound.isFavorite = true);
  }

  // ─── Login gerekli dialog (Favoriler) ───
  void _showLoginRequiredForFavorites() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.12),
                    Colors.white.withValues(alpha: 0.05),
                    AppColors.purple.withValues(alpha: 0.08),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.5),
                boxShadow: [
                  BoxShadow(color: AppColors.purple.withValues(alpha: 0.2), blurRadius: 40, spreadRadius: -8),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 10)),
                ],
              ),
              child: Stack(
                children: [
                  // Üst yansıma
                  Positioned(
                    top: 0, left: 0, right: 0, height: 60,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.0)],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Kalp ikonu
                        Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [AppColors.purple.withValues(alpha: 0.3), AppColors.purple.withValues(alpha: 0.05)],
                            ),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
                            boxShadow: [
                              BoxShadow(color: AppColors.purple.withValues(alpha: 0.4), blurRadius: 24, spreadRadius: -4),
                            ],
                          ),
                          child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 32),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _loc.t('LoginFavoriteMsg'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _loc.t('LoginFavoriteDesc'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14, height: 1.5),
                        ),
                        const SizedBox(height: 8),
                        // Sync vurgusu
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.sync_rounded, color: Colors.white.withValues(alpha: 0.4), size: 14),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _loc.t('SyncDevicesMsg'),
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Giriş Yap butonu
                        GestureDetector(
                          onTap: () async {
                            Navigator.pop(ctx);
                            await LoginScreen.show(context, feature: _loc.t('LoginFavoriteMsg'));
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                              ),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.5),
                              boxShadow: [
                                BoxShadow(color: AppColors.purple.withValues(alpha: 0.5), blurRadius: 16, spreadRadius: -4, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.login_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(_loc.t('BtnSignIn'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Daha Sonra butonu
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.white.withValues(alpha: 0.06),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.5),
                            ),
                            child: Text(
                              _loc.t('BtnLater'),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14, fontWeight: FontWeight.w500),
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
        ),
      ),
    );
  }

  void _showFavoriteLimitDialog() {
    PlusDialog.show(
      context,
      title: _loc.t('FavLimitTitle'),
      description: _loc.t('FavLimitDesc'),
      featureTitle: _loc.t('FeatUnlimitedFavorite'),
      secondaryIcon: Icons.favorite_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.babyName.isNotEmpty
                              ? '${_loc.t('GoodNight')}, ${widget.babyName}'
                              : '${_loc.t('GoodNight')},',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            const Text('Sleepora', style: TextStyle(color: AppColors.grey, fontSize: 11)),
                            if (!_isEditing && !SubscriptionService().isPremium) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen())),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFA370F7), Color(0xFF7C3AED)],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _loc.t('UpgradeToPlus'),
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_isEditing)
                    _HeaderButton(
                      label: _loc.t('BtnDone'),
                      icon: Icons.check,
                      isPrimary: true,
                      onTap: () {
                        setState(() {
                          _isEditing = false;
                          _jiggleController.stop();
                        });
                      },
                    )
                  else ...[
                    _HeaderButton(label: '', icon: Icons.tune, isPrimary: true, onTap: widget.onGoToMixer),
                    const SizedBox(width: 8),
                    _HeaderButton(label: '', icon: Icons.shuffle_rounded, isPrimary: false, onTap: widget.onShuffle),
                    const SizedBox(width: 8),
                    _HeaderButton(label: '', icon: Icons.nightlight_round, isPrimary: false, onTap: widget.onSleepGuide),
                  ],
                ],
              ),
            ),
            if (_frequentSounds.isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, color: Colors.white.withValues(alpha:0.3), size: 14),
                    const SizedBox(width: 4),
                    Text(_loc.t('RecentSounds'), style: TextStyle(color: Colors.white.withValues(alpha:0.3), fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: List.generate(_frequentSounds.length, (i) {
                      final freqSound = _frequentSounds[i];
                      final isPlaying = widget.currentPlayingSound == freqSound && freqSound.isPlaying;

                      return Padding(
                        padding: EdgeInsets.only(right: i < _frequentSounds.length - 1 ? 10 : 0),
                        child: GestureDetector(
                          onTap: _isEditing ? null : () => _togglePlay(freqSound),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isPlaying ? AppColors.purple : const Color(0xFF1A1A2E),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: isPlaying ? AppColors.purple : Colors.white.withValues(alpha:0.08),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: isPlaying ? Colors.white : AppColors.grey,
                                  size: 18
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  freqSound.localizedName,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: isPlaying ? FontWeight.w600 : FontWeight.normal
                                  )
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: AnimationLimiter(
                child: ReorderableGridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 160),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      final sound = allSounds.removeAt(oldIndex);
                      allSounds.insert(newIndex, sound);
                    });
                  },
                  itemCount: allSounds.length,
                  itemBuilder: (context, index) {
                    final sound = allSounds[index];

                    final card = SoundCard(
                      sound: sound,
                      isPremiumLocked: SubscriptionService().isSoundPremium(sound.name),
                      isPreviewPlaying: widget.isPreviewMode && widget.currentPlayingSound == sound && sound.isPlaying,
                      onTap: _isEditing ? () {} : () => _togglePlay(sound),
                      onFavorite: () => _toggleFavorite(sound),
                      onLongPress: _isEditing ? null : () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _isEditing = true;
                          _jiggleController.repeat(reverse: true);
                        });
                      },
                    );

                    return ListenableBuilder(
                      key: ValueKey(sound.name),
                      listenable: _jiggleController,
                      builder: (context, child) {
                        if (!_isEditing) {
                          return AnimationConfiguration.staggeredGrid(
                            position: index,
                            columnCount: 2,
                            duration: const Duration(milliseconds: 400),
                            child: ScaleAnimation(
                              child: FadeInAnimation(child: child!),
                            ),
                          );
                        }
                        final offset = math.sin(_jiggleController.value * math.pi * 2) * 0.008;
                        return Transform.rotate(angle: offset, child: child);
                      },
                      child: card,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback? onTap;

  const _HeaderButton({required this.label, required this.icon, required this.isPrimary, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isPrimary ? AppColors.purple : const Color(0xFF1A1A2E),
            shape: BoxShape.circle,
            border: isPrimary ? null : Border.all(color: Colors.white.withValues(alpha:0.1)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.purple : const Color(0xFF1A1A3E),
          borderRadius: BorderRadius.circular(20),
          border: isPrimary ? null : Border.all(color: Colors.white.withValues(alpha:0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}
