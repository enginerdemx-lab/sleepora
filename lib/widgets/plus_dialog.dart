import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/localization_service.dart';
import '../screens/paywall_screen.dart';
import 'unlock_button.dart';

/// Animasyonlu kilit açma ikonlu Plus upgrade dialog.
/// Tüm Plus/premium prompt'ları bu widget'ı kullanır — tutarlı tasarım.
class PlusDialog extends StatefulWidget {
  final String title;
  final String description;
  final String? featureTitle; // Paywall'a iletilir
  final IconData? secondaryIcon; // Kilit ikonunun altında küçük context ikonu
  final VoidCallback? onDismiss;

  const PlusDialog({
    super.key,
    required this.title,
    required this.description,
    this.featureTitle,
    this.secondaryIcon,
    this.onDismiss,
  });

  /// Kolay gösterim helper'ı
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String description,
    String? featureTitle,
    IconData? secondaryIcon,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => PlusDialog(
        title: title,
        description: description,
        featureTitle: featureTitle,
        secondaryIcon: secondaryIcon,
      ),
    );
  }

  @override
  State<PlusDialog> createState() => _PlusDialogState();
}

class _PlusDialogState extends State<PlusDialog> with TickerProviderStateMixin {
  late final AnimationController _lockController;
  late final AnimationController _shimmerController;
  late final AnimationController _scaleController;

  // Kilit açılma animasyonu
  late final Animation<double> _shackleAnim; // Shackle (üst kısım) yukarı kayma
  late final Animation<double> _lockBodyAnim; // Gövde hafif aşağı kayma
  late final Animation<double> _shimmerAnim; // Parıltı sweep
  late final Animation<double> _scaleAnim; // Genel pop-in

  @override
  void initState() {
    super.initState();

    // Pop-in animasyonu
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnim = CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut);

    // Elmas pulse animasyonu — nazikçe büyüyüp küçülür
    _lockController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _shackleAnim = Tween<double>(begin: 0.92, end: 1.06).animate(
      CurvedAnimation(parent: _lockController, curve: Curves.easeInOut),
    );
    _lockBodyAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _lockController, curve: Curves.easeInOut),
    );

    // Dönen kıvılcımlar için rotasyon animasyonu
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    _shimmerAnim = Tween<double>(begin: 0, end: 1).animate(_shimmerController);

    // Pop-in bittikten sonra pulse + dönen kıvılcımları başlat
    _scaleController.forward().then((_) {
      if (mounted) {
        _lockController.repeat(reverse: true);
        _shimmerController.repeat();
      }
    });
  }

  @override
  void dispose() {
    _lockController.dispose();
    _shimmerController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = LocalizationService();

    return ScaleTransition(
      scale: _scaleAnim,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 36),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.12),
                    Colors.white.withValues(alpha: 0.04),
                    AppColors.purple.withValues(alpha: 0.06),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.5),
                boxShadow: [
                  BoxShadow(color: AppColors.purple.withValues(alpha: 0.15), blurRadius: 40, spreadRadius: -8),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 10)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Animasyonlu kilit ikonu ──
                    _buildAnimatedLock(),
                    const SizedBox(height: 20),

                    // ── Başlık ──
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Açıklama ──
                    Text(
                      widget.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Plus'a Geç butonu ──
                    SizedBox(
                      width: double.infinity,
                      child: UnlockButton(
                        label: loc.t('BtnGoPremium'),
                        height: 54,
                        onTap: () {
                          Navigator.pop(context);
                          PaywallScreen.showIfNeeded(context, feature: widget.featureTitle);
                        },
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Kapat ──
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        widget.onDismiss?.call();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          loc.t('BtnCancel'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Animasyonlu premium elmas ikonu — nazik pulse + dönen kıvılcımlar
  Widget _buildAnimatedLock() {
    return ListenableBuilder(
      listenable: Listenable.merge([_lockController, _shimmerController]),
      builder: (context, _) {
        final pulse = _shackleAnim.value;           // 0.92..1.06
        final glowOpacity = _lockBodyAnim.value;    // 0.5..1.0
        final rotAngle = _shimmerAnim.value * 2 * math.pi; // 0..2π

        return SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Dışarıdan yayılan glow (pulse ile soluyor)
              Opacity(
                opacity: (glowOpacity * 0.45).clamp(0.0, 1.0),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.purple.withValues(alpha: 0.6),
                        AppColors.purple.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),

              // Elmas dairesi — pulse ile büyüyüp küçülür
              Transform.scale(
                scale: pulse,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF9B6FF7), Color(0xFF5B21B6)],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.purple.withValues(alpha: 0.45 * glowOpacity),
                        blurRadius: 18,
                        spreadRadius: -3,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.diamond_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),

              // 3 dönen kıvılcım
              ...List.generate(3, (i) {
                final angle = rotAngle + (i * 2 * math.pi / 3);
                const radius = 30.0;
                final sparkOpacity = ((math.sin(rotAngle * 1.5 + i * 2.1) + 1) / 2 * 0.85).clamp(0.0, 1.0);
                return Positioned(
                  left: 36 + math.cos(angle) * radius - 5,
                  top: 36 + math.sin(angle) * radius - 5,
                  child: Opacity(
                    opacity: sparkOpacity,
                    child: Icon(
                      i == 1 ? Icons.auto_awesome : Icons.star_rounded,
                      color: const Color(0xFFFFD700),
                      size: i == 1 ? 10 : 7,
                    ),
                  ),
                );
              }),

              // Context ikonu (küçük, sağ alt)
              if (widget.secondaryIcon != null)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.purple,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Icon(widget.secondaryIcon, color: Colors.white, size: 11),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

