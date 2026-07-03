import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Admin panelden yönetilen uzaktan yapılandırma.
///
/// Firestore: `config/app` dokümanını okur (uygulamayı yeniden yayınlamadan
/// premium ses listesi, ücretsiz limitler ve duyuru değiştirilebilir).
/// Tüm değerlerin güvenli varsayılanı vardır — config yoksa/çevrimdışıysa
/// uygulama eski davranışıyla çalışır.
class RemoteConfigService extends ChangeNotifier {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  Map<String, dynamic> _data = {};

  // ── Varsayılanlar (mevcut hardcoded değerlerle birebir) ──
  static const List<String> _defaultPremiumSounds = [
    'Kolik', 'Pış Pış 2', 'Yıldız Tozu', 'Konuşma', 'Tren', 'Çamaşır Makinesi',
  ];

  List<String> get premiumSounds {
    final v = _data['premium_sounds'];
    if (v is List && v.isNotEmpty) {
      return v.map((e) => e.toString()).toList();
    }
    return _defaultPremiumSounds;
  }

  int get freeFavoriteLimit => _asInt('free_favorite_limit', 3);
  int get freeMixerLimit => _asInt('free_mixer_limit', 2);
  int get freeTimerMinutes => _asInt('free_timer_minutes', 45);

  bool get announcementEnabled => _data['announcement_enabled'] == true;
  String get announcementText {
    final v = _data['announcement_text'];
    return v is String ? v : '';
  }

  int _asInt(String key, int fallback) {
    final v = _data[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return fallback;
  }

  /// Açılışta çağrılır. Önce yerel önbellekten, sonra Firestore'dan yükler.
  Future<void> init() async {
    // 1) Önbellek (çevrimdışı / hızlı ilk render)
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('remote_config_json');
      if (cached != null) {
        final decoded = jsonDecode(cached);
        if (decoded is Map<String, dynamic>) _data = decoded;
      }
    } catch (_) {}

    // 2) Firestore'dan güncel config
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('app')
          .get();
      if (doc.exists && doc.data() != null) {
        _data = doc.data()!;
        notifyListeners();
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('remote_config_json', jsonEncode(_data));
        } catch (_) {
          // Encode edilemeyen alan (ör. Timestamp) varsa önbelleği atla.
        }
      }
    } catch (e) {
      debugPrint('❌ RemoteConfig yükleme hatası: $e');
    }
  }
}
