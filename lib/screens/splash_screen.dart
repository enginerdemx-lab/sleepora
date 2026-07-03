import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart' show appCriticalReady;
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _starsController;
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  final List<_Star> _stars = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    // Yıldızları oluştur — her birine farklı faz ver
    for (int i = 0; i < 50; i++) {
      _stars.add(_Star(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 3 + 0.5,
        opacity: _random.nextDouble() * 0.8 + 0.2,
        phase: _random.nextDouble() * 2 * pi, // Her yıldız farklı zamanda yanıp söner
        speed: _random.nextDouble() * 0.5 + 0.5, // Farklı hızlar
      ));
    }

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // Daha hızlı
    );
    _starsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );
    _logoScale = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoController.forward();

    _navigateWhenReady();
  }

  /// Ana ekrana geçiş — kör 2 sn beklemek yerine, kritik servisler (Firebase +
  /// Auth + Lokalizasyon) hazır olduğunda geçer. Böylece:
  ///  • Logo animasyonu için en az ~1.6 sn splash gösterilir.
  ///  • Servisler erken hazırsa gereksiz bekleme olmaz.
  ///  • Servisler yavaşsa en fazla 6 sn beklenir, sonra yine de geçilir
  ///    (ana ekran kendi yükleme durumlarını gösterir).
  Future<void> _navigateWhenReady() async {
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!appCriticalReady.isCompleted) {
      await appCriticalReady.future
          .timeout(const Duration(seconds: 6), onTimeout: () {});
    }
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(OnboardingScreen.doneKey) ?? false;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            done ? const HomeScreen() : const OnboardingScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _starsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Arka plan gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  Color(0xFF2D1B6E),
                  Color(0xFF1A0A3E),
                  Color(0xFF0D0520),
                ],
              ),
            ),
          ),

          // Yanıp sönen yıldızlar
          ListenableBuilder(
            listenable: _starsController,
            builder: (context, _) {
              return CustomPaint(
                painter: _StarsPainter(_stars, _starsController.value),
                size: Size.infinite,
              );
            },
          ),

          // Logo ve yazı
          Center(
            child: FadeTransition(
              opacity: _logoFade,
              child: ScaleTransition(
                scale: _logoScale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo container — resim varsa göster, yoksa ikon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.purple.withValues(alpha:0.5),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Image.asset(
                          'assets/images/logo.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)],
                              ),
                            ),
                            child: const Center(
                              child: Text('\u{1F319}', style: TextStyle(fontSize: 60)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Sleepora',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bebek Uyku Sesleri',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha:0.7),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Star {
  final double x, y, size, opacity, phase, speed;
  _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.phase,
    required this.speed,
  });
}

class _StarsPainter extends CustomPainter {
  final List<_Star> stars;
  final double animValue;
  _StarsPainter(this.stars, this.animValue);

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in stars) {
      // Her yıldız kendi fazında yanıp söner
      final twinkle = (sin((animValue * 2 * pi * star.speed) + star.phase) + 1) / 2;
      final currentOpacity = star.opacity * (0.2 + 0.8 * twinkle);

      // Yıldız şekli çiz (4 kollu)
      if (star.size > 2) {
        _drawStarShape(canvas, Offset(star.x * size.width, star.y * size.height), star.size, currentOpacity);
      } else {
        // Küçük yıldızlar sadece nokta
        final paint = Paint()
          ..color = Colors.white.withValues(alpha:currentOpacity)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(star.x * size.width, star.y * size.height),
          star.size * (0.7 + 0.3 * twinkle),
          paint,
        );
      }
    }
  }

  void _drawStarShape(Canvas canvas, Offset center, double radius, double opacity) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha:opacity)
      ..style = PaintingStyle.fill;

    // Yatay ve dikey kollar (haç şeklinde parlama)
    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha:opacity * 0.3)
      ..style = PaintingStyle.fill;

    // Merkez daire
    canvas.drawCircle(center, radius * 0.4, paint);

    // Parlama kolları
    final armLength = radius * 1.5;
    final armWidth = radius * 0.15;

    // Yatay kol
    canvas.drawRect(
      Rect.fromCenter(center: center, width: armLength * 2, height: armWidth),
      glowPaint,
    );
    // Dikey kol
    canvas.drawRect(
      Rect.fromCenter(center: center, width: armWidth, height: armLength * 2),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(_StarsPainter old) => true;
}
