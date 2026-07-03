import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_service.dart';
import 'subscription_service.dart';

/// Uygulama sürümü (pubspec ile eşle — sürüm yükseltince güncelle).
const String kAppVersion = '1.0.0+14';

/// Sleepora Authentication Servisi
///
/// Singleton + ChangeNotifier — tüm uygulamadan dinlenebilir.
/// Apple ve Google Sign-In destekler.
/// Giriş sonrası local verileri otomatik olarak Firestore'a migrate eder.
///
/// Kullanım:
///   final auth = AuthService();
///   await auth.init(); // main.dart'ta bir kez çağır
///   auth.addListener(() => setState(() {})); // UI güncelleme
///
///   if (auth.isLoggedIn) { ... }
///   await auth.signInWithApple();
///   await auth.signOut();
class AuthService extends ChangeNotifier {
  // ─── Singleton ───
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // ─── Firebase Auth ───
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ─── State ───
  User? _user;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<User?>? _authSub;

  // ─── Getters ───
  User? get currentUser => _user;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get uid => _user?.uid;
  String? get email => _user?.email;
  String? get displayName => _user?.displayName;
  String? get photoUrl => _user?.photoURL;

  /// Giriş sağlayıcısını döndürür: 'apple', 'google', veya null
  String? get authProvider {
    if (_user == null) return null;
    for (final info in _user!.providerData) {
      if (info.providerId == 'apple.com') return 'apple';
      if (info.providerId == 'google.com') return 'google';
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════
  // Başlatma
  // ═══════════════════════════════════════════════════════

  /// Uygulama açılışında çağır — auth state'i dinlemeye başlar.
  /// main.dart'ta Firebase.initializeApp() sonrasında çağrılmalı.
  Future<void> init() async {
    _user = _auth.currentUser;

    _authSub = _auth.authStateChanges().listen((user) {
      final wasLoggedIn = _user != null;
      _user = user;
      notifyListeners();

      // İlk kez giriş yapıldıysa (önceki oturumda giriş yoktu)
      if (!wasLoggedIn && user != null) {
        debugPrint('🔐 Auth: Kullanıcı giriş yaptı → ${user.uid}');
      }
    });

    if (_user != null) {
      debugPrint('🔐 Auth: Mevcut oturum → ${_user!.uid}');
    }
  }

  // ═══════════════════════════════════════════════════════
  // Apple ile Giriş
  // ═══════════════════════════════════════════════════════

  /// Apple Sign In akışı.
  /// Başarılıysa [true] döner ve local veriyi migrate eder.
  /// Hata varsa [_error] set eder ve [false] döner.
  Future<bool> signInWithApple() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Apple credential al
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // 2. Firebase OAuthCredential oluştur
      final oAuthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // 3. Firebase'e giriş yap
      final userCredential = await _auth.signInWithCredential(oAuthCredential);
      _user = userCredential.user;

      // 4. Apple bazen displayName'i sadece ilk girişte verir
      if (_user != null &&
          (_user!.displayName == null || _user!.displayName!.isEmpty)) {
        final fullName = [
          appleCredential.givenName,
          appleCredential.familyName,
        ].where((n) => n != null && n.isNotEmpty).join(' ');

        if (fullName.isNotEmpty) {
          await _user!.updateDisplayName(fullName);
          await _user!.reload();
          _user = _auth.currentUser;
        }
      }

      // 5. Firestore'da kullanıcının var olduğundan emin ol (yoksa oluşturur, varsa günceller)
      await _ensureFirestoreUser('apple');

      // 6. Local veriyi Firestore'a migrate et
      await _migrateLocalData();

      _isLoading = false;
      notifyListeners();
      debugPrint('✅ Apple Sign In başarılı: ${_user?.uid}');
      return true;
    } on SignInWithAppleAuthorizationException catch (e) {
      // Kullanıcı iptal ettiyse hata gösterme
      if (e.code == AuthorizationErrorCode.canceled) {
        _isLoading = false;
        _error = null;
        notifyListeners();
        return false;
      }
      _error = 'Apple giriş hatası: ${e.message}';
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Apple Sign In error: $e');
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Apple Sign In error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════
  // Google ile Giriş
  // ═══════════════════════════════════════════════════════

  /// Google Sign In akışı.
  /// Başarılıysa [true] döner ve local veriyi migrate eder.
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Google hesap seçimi
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // Kullanıcı iptal etti
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 2. Google auth token'ları al
      final googleAuth = await googleUser.authentication;

      // 3. Firebase credential oluştur
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Firebase'e giriş yap
      final userCredential = await _auth.signInWithCredential(credential);
      _user = userCredential.user;

      // 5. Firestore'da kullanıcının var olduğundan emin ol
      await _ensureFirestoreUser('google');

      // 6. Local veriyi migrate et
      await _migrateLocalData();

      _isLoading = false;
      notifyListeners();
      debugPrint('✅ Google Sign In başarılı: ${_user?.uid}');
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Google Sign In error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════
  // Profil Güncelleme
  // ═══════════════════════════════════════════════════════

  /// Kullanıcı adı değiştirme bekleme süresi (gün).
  /// Bir değişiklikten sonra bu süre dolmadan tekrar değiştirilemez.
  static const int nameChangeCooldownDays = 3;

  /// Son ad değişikliği zaman damgası, kullanıcıya özel saklanır
  /// (uid yoksa misafir oturumu için ortak anahtar).
  String get _nameChangeKey => 'name_changed_at_${_user?.uid ?? 'guest'}';

  /// Adın tekrar değiştirilebilmesi için kalan süre.
  /// `null` dönerse şu an değiştirilebilir demektir.
  Future<Duration?> nameChangeRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_nameChangeKey);
    if (str == null) return null;
    final last = DateTime.tryParse(str);
    if (last == null) return null;
    final availableAt = last.add(const Duration(days: nameChangeCooldownDays));
    final now = DateTime.now();
    return availableAt.isAfter(now) ? availableAt.difference(now) : null;
  }

  /// Firebase Auth profilindeki görünen adı günceller.
  ///
  /// Bekleme süresi ([nameChangeCooldownDays] gün) dolmadıysa değişiklik
  /// yapılmaz ve `false` döner. Çağıran taraf, süreyi önceden
  /// [nameChangeRemaining] ile kontrol edip kullanıcıyı uyarmalıdır.
  Future<bool> updateDisplayName(String newName) async {
    if (_user == null || newName.trim().isEmpty) return false;

    // Bekleme süresi kontrolü — güvenlik için burada da doğrula.
    if (await nameChangeRemaining() != null) {
      debugPrint('⏳ Ad değişikliği bekleme süresi dolmadı.');
      return false;
    }

    try {
      await _user!.updateDisplayName(newName.trim());
      await _user!.reload();
      _user = _auth.currentUser;
      // Değişiklik zamanını kaydet — bir sonraki değişiklik için kronometre.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_nameChangeKey, DateTime.now().toIso8601String());
      notifyListeners();
      debugPrint('✏️ Görünen ad güncellendi: ${_user?.displayName}');
      return true;
    } catch (e) {
      debugPrint('❌ updateDisplayName hatası: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════
  // Çıkış
  // ═══════════════════════════════════════════════════════

  /// Aktif oturumu sonlandırır.
  /// Google oturumu da kapatır (tekrar hesap seçtirmek için).
  ///
  /// ÖNEMLİ: Local premium cache'i de temizlenir. Aksi halde guest girişi
  /// veya başka bir hesap önceki kullanıcının (ör. admin panelden manuel
  /// premium verilmiş) premium durumunu devralır.
  /// Gerçek IAP satın alması varsa cache korunur — App Store hesabı ile bağlı.
  Future<void> signOut() async {
    try {
      // Google oturumunu da kapat
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      await _auth.signOut();

      // Premium cache'ini hesaba göre sıfırla
      await SubscriptionService().handleSignOut();

      _user = null;
      _error = null;
      notifyListeners();
      debugPrint('🚪 Çıkış yapıldı');
    } catch (e) {
      debugPrint('❌ Sign out error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // Hesap Silme (KVKK/GDPR)
  // ═══════════════════════════════════════════════════════

  /// Kullanıcı hesabını ve tüm verilerini kalıcı olarak siler.
  /// Firestore verileri Cloud Functions onUserDelete trigger'ı ile temizlenir.
  /// Firebase Auth hesabı da silinir.
  Future<bool> deleteAccount() async {
    if (_user == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final uid = _user!.uid;

      // 1. Firestore verilerini sil
      await FirestoreService().deleteUserData(uid);

      // 2. Firebase Auth hesabını sil
      await _user!.delete();

      // 3. Google oturumunu da kapat
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }

      // 4. Local premium durumunu sıfırla
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_premium', false);
      await prefs.remove('subscription_id');

      _user = null;
      _isLoading = false;
      notifyListeners();
      debugPrint('🗑️ Hesap silindi: $uid');
      return true;
    } on FirebaseAuthException catch (e) {
      // Yeniden kimlik doğrulama gerekebilir
      if (e.code == 'requires-recent-login') {
        _error = 'Hesabınızı silmek için tekrar giriş yapmanız gerekiyor.';
      } else {
        _error = e.message;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════
  // Firestore Kullanıcı Eşitleme
  // ═══════════════════════════════════════════════════════

  /// Firestore'da kullanıcı dokümanının varlığından emin olur.
  /// Yoksa oluşturur, varsa sadece güncel bilgileri (email, isim) eşitler.
  Future<void> _ensureFirestoreUser(String provider) async {
    if (_user == null) return;

    try {
      final fs = FirestoreService();
      final userData = await fs.getUser(_user!.uid);

      if (userData == null) {
        // Kullanıcı Firestore'da yok, yeni oluştur
        await fs.createUser(
          uid: _user!.uid,
          email: _user!.email,
          displayName: _user!.displayName,
          photoUrl: _user!.photoURL,
          authProvider: provider,
        );
        debugPrint('📝 Firestore user oluşturuldu: ${_user!.uid}');
      } else {
        // Kullanıcı zaten var, sadece güncel auth bilgilerini senkronize et
        await fs.updateUserFields(_user!.uid, {
          'email': _user!.email,
          'display_name': _user!.displayName,
          'photo_url': _user!.photoURL,
        });
        debugPrint('📝 Firestore user bilgileri güncellendi: ${_user!.uid}');
      }
    } catch (e) {
      debugPrint('❌ Firestore ensure user hatası: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // Local → Firestore Veri Migrasyon
  // ═══════════════════════════════════════════════════════

  /// SharedPreferences'teki tüm kullanıcı verisini Firestore'a aktarır.
  ///
  /// Migre edilen veriler:
  /// - baby_name (bebek adı)
  /// - favorites (favori sesler)
  /// - sound_play_counts (çalma istatistikleri)
  /// - Ayarlar (dil, auto_stop, fade_out, bg_play, notifications, reminder)
  /// - is_premium, subscription_id (abonelik durumu)
  ///
  /// Bu metod "local üstün gelir" politikası uygular:
  /// Local'de veri varsa Firestore'a yazar, yoksa Firestore'dan okumaz.
  /// Böylece giriş yapan kullanıcının mevcut ayarları korunur.
  Future<void> _migrateLocalData() async {
    if (_user == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final fs = FirestoreService();
      final uid = _user!.uid;

      debugPrint('📦 Local veri migrasyonu başlıyor...');

      // ─── 1. Bebek Adı ───
      final babyName = prefs.getString('baby_name');
      if (babyName != null && babyName.isNotEmpty) {
        await fs.updateUserField(uid, 'baby_name', babyName);
      }

      // ─── 2. Favoriler ───
      // allSounds listesinden isFavorite olanları topla
      // Not: Bu import'suz çalışır çünkü allSounds global bir liste
      // Migration sırasında favorileri Firestore'a aktar
      await _migrateFavorites(uid);

      // ─── 3. Çalma İstatistikleri ───
      final playCountsJson = prefs.getString('sound_play_counts');
      if (playCountsJson != null) {
        await fs.updateUserField(uid, 'play_counts', playCountsJson);
      }

      // ─── 4. Ayarlar ───
      final settings = <String, dynamic>{};

      final lang = prefs.getInt('app_lang');
      if (lang != null) settings['language'] = lang;

      final autoStop = prefs.getBool('auto_stop');
      if (autoStop != null) settings['auto_stop'] = autoStop;

      final fadeOut = prefs.getBool('fade_out');
      if (fadeOut != null) settings['fade_out'] = fadeOut;

      final bgPlay = prefs.getBool('bg_play');
      if (bgPlay != null) settings['bg_play'] = bgPlay;

      final notifications = prefs.getBool('notifications');
      if (notifications != null) settings['notifications_enabled'] = notifications;

      final remHour = prefs.getInt('rem_hour');
      final remMinute = prefs.getInt('rem_minute');
      if (remHour != null) settings['rem_hour'] = remHour;
      if (remMinute != null) settings['rem_minute'] = remMinute;

      if (settings.isNotEmpty) {
        await fs.updateUserFields(uid, settings);
      }

      // ─── 5. Abonelik Durumu ───
      // GÜVENLİK: Local is_premium cache'ini KOŞULSUZCA yeni hesabın Firestore
      // dokümanına yazma! Aksi halde admin panelden bir hesaba verilen premium,
      // çıkış→başka giriş sonrası diğer hesaplara da bulaşır.
      //
      // SADECE cihazda doğrulanmış bir IAP satın alması varsa (subscription_id
      // gerçek bir App Store ürün ID'si) Firestore'a yaz.
      final isPremium = prefs.getBool('is_premium') ?? false;
      final subscriptionId = prefs.getString('subscription_id');
      final hasVerifiedIap = subscriptionId != null &&
          SubscriptionIds.all.contains(subscriptionId);

      if (isPremium && hasVerifiedIap) {
        await fs.updateUserFields(uid, {
          'is_premium': true,
          'subscription_plan': _planFromId(subscriptionId),
          'subscription_platform': 'ios',
        });
      }

      // ─── 6. Son giriş zamanını güncelle ───
      await fs.updateLastLogin(uid);

      // ─── 6b. Cihaz / sürüm bilgisi (analitik) ───
      try {
        String platform = 'unknown';
        String osVer = '';
        try {
          platform = Platform.isIOS
              ? 'ios'
              : (Platform.isAndroid ? 'android' : Platform.operatingSystem);
          osVer = Platform.operatingSystemVersion;
        } catch (_) {}
        final locale = PlatformDispatcher.instance.locale;
        await fs.updateUserFields(uid, {
          'platform': platform,
          'os_version': osVer,
          'app_version': kAppVersion,
          'locale': locale.languageCode,
          'country': locale.countryCode ?? '',
        });
      } catch (e) {
        debugPrint('❌ Cihaz bilgisi yazılamadı: $e');
      }

      // ─── 7. Migrasyonun tamamlandığını işaretle ───
      await prefs.setBool('data_migrated', true);

      // ─── 8. Yeni hesabın GERÇEK premium durumunu Firestore'dan al ───
      // Önceki hesaptan kalmış olabilecek local cache'i, yeni hesabın
      // doğru durumuyla değiştir.
      await SubscriptionService().syncPremiumFromFirestore();

      debugPrint('✅ Local veri migrasyonu tamamlandı');
    } catch (e) {
      debugPrint('❌ Migrasyon hatası: $e');
      // Migrasyon hatası kritik değil — uygulama çalışmaya devam eder
    }
  }

  /// Favori sesleri Firestore'a aktarır
  Future<void> _migrateFavorites(String uid) async {
    try {
      // sounds_screen.dart'taki allSounds listesine erişim
      // Bu import döngüsü oluşturmaması için sadece isimleri toplarız
      final prefs = await SharedPreferences.getInstance();
      final favNames = prefs.getStringList('favorite_sounds');

      if (favNames != null && favNames.isNotEmpty) {
        for (final name in favNames) {
          await FirestoreService().addFavorite(uid, name);
        }
        debugPrint('  → ${favNames.length} favori aktarıldı');
      }
    } catch (e) {
      debugPrint('  ❌ Favori migrasyonu hatası: $e');
    }
  }

  /// subscription_id'den plan adı çıkarır
  String? _planFromId(String? subscriptionId) {
    if (subscriptionId == null) return null;
    if (subscriptionId.contains('monthly')) return 'monthly';
    if (subscriptionId.contains('yearly')) return 'yearly';
    if (subscriptionId.contains('lifetime')) return 'lifetime';
    return subscriptionId;
  }

  // ═══════════════════════════════════════════════════════
  // Firestore'dan Veriyi Local'e Çekme (Sync)
  // ═══════════════════════════════════════════════════════

  /// Firestore'daki kullanıcı verisini SharedPreferences'e yazar.
  /// Başka cihazda giriş yapıldığında çağrılır.
  Future<void> syncFromFirestore() async {
    if (_user == null) return;

    try {
      final fs = FirestoreService();
      final userData = await fs.getUser(_user!.uid);
      if (userData == null) return;

      final prefs = await SharedPreferences.getInstance();

      // Bebek adı
      if (userData['baby_name'] != null) {
        await prefs.setString('baby_name', userData['baby_name']);
      }

      // Dil
      if (userData['language'] != null) {
        await prefs.setInt('app_lang', userData['language']);
      }

      // Ayarlar
      if (userData['auto_stop'] != null) {
        await prefs.setBool('auto_stop', userData['auto_stop']);
      }
      if (userData['fade_out'] != null) {
        await prefs.setBool('fade_out', userData['fade_out']);
      }
      if (userData['bg_play'] != null) {
        await prefs.setBool('bg_play', userData['bg_play']);
      }
      if (userData['notifications_enabled'] != null) {
        await prefs.setBool('notifications', userData['notifications_enabled']);
      }

      // Premium durumu — true VE false olarak senkronize et.
      // Aksi halde Firestore'da premium kaldırılsa bile local cache'de
      // true olarak kalır ve guest moduna düşüldüğünde devralınır.
      final fsPremium = userData['is_premium'] == true;
      await prefs.setBool('is_premium', fsPremium);
      if (!fsPremium) {
        await prefs.remove('subscription_id');
      }

      debugPrint('🔄 Firestore → Local sync tamamlandı (premium=$fsPremium)');
    } catch (e) {
      debugPrint('❌ Sync hatası: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // Dispose
  // ═══════════════════════════════════════════════════════

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
