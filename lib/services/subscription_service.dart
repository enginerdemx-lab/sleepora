import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Abonelik ürün ID'leri — App Store Connect'te oluşturulacak
class SubscriptionIds {
  static const String monthly = 'sleepora_premium_monthly';
  static const String yearly = 'sleepora_premium_yearly';
  static const String lifetime = 'sleepora_premium_lifetime';
  static const Set<String> all = {monthly, yearly, lifetime};
}

/// Premium olarak kilitli ses adları
class PremiumContent {
  static const List<String> sounds = ['Kolik', 'Pış Pış 2', 'Yıldız Tozu', 'Konuşma'];
  static const List<String> games = []; // Oyunlar ücretsiz — içlerinde premium özellikler var
  static const List<String> premiumQuizCategories = ['Tarih', 'Coğrafya', 'Bilim & Teknoloji'];
  static const int freeMinesweeperHints = 0; // Ücretsiz planda ipucu yok
  static const int freeTimerMaxMinutes = 45;
  static const int freeRecordingMaxCount = 1;
  static const int freeFavoriteMaxCount = 3;
}

class SubscriptionService extends ChangeNotifier {
  // Singleton
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  bool _isAvailable = false;
  bool _isPremium = false;
  bool _debugOverride = false; // Geliştirici test modu
  bool _isLoading = false;
  List<ProductDetails> _products = [];
  String? _error;

  bool get isAvailable => _isAvailable;
  bool get isPremium => _debugOverride ? true : _isPremium;
  bool get isDebugPremium => _debugOverride;
  bool get isLoading => _isLoading;
  List<ProductDetails> get products => _products;
  String? get error => _error;

  /// Başlat — uygulama açılışında çağır
  Future<void> init() async {
    // Önce SharedPreferences'den oku (offline destek)
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool('is_premium') ?? false;
    notifyListeners();

    try {
      _isAvailable = await _iap.isAvailable().timeout(const Duration(seconds: 5));
    } catch (_) {
      _isAvailable = false;
    }
    if (!_isAvailable) {
      debugPrint('IAP not available');
      return;
    }

    // Satın alma stream'ini dinle
    _purchaseSub = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _purchaseSub?.cancel(),
      onError: (error) => debugPrint('Purchase stream error: $error'),
    );

    // Ürünleri yükle (timeout ile)
    try {
      await loadProducts().timeout(const Duration(seconds: 8));
    } catch (_) {
      _isLoading = false;
      notifyListeners();
    }

    // Mevcut satın almaları restore et (abonelik durumunu kontrol)
    try {
      await restorePurchases().timeout(const Duration(seconds: 5));
    } catch (_) {
      // Restore başarısız — devam et
    }
  }

  /// Ürünleri App Store'dan yükle
  Future<void> loadProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _iap.queryProductDetails(SubscriptionIds.all);
      if (response.error != null) {
        _error = response.error!.message;
        debugPrint('Product query error: ${response.error}');
      }
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('Products not found: ${response.notFoundIDs}');
      }
      _products = response.productDetails;
    } catch (e) {
      _error = e.toString();
      debugPrint('Load products error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Satın alma başlat
  Future<void> buySubscription(ProductDetails product) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      // Lifetime non-consumable, abonelikler de non-consumable olarak işlenir
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Önceki satın almaları geri yükle
  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('Restore error: $e');
    }
  }

  /// Satın alma güncellemeleri
  void _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndActivate(purchase);
          break;
        case PurchaseStatus.error:
          _error = purchase.error?.message ?? 'Satın alma hatası';
          _isLoading = false;
          notifyListeners();
          break;
        case PurchaseStatus.canceled:
          _isLoading = false;
          notifyListeners();
          break;
        case PurchaseStatus.pending:
          break;
      }

      // pending olmayan işlemleri tamamla
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  /// Satın almayı doğrula ve aktifleştir
  Future<void> _verifyAndActivate(PurchaseDetails purchase) async {
    if (SubscriptionIds.all.contains(purchase.productID)) {
      _isPremium = true;
      _isLoading = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_premium', true);
      await prefs.setString('subscription_id', purchase.productID);

      notifyListeners();
    }
  }

  /// Ürün bilgisi al
  ProductDetails? getProduct(String id) {
    return _products.where((p) => p.id == id).firstOrNull;
  }

  /// Premium kontrolü — ses adına göre
  bool isSoundPremium(String soundName) {
    if (isPremium) return false;
    return PremiumContent.sounds.contains(soundName);
  }

  /// Premium kontrolü — oyun adına göre
  bool isGamePremium(String gameName) {
    if (isPremium) return false;
    return PremiumContent.games.contains(gameName);
  }

  /// Premium kontrolü — zamanlayıcı dakikası
  bool isTimerPremium(int minutes) {
    if (isPremium) return false;
    return minutes > PremiumContent.freeTimerMaxMinutes;
  }

  /// Premium kontrolü — kayıt sayısı
  bool isRecordingLimitReached(int currentCount) {
    if (isPremium) return false;
    return currentCount >= PremiumContent.freeRecordingMaxCount;
  }

  /// Premium kontrolü — favori sayısı
  bool isFavoriteLimitReached(int currentCount) {
    if (isPremium) return false;
    return currentCount >= PremiumContent.freeFavoriteMaxCount;
  }

  /// Geliştirici test modu — Premium'u simüle et
  void toggleDebugPremium() {
    _debugOverride = !_debugOverride;
    debugPrint('🔧 Debug Premium: $_debugOverride');
    notifyListeners();
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }
}
