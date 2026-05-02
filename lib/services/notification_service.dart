import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Use explicit Jakarta location — avoids tz.local being UTC on device
  static tz.Location get _jakartaLocation => tz.getLocation('Asia/Jakarta');

  static const _channelId = 'reminder_channel';
  static const _channelName = 'Reminders';

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    ),
    iOS: DarwinNotificationDetails(),
    macOS: DarwinNotificationDetails(),
  );

  // ─── Init ────────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    if (kIsWeb) {
      debugPrint('[Notif] Web — skipping init.');
      return;
    }

    const initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initDarwin = DarwinInitializationSettings();
    const initLinux = LinuxInitializationSettings(defaultActionName: 'Open');

    await _notifications.initialize(
      const InitializationSettings(
        android: initAndroid,
        iOS: initDarwin,
        macOS: initDarwin,
        linux: initLinux,
      ),
    );

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    final granted = await androidPlugin?.requestNotificationsPermission();
    debugPrint('[Notif] POST_NOTIFICATIONS granted=$granted');

    // Required for Android 14+ — requests SCHEDULE_EXACT_ALARM at runtime
    await androidPlugin?.requestExactAlarmsPermission();
    debugPrint('[Notif] Exact alarm permission requested.');
  }

  // ─── Immediate notification (for testing) ────────────────────────────────────

  static Future<bool> showImmediateNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return false;
    try {
      await _notifications.show(9999, title, body, _details);
      debugPrint('[Notif] Immediate fired: "$title"');
      return true;
    } catch (e) {
      debugPrint('[Notif] Immediate FAILED: $e');
      return false;
    }
  }

  // ─── Core scheduler using flutter_local_notifications zonedSchedule ──────────

  static Future<bool> _schedule(int id, String title, String body, DateTime when) async {
    if (kIsWeb) return false;
    if (when.isBefore(DateTime.now())) {
      debugPrint('[Notif] SKIP (past) id=$id  when=$when');
      return false;
    }

    // Convert using the explicit Jakarta timezone — avoids tz.local UTC bug
    final tzWhen = tz.TZDateTime.from(when, _jakartaLocation);

    debugPrint('[Notif] Schedule id=$id  title="$title"');
    debugPrint('[Notif]   now  = ${DateTime.now()}');
    debugPrint('[Notif]   when = $tzWhen (${_jakartaLocation.name})');

    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tzWhen,
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('[Notif] ✓ Scheduled id=$id');
      return true;
    } catch (e) {
      debugPrint('[Notif] ✗ Schedule FAILED id=$id: $e');
      return false;
    }
  }

  // ─── Deadline feature ────────────────────────────────────────────────────────
  //
  // Schedules up to 2 notifications:
  //   • Urgent warning: fires 1 minute from now  (always, if deadline still future)
  //   • Exact deadline: fires at the deadline moment
  //
  // The "1 minute from now" acts as an immediate confirmation that scheduling works,
  // AND as the H-3 urgent ping when deadline < 3 days away.

  static Future<String> scheduleDeadlineNotifications({
    required int id,
    required String title,
    required DateTime deadline,
  }) async {
    final now = DateTime.now();
    final formatted = DateFormat('dd MMM yyyy, HH:mm').format(deadline);
    debugPrint('[Notif] scheduleDeadline  title="$title"  deadline=$deadline  now=$now');

    if (deadline.isBefore(now)) {
      debugPrint('[Notif] Deadline already passed — nothing scheduled.');
      return 'Deadline sudah lewat, notifikasi tidak dijadwalkan.';
    }

    // 1. Exact deadline notification
    final exactOk = await _schedule(
      id,
      '⏰ Deadline: $title',
      'Tenggat waktu tugas ini telah tiba!',
      deadline,
    );

    // 2. Warning notification
    final threeDaysBefore = deadline.subtract(const Duration(days: 3));
    bool warningOk = false;

    if (threeDaysBefore.isAfter(now)) {
      // Deadline is > 3 days away — schedule H-3 warning
      warningOk = await _schedule(
        id + 10000,
        '📅 Pengingat Deadline: $title',
        'Tenggat waktu tugas ini tinggal 3 hari lagi!',
        threeDaysBefore,
      );
    } else {
      // Deadline is < 3 days away — fire urgent warning in 1 minute
      warningOk = await _schedule(
        id + 10000,
        '🚨 Tugas Mendesak: $title',
        'Tenggat waktu tugas ini sangat dekat! Deadline: $formatted',
        now.add(const Duration(minutes: 1)),
      );
    }

    final msg = 'Notifikasi deadline dijadwalkan untuk $formatted';
    debugPrint('[Notif] Result: exact=$exactOk  warning=$warningOk');
    return msg;
  }
}
