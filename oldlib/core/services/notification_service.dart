import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NotificationService
// ─────────────────────────────────────────────────────────────────────────────

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // ── Initialise ─────────────────────────────────────────────────────────────

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  // ── Permissions ────────────────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final result =
        await android?.requestNotificationsPermission() ?? false;
    return result;
  }

  // ── Immediate notification ─────────────────────────────────────────────────

  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const android = AndroidNotificationDetails(
      'eduserve_channel',
      'EduServe Alerts',
      channelDescription: 'Assignment due dates and portal alerts',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const ios = DarwinNotificationDetails();
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: android, iOS: ios),
      payload: payload,
    );
  }

  // ── Scheduled notifications ────────────────────────────────────────────────

  /// Schedule a reminder one day before an assignment is due.
  Future<void> scheduleAssignmentReminder({
    required int id,
    required String subject,
    required DateTime dueDate,
  }) async {
    final formattedDate = DateFormat('d MMM').format(dueDate);
    final reminderDate = dueDate.subtract(const Duration(days: 1));
    if (reminderDate.isBefore(DateTime.now())) return;

    const android = AndroidNotificationDetails(
      'eduserve_assignments',
      'Assignment Reminders',
      channelDescription: 'Reminders for upcoming assignment due dates',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _plugin.show(
      id,
      'Assignment Due Tomorrow',
      '$subject assignment is due on $formattedDate',
      const NotificationDetails(
        android: android,
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  // ── Attendance alert ───────────────────────────────────────────────────────

  Future<void> showLowAttendanceAlert(String subject, double percent) async {
    await showNow(
      id: subject.hashCode,
      title: '⚠ Low Attendance',
      body:
          '$subject attendance is at ${percent.toStringAsFixed(1)}%. Minimum required is 75%.',
      payload: 'attendance',
    );
  }

  // ── Cancel ─────────────────────────────────────────────────────────────────

  Future<void> cancel(int id) => _plugin.cancel(id);
  Future<void> cancelAll() => _plugin.cancelAll();
}
