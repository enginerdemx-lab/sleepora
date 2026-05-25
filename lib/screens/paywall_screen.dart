import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/subscription_service.dart';
import '../services/localization_service.dart';
import 'package:video_player/video_player.dart';

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

    // Apple Guideline 2.1(b) uyumu — buton her zaman görsel olarak tepki versin.
    // Önce loading state'e geç, sonra ürünü kontrol et.
    setState(() => _isProcessing = true);

    // Ürünler henüz yüklenmediyse anlık olarak yüklemeyi dene.
    var product = _sub.getProduct(targetId);
    if (product == null) {
      try {
        await _sub.loadProducts().timeout(const Duration(seconds: 6));
      } catch (_) {
        // Yükleme başarısız — devam et, aşağıdaki kontrol hatayı bildirecek.
      }
      product = _sub.getProduct(targetId);
    }

    if (product == null) {
      // Ürün hâlâ bulunamadı — kullanıcıya açık ve uzun süreli geri bildirim ver.
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_loc.t('ProductNotFound')),
            backgroundColor: AppColors.card,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(
              label: _loc.t('RestorePurchases'),
              textColor: const Color(0xFF8B5CF6),
              onPressed: _restore,
            ),
          ),
        );
      }
      return;
    }

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

  void _onCloseTapped() {
    // Apple Guideline 5.6 uyumu: kullanıcı paywall'ı kapatmak istediğinde
    // ikinci bir satın alma teklifi / abandon sheet göstermiyoruz.
    // Kullanıcının kararına saygı duyup paywall'ı doğrudan kapatıyoruz.
    Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFF080B16),
      body: Stack(
        children: [
          // ─── Arka plan resmi (Video Animasyon) ───
          const Positioned.fill(
            child: _VideoBackground(),
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
                        onTap: _onCloseTapped,
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

                // ─── Telefon mockup + özellik alanı ───
                // Üst kısım kalan TÜM dikey boşluğu doldurur. Alt kısım sabit/doğal
                // yüksekliğe sahip olduğundan, küçük/büyük ekran fark etmeksizin
                // buton ve linkler her zaman safe-area üstünde görünür.
                Expanded(
                  child: _PhoneMockupSection(),
                ),

                // ─── Alt kısım: planlar + timeline + buton ───
                // Doğal (content-sized) yükseklik kullanıyoruz; sabit flex oranı
                // yerine içerik kadar yer kaplıyor. Böylece iPhone 17 dahil farklı
                // ekran oranlarında alttaki buton kesilmiyor.
                const SizedBox(height: 8),

                // ─── Plan seçimleri (en ucuzdan en pahalıya sıralama) ───
                // Aylık (en ucuz) → Yıllık (popüler) → Ömür Boyu (en avantajlı)
                _CompactPlan(
                  title: _loc.t('PlanMonthly'),
                  price: _sub.getProduct(SubscriptionIds.monthly)?.price ?? '₺59,99',
                  period: '/${_loc.t('perMonth')}',
                  isSelected: _selectedPlan == 1,
                  onTap: () => setState(() => _selectedPlan = 1),
                ),
                const SizedBox(height: 8),
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
                  title: _loc.t('PlanLifetime'),
                  price: _sub.getProduct(SubscriptionIds.lifetime)?.price ?? '₺1299,99',
                  period: ' ${_loc.t('perSingle')}',
                  badge: _loc.t('BadgeBestValue'),
                  badgeColor: const Color(0xFF10B981),
                  isSelected: _selectedPlan == 2,
                  onTap: () => setState(() => _selectedPlan = 2),
                ),

                const SizedBox(height: 12),

                // ─── Deneme timeline / Ömür boyu bilgi (FIXED-HEIGHT SLOT) ───
                // Plan değişince mockup'ın zıplamaması için bu slot SABİT
                // yükseklikte. İçerik plan'a göre değişir ama dış konteynerin
                // boyu sabit (~96pt), böylece üstteki Expanded(mockup) hiç
                // yeniden boyutlandırılmıyor.
                SizedBox(
                  height: 96,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: child,
                    ),
                    child: _selectedPlan == 0
                        ? _TrialTimeline(
                            key: const ValueKey('yearly_trial'),
                            price: _getTimelinePrice(),
                          )
                        : _selectedPlan == 2
                            ? Padding(
                                key: const ValueKey('lifetime_info'),
                                padding: const EdgeInsets.only(top: 8),
                                child: _LifetimeInfo(),
                              )
                            : const SizedBox.shrink(key: ValueKey('monthly_empty')),
                  ),
                ),

                // ─── Otomatik yenileme açıklaması (FIXED-HEIGHT SLOT) ───
                // Aylık/Yıllık'ta disclosure metni, Lifetime'da boş — slot her
                // zaman aynı yüksekliği rezerve eder ki mockup zıplamasın.
                SizedBox(
                  height: 36,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _selectedPlan != 2
                        ? Padding(
                            key: const ValueKey('disclosure_text'),
                            padding: const EdgeInsets.only(top: 6, bottom: 6),
                            child: Text(
                              _loc.t('SubscriptionDisclosure'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 10,
                                height: 1.3,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('disclosure_empty')),
                  ),
                ),

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
                                  _selectedPlan == 0 ? _loc.t('BtnTryFree') : _loc.t('BtnBuyNow'),
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
                        // Apple Guideline 3.1.2: Kullanım Şartları (EULA) zorunlu link
                        final url = Uri.parse('https://www.apple.com/legal/internet-services/itunes/dev/stdeula/');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Text(_loc.t('Terms'), style: TextStyle(color: Colors.white.withValues(alpha:0.3), fontSize: 11, fontWeight: FontWeight.w500, decoration: TextDecoration.underline, decorationColor: Colors.white24)),
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
                        // Apple Guideline 3.1.2: Gizlilik Politikası zorunlu link
                        final url = Uri.parse('https://sleepora.app/privacy-policy.html');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Text(_loc.t('Privacy'), style: TextStyle(color: Colors.white.withValues(alpha:0.3), fontSize: 11, fontWeight: FontWeight.w500, decoration: TextDecoration.underline, decorationColor: Colors.white24)),
                    ),
                  ],
                ),

                // Home indicator / gesture bar boşluğu — her cihazda buton üstte kalır.
                // Min 12pt boşluk garantilenir (eski iPhone'larda bottomPad=0 olabiliyor).
                SizedBox(height: bottomPad > 0 ? bottomPad + 8 : 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Telefon Mockup + Özellikler (Carousel) ───
class _PhoneMockupSection extends StatefulWidget {
  @override
  State<_PhoneMockupSection> createState() => _PhoneMockupSectionState();
}

class _PhoneMockupSectionState extends State<_PhoneMockupSection>
    with TickerProviderStateMixin {
  final _loc = LocalizationService();
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoSlideTimer;
  static const int _slideCount = 3;

  late AnimationController _floatCtrl;
  late Animation<double> _floatAnim;
  late Animation<double> _floatAnimInverse;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );
    _floatAnimInverse = Tween<double>(begin: 8.0, end: -8.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    // Banner carousel: her 3 saniyede bir slide değiştir, sonsuz döngü.
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_currentPage + 1) % _slideCount;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _floatCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildPhoneImageSlide(String assetPath) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: 1.05, // Yazıların okunması için %5 büyütme yeterli
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }

  Widget _buildStar(double opacity, double size) {
    return Opacity(
      opacity: opacity,
      child: Image.asset(
        'assets/images/star.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }

  /// 1. slide: odeme1.png merkezde, etrafında hareketli ve parlayan 4 yıldız
  Widget _buildSlide1() {
    return AnimatedBuilder(
      animation: _floatCtrl,
      builder: (context, _) {
        final floatVal = _floatAnim.value; // -8 to +8
        final floatInv = _floatAnimInverse.value; // +8 to -8
        
        // Pulse between 0.5 and 1.0
        final pulse = 0.5 + 0.5 * (floatVal / 8.0).abs();
        final pulseInv = 0.5 + 0.5 * (floatInv / 8.0).abs();

        return Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            // Yıldız 1: Sol Üst
            Positioned(
              left: 30,
              top: 50,
              child: Transform.translate(
                offset: Offset(0, floatVal),
                child: _buildStar(pulse, 36),
              ),
            ),
            // Yıldız 2: Sol Alt
            Positioned(
              left: 45,
              bottom: 120,
              child: Transform.translate(
                offset: Offset(0, floatInv),
                child: _buildStar(pulseInv, 28),
              ),
            ),
            // Yıldız 3: Sağ Üst
            Positioned(
              right: 35,
              top: 80,
              child: Transform.translate(
                offset: Offset(0, floatInv),
                child: _buildStar(pulseInv, 32),
              ),
            ),
            // Yıldız 4: Sağ Alt
            Positioned(
              right: 25,
              bottom: 140,
              child: Transform.translate(
                offset: Offset(0, floatVal),
                child: _buildStar(pulse, 40),
              ),
            ),
            // Ana telefon mock-up
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: 1.05,
                child: Image.asset(
                  'assets/images/odeme1.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 2. slide: odeme2.png merkezde, odeme2a ve odeme2b yanlarında animasyonlu
  Widget _buildSlide2() {
    return AnimatedBuilder(
      animation: _floatCtrl,
      builder: (context, _) {
        return Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Ana telefon (ortada, %15 büyük)
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: 1.05,
                child: Image.asset(
                  'assets/images/odeme2.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            // Sol üst — odeme2a.png, yukarı-aşağı animasyonlu
            Positioned(
              left: 0,
              bottom: 30,
              child: Transform.translate(
                offset: Offset(0, _floatAnim.value),
                child: Opacity(
                  opacity: 0.92,
                  child: Image.asset(
                    'assets/images/odeme2a.png',
                    width: 110,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
            // Sağ alt — odeme2b.png, ters faz animasyonlu
            Positioned(
              right: 0,
              bottom: 20,
              child: Transform.translate(
                offset: Offset(0, _floatAnimInverse.value),
                child: Opacity(
                  opacity: 0.92,
                  child: Image.asset(
                    'assets/images/odeme2b.png',
                    width: 125, // %15 civarı daha büyütüldü
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Tek oyun ikonu — asıl artwork'ü gradyan rozet içinde gösterir.
  /// [floatY] dikey float, [tilt] hafif eğilme açısı (radyan), [scale] nabız.
  Widget _buildGameIcon({
    required String imagePath,
    required Color c1,
    required Color c2,
    required double floatY,
    required double tilt,
    required double scale,
  }) {
    return Transform.translate(
      offset: Offset(0, floatY),
      child: Transform.rotate(
        angle: tilt,
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c1, c2],
              ),
              boxShadow: [
                BoxShadow(
                  color: c2.withValues(alpha: 0.55),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
                // İç parlama hissi için ekstra hafif siyah gölge
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
              // İnce çerçeve — gradyan rozet kenarına ince beyaz halka
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 0.8,
              ),
            ),
            // Artwork'u gradyan rozetin içine yuvarlatılmış olarak yerleştir
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 3. slide: odeme3.png en altta, üzerinde oyunların kendi artwork'leri
  /// hafif sallanarak ve nabız atarak süzülüyor.
  Widget _buildSlide3() {
    return AnimatedBuilder(
      animation: _floatCtrl,
      builder: (context, _) {
        final floatVal = _floatAnim.value;       // -8 → +8
        final floatInv = _floatAnimInverse.value; // +8 → -8

        // Hafif eğilme — float'ı küçük bir açıya (max ~5°) eşler.
        final tiltA = (floatVal / 8.0) * 0.085;
        final tiltB = -(floatVal / 8.0) * 0.085;

        // Nabız — 0.95 ile 1.05 arasında ölçek değişimi.
        final pulseA = 1.0 + (floatVal / 8.0) * 0.05;
        final pulseB = 1.0 - (floatVal / 8.0) * 0.05;

        return Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            // ─── 1) Ana telefon — EN ALTTA, üstüne oyun ikonları biniyor ───
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: 1.05,
                child: Image.asset(
                  'assets/images/odeme3.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),

            // ─── 2) Oyun ikonları — TELEFONUN ÜSTÜNDE, hareketli ───
            // Diagonal stagger: aynı taraftaki iki ikon arası ~150px düşey
            // boşluk bırakıldı; iki taraftaki ikonlar farklı yüksekliklerde
            // → küçük ekranlarda bile çakışma olmuyor.
            //
            // Minesweeper — Sol Üst (en üstte)
            Positioned(
              left: 14,
              top: 24,
              child: _buildGameIcon(
                imagePath: 'assets/images/artwork/mayintarlasi.jpg',
                c1: const Color(0xFF0E7490),
                c2: const Color(0xFF06B6D4),
                floatY: floatVal,
                tilt: tiltA,
                scale: pulseA,
              ),
            ),
            // 2048 — Sağ Üst (Minesweeper'dan ~95px aşağıda)
            Positioned(
              right: 14,
              top: 120,
              child: _buildGameIcon(
                imagePath: 'assets/images/artwork/2048.jpg',
                c1: const Color(0xFF9D174D),
                c2: const Color(0xFFDB2777),
                floatY: floatInv,
                tilt: tiltB,
                scale: pulseB,
              ),
            ),
            // Block Puzzle — Sol Alt (Minesweeper'ın çok altında)
            Positioned(
              left: 26,
              bottom: 230,
              child: _buildGameIcon(
                imagePath: 'assets/images/artwork/block.png',
                c1: const Color(0xFF1E40AF),
                c2: const Color(0xFF3B82F6),
                floatY: floatInv,
                tilt: tiltB,
                scale: pulseB,
              ),
            ),
            // Bilgi Yarışması — Sağ Alt (Block Puzzle'dan daha aşağıda,
            // 2048'den iyice ayrı; ekranın sağ-alt köşesine yakın değil
            // ki nokta indikatörlerine çarpmasın)
            Positioned(
              right: 18,
              bottom: 110,
              child: _buildGameIcon(
                imagePath: 'assets/images/artwork/bilgiyarismasi.jpg',
                c1: const Color(0xFF4C1D95),
                c2: const Color(0xFF7C3AED),
                floatY: floatVal,
                tilt: tiltA,
                scale: pulseA,
              ),
            ),
          ],
        );
      },
    );
  }

  // ignore: unused_element
  Widget _buildPlaceholderSlide() {
    return Center(
      child: Container(
        width: 200,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 2),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1A1040).withValues(alpha: 0.8),
              const Color(0xFF0D0820).withValues(alpha: 0.6),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
              blurRadius: 30,
              spreadRadius: 2,
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
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.nightlight_round, color: Colors.white, size: 26),
                  ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 4),

        // ─── Telefon çerçevesi (Slider) — kalan tüm alan ───
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            children: [
              _buildSlide1(),
              _buildSlide2(),
              _buildSlide3(),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // ─── Nokta göstergeleri ───
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final active = _currentPage == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color:
                    active ? Colors.white : Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
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
  // super.key — AnimatedSwitcher child'ları için ValueKey desteği
  _TrialTimeline({super.key, required this.price});

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
  // super.key — AnimatedSwitcher child'ları için ValueKey desteği
  _LifetimeInfo({super.key});

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

// ─── Animasyonlu Video Arka Plan ───
class _VideoBackground extends StatefulWidget {
  const _VideoBackground();

  @override
  State<_VideoBackground> createState() => _VideoBackgroundState();
}

class _VideoBackgroundState extends State<_VideoBackground> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    // odeme.mp4 "ping-pong" versiyonu olarak bake edildi:
    // dosya içinde ileri-oynayış + ters-oynayış zaten ardışık birleştirilmiş.
    // Biz sadece düz loop yapıyoruz — sonuç akıcı boomerang efekti,
    // donma yok çünkü seekTo zorlamıyoruz.
    _controller = VideoPlayerController.asset('assets/images/odeme.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        _controller.setLooping(true);
        _controller.setVolume(0.0); // Sesi tamamen kapat (arka plan videosu)
        setState(() {}); // Hazır olunca render tetikle
        _controller.play();
      }).catchError((e) {
        debugPrint('⚠️ odeme.mp4 yüklenemedi: $e');
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return Container(color: const Color(0xFF080B16)); // Yüklenirken boş kalsın
    }
    
    return SizedBox.expand(
      child: Transform.scale(
        scale: 1.20, // Ekranı %20 büyüterek dikeyde kaydırma payı (overflow) yaratıyoruz
        child: FractionalTranslation(
          translation: const Offset(0.0, 0.06), // Videoyu biraz aşağıya kaydırarak 'Notch' çentiğinden kurtarıyoruz
          child: FittedBox(
            fit: BoxFit.cover,
            alignment: Alignment.center,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          ),
        ),
      ),
    );
  }
}

