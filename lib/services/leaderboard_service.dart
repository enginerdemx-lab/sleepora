import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_service.dart';

/// Leaderboard Servisi
///
/// Firestore + SharedPreferences dual katmanlı skor tablosu.
/// Firestore erişilemezse (güvenlik kuralları, offline vb.)
/// local skorları kullanır — kullanıcı deneyimi asla bozulmaz.
///
/// Kullanım:
///   await LeaderboardService().submitScore(gameId: '2048', ...);
///   final scores = await LeaderboardService().getLeaderboard('2048');
class LeaderboardService {
  static final LeaderboardService _instance = LeaderboardService._internal();
  factory LeaderboardService() => _instance;
  LeaderboardService._internal();

  final _fs = FirestoreService();

  // ─── SharedPreferences key formatı ───
  String _localKey(String gameId) => 'leaderboard_$gameId';

  // ═══════════════════════════════════════════════════════
  // Skor Gönderme
  // ═══════════════════════════════════════════════════════

  /// Skoru hem local'e hem Firestore'a gönderir.
  /// Firestore başarısız olsa bile local'e yazılır.
  Future<bool> submitScore({
    required String gameId,
    required String uid,
    required String displayName,
    required int score,
    bool higherIsBetter = true,
  }) async {
    // 1. Local'e yaz (asla başarısız olmaz)
    final isLocalBest = await _saveLocal(
      gameId: gameId,
      uid: uid,
      displayName: displayName,
      score: score,
      higherIsBetter: higherIsBetter,
    );

    // 2. Firestore'a da göndermeye çalış (arka plan)
    try {
      await _fs.submitScore(
        gameId: gameId,
        uid: uid,
        displayName: displayName,
        score: score,
        higherIsBetter: higherIsBetter,
      );
      debugPrint('🏆 Leaderboard: Firestore + Local yazıldı → $gameId | skor: $score | uid: $uid');
    } catch (e) {
      // Firestore erişim hatası — genellikle güvenlik kuralı eksik
      // Firebase Console → Firestore → Rules bölümünde
      // leaderboards koleksiyonuna izin verildiğinden emin ol.
      debugPrint('❌ Leaderboard: Firestore yazılamadı → $e');
      debugPrint('   ↳ Kontrol et: Firebase Console → Firestore → Rules → leaderboards koleksiyonu');
    }

    return isLocalBest;
  }

  // ═══════════════════════════════════════════════════════
  // Skor Tablosu Okuma
  // ═══════════════════════════════════════════════════════

  /// Skor tablosunu getirir. Önce Firestore'u dener,
  /// başarısız olursa local verileri döner.
  Future<List<Map<String, dynamic>>> getLeaderboard(
    String gameId, {
    int limit = 50,
    bool higherIsBetter = true,
  }) async {
    // 1. Firestore'dan dene
    try {
      final firestoreScores = await _fs.getLeaderboard(
        gameId,
        limit: limit,
        higherIsBetter: higherIsBetter,
      );
      if (firestoreScores.isNotEmpty) {
        debugPrint('📊 Leaderboard: Firestore\'dan ${firestoreScores.length} skor çekildi');
        return firestoreScores;
      }
      // Firestore boş — henüz skor yok veya rules izin vermiyor
      debugPrint('📊 Leaderboard: Firestore boş döndü (henüz skor yok?) → local\'e fallback');
    } catch (e) {
      // Firestore okuma hatası — en sık neden: güvenlik kuralı eksik
      debugPrint('❌ Leaderboard: Firestore okunamadı → $e');
      debugPrint('   ↳ Kontrol et: Firebase Console → Firestore → Rules → leaderboards koleksiyonu');
    }

    // 2. Firestore başarısızsa veya boşsa local'den oku
    final localScores = await _getLocal(gameId, higherIsBetter: higherIsBetter);
    debugPrint('📊 Leaderboard: Local\'den ${localScores.length} skor okundu (sadece bu cihaz)');
    return localScores.take(limit).toList();
  }

  /// Kullanıcının en iyi skorunu getirir.
  Future<int?> getUserBestScore(String gameId, String uid) async {
    // Firestore'dan dene
    try {
      final firestoreBest = await _fs.getUserBestScore(gameId, uid);
      if (firestoreBest != null) return firestoreBest;
    } catch (e) {
      debugPrint('❌ Leaderboard: Firestore best skor okunamadı → $e');
    }

    // Local'den oku
    final localScores = await _getLocal(gameId);
    for (final s in localScores) {
      if (s['uid'] == uid) return s['score'] as int?;
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════
  // Local (SharedPreferences) İşlemleri
  // ═══════════════════════════════════════════════════════

  /// Local'e skor yaz. Kullanıcının en iyi skorunu tut.
  Future<bool> _saveLocal({
    required String gameId,
    required String uid,
    required String displayName,
    required int score,
    required bool higherIsBetter,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _localKey(gameId);
    final raw = prefs.getString(key);
    
    List<Map<String, dynamic>> scores = [];
    if (raw != null) {
      scores = List<Map<String, dynamic>>.from(
        (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)),
      );
    }

    // Mevcut skoru bul
    final existingIndex = scores.indexWhere((s) => s['uid'] == uid);
    bool isNewBest = true;

    if (existingIndex >= 0) {
      final oldScore = scores[existingIndex]['score'] as int;
      if (higherIsBetter) {
        isNewBest = score > oldScore;
      } else {
        isNewBest = score < oldScore;
      }
      if (isNewBest) {
        scores[existingIndex] = {
          'uid': uid,
          'display_name': displayName,
          'score': score,
          'updated_at': DateTime.now().toIso8601String(),
        };
      }
    } else {
      scores.add({
        'uid': uid,
        'display_name': displayName,
        'score': score,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    await prefs.setString(key, jsonEncode(scores));
    return isNewBest;
  }

  /// Local skorları sıralı olarak döner.
  Future<List<Map<String, dynamic>>> _getLocal(
    String gameId, {
    bool higherIsBetter = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localKey(gameId));
    if (raw == null) return [];

    final scores = List<Map<String, dynamic>>.from(
      (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)),
    );

    // Sırala
    scores.sort((a, b) {
      final aScore = a['score'] as int;
      final bScore = b['score'] as int;
      return higherIsBetter ? bScore.compareTo(aScore) : aScore.compareTo(bScore);
    });

    // Sıralama numarası ekle
    for (int i = 0; i < scores.length; i++) {
      scores[i]['rank'] = i + 1;
    }

    return scores;
  }
}
