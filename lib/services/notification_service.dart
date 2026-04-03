import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    tz.initializeTimeZones();

    // Cihazın gerçek saat dilimini al ve ayarla (olmadan tz.local = UTC kalır)
    try {
      final String localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone));
    } catch (_) {}

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwin = DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );

    const initSettings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );

    try {
      await _notificationsPlugin.initialize(settings: initSettings);
      _initialized = true;
    } catch (_) {
      _initialized = false;
    }
  }

  Future<void> scheduleSleepReminder(TimeOfDay time) async {
    if (!_initialized) return;

    // Check and request iOS permissions before scheduling
    final iOSImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iOSImplementation != null) {
      await iOSImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    await _notificationsPlugin.cancelAll();

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'sleepora_reminder',
      'Uyku Hatırlatıcısı',
      channelDescription: 'Bebeğinizin uyku saati geldi.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notifDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      id: 0,
      title: 'Uyku Vakti!',
      body: 'Bebeğinizin uyku rutinini başlatma saati geldi.',
      scheduledDate: scheduledDate,
      notificationDetails: notifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelReminder() async {
    if (!_initialized) return;
    await _notificationsPlugin.cancelAll();
  }

  /// Deneme süresi hatırlatıcısı — 5 gün sonra bildirim gönderir
  Future<void> scheduleTrialEndReminder() async {
    if (!_initialized) return;

    // iOS izin iste
    final iOSImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iOSImpl != null) {
      await iOSImpl.requestPermissions(alert: true, badge: true, sound: true);
    }

    final scheduledDate = tz.TZDateTime.now(tz.local).add(const Duration(days: 5));

    const androidDetails = AndroidNotificationDetails(
      'sleepora_trial_reminder',
      'Deneme Hatırlatıcısı',
      channelDescription: 'Sleepora Plus deneme süresi hatırlatıcısı.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notifDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      id: 2,
      title: '⏰ Deneme süreniz bitiyor!',
      body: 'Sleepora Plus denemenizin bitmesine 2 gün kaldı. Tüm özelliklere erişmeye devam etmek için abone olun.',
      scheduledDate: scheduledDate,
      notificationDetails: notifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}
