import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'firestore_service.dart';
import 'localization_service.dart';

/// Abonelik ürün ID'leri — App Store Connect'te oluşturulacak
class SubscriptionIds {
  static const String monthly = 'sleepora_premium_monthly';
  static const String yearly = 'sleepora_premium_yearly';
  static const String lifetime = 'sleepora_premium_lifetime';
  static const Set<String> all = {monthly, yearly, lifetime};
}

/// Premium olarak kilitli ses adları
class PremiumContent {
  static const List<String> sounds = ['Kolik', 'Pış Pış 2', 'Yıldız Tozu', 'Konuşma', 'Tren', 'Çamaşır Makinesi'];
  static const List<String> games = []; // Oyunlar ücretsiz — içlerinde premium özellikler var
  static const List<String> premiumQuizCategories = ['Tarih', 'Coğrafya', 'Bilim & Teknoloji'];
  static const int freeMinesweeperHints = 0; // Ücretsiz planda ipucu yok
  static const int freeTimerMaxMinutes = 45;
  static const int freeRecordingMaxCount = 1;
  static const int freeFavoriteMaxCount = 3;
  static const int freeMixerMaxSounds = 2; // Ücretsiz planda karıştırıcıda max 2 ses
  static const int previewDurationSeconds = 5; // Premium ses önizleme süresi
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
  bool _isLoading = false;
  List<ProductDetails> _products = [];
  String? _error;

  // Abonelik planı: 'monthly', 'yearly', 'lifetime' veya null.
  // null → admin/manuel premium (Firestore'dan geldi, IAP'ten değil).
  String? _subscriptionPlan;
  // Abonelik bitiş tarihi (Firestore'dan). lifetime için null.
  // monthly/yearly için settings ekranı bundan "X gün kaldı" hesaplar.
  DateTime? _subscriptionEndDate;

  bool get isAvailable => _isAvailable;
  bool get isPremium => _isPremium;
  bool get isLoading => _isLoading;
  List<ProductDetails> get products => _products;
  String? get error => _error;

  /// 'monthly' | 'yearly' | 'lifetime' | null (manuel premium)
  String? get subscriptionPlan => _subscriptionPlan;

  /// Abonelik bitiş tarihi. lifetime/manuel için null.
  DateTime? get subscriptionEndDate => _subscriptionEndDate;

  /// Lifetime aboneliği mi? (subscription_id veya plan kontrolü)
  bool get isLifetime => _subscriptionPlan == 'lifetime';

  /// Aktif abonelikten kalan gün sayısı.
  /// lifetime veya endDate yoksa null döner.
  int? get remainingDays {
    if (!isPremium) return null;
    if (isLifetime) return null;
    final end = _subscriptionEndDate;
    if (end == null) return null;
    final diff = end.difference(DateTime.now()).inSeconds;
    if (diff <= 0) return 0;
    // En az 1 gün gösterimi için yukarı yuvarla
    return (diff / 86400).ceil();
  }

  /// Başlat — uygulama açılışında çağır
  Future<void> init() async {
    // Önce SharedPreferences'den oku (offline destek)
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool('is_premium') ?? false;
    // Local cache: subscription_id varsa plana çevir.
    _subscriptionPlan = _planFromSubId(prefs.getString('subscription_id'));
    final endMs = prefs.getInt('subscription_end_ms');
    if (endMs != null) {
      _subscriptionEndDate = DateTime.fromMillisecondsSinceEpoch(endMs);
    }
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

    // Firestore'dan manuel premium durumunu eşitle (Admin Panel senkronizasyonu)
    await syncPremiumFromFirestore();
  }

  /// Firestore'daki güncel premium durumunu locale yansıtır.
  /// Hem true hem false durumunu eşitler — böylece admin panelden premium
  /// kaldırılırsa veya yeni bir hesaba geçilirse local cache temiz tutulur.
  Future<void> syncPremiumFromFirestore() async {
    try {
      final auth = AuthService();
      if (!auth.isLoggedIn || auth.uid == null) return;

      final userData = await FirestoreService().getUser(auth.uid!);
      // Doküman yoksa veya alan yoksa premium = false varsay.
      final fsPremium = userData?['is_premium'] == true;
      final fsPlan = userData?['subscription_plan'] as String?;
      // Firestore Timestamp veya null
      DateTime? fsEnd;
      final endRaw = userData?['subscription_end'];
      try {
        // Cloud Firestore Timestamp objesini parse et
        if (endRaw != null) {
          // ignore: avoid_dynamic_calls
          fsEnd = (endRaw as dynamic).toDate() as DateTime?;
        }
      } catch (_) { fsEnd = null; }

      final prefs = await SharedPreferences.getInstance();
      final localPremium = prefs.getBool('is_premium') ?? false;

      // Plan / end değişikliklerini her zaman yansıt — premium durumu aynı kalsa
      // bile abonelik bilgisi yenilenmiş olabilir.
      bool changed = false;

      if (fsPremium != localPremium || fsPremium != _isPremium) {
        _isPremium = fsPremium;
        await prefs.setBool('is_premium', fsPremium);
        changed = true;

        if (!fsPremium) {
          // Premium kaldırıldıysa tüm abonelik metadatasını temizle.
          await prefs.remove('subscription_id');
          await prefs.remove('subscription_end_ms');
          _subscriptionPlan = null;
          _subscriptionEndDate = null;
        }
      }

      if (fsPremium) {
        if (fsPlan != null && fsPlan != _subscriptionPlan) {
          _subscriptionPlan = fsPlan;
          changed = true;
        }
        if (fsEnd != _subscriptionEndDate) {
          _subscriptionEndDate = fsEnd;
          if (fsEnd != null) {
            await prefs.setInt('subscription_end_ms', fsEnd.millisecondsSinceEpoch);
          } else {
            await prefs.remove('subscription_end_ms');
          }
          changed = true;
        }
      }

      if (changed) {
        notifyListeners();
        debugPrint('🔄 SubscriptionService: Premium=$_isPremium plan=$_subscriptionPlan end=$_subscriptionEndDate');
      }
    } catch (e) {
      debugPrint('❌ SubscriptionService Firestore sync error: $e');
    }
  }

  /// `subscription_id` (App Store ürün ID'si) → 'monthly' | 'yearly' | 'lifetime' | null
  String? _planFromSubId(String? id) {
    if (id == null) return null;
    if (id == SubscriptionIds.monthly) return 'monthly';
    if (id == SubscriptionIds.yearly) return 'yearly';
    if (id == SubscriptionIds.lifetime) return 'lifetime';
    return null;
  }

  /// Çıkış yapan kullanıcının local premium cache'ini temizler.
  ///
  /// Önemli: Eğer cihazda gerçek bir IAP satın alması varsa
  /// (subscription_id, App Store ürün ID'lerinden biri) local cache'i KORURUZ —
  /// çünkü IAP satın alması Firebase hesabına değil App Store hesabına bağlıdır.
  ///
  /// Aksi halde (admin panelden verilen premium veya başka hesabın cache'i)
  /// local durum sıfırlanır. Bu sayede guest girişi veya farklı hesap
  /// önceki kullanıcının premium durumunu devralmaz.
  Future<void> handleSignOut() async {
    final prefs = await SharedPreferences.getInstance();
    final subId = prefs.getString('subscription_id');

    if (subId != null && SubscriptionIds.all.contains(subId)) {
      debugPrint('🚪 SubscriptionService: Gerçek IAP tespit edildi, premium cache korunuyor');
      return;
    }

    _isPremium = false;
    _subscriptionPlan = null;
    _subscriptionEndDate = null;
    await prefs.setBool('is_premium', false);
    await prefs.remove('subscription_id');
    await prefs.remove('subscription_end_ms');
    notifyListeners();
    debugPrint('🚪 SubscriptionService: Çıkış sonrası premium cache temizlendi');
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
          _error = purchase.error?.message ?? LocalizationService().t('PurchaseError');
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
      _subscriptionPlan = _planFromSubId(purchase.productID);
      // Yerel olarak yaklaşık bitiş tarihi hesapla (offline UI için).
      // Firestore senkronizasyonu gerçek bitişi (kesin) ayrıca yansıtır.
      if (_subscriptionPlan == 'monthly') {
        _subscriptionEndDate = DateTime.now().add(const Duration(days: 30));
      } else if (_subscriptionPlan == 'yearly') {
        _subscriptionEndDate = DateTime.now().add(const Duration(days: 365));
      } else {
        _subscriptionEndDate = null; // lifetime
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_premium', true);
      await prefs.setString('subscription_id', purchase.productID);
      if (_subscriptionEndDate != null) {
        await prefs.setInt('subscription_end_ms', _subscriptionEndDate!.millisecondsSinceEpoch);
      } else {
        await prefs.remove('subscription_end_ms');
      }

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

  /// Premium kontrolü — karıştırıcı ses sayısı
  bool isMixerLimitReached(int currentCount) {
    if (isPremium) return false;
    return currentCount >= PremiumContent.freeMixerMaxSounds;
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }
}
