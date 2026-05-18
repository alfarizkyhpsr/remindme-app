import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

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

  // ─── Init ─────────────────────────────────────────────────────────────────

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

  // Semua dalam satu baris — jangan pisah generic type dengan newline
  final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  final granted = await androidPlugin?.requestNotificationsPermission();
  debugPrint('[Notif] POST_NOTIFICATIONS granted=$granted');

  await androidPlugin?.requestExactAlarmsPermission();
  debugPrint('[Notif] Exact alarm permission requested.');
}

  // ─── Cek apakah exact alarm tersedia ──────────────────────────────────────

static Future<bool> _canScheduleExact() async {
  if (kIsWeb) return false;

  // Semua dalam satu baris — jangan pisah generic type dengan newline
  final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  if (androidPlugin == null) return true;
  final canSchedule = await androidPlugin.canScheduleExactNotifications();
  debugPrint('[Notif] canScheduleExactAlarms=$canSchedule');
  return canSchedule ?? false;
}

  // ─── Immediate notification ────────────────────────────────────────────────

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

  // ─── Core scheduler ────────────────────────────────────────────────────────

  static Future<bool> _schedule(
      int id, String title, String body, DateTime when) async {
    if (kIsWeb) return false;

    final now = DateTime.now();
    if (when.isBefore(now)) {
      debugPrint('[Notif] SKIP (past) id=$id  when=$when');
      return false;
    }

    // FIX #1: Bangun TZDateTime dari komponen waktu secara eksplisit
    // (bukan via .from() yang bergantung pada millisecondsSinceEpoch + timezone device)
    // Ini memastikan "10:30 yang dipilih user" = "10:30 di Jakarta", titik.
    final tzWhen = tz.TZDateTime(
      _jakartaLocation,
      when.year,
      when.month,
      when.day,
      when.hour,
      when.minute,
      when.second,
    );

    debugPrint('[Notif] Schedule id=$id  title="$title"');
    debugPrint('[Notif]   now  = $now');
    debugPrint('[Notif]   when = $tzWhen (${_jakartaLocation.name})');

    // FIX #2: Cek apakah exact alarm bisa dijadwalkan
    final canExact = await _canScheduleExact();

    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tzWhen,
        _details,
        // FIX #3: Gunakan alarmClock — setara dengan alarm jam fisik,
        // paling tepat waktu, menembus Doze mode, tidak perlu runtime permission
        // di API 33+ (USE_EXACT_ALARM), cukup deklarasi di Manifest.
        // Fallback ke exactAllowWhileIdle jika exact tidak tersedia.
        androidScheduleMode: canExact
            ? AndroidScheduleMode.alarmClock
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint(
          '[Notif] ✓ Scheduled id=$id  mode=${canExact ? "alarmClock" : "inexact"}');
      return true;
    } catch (e) {
      debugPrint('[Notif] ✗ Schedule FAILED id=$id: $e');
      return false;
    }
  }

  // ─── Deadline feature ──────────────────────────────────────────────────────

  static Future<String> scheduleDeadlineNotifications({
    required int id,
    required String title,
    required DateTime deadline,
  }) async {
    final now = DateTime.now();
    final formatted = DateFormat('dd MMM yyyy, HH:mm').format(deadline);
    debugPrint(
        '[Notif] scheduleDeadline  title="$title"  deadline=$deadline  now=$now');

    if (deadline.isBefore(now)) {
      debugPrint('[Notif] Deadline already passed — nothing scheduled.');
      return 'Deadline sudah lewat, notifikasi tidak dijadwalkan.';
    }

    // 1. Notifikasi tepat saat deadline tiba
    final exactOk = await _schedule(
      id,
      '⏰ Deadline: $title',
      'Tenggat waktu tugas ini telah tiba!',
      deadline,
    );

    // 2. Notifikasi peringatan dini
    final threeDaysBefore = deadline.subtract(const Duration(days: 3));
    bool warningOk = false;

    if (threeDaysBefore.isAfter(now)) {
      // Deadline > 3 hari lagi — jadwalkan H-3
      warningOk = await _schedule(
        id + 10000,
        '📅 Pengingat Deadline: $title',
        'Tenggat waktu tugas ini tinggal 3 hari lagi!',
        threeDaysBefore,
      );
    } else {
      // Deadline < 3 hari — jadwalkan peringatan mendesak 1 menit dari sekarang
      warningOk = await _schedule(
        id + 10000,
        '🚨 Tugas Mendesak: $title',
        'Tenggat waktu tugas ini sangat dekat! Deadline: $formatted',
        now.add(const Duration(minutes: 1)),
      );
    }

    debugPrint('[Notif] Result: exact=$exactOk  warning=$warningOk');

    // FIX #4: Beri tahu user jika exact alarm tidak tersedia
    if (!exactOk && !warningOk) {
      return 'Notifikasi gagal dijadwalkan. Buka Pengaturan → Aplikasi → RemindMe+ → Izin Alarm untuk mengaktifkan.';
    }

    return 'Notifikasi deadline dijadwalkan untuk $formatted';
  }
}