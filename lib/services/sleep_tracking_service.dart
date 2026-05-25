import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'firestore_service.dart';

// ─── Uyku Oturumu Modeli ───
class SleepSession {
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final String soundName;
  final String date; // YYYY-MM-DD

  SleepSession({
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.soundName,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'duration_minutes': durationMinutes,
        'sound_name': soundName,
        'date': date,
        // Yerel saati ayrıca kaydet — UTC dönüşüm sorunlarını önlemek için
        'local_hour': startTime.toLocal().hour,
      };

  static SleepSession fromMap(Map<String, dynamic> map) {
    final parsed = DateTime.parse(map['start_time'] as String);
    return SleepSession(
      // Yerel zaman dilimine dönüştür — istatistiklerde doğru saat gösterimi için
      startTime: parsed.toLocal(),
      endTime: DateTime.parse(map['end_time'] as String).toLocal(),
      durationMinutes: (map['duration_minutes'] as num).toInt(),
      soundName: map['sound_name'] as String? ?? '',
      date: map['date'] as String? ?? '',
    );
  }
}

// ─── 7 Günlük Özet ───
class WeeklyStats {
  final List<DayStat> days; // 7 gün (en eski → en yeni)
  final int totalMinutes;
  final int sessionCount;
  final int avgMinutes;
  final int streakDays;
  final SleepSession? lastSession;
  /// Oturumların genellikle başladığı saat (0-23). Yeterli veri yoksa null.
  final int? preferredHour;
  /// En çok kullanılan ses adı ve toplam süresi (dakika).
  final String? topSoundName;
  final int topSoundMinutes;
  /// Bugün başlayan tüm uyutma oturumları (eski → yeni sıralı).
  /// "Bugün bebeği kaç defa, hangi saatlerde uyuttunuz?" cevabını verir.
  final List<SleepSession> todaySessions;
  /// 24-bucket histogram: i. eleman = saatte başlayan oturum sayısı (0=00:00…23=23:00).
  /// Hangi saatlerde sıkça uyutma yapıldığını gösteren saatlik ısı dağılımı.
  final List<int> hourHistogram;
  /// Gün → o güne ait oturumların listesi (drill-down için).
  /// Anahtar formatı `YYYY-MM-DD`.
  final Map<String, List<SleepSession>> sessionsByDay;

  WeeklyStats({
    required this.days,
    required this.totalMinutes,
    required this.sessionCount,
    required this.avgMinutes,
    required this.streakDays,
    this.lastSession,
    this.preferredHour,
    this.topSoundName,
    this.topSoundMinutes = 0,
    this.todaySessions = const [],
    this.hourHistogram = const [],
    this.sessionsByDay = const {},
  });
}

class DayStat {
  final String date; // YYYY-MM-DD
  final int totalMinutes;
  final int sessionCount;
  DayStat({required this.date, required this.totalMinutes, required this.sessionCount});
}

// ─── Servis ───
class SleepTrackingService {
  static final SleepTrackingService _instance = SleepTrackingService._internal();
  factory SleepTrackingService() => _instance;
  SleepTrackingService._internal();

  String? _currentSoundName;
  DateTime? _sessionStart;

  /// Minimum kayıt edilecek süre (dakika)
  static const int _minDurationMinutes = 1;

  bool get isTracking => _sessionStart != null;

  /// Ses çalmaya başlayınca çağrılır — oturum başlatır.
  void startSession(String soundName) {
    _currentSoundName = soundName;
    _sessionStart = DateTime.now();
    debugPrint('🌙 Uyku takibi başladı → $soundName');
  }

  /// Ses durduğunda çağrılır — oturumu kaydeder.
  Future<void> endSession() async {
    if (_sessionStart == null || _currentSoundName == null) return;

    final end = DateTime.now();
    final duration = end.difference(_sessionStart!).inMinutes;

    // Minimum süreye ulaşılmadıysa kaydetme
    if (duration < _minDurationMinutes) {
      _reset();
      debugPrint('🌙 Oturum çok kısa ($duration dk), kaydedilmedi');
      return;
    }

    final session = SleepSession(
      startTime: _sessionStart!,
      endTime: end,
      durationMinutes: duration,
      soundName: _currentSoundName!,
      date: _dateString(_sessionStart!),
    );

    _reset();
    debugPrint('🌙 Uyku oturumu kaydediliyor → ${session.durationMinutes} dk');

    final uid = AuthService().currentUser?.uid;
    if (uid != null) {
      await FirestoreService().saveSleepSession(uid, session.toMap());
    }
  }

  /// Son 7 günlük istatistikleri getirir.
  Future<WeeklyStats> getWeeklyStats() async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return _emptyStats();

    final rawList = await FirestoreService().getSleepSessions(uid, days: 7);
    final sessions = rawList
        .map((m) {
          try {
            return SleepSession.fromMap(m);
          } catch (_) {
            return null;
          }
        })
        .whereType<SleepSession>()
        .toList();

    return _computeStats(sessions);
  }

  // ─── Yardımcılar ───

  void _reset() {
    _sessionStart = null;
    _currentSoundName = null;
  }

  String _dateString(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  WeeklyStats _emptyStats() => WeeklyStats(
        days: _buildEmptyDays(),
        totalMinutes: 0,
        sessionCount: 0,
        avgMinutes: 0,
        streakDays: 0,
        lastSession: null,
        todaySessions: const [],
        hourHistogram: List<int>.filled(24, 0),
        sessionsByDay: const {},
      );

  List<DayStat> _buildEmptyDays() {
    final today = DateTime.now();
    return List.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      return DayStat(date: _dateString(d), totalMinutes: 0, sessionCount: 0);
    });
  }

  WeeklyStats _computeStats(List<SleepSession> sessions) {
    final today = DateTime.now();
    final todayKey = _dateString(today);

    // Gün bazında grupla
    final Map<String, List<SleepSession>> byDay = {};
    for (final s in sessions) {
      byDay.putIfAbsent(s.date, () => []).add(s);
    }
    // Her gün içindeki oturumları başlangıç zamanına göre sırala
    for (final list in byDay.values) {
      list.sort((a, b) => a.startTime.compareTo(b.startTime));
    }

    // Son 7 gün listesi (Pzt - Paz yerine sıralı)
    final days = List.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      final key = _dateString(d);
      final daySessions = byDay[key] ?? [];
      return DayStat(
        date: key,
        totalMinutes: daySessions.fold(0, (sum, s) => sum + s.durationMinutes),
        sessionCount: daySessions.length,
      );
    });

    // Bugünkü uyutmalar (start time sıralı)
    final todaySessions = List<SleepSession>.from(byDay[todayKey] ?? const [])
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    // 24-bucket saatlik histogram (haftanın tüm oturumları için)
    final hourHistogram = List<int>.filled(24, 0);
    for (final s in sessions) {
      final h = s.startTime.toLocal().hour.clamp(0, 23);
      hourHistogram[h] = hourHistogram[h] + 1;
    }

    final totalMinutes = sessions.fold(0, (sum, s) => sum + s.durationMinutes);
    final sessionCount = sessions.length;
    final avgMinutes = sessionCount > 0 ? totalMinutes ~/ sessionCount : 0;

    // Streak hesapla (üst üste uyku olan gün sayısı, bugünden geriye)
    int streak = 0;
    for (int i = 6; i >= 0; i--) {
      if (days[i].sessionCount > 0) {
        streak++;
      } else {
        break;
      }
    }

    // Son oturum
    final lastSession = sessions.isNotEmpty ? sessions.last : null;

    // Tercih edilen saat: gece yarısı geçişini doğru ele almak için dairesel ortalama.
    // .toLocal() ile her zaman yerel saat kullanılır — UTC karışıklığını önler.
    int? preferredHour;
    if (sessions.length >= 2) {
      double sinSum = 0;
      double cosSum = 0;
      for (final s in sessions) {
        // Dakikaları da dahil et — daha hassas sonuç
        final localTime = s.startTime.toLocal();
        final hourFraction = localTime.hour + localTime.minute / 60.0;
        final angle = 2 * math.pi * hourFraction / 24;
        sinSum += math.sin(angle);
        cosSum += math.cos(angle);
      }
      final avgAngle = math.atan2(sinSum / sessions.length, cosSum / sessions.length);
      final rawHour = (avgAngle / (2 * math.pi) * 24).round() % 24;
      preferredHour = rawHour < 0 ? rawHour + 24 : rawHour;
    }

    // En çok kullanılan ses (toplam dakikaya göre)
    String? topSoundName;
    int topSoundMinutes = 0;
    if (sessions.isNotEmpty) {
      final Map<String, int> minutesBySound = {};
      for (final s in sessions) {
        minutesBySound[s.soundName] =
            (minutesBySound[s.soundName] ?? 0) + s.durationMinutes;
      }
      final topEntry = minutesBySound.entries
          .reduce((a, b) => a.value >= b.value ? a : b);
      topSoundName = topEntry.key;
      topSoundMinutes = topEntry.value;
    }

    return WeeklyStats(
      days: days,
      totalMinutes: totalMinutes,
      sessionCount: sessionCount,
      avgMinutes: avgMinutes,
      streakDays: streak,
      lastSession: lastSession,
      preferredHour: preferredHour,
      topSoundName: topSoundName,
      topSoundMinutes: topSoundMinutes,
      todaySessions: todaySessions,
      hourHistogram: hourHistogram,
      sessionsByDay: byDay,
    );
  }
}
