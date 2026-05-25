import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Minimal mor pill butonu — hareketli shimmer efektli.
/// Wrap-content genişliğinde çalışır (IntrinsicWidth gerekmez).
/// height < 45 ise kompakt mod (küçük ikon/yazı).
class UnlockButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final double height;
  final double fontSize;
  final double horizontalPadding;

  const UnlockButton({
    super.key,
    required this.label,
    this.onTap,
    this.height = 54,
    this.fontSize = 15,
    this.horizontalPadding = 24,
  });

  @override
  State<UnlockButton> createState() => _UnlockButtonState();
}

class _UnlockButtonState extends State<UnlockButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.height / 2;
    final compact = widget.height <= 42;
    final iconSize = compact ? 15.0 : 20.0;
    final iconGap = compact ? 6.0 : 10.0;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFA370F7), // açık mor
              Color(0xFF7C3AED), // koyu mor
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.purple.withValues(alpha: compact ? 0.35 : 0.50),
              blurRadius: compact ? 8 : 16,
              spreadRadius: -2,
              offset: Offset(0, compact ? 3 : 5),
            ),
          ],
        ),
        // ── ClipRRect — içerik + shimmer bir arada ──
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            alignment: Alignment.center, // içeriği dikey + yatay ortala
            children: [
              // ── İçerik: ikon + yazı (boyutu belirleyen katman) ──
              Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
                child: Row(
                  mainAxisSize: MainAxisSize.min, // wrap-content genişlik
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_open_rounded,
                        color: Colors.white, size: iconSize),
                    SizedBox(width: iconGap),
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: widget.fontSize,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Hareketli ışık geçişi (shimmer) — tam kapsayan ──
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _shimmerCtrl,
                  builder: (_, __) {
                    // İlk %35'te sweep geçiyor, kalan %65 bekliyor (doğal duraklama)
                    final sweepT = (_shimmerCtrl.value / 0.35).clamp(0.0, 1.0);
                    final pos = -0.6 + sweepT * 2.2; // -0.6 → 1.6 (her iki uç ekran dışı)
                    return IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(pos - 0.4, -1),
                            end: Alignment(pos + 0.4, 1),
                            colors: [
                              Colors.white.withValues(alpha: 0.0),
                              Colors.white.withValues(alpha: 0.22),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── Üst kenar ince parlak çizgi ──
              Positioned(
                top: 0,
                left: radius * 0.5,
                right: radius * 0.5,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.50),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
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
