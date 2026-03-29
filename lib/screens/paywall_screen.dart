import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/subscription_service.dart';
import '../services/localization_service.dart';

class PaywallScreen extends StatefulWidget {
  final String? featureTitle;
  const PaywallScreen({super.key, this.featureTitle});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();

  static Future<bool> showIfNeeded(BuildContext context, {String? feature}) async {
    final sub = SubscriptionService();
    if (sub.isPremium) return true;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PaywallScreen(featureTitle: feature)),
    );
    return result == true;
  }
}

class _PaywallScreenState extends State<PaywallScreen> with SingleTickerProviderStateMixin {
  final SubscriptionService _sub = SubscriptionService();
  final _loc = LocalizationService();
  int _selectedPlan = 0; // 0=yıllık, 1=aylık, 2=ömür boyu
  bool _isProcessing = false;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
    _sub.addListener(_onSubChange);
    // Ürünleri arka planda yükle — ekranı kilitlemeden
    if (_sub.products.isEmpty) {
      Future.microtask(() async {
        try {
          await _sub.loadProducts().timeout(const Duration(seconds: 8));
        } catch (_) {
          // Timeout veya hata — devam et
        }
        if (mounted) setState(() => _isProcessing = false);
      });
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _sub.removeListener(_onSubChange);
    super.dispose();
  }

  void _onSubChange() {
    if (!mounted) return;
    // Sadece satın alma sonucu gelince state güncelle — loadProducts sırasında donmasın
    setState(() {});
    if (_sub.isPremium && mounted) Navigator.pop(context, true);
  }

  void _purchase() async {
    String targetId;
    if (_selectedPlan == 0) {
      targetId = SubscriptionIds.yearly;
    } else if (_selectedPlan == 1) {
      targetId = SubscriptionIds.monthly;
    } else {
      targetId = SubscriptionIds.lifetime;
    }
    final product = _sub.getProduct(targetId);
    if (product == null) {
      // Ürün App Store'da bulunamadı — kullanıcıya bildir
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_loc.t('ProductNotFound')),
            backgroundColor: AppColors.card,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }
    setState(() => _isProcessing = true);
    try {
      await _sub.buySubscription(product).timeout(const Duration(seconds: 30));
    } catch (_) {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _restore() async {
    setState(() => _isProcessing = true);
    try {
      await _sub.restorePurchases().timeout(const Duration(seconds: 8));
      await Future.delayed(const Duration(seconds: 2));
    } catch (_) {
      // Timeout veya hata — devam et
    }
    if (mounted && !_sub.isPremium) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_loc.t('RestoreNoActive')),
          backgroundColor: AppColors.card,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  String _getTimelinePrice() {
    switch (_selectedPlan) {
      case 0:
        return _sub.getProduct(SubscriptionIds.yearly)?.price ?? '₺299,99';
      case 1:
        return _sub.getProduct(SubscriptionIds.monthly)?.price ?? '₺59,99';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFF080B16),
      body: Stack(
        children: [
          // ─── Arka plan yıldızlı gradient ───
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.4, 1.0],
                  colors: [Color(0xFF1A1040), Color(0xFF0D0820), Color(0xFF080B16)],
                ),
              ),
              child: CustomPaint(painter: _StarsPainter()),
            ),
          ),

          // ─── Ana içerik ───
          Padding(
            padding: EdgeInsets.fromLTRB(20, topPad, 20, 0),
            child: Column(
              children: [
                // ─── Üst bar ───
                SizedBox(
                  height: 44,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context, false),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha:0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white54, size: 18),
                        ),
                      ),
                      GestureDetector(
                        onTap: _isProcessing ? null : _restore,
                        child: Text(
                          _loc.t('RestorePurchases'),
                          style: TextStyle(color: Colors.white.withValues(alpha:0.5), fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── Telefon mockup + özellik alanı (üst kısım — ekranın ~38%'i) ───
                Expanded(
                  flex: 38,
                  child: _PhoneMockupSection(),
                ),

                // ─── Alt kısım: planlar + timeline + buton ───
                Expanded(
                  flex: 62,
                  child: Column(
                    children: [
                      const SizedBox(height: 8),

                      // ─── Plan seçimleri ───
                      _CompactPlan(
                        title: _loc.t('PlanYearly'),
                        price: _sub.getProduct(SubscriptionIds.yearly)?.price ?? '₺299,99',
                        period: '/${_loc.t('perYear')}',
                        badge: _loc.t('BadgePopular'),
                        isSelected: _selectedPlan == 0,
                        onTap: () => setState(() => _selectedPlan = 0),
                      ),
                      const SizedBox(height: 8),
                      _CompactPlan(
                        title: _loc.t('PlanMonthly'),
                        price: _sub.getProduct(SubscriptionIds.monthly)?.price ?? '₺59,99',
                        period: '/${_loc.t('perMonth')}',
                        isSelected: _selectedPlan == 1,
                        onTap: () => setState(() => _selectedPlan = 1),
                      ),
                      const SizedBox(height: 8),
                      _CompactPlan(
                        title: _loc.t('PlanLifetime'),
                        price: _sub.getProduct(SubscriptionIds.lifetime)?.price ?? '₺1299,99',
                        period: ' ${_loc.t('perSingle')}',
                        badge: _loc.t('BadgeBestValue'),
                        badgeColor: const Color(0xFF10B981),
                        isSelected: _selectedPlan == 2,
                        onTap: () => setState(() => _selectedPlan = 2),
                      ),

                      const SizedBox(height: 12),

                      // ─── Deneme timeline / Ömür boyu bilgi ───
                      if (_selectedPlan != 2)
                        _TrialTimeline(price: _getTimelinePrice()),

                      if (_selectedPlan == 2)
                        _LifetimeInfo(),

                      const Spacer(),

                      // ─── Devam Et butonu ───
                      GestureDetector(
                        onTap: _isProcessing ? null : _purchase,
                        child: ListenableBuilder(
                          listenable: _shimmerController,
                          builder: (context, child) {
                            return Container(
                              width: double.infinity,
                              height: 54,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(-2.0 + _shimmerController.value * 4, 0),
                                  end: Alignment(0.0 + _shimmerController.value * 4, 0),
                                  colors: _isProcessing
                                      ? [AppColors.purple.withValues(alpha:0.4), AppColors.purpleDark.withValues(alpha:0.4)]
                                      : const [Color(0xFF6D28D9), Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: _isProcessing
                                    ? null
                                    : [BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha:0.3), blurRadius: 16, offset: const Offset(0, 4))],
                              ),
                              child: Center(
                                child: _isProcessing
                                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                    : Text(
                                        _selectedPlan == 2 ? _loc.t('BtnBuyNow') : _loc.t('BtnTryFree'),
                                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                                      ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ─── Alt linkler ───
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final url = Uri.parse('https://enginerdemx-lab.github.io/bebek-uykusu-app/privacy-policy.html');
                              if (await canLaunchUrl(url)) await launchUrl(url);
                            },
                            child: Text(_loc.t('Terms'), style: TextStyle(color: Colors.white.withValues(alpha:0.3), fontSize: 11, fontWeight: FontWeight.w500)),
                          ),
                          Row(
                            children: [
                              Icon(Icons.lock_rounded, color: Colors.white.withValues(alpha:0.2), size: 12),
                              const SizedBox(width: 3),
                              Text(_loc.t('SecureApple'), style: TextStyle(color: Colors.white.withValues(alpha:0.3), fontSize: 11)),
                            ],
                          ),
                          GestureDetector(
                            onTap: () async {
                              final url = Uri.parse('https://enginerdemx-lab.github.io/bebek-uykusu-app/privacy-policy.html');
                              if (await canLaunchUrl(url)) await launchUrl(url);
                            },
                            child: Text(_loc.t('Privacy'), style: TextStyle(color: Colors.white.withValues(alpha:0.3), fontSize: 11, fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),

                      SizedBox(height: bottomPad + 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Telefon Mockup + Özellikler ───
class _PhoneMockupSection extends StatelessWidget {
  final _loc = LocalizationService();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Telefon çerçevesi
        Expanded(
          child: Center(
            child: Container(
              width: 200,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha:0.12), width: 2),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1A1040).withValues(alpha:0.8),
                    const Color(0xFF0D0820).withValues(alpha:0.6),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha:0.08),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha:0.05),
                    blurRadius: 20,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                      // App icon
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha:0.3), blurRadius: 12),
                          ],
                        ),
                        child: const Icon(Icons.nightlight_round, color: Colors.white, size: 26),
                      ),
                      // Features inside phone
                      _MockupFeatureRow(icon: Icons.music_note_rounded, label: _loc.t('FeatAllSounds'), color: const Color(0xFF8B5CF6)),
                      _MockupFeatureRow(icon: Icons.games_rounded, label: _loc.t('FeatAllGames'), color: const Color(0xFF6D28D9)),
                      _MockupFeatureRow(icon: Icons.timer_rounded, label: _loc.t('FeatUnlimitedTimer'), color: const Color(0xFF10B981)),
                      _MockupFeatureRow(icon: Icons.mic_rounded, label: _loc.t('FeatVoiceRecord'), color: const Color(0xFFEF4444)),
                      _MockupFeatureRow(icon: Icons.queue_music_rounded, label: _loc.t('FeatMixer'), color: const Color(0xFFF59E0B)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 4),

        // Başlık
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFA500), Color(0xFFFFD700)],
          ).createShader(bounds),
          child: const Text(
            'Sleepora Plus',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 0.5),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _loc.t('PeacefulSleep'),
          style: TextStyle(color: Colors.white.withValues(alpha:0.5), fontSize: 13),
        ),
      ],
    );
  }
}

// ─── Mockup feature row (telefon içi) ───
class _MockupFeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MockupFeatureRow({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 15),
        ),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
        const Spacer(),
        Icon(Icons.check_circle_rounded, color: color.withValues(alpha:0.7), size: 16),
      ],
    );
  }
}

// ─── Trial Timeline ───
class _TrialTimeline extends StatelessWidget {
  final String price;
  final _loc = LocalizationService();
  _TrialTimeline({required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha:0.06)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.purple, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Text(_loc.t('TrialStarting'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const Spacer(),
              Text(_loc.t('TrialDuration'), style: TextStyle(color: AppColors.green, fontSize: 12, fontWeight: FontWeight.w600)),
              Text(' ₺0', style: TextStyle(color: Colors.white.withValues(alpha:0.4), fontSize: 12)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 3),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(width: 1.5, height: 16, color: Colors.white.withValues(alpha:0.1)),
            ),
          ),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha:0.3), width: 1.5),
                ),
              ),
              const SizedBox(width: 10),
              Text(_loc.t('TrialAfter'), style: TextStyle(color: Colors.white.withValues(alpha:0.4), fontSize: 12)),
              const Spacer(),
              Text(price, style: TextStyle(color: Colors.white.withValues(alpha:0.4), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
             _loc.t('TrialCancelAnytime'),
            style: TextStyle(color: Colors.white.withValues(alpha:0.2), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ─── Lifetime Info ───
class _LifetimeInfo extends StatelessWidget {
  final _loc = LocalizationService();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2818).withValues(alpha:0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha:0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _loc.t('LifetimeInfo'),
              style: TextStyle(color: const Color(0xFF10B981).withValues(alpha:0.8), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Compact Plan Option ───
class _CompactPlan extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final String? badge;
  final Color? badgeColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _CompactPlan({
    required this.title,
    required this.price,
    required this.period,
    this.badge,
    this.badgeColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bColor = badgeColor ?? AppColors.purple;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A1040) : const Color(0xFF111827),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.purple : Colors.white.withValues(alpha:0.06),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.purple : Colors.white.withValues(alpha:0.25),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(child: Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.purple)))
                  : null,
            ),
            const SizedBox(width: 12),
            // Title + badge
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: bColor.withValues(alpha:0.15),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: bColor.withValues(alpha:0.3)),
                      ),
                      child: Text(badge!, style: TextStyle(color: bColor, fontSize: 9, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ),
            // Price
            Text(price, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            Text(period, style: TextStyle(color: Colors.white.withValues(alpha:0.4), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ─── Yıldızlar arka plan ───
class _StarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final stars = [
      [0.1, 0.05, 1.2], [0.25, 0.03, 0.8], [0.4, 0.08, 1.0],
      [0.55, 0.02, 0.6], [0.7, 0.07, 1.4], [0.85, 0.04, 0.9],
      [0.15, 0.12, 0.7], [0.3, 0.1, 1.1], [0.5, 0.13, 0.5],
      [0.65, 0.09, 1.3], [0.8, 0.14, 0.8], [0.9, 0.11, 1.0],
      [0.05, 0.18, 0.6], [0.2, 0.16, 0.9], [0.45, 0.19, 0.7],
      [0.6, 0.15, 1.1], [0.75, 0.2, 0.5], [0.95, 0.17, 0.8],
      [0.12, 0.25, 0.9], [0.35, 0.22, 0.7], [0.58, 0.28, 1.0],
      [0.78, 0.24, 0.6], [0.92, 0.27, 0.8],
    ];
    for (final s in stars) {
      paint.color = Colors.white.withValues(alpha:0.15 + s[2] * 0.15);
      canvas.drawCircle(Offset(s[0] * size.width, s[1] * size.height), s[2], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
