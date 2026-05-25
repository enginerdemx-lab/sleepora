import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/localization_service.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

/// Login ekranı — Paywall ile aynı koyu tema ve yıldızlı arka plan.
class LoginScreen extends StatefulWidget {
  final String? featureTitle;
  const LoginScreen({super.key, this.featureTitle});

  @override
  State<LoginScreen> createState() => _LoginScreenState();

  /// Navigator ile ekranı açar ve giriş başarılıysa true döndürür.
  static Future<bool> show(BuildContext context, {String? feature}) async {
    final result = await Navigator.push<bool>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => LoginScreen(featureTitle: feature),
        transitionsBuilder: (_, anim, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
    return result == true;
  }
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _loc = LocalizationService();
  late AnimationController _moonPulse;
  late AnimationController _starsController;
  late AnimationController _fadeIn;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;
  bool _isLoading = false;
  String? _loadingProvider;

  final List<_Star> _stars = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    for (int i = 0; i < 60; i++) {
      _stars.add(_Star(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 2.5 + 0.3,
        opacity: _random.nextDouble() * 0.6 + 0.2,
        phase: _random.nextDouble() * 2 * pi,
        speed: _random.nextDouble() * 0.4 + 0.3,
      ));
    }

    _moonPulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true);
    _starsController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _fadeIn = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

    _contentFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _fadeIn, curve: Curves.easeOut));
    _contentSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(CurvedAnimation(parent: _fadeIn, curve: Curves.easeOutCubic));

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _fadeIn.forward();
    });
  }

  @override
  void dispose() {
    _moonPulse.dispose();
    _starsController.dispose();
    _fadeIn.dispose();
    super.dispose();
  }

  /// Giriş başarılıysa pop ya da (root ise) HomeScreen'e yönlendir.
  void _afterSignInSuccess() {
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.pop(context, true);
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _signInWithApple() async {
    setState(() { _isLoading = true; _loadingProvider = 'apple'; });
    try {
      final success = await AuthService().signInWithApple();
      if (mounted) {
        if (success) {
          _afterSignInSuccess();
        } else {
          setState(() { _isLoading = false; _loadingProvider = null; });
          final error = AuthService().error;
          if (error != null) _showError(error);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; _loadingProvider = null; });
        _showError(e.toString());
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _isLoading = true; _loadingProvider = 'google'; });
    try {
      final success = await AuthService().signInWithGoogle();
      if (mounted) {
        if (success) {
          _afterSignInSuccess();
        } else {
          setState(() { _isLoading = false; _loadingProvider = null; });
          final error = AuthService().error;
          if (error != null) _showError(error);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; _loadingProvider = null; });
        _showError(e.toString());
      }
    }
  }

  void _continueAsGuest() {
    // Eğer pop yapacak bir route varsa pop ile dön (normal akış).
    // Yoksa (örn. hesap silindikten sonra LoginScreen root olarak açılırsa),
    // siyah ekrana düşmesin diye HomeScreen'i root yap.
    if (Navigator.of(context).canPop()) {
      Navigator.pop(context, false);
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1E1050),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF080B16),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.35, 1.0],
                  colors: [Color(0xFF1E1050), Color(0xFF0D0820), Color(0xFF080B16)],
                ),
              ),
              child: ListenableBuilder(
                listenable: _starsController,
                builder: (context, _) => CustomPaint(
                  painter: _TwinklingStarsPainter(_stars, _starsController.value),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPad > 0 ? 0 : 16),
              child: Column(
                children: [
                  SizedBox(
                    height: 52,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: _isLoading ? null : _continueAsGuest,
                          child: Container(
                            width: 36, height: 36,
                            decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
                            child: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 42,
                    child: SlideTransition(
                      position: _contentSlide,
                      child: FadeTransition(
                        opacity: _contentFade,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildAppLogo(),
                            const SizedBox(height: 28),
                            const Text('Sleepora', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                            const SizedBox(height: 8),
                            Text(
                              widget.featureTitle != null ? _loc.t('LoginRequired') : _loc.t('LoginWelcome'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white54, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 58,
                    child: SlideTransition(
                      position: _contentSlide,
                      child: FadeTransition(
                        opacity: _contentFade,
                        child: Column(
                          children: [
                            const SizedBox(height: 28),
                            _buildAppleButton(),
                            const SizedBox(height: 12),
                            _buildGoogleButton(),
                            const SizedBox(height: 24),
                            _buildDivider(),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: _isLoading ? null : _continueAsGuest,
                              child: Text(_loc.t('LoginGuest'), style: const TextStyle(color: Color(0xFFB8A9E8), fontSize: 14, fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () async {
                                final url = Uri.parse(
                                    'https://sleepora.app/privacy-policy.html');
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url,
                                      mode: LaunchMode.externalApplication);
                                }
                              },
                              child: Text(_loc.t('LoginPrivacy'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white24, fontSize: 11)),
                            ),
                            SizedBox(height: bottomPad > 0 ? bottomPad : 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppLogo() {
    return ListenableBuilder(
      listenable: _moonPulse,
      builder: (context, _) {
        final pulse = 0.92 + _moonPulse.value * 0.08;
        final glow = 0.15 + _moonPulse.value * 0.2;
        return Transform.scale(
          scale: pulse,
          child: Container(
            width: 110, height: 110,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: glow), blurRadius: 50, spreadRadius: 15),
                BoxShadow(color: const Color(0xFFB8A9E8).withValues(alpha: glow * 0.5), blurRadius: 25, spreadRadius: 5),
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
                    gradient: const RadialGradient(
                      center: Alignment(-0.15, -0.15),
                      radius: 0.7,
                      colors: [Color(0xFFB8A9E8), Color(0xFF8B6FC0), Color(0xFF5B3A8A)],
                    ),
                  ),
                  child: const Center(child: Icon(Icons.nightlight_round, color: Colors.white, size: 42)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppleButton() {
    final loading = _isLoading && _loadingProvider == 'apple';
    return GestureDetector(
      onTap: _isLoading ? null : _signInWithApple,
      child: Container(
        width: double.infinity, height: 56,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: loading
          ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)))
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Image.asset('assets/images/apple_login.png', width: 24, height: 24),
              const SizedBox(width: 10),
              Text(_loc.t('LoginApple'), style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600)),
            ]),
      ),
    );
  }

  Widget _buildGoogleButton() {
    final loading = _isLoading && _loadingProvider == 'google';
    return GestureDetector(
      onTap: _isLoading ? null : _signInWithGoogle,
      child: Container(
        width: double.infinity, height: 56,
        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
        child: loading
          ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Image.asset('assets/images/google_login.png', width: 24, height: 24),
              const SizedBox(width: 10),
              Text(_loc.t('LoginGoogle'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ]),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(children: [
      Expanded(child: Container(height: 1, decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Colors.white.withValues(alpha: 0.12)])))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(_loc.t('LoginOr'), style: const TextStyle(color: Colors.white30, fontSize: 13))),
      Expanded(child: Container(height: 1, decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0.12), Colors.transparent])))),
    ]);
  }
}

class _Star {
  final double x, y, size, opacity, phase, speed;
  _Star({required this.x, required this.y, required this.size, required this.opacity, required this.phase, required this.speed});
}

class _TwinklingStarsPainter extends CustomPainter {
  final List<_Star> stars;
  final double animValue;
  _TwinklingStarsPainter(this.stars, this.animValue);

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in stars) {
      final twinkle = (sin((animValue * 2 * pi * star.speed) + star.phase) + 1) / 2;
      final opacity = star.opacity * (0.15 + 0.85 * twinkle);
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.size * (0.6 + 0.4 * twinkle),
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_TwinklingStarsPainter old) => true;
}

class _GoogleLogoPainter extends CustomPainter {
  static const double _d2r = 3.14159265358979 / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final double sw = s * 0.2;
    final Rect oval = Rect.fromLTWH(sw / 2, sw / 2, s - sw, s - sw);

    void drawArc(double startDeg, double sweepDeg, Color color) {
      canvas.drawArc(oval, startDeg * _d2r, sweepDeg * _d2r, false,
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = sw..strokeCap = StrokeCap.butt);
    }

    // Google "G": gap at right-center, colors by quadrant
    drawArc(5, 85, const Color(0xFF4285F4));    // Blue  — right side ↓
    drawArc(90, 90, const Color(0xFF34A853));    // Green — bottom
    drawArc(180, 90, const Color(0xFFFBBC05));   // Yellow — left side
    drawArc(270, 85, const Color(0xFFEA4335));   // Red   — top

    // Horizontal blue bar (center → right)
    canvas.drawRect(
      Rect.fromLTWH(s / 2, s / 2 - sw / 2, s / 2 - sw / 2, sw),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}