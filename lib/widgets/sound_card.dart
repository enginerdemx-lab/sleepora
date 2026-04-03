import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../screens/sounds_screen.dart';
import '../services/localization_service.dart';

class SoundCard extends StatefulWidget {
  final Sound sound;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback? onLongPress;
  final bool isPremiumLocked;
  final bool isPreviewPlaying;

  const SoundCard({
    super.key,
    required this.sound,
    required this.onTap,
    required this.onFavorite,
    this.onLongPress,
    this.isPremiumLocked = false,
    this.isPreviewPlaying = false,
  });

  @override
  State<SoundCard> createState() => _SoundCardState();
}

class _SoundCardState extends State<SoundCard> with TickerProviderStateMixin {
  late AnimationController _ring1Controller;
  late AnimationController _ring2Controller;
  late AnimationController _tapController;
  late AnimationController _ringFadeController;
  late Animation<double> _tapScale;
  late Animation<double> _ring1Anim;
  late Animation<double> _ring2Anim;

  bool _wasPlaying = false; // Önceki çalma durumu takibi

  @override
  void initState() {
    super.initState();

    // Daha uzun süre + easeInOut → pürüzsüz döngü
    _ring1Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    _ring2Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // Smooth easeInOut eğrisiyle animasyon değerleri
    _ring1Anim = CurvedAnimation(
      parent: _ring1Controller,
      curve: Curves.easeInOut,
    );
    _ring2Anim = CurvedAnimation(
      parent: _ring2Controller,
      curve: Curves.easeInOut,
    );

    _ringFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );

    _tapScale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeInOut),
    );

    // Eğer zaten çalıyorsa halkalar hemen gösterilsin
    _wasPlaying = widget.sound.isPlaying;
    if (_wasPlaying) {
      _ringFadeController.value = 1.0;
      _ring1Controller.repeat(reverse: true);
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _ring2Controller.repeat(reverse: true);
      });
    }
  }

  @override
  void didUpdateWidget(covariant SoundCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final nowPlaying = widget.sound.isPlaying;

    if (nowPlaying && !_wasPlaying) {
      // Çalmaya başladı — halkaları yavaşça aç
      _ringFadeController.forward();
      _ring1Controller.repeat(reverse: true);
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _ring2Controller.repeat(reverse: true);
      });
    } else if (!nowPlaying && _wasPlaying) {
      // Durdu — halkaları yavaşça kapat
      _ringFadeController.reverse().then((_) {
        if (mounted) {
          _ring1Controller.reset();
          _ring2Controller.reset();
        }
      });
    }

    _wasPlaying = nowPlaying;
  }

  @override
  void dispose() {
    _ring1Controller.dispose();
    _ring2Controller.dispose();
    _ringFadeController.dispose();
    _tapController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _tapController.forward().then((_) => _tapController.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = widget.sound.isPlaying;

    return GestureDetector(
      onTap: _handleTap,
      onLongPress: widget.onLongPress,
      child: ListenableBuilder(
        listenable: Listenable.merge([_ring1Controller, _ring2Controller, _tapController, _ringFadeController]),
        builder: (context, _) {
          final r1 = _ring1Anim.value;
          final r2 = _ring2Anim.value;
          final ringFade = _ringFadeController.value;
          return Transform.scale(
            scale: _tapScale.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isPlaying
                      ? [const Color(0xFF5B21B6), const Color(0xFF7C3AED)]
                      : [const Color(0xFF1A1025), const Color(0xFF2D1B4E)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isPlaying
                      ? AppColors.purple.withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.06),
                  width: isPlaying ? 1.5 : 1,
                ),
                boxShadow: isPlaying
                    ? [BoxShadow(
                        color: AppColors.purple.withValues(alpha: 0.35),
                        blurRadius: 18,
                        spreadRadius: 1,
                      )]
                    : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    // Premium badge: Ön izleme veya elmas
                    if (widget.isPreviewPlaying)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B6B), Color(0xFFEE5A24)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFFFF6B6B).withValues(alpha: 0.4), blurRadius: 8, spreadRadius: -2),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.play_circle_outline, color: Colors.white, size: 12),
                              const SizedBox(width: 3),
                              Text(LocalizationService().t('PreviewBadge'), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                            ],
                          ),
                        ),
                      )
                    else if (widget.isPremiumLocked)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.diamond_outlined, color: Colors.white, size: 14),
                        ),
                      ),

                    // Favori butonu
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: widget.onFavorite,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            widget.sound.isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            key: ValueKey(widget.sound.isFavorite),
                            color: widget.sound.isFavorite
                                ? AppColors.red
                                : Colors.white.withValues(alpha: 0.3),
                            size: 20,
                          ),
                        ),
                      ),
                    ),

                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 130,
                            height: 130,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Dış halka — daha soft, az hareket
                                if (ringFade > 0)
                                  Opacity(
                                    opacity: ringFade * 0.85,
                                    child: Transform.scale(
                                      scale: 0.6 + ringFade * 0.4,
                                      child: Container(
                                        width: 106 + r2 * 10,
                                        height: 106 + r2 * 10,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withValues(alpha: (0.03 + r2 * 0.02).clamp(0.0, 1.0)),
                                        ),
                                      ),
                                    ),
                                  ),
                                // İç halka — daha soft
                                if (ringFade > 0)
                                  Opacity(
                                    opacity: ringFade * 0.9,
                                    child: Transform.scale(
                                      scale: 0.65 + ringFade * 0.35,
                                      child: Container(
                                        width: 80 + r1 * 10,
                                        height: 80 + r1 * 10,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withValues(alpha: (0.055 + r1 * 0.03).clamp(0.0, 1.0)),
                                        ),
                                      ),
                                    ),
                                  ),
                                // Ana daire
                                Container(
                                  width: 58,
                                  height: 58,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: isPlaying ? 0.2 : 0.08),
                                  ),
                                  child: Icon(
                                    widget.sound.icon,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.sound.localizedName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
