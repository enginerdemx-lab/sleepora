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
import 'paywall_screen.dart';
import '../services/localization_service.dart';

class Sound {
  final String name; // Dahili anahtar — değişmez (premium, favori, playCount için)
  final IconData icon;
  final String assetPath;
  bool isFavorite;
  bool isPlaying;
  double volume;

  Sound({
    required this.name,
    required this.icon,
    required this.assetPath,
    this.isFavorite = false,
    this.isPlaying = false,
    this.volume = 0.5,
  });

  /// Dil ayarına göre çevrilmiş ses adı
  String get localizedName => LocalizationService().t('Sound_$name');
}

final List<Sound> allSounds = [
  Sound(name: 'Pış Pış', icon: Icons.nightlight_round, assetPath: 'assets/sounds/Pis Pis Sesi.mp3'),
  Sound(name: 'Eee Eee', icon: Icons.child_care, assetPath: 'assets/sounds/Eee Eee.mp3'),
  Sound(name: 'Dandini', icon: Icons.nightlight_round, assetPath: 'assets/sounds/Dandini-Dandini-Dastana.mp3'),
  Sound(name: 'Süpürge', icon: Icons.bolt, assetPath: 'assets/sounds/süpürge-sesi.mp3'),
  Sound(name: 'Kolik', icon: Icons.child_care, assetPath: 'assets/sounds/Kolik.mp3'),           // premium
  Sound(name: 'Kabin Sesi', icon: Icons.airplanemode_active, assetPath: 'assets/sounds/kabin-sesi.mp3'),
  Sound(name: 'Uyusunda Büyüsün', icon: Icons.auto_awesome, assetPath: 'assets/sounds/uyusunda-büyüsün-nini.mp3'),
  Sound(name: 'Yıldız Tozu', icon: Icons.star, assetPath: 'assets/sounds/Yildiz-Tozu-Ninnisi.mp3'), // premium
  Sound(name: 'Pış Pış + Süpürge', icon: Icons.bolt, assetPath: 'assets/sounds/Pis-pis-ve-süpürge.mp3'),
  Sound(name: 'Beyaz Gürültü', icon: Icons.layers, assetPath: 'assets/sounds/beyaz-gürültü.mp3'),
  Sound(name: 'Konuşma', icon: Icons.record_voice_over, assetPath: 'assets/sounds/Konusma.mp3'), // premium
  Sound(name: 'Yol Sesi', icon: Icons.directions_car, assetPath: 'assets/sounds/yol-sesi.mp3'),
  Sound(name: 'Yağmur', icon: Icons.umbrella, assetPath: 'assets/sounds/yagmur.mp3'),
  Sound(name: 'Saç Kurutma', icon: Icons.air, assetPath: 'assets/sounds/sac-kurutma.mp3'),
  Sound(name: 'Pış Pış 2', icon: Icons.nightlight_round, assetPath: 'assets/sounds/Piş_piş2.mp3'), // premium
  Sound(name: 'Rüzgar', icon: Icons.air, assetPath: 'assets/sounds/Rüzgar.mp3'),
  Sound(name: 'Dalga', icon: Icons.water, assetPath: 'assets/sounds/Dalga.mp3'),
  Sound(name: 'Duş', icon: Icons.shower, assetPath: 'assets/sounds/Dus.mp3'),
  Sound(name: 'Helikopter', icon: Icons.flight, assetPath: 'assets/sounds/Helikopter.mp3'),
  Sound(name: 'Tren', icon: Icons.train, assetPath: 'assets/sounds/Tren.mp3'),
  Sound(name: 'Vantilatör', icon: Icons.toys_rounded, assetPath: 'assets/sounds/Vantilatör.mp3'),
  Sound(name: 'Kalp Atışı', icon: Icons.favorite, assetPath: 'assets/sounds/kalp-atisi.mp3'),
  Sound(name: 'Kuş Sesi', icon: Icons.park, assetPath: 'assets/sounds/kus-sesi.mp3'),
  Sound(name: 'Su Sesi', icon: Icons.water_drop, assetPath: 'assets/sounds/su.mp3'),
  Sound(name: 'Çamaşır Makinesi', icon: Icons.local_laundry_service, assetPath: 'assets/sounds/Camasir-mak.mp3'),
  Sound(name: 'Trafik', icon: Icons.traffic, assetPath: 'assets/sounds/trafik.mp3'),
];

class SoundsScreen extends StatefulWidget {
  final Function(Sound?) onSoundChanged;
  final Sound? currentPlayingSound;
  final VoidCallback? onGoToMixer;
  final VoidCallback? onShuffle;
  final VoidCallback? onSleepGuide;
  final String babyName;

  const SoundsScreen({
    super.key,
    required this.onSoundChanged,
    this.currentPlayingSound,
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
    _jiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _loadPlayCounts();
  }

  @override
  void dispose() {
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
    // Premium ses kontrolü
    if (SubscriptionService().isSoundPremium(sound.name)) {
      await PaywallScreen.showIfNeeded(context, feature: sound.name);
      return;
    }
    if (widget.currentPlayingSound == sound && sound.isPlaying) {
      widget.onSoundChanged(null);
    } else {
      _incrementPlayCount(sound);
      widget.onSoundChanged(sound);
    }
  }

  void _toggleFavorite(Sound sound) {
    // Favoriden çıkarma her zaman serbest
    if (sound.isFavorite) {
      setState(() => sound.isFavorite = false);
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

  void _showFavoriteLimitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1A1025),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha:0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite_rounded, color: Color(0xFF8B5CF6), size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                _loc.t('FavLimitTitle'),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                _loc.t('FavLimitDesc'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha:0.6), fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  PaywallScreen.showIfNeeded(context, feature: _loc.t('FeatUnlimitedFavorite'));
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.purple, AppColors.purpleDark]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _loc.t('BtnUpgrade'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Text(
                  _loc.t('BtnCancel'),
                  style: TextStyle(color: Colors.white.withValues(alpha:0.4), fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
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
                        const Text('Sleepora', style: TextStyle(color: AppColors.grey, fontSize: 11)),
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
