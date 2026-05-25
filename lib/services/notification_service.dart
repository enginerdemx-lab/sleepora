import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/material.dart';
import 'localization_service.dart';

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

  /// Ana uyku hatırlatıcısı + (opsiyonel) hazırlık hatırlatıcısı planlar.
  ///
  /// [time] ana hatırlatma saati (uyku vakti).
  /// [preReminderEnabled] true ise [preReminderMinutesBefore] dakika öncesinde
  /// ekstra "hazırlık" bildirimi gönderir (banyo / loş ışık / rutine başla
  /// motivasyonu).
  ///
  /// Önceki tüm bildirimleri iptal edip yeniden planlar (idempotent).
  Future<void> scheduleSleepReminder(
    TimeOfDay time, {
    bool preReminderEnabled = false,
    int preReminderMinutesBefore = 15,
  }) async {
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

    // Sadece reminder ID'lerini iptal et (id=0 ana, id=1 ön-hatırlatma).
    // Trial reminder (id=2) gibi diğer bildirimleri etkileme.
    await _notificationsPlugin.cancel(id: 0);
    await _notificationsPlugin.cancel(id: 1);

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final loc = LocalizationService();
    final androidDetails = AndroidNotificationDetails(
      'sleepora_reminder',
      loc.t('NotifReminderChannel'),
      channelDescription: loc.t('NotifReminderChannelDesc'),
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: 'ic_notification', // Beyaz/şeffaf bildirim ikonu (drawable/ic_notification.xml)
    );

    const iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notifDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    // ── Ana hatırlatma (id=0) ──
    await _notificationsPlugin.zonedSchedule(
      id: 0,
      title: loc.t('NotifReminderTitle'),
      body: loc.t('NotifReminderBody'),
      scheduledDate: scheduledDate,
      notificationDetails: notifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // ── Hazırlık hatırlatması (id=1) ──
    if (preReminderEnabled && preReminderMinutesBefore > 0) {
      var preDate = scheduledDate.subtract(Duration(minutes: preReminderMinutesBefore));
      // Eğer bu zaman geçmişte kaldıysa bir gün ileri al
      if (preDate.isBefore(now)) {
        preDate = preDate.add(const Duration(days: 1));
      }

      final preAndroidDetails = AndroidNotificationDetails(
        'sleepora_reminder_pre',
        loc.t('NotifPreChannel'),
        channelDescription: loc.t('NotifPreChannelDesc'),
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: 'ic_notification',
      );

      const preIOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final preNotifDetails = NotificationDetails(
        android: preAndroidDetails,
        iOS: preIOSDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        id: 1,
        title: loc.t('NotifPreTitle'),
        body: loc.t('NotifPreBody').replaceAll('{n}', '$preReminderMinutesBefore'),
        scheduledDate: preDate,
        notificationDetails: preNotifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  /// Sadece reminder bildirimlerini (id=0 ve id=1) iptal eder.
  /// Trial reminder gibi diğer bildirimleri etkilemez.
  Future<void> cancelReminder() async {
    if (!_initialized) return;
    await _notificationsPlugin.cancel(id: 0);
    await _notificationsPlugin.cancel(id: 1);
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

    final loc = LocalizationService();
    final androidDetails = AndroidNotificationDetails(
      'sleepora_trial_reminder',
      loc.t('NotifTrialChannel'),
      channelDescription: loc.t('NotifTrialChannelDesc'),
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: 'ic_notification', // Beyaz/şeffaf bildirim ikonu (drawable/ic_notification.xml)
    );

    const iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notifDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      id: 2,
      title: loc.t('NotifTrialTitle'),
      body: loc.t('NotifTrialBody'),
      scheduledDate: scheduledDate,
      notificationDetails: notifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}
