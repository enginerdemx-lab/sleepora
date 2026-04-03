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
      };

  static SleepSession fromMap(Map<String, dynamic> map) => SleepSession(
        startTime: DateTime.parse(map['start_time'] as String),
        endTime: DateTime.parse(map['end_time'] as String),
        durationMinutes: (map['duration_minutes'] as num).toInt(),
        soundName: map['sound_name'] as String? ?? '',
        date: map['date'] as String? ?? '',
      );
}

// ─── 7 Günlük Özet ───
class WeeklyStats {
  final List<DayStat> days; // 7 gün (en eski → en yeni)
  final int totalMinutes;
  final int sessionCount;
  final int avgMinutes;
  final int streakDays;
  final SleepSession? lastSession;

  WeeklyStats({
    required this.days,
    required this.totalMinutes,
    required this.sessionCount,
    required this.avgMinutes,
    required this.streakDays,
    this.lastSession,
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

    // Gün bazında grupla
    final Map<String, List<SleepSession>> byDay = {};
    for (final s in sessions) {
      byDay.putIfAbsent(s.date, () => []).add(s);
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

    return WeeklyStats(
      days: days,
      totalMinutes: totalMinutes,
      sessionCount: sessionCount,
      avgMinutes: avgMinutes,
      streakDays: streak,
      lastSession: lastSession,
    );
  }
}
