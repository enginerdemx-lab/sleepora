import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';
import '../services/subscription_service.dart';

/// Adaptif banner reklam widget'ı.
///
/// Plus kullanıcılarda hiçbir şey göstermez (boş [SizedBox.shrink]).
/// Reklam yüklenirken aynı yüksekliği placeholder olarak tutar (layout shift olmaz).
/// Reklam yüklenemezse boş kalır (kullanıcı deneyimi bozulmaz).
class BannerAdWidget extends StatefulWidget {
  final BannerSlot slot;

  /// Banner'ın etrafına ek padding (varsa). Default: alt boşluk yok.
  final EdgeInsets padding;

  /// Reklam başarıyla yüklendiğinde tetiklenir.
  final VoidCallback? onAdLoaded;

  /// Reklam yüklenemediğinde tetiklenir.
  final VoidCallback? onAdFailed;

  const BannerAdWidget({
    super.key,
    required this.slot,
    this.padding = EdgeInsets.zero,
    this.onAdLoaded,
    this.onAdFailed,
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _failed = false;
  AnchoredAdaptiveBannerAdSize? _size;

  @override
  void initState() {
    super.initState();
    if (AdService().adsEnabled) {
      // Premium değilse load başlat
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    debugPrint('🟢 [BANNER_DEBUG] _load BAŞLADI slot=${widget.slot}, adsEnabled=${AdService().adsEnabled}');
    try {
      final width = MediaQuery.of(context).size.width.truncate();
      debugPrint('🟢 [BANNER_DEBUG] genişlik=$width, adaptive size hesaplanıyor...');
      final size = await AdSize.getAnchoredAdaptiveBannerAdSize(
        Orientation.portrait,
        width,
      );
      if (size == null) {
        debugPrint('❌ [BANNER_DEBUG] anchored adaptive size NULL → ad load iptal');
        if (mounted) {
          setState(() => _failed = true);
        }
        return;
      }
      debugPrint('🟢 [BANNER_DEBUG] size hazır: ${size.width}x${size.height}');
      _size = size;
      final unitId = AdService().bannerUnitId(widget.slot);
      debugPrint('🟢 [BANNER_DEBUG] unitId=$unitId, ad.load() çağrılıyor...');
      final ad = BannerAd(
        adUnitId: unitId,
        request: const AdRequest(),
        size: size,
        listener: BannerAdListener(
          onAdLoaded: (_) {
            debugPrint('✅ [BANNER_DEBUG] AD LOADED slot=${widget.slot}');
            if (!mounted) return;
            setState(() {
              _loaded = true;
              _failed = false;
            });
            widget.onAdLoaded?.call();
          },
          onAdFailedToLoad: (ad, err) {
            debugPrint('❌ [BANNER_DEBUG] LOAD FAILED slot=${widget.slot} → code=${err.code}, domain=${err.domain}, message=${err.message}');
            ad.dispose();
            if (mounted) {
              setState(() {
                _failed = true;
                _loaded = false;
              });
            }
            widget.onAdFailed?.call();
          },
        ),
      );
      _ad = ad;
      ad.load();
      debugPrint('🟢 [BANNER_DEBUG] ad.load() asenkron başlatıldı (callback bekleniyor)');
    } catch (e, st) {
      debugPrint('❌ [BANNER_DEBUG] OUTER EXCEPTION: $e\nstack: $st');
      if (mounted) {
        setState(() => _failed = true);
      }
    }
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Premium veya hata durumunda hiçbir şey gösterme
    if (!AdService().adsEnabled || SubscriptionService().isPremium || _failed) {
      return const SizedBox.shrink();
    }
    if (!_loaded || _ad == null || _size == null) {
      // Yüklenirken görsel yer tutmaması için basit bir spacer (50dp)
      return const SizedBox(height: 50);
    }
    return Padding(
      padding: widget.padding,
      child: SizedBox(
        width: _size!.width.toDouble(),
        height: _size!.height.toDouble(),
        child: AdWidget(ad: _ad!),
      ),
    );
  }
}
