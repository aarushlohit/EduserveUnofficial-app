import 'package:eduserveapp/core/constants/app_config.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppNotification {
  const AppNotification({
    required this.title,
    required this.message,
    required this.timestamp,
    this.read = false,
  });

  final String title;
  final String message;
  final DateTime timestamp;
  final bool read;

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      title: title,
      message: message,
      timestamp: timestamp,
      read: read ?? this.read,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NotificationService
// ─────────────────────────────────────────────────────────────────────────────

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final List<AppNotification> _inAppNotifications = <AppNotification>[];

  List<AppNotification> get inAppNotifications =>
      List<AppNotification>.unmodifiable(_inAppNotifications);

  bool get hasUnread => _inAppNotifications.any((n) => !n.read);

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
    _seedInAppNotifications();
    await _initFirebaseMessaging();
  }

  Future<void> _initFirebaseMessaging() async {
    if (!_supportsFirebaseMessaging()) {
      return;
    }

    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await _messaging.getToken().timeout(
            const Duration(seconds: 8),
            onTimeout: () => null,
          );
      if (token != null && token.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConfig.fcmTokenKey, token);
      }

      await _messaging.subscribeToTopic('hackathons').timeout(
            const Duration(seconds: 8),
          );
    } catch (error, stackTrace) {
      debugPrint('[notifications] FCM setup skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final title = message.notification?.title ?? 'EduServe Companion';
      final body = message.notification?.body ?? 'You have a new notification';

      _pushInAppNotification(title: title, message: body);

      await showNow(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final title = message.notification?.title ?? 'EduServe Companion';
      final body = message.notification?.body ?? 'Opened from push message';
      _pushInAppNotification(title: title, message: body);
    });
  }

  bool _supportsFirebaseMessaging() {
    if (kIsWeb) {
      return true;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return false;
    }
  }

  void _pushInAppNotification(
      {required String title, required String message}) {
    _inAppNotifications.insert(
      0,
      AppNotification(
        title: title,
        message: message,
        timestamp: DateTime.now(),
      ),
    );
  }

  void _seedInAppNotifications() {
    // Notifications are sourced from Firestore + FCM.
  }

  void markAllAsRead() {
    for (var i = 0; i < _inAppNotifications.length; i++) {
      _inAppNotifications[i] = _inAppNotifications[i].copyWith(read: true);
    }
  }

  // ── Permissions ────────────────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final result = await android?.requestNotificationsPermission() ?? false;
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
