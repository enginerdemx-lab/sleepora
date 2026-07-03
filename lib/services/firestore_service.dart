import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Sleepora Firestore Servisi
///
/// Tüm Firestore CRUD operasyonlarını merkezi olarak yönetir.
/// Singleton pattern — her yerden tek instance ile erişim.
///
/// Koleksiyon yapısı:
///   users/{uid}                → Kullanıcı profili, ayarlar, abonelik
///   users/{uid}/favorites/{id} → Favori sesler
///   users/{uid}/mixes/{id}     → Kaydedilmiş mi preset'leri
///
/// Kullanım:
///   final fs = FirestoreService();
///   await fs.createUser(uid: 'abc', email: 'a@b.com');
///   await fs.addFavorite('abc', 'Yağmur');
///   final data = await fs.getUser('abc');
class FirestoreService {
  // ─── Singleton ───
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  // ─── Firestore instance ───
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Koleksiyon referansları ───
  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _db.collection('users');

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _usersRef.doc(uid);

  CollectionReference<Map<String, dynamic>> _favoritesRef(String uid) =>
      _userDoc(uid).collection('favorites');

  CollectionReference<Map<String, dynamic>> _mixesRef(String uid) =>
      _userDoc(uid).collection('mixes');

  CollectionReference<Map<String, dynamic>> _sleepSessionsRef(String uid) =>
      _userDoc(uid).collection('sleep_sessions');

  // ═══════════════════════════════════════════════════════
  // Kullanıcı İşlemleri
  // ═══════════════════════════════════════════════════════

  /// Yeni kullanıcı dokümanı oluşturur.
  /// [authProvider]: 'apple' veya 'google'
  ///
  /// Bu metod sadece ilk kayıtta çağrılır (isNewUser == true).
  /// Mevcut kullanıcı varsa üzerine yazmaz (merge: true).
  Future<void> createUser({
    required String uid,
    String? email,
    String? displayName,
    String? photoUrl,
    required String authProvider,
  }) async {
    try {
      await _userDoc(uid).set({
        // Kimlik
        'email': email,
        'display_name': displayName,
        'photo_url': photoUrl,
        'auth_provider': authProvider,

        // Zaman damgaları
        'created_at': FieldValue.serverTimestamp(),
        'last_login': FieldValue.serverTimestamp(),

        // Varsayılan değerler
        'baby_name': '',
        'is_premium': false,
        'subscription_plan': null,
        'subscription_start': null,
        'subscription_end': null,
        'original_transaction_id': null,
        'subscription_platform': null,

        // Tercihler
        'language': 0, // Varsayılan: Türkçe
        'auto_stop': false,
        'fade_out': true,
        'bg_play': true,
        'notifications_enabled': false,

        // İstatistikler
        'total_play_time_minutes': 0,
        'session_count': 0,
        'last_played_sound': null,
      }, SetOptions(merge: true));

      debugPrint('📝 Firestore: User oluşturuldu → $uid');
    } catch (e) {
      debugPrint('❌ Firestore createUser hatası: $e');
      rethrow;
    }
  }

  /// Kullanıcı verisini okur. Yoksa null döner.
  Future<Map<String, dynamic>?> getUser(String uid) async {
    try {
      final doc = await _userDoc(uid).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      debugPrint('❌ Firestore getUser hatası: $e');
      return null;
    }
  }

  /// Tek bir alanı günceller.
  Future<void> updateUserField(String uid, String field, dynamic value) async {
    try {
      await _userDoc(uid).update({field: value});
    } catch (e) {
      debugPrint('❌ Firestore updateField hatası ($field): $e');
    }
  }

  /// Birden fazla alanı tek seferde günceller.
  Future<void> updateUserFields(String uid, Map<String, dynamic> fields) async {
    try {
      await _userDoc(uid).update(fields);
    } catch (e) {
      debugPrint('❌ Firestore updateFields hatası: $e');
    }
  }

  /// Son giriş zamanını günceller + oturum sayacını artırır.
  Future<void> updateLastLogin(String uid) async {
    try {
      await _userDoc(uid).update({
        'last_login': FieldValue.serverTimestamp(),
        'session_count': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('❌ Firestore updateLastLogin hatası: $e');
    }
  }

  /// Kullanıcı verisini ve tüm alt koleksiyonları siler.
  /// KVKK/GDPR hesap silme işlemi için.
  Future<void> deleteUserData(String uid) async {
    try {
      // 1. Favoriler alt koleksiyonunu sil
      await _deleteCollection(_favoritesRef(uid));

      // 2. Mixler alt koleksiyonunu sil
      await _deleteCollection(_mixesRef(uid));

      // 3. Ana dokümanı sil
      await _userDoc(uid).delete();

      debugPrint('🗑️ Firestore: User verisi silindi → $uid');
    } catch (e) {
      debugPrint('❌ Firestore deleteUser hatası: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════
  // Favoriler
  // ═══════════════════════════════════════════════════════

  /// Favori ses ekler.
  /// Doküman ID olarak ses adını (name) kullanır — tekrarı önler.
  Future<void> addFavorite(String uid, String soundName) async {
    try {
      await _favoritesRef(uid).doc(soundName).set({
        'name': soundName,
        'added_at': FieldValue.serverTimestamp(),
        'play_count': 0,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Firestore addFavorite hatası: $e');
    }
  }

  /// Favori ses kaldırır.
  Future<void> removeFavorite(String uid, String soundName) async {
    try {
      await _favoritesRef(uid).doc(soundName).delete();
    } catch (e) {
      debugPrint('❌ Firestore removeFavorite hatası: $e');
    }
  }

  /// Tüm favorileri okur.
  /// Her favori: {'name': String, 'added_at': Timestamp, 'play_count': int}
  Future<List<Map<String, dynamic>>> getFavorites(String uid) async {
    try {
      final snapshot = await _favoritesRef(uid)
          .orderBy('added_at', descending: false)
          .get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('❌ Firestore getFavorites hatası: $e');
      return [];
    }
  }

  /// Favori listesini toplu olarak set eder (migrasyon için).
  /// Mevcut favorileri silmez, sadece ekler (merge).
  Future<void> setFavorites(String uid, List<String> soundNames) async {
    try {
      final batch = _db.batch();
      for (final name in soundNames) {
        final ref = _favoritesRef(uid).doc(name);
        batch.set(ref, {
          'name': name,
          'added_at': FieldValue.serverTimestamp(),
          'play_count': 0,
        }, SetOptions(merge: true));
      }
      await batch.commit();
      debugPrint('📝 Firestore: ${soundNames.length} favori set edildi');
    } catch (e) {
      debugPrint('❌ Firestore setFavorites hatası: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // Mixler (Kaydedilmiş Ses Karışımları)
  // ═══════════════════════════════════════════════════════

  /// Yeni mix kaydeder.
  /// Her ses: {'name': String, 'volume': double}
  Future<String?> saveMix(
    String uid,
    String mixName,
    List<Map<String, dynamic>> sounds,
  ) async {
    try {
      final docRef = await _mixesRef(uid).add({
        'name': mixName,
        'sounds': sounds,
        'created_at': FieldValue.serverTimestamp(),
        'is_favorite': false,
      });
      debugPrint('📝 Firestore: Mix kaydedildi → ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Firestore saveMix hatası: $e');
      return null;
    }
  }

  /// Tüm mixleri okur.
  Future<List<Map<String, dynamic>>> getMixes(String uid) async {
    try {
      final snapshot = await _mixesRef(uid)
          .orderBy('created_at', descending: false)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Doküman ID'sini de ekle (silme/güncelleme için)
        return data;
      }).toList();
    } catch (e) {
      debugPrint('❌ Firestore getMixes hatası: $e');
      return [];
    }
  }

  /// Mix günceller (ses listesi veya isim değişikliği).
  Future<void> updateMix(
    String uid,
    String mixId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _mixesRef(uid).doc(mixId).update(updates);
    } catch (e) {
      debugPrint('❌ Firestore updateMix hatası: $e');
    }
  }

  /// Mix siler.
  Future<void> deleteMix(String uid, String mixId) async {
    try {
      await _mixesRef(uid).doc(mixId).delete();
    } catch (e) {
      debugPrint('❌ Firestore deleteMix hatası: $e');
    }
  }

  /// Mixleri toplu olarak kaydeder (migrasyon için).
  Future<void> setMixes(
    String uid,
    List<Map<String, dynamic>> mixes,
  ) async {
    try {
      final batch = _db.batch();
      for (final mix in mixes) {
        final ref = _mixesRef(uid).doc(); // Auto-generated ID
        batch.set(ref, {
          'name': mix['name'],
          'sounds': mix['sounds'],
          'created_at': FieldValue.serverTimestamp(),
          'is_favorite': false,
        });
      }
      await batch.commit();
      debugPrint('📝 Firestore: ${mixes.length} mix set edildi');
    } catch (e) {
      debugPrint('❌ Firestore setMixes hatası: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // Uyku Oturumları (Sleep Sessions)
  // ═══════════════════════════════════════════════════════

  /// Yeni uyku oturumu kaydeder.
  Future<void> saveSleepSession(
      String uid, Map<String, dynamic> sessionData) async {
    try {
      await _sleepSessionsRef(uid)
          .add({...sessionData, 'created_at': FieldValue.serverTimestamp()});
    } catch (e) {
      debugPrint('❌ Firestore saveSleepSession hatası: $e');
    }
  }

  /// Son [days] güne ait oturumları getirir (date alanına göre).
  Future<List<Map<String, dynamic>>> getSleepSessions(String uid,
      {int days = 7}) async {
    try {
      final since = DateTime.now().subtract(Duration(days: days));
      final sinceStr =
          '${since.year}-${since.month.toString().padLeft(2, '0')}-${since.day.toString().padLeft(2, '0')}';

      final snapshot = await _sleepSessionsRef(uid)
          .where('date', isGreaterThanOrEqualTo: sinceStr)
          .orderBy('date', descending: false)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('❌ Firestore getSleepSessions hatası: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════
  // Abonelik İşlemleri
  // ═══════════════════════════════════════════════════════

  /// Premium durumunu Firestore'da günceller.
  ///
  /// ⚠️ Bu metod sadece sunucu tarafından çağrılmalıdır (Cloud Functions).
  /// Client-side kullanım, güvenlik kuralları tarafından engellenecektir.
  ///
  /// Geçici olarak client'tan da çağrılabilir (security rules uygulanana kadar).
  Future<void> updateSubscription({
    required String uid,
    required bool isPremium,
    String? plan,
    DateTime? startDate,
    DateTime? endDate,
    String? transactionId,
    String platform = 'ios',
  }) async {
    try {
      await _userDoc(uid).update({
        'is_premium': isPremium,
        'subscription_plan': plan,
        'subscription_start':
            startDate != null ? Timestamp.fromDate(startDate) : null,
        'subscription_end':
            endDate != null ? Timestamp.fromDate(endDate) : null,
        'original_transaction_id': transactionId,
        'subscription_platform': platform,
      });
      debugPrint('💎 Firestore: Abonelik güncellendi → $uid ($plan)');
    } catch (e) {
      debugPrint('❌ Firestore updateSubscription hatası: $e');
    }
  }

  /// Kullanıcının premium durumunu okur (offline check için).
  Future<bool> isPremium(String uid) async {
    try {
      final data = await getUser(uid);
      if (data == null) return false;

      final premium = data['is_premium'] ?? false;
      if (!premium) return false;

      // Lifetime ise her zaman premium
      if (data['subscription_plan'] == 'lifetime') return true;

      // Süre kontrolü
      final endDate = data['subscription_end'] as Timestamp?;
      if (endDate == null) return premium; // endDate yoksa mevcut durumu dön

      return endDate.toDate().isAfter(DateTime.now());
    } catch (e) {
      debugPrint('❌ Firestore isPremium hatası: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════
  // İstatistikler
  // ═══════════════════════════════════════════════════════

  /// Toplam çalma süresini artırır.
  Future<void> incrementPlayTime(String uid, int minutes) async {
    try {
      await _userDoc(uid).update({
        'total_play_time_minutes': FieldValue.increment(minutes),
      });
    } catch (e) {
      debugPrint('❌ Firestore incrementPlayTime hatası: $e');
    }
  }

  /// Son çalınan sesi günceller.
  Future<void> updateLastPlayedSound(String uid, String soundName) async {
    try {
      await _userDoc(uid).update({
        'last_played_sound': soundName,
      });
    } catch (e) {
      debugPrint('❌ Firestore updateLastPlayed hatası: $e');
    }
  }

  /// Paywall görüntülenme sayacını artırır (dönüşüm hunisi takibi).
  Future<void> incrementPaywallView(String uid) async {
    try {
      await _userDoc(uid).set({
        'paywall_views': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Firestore incrementPaywallView hatası: $e');
    }
  }

  /// Oyun başına oynanma sayacını artırır (game_plays.{gameKey}).
  Future<void> incrementGamePlay(String uid, String gameKey) async {
    if (gameKey.isEmpty) return;
    try {
      await _userDoc(uid).set({
        'game_plays': {gameKey: FieldValue.increment(1)},
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Firestore incrementGamePlay hatası: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // Realtime Listeners
  // ═══════════════════════════════════════════════════════

  /// Kullanıcı dokümanını realtime olarak dinler.
  /// Premium durumu değiştiğinde anında UI güncellemesi için.
  Stream<Map<String, dynamic>?> userStream(String uid) {
    return _userDoc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return doc.data();
    });
  }

  /// Favori değişikliklerini realtime dinler.
  Stream<List<Map<String, dynamic>>> favoritesStream(String uid) {
    return _favoritesRef(uid)
        .orderBy('added_at', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => d.data()).toList());
  }

  /// Mix değişikliklerini realtime dinler.
  Stream<List<Map<String, dynamic>>> mixesStream(String uid) {
    return _mixesRef(uid)
        .orderBy('created_at', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    });
  }

  // ═══════════════════════════════════════════════════════
  // Yardımcı Metotlar
  // ═══════════════════════════════════════════════════════

  /// Bir koleksiyondaki tüm dokümanları siler (batch ile).
  /// Alt koleksiyon silme işlemi için kullanılır.
  Future<void> _deleteCollection(
      CollectionReference<Map<String, dynamic>> ref) async {
    const batchSize = 100;
    QuerySnapshot<Map<String, dynamic>> snapshot;

    do {
      snapshot = await ref.limit(batchSize).get();
      if (snapshot.docs.isEmpty) break;

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } while (snapshot.docs.length == batchSize);
  }

  // ═══════════════════════════════════════════════════════
  // Skor Tablosu (Leaderboard)
  // ═══════════════════════════════════════════════════════

  /// Leaderboard koleksiyon referansı.
  /// Yapı: leaderboards/{gameId}/scores/{uid}
  CollectionReference<Map<String, dynamic>> _scoresRef(String gameId) =>
      _db.collection('leaderboards').doc(gameId).collection('scores');

  /// Kullanıcının skorunu gönderir.
  /// Eğer mevcut skoru daha iyiyse güncelleme yapılmaz.
  ///
  /// [gameId]: 'minesweeper', '2048', 'quiz'
  /// [higherIsBetter]: true → yüksek skor daha iyi (2048, quiz)
  ///                   false → düşük skor daha iyi (minesweeper süre)
  Future<bool> submitScore({
    required String gameId,
    required String uid,
    required String displayName,
    required int score,
    bool higherIsBetter = true,
  }) async {
    final docRef = _scoresRef(gameId).doc(uid);
    bool isNewBest = true;

    try {
      final existing = await docRef.get();
      if (existing.exists) {
        final oldScore = existing.data()?['score'] as int? ?? 0;
        if (higherIsBetter) {
          isNewBest = score > oldScore;
        } else {
          isNewBest = score < oldScore;
        }
      }
    } catch (e) {
      // Okuma izni yoksa veya bağlantı koptuysa hata verir.
      // Bu durumda skoru Firestore'a her halükarda yazmayı denemeliyiz.
      debugPrint('⚠️ Firestore submitScore okuma uyarısı: $e');
    }

    if (isNewBest) {
      // SetOptions(merge: true) ile varsa sadece güncelliyoruz.
      await docRef.set({
        'uid': uid,
        'display_name': displayName.isNotEmpty ? displayName : 'Anonim',
        'score': score,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('🏆 Leaderboard: Yeni en iyi skor → $gameId: $score');
    }

    return isNewBest;
  }

  /// Skor tablosunu getirir (en iyi N skor).
  ///
  /// [higherIsBetter]: true → azalan sıra, false → artan sıra
  Future<List<Map<String, dynamic>>> getLeaderboard(
    String gameId, {
    int limit = 50,
    bool higherIsBetter = true,
  }) async {
    // Hataları yukarı fırlat — LeaderboardService loglar
    final snapshot = await _scoresRef(gameId)
        .orderBy('score', descending: higherIsBetter)
        .limit(limit)
        .get();

    return snapshot.docs.asMap().entries.map((entry) {
      final raw = entry.value.data();
      // Rank'i yeni map'e ekle — mevcut map'i mutate etme
      return <String, dynamic>{...raw, 'rank': entry.key + 1};
    }).toList();
  }

  /// Kullanıcının belirli bir oyundaki en iyi skorunu getirir.
  /// Hataları yukarı fırlatır — çağıran handle eder.
  Future<int?> getUserBestScore(String gameId, String uid) async {
    final doc = await _scoresRef(gameId).doc(uid).get();
    if (!doc.exists) return null;
    return doc.data()?['score'] as int?;
  }
}
