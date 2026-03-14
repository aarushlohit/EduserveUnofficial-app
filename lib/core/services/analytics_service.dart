import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  Future<void> logAppOpen() async {
    await _analytics.logAppOpen();
    await _analytics.logEvent(name: 'app_open');
  }

  Future<void> logScreenView(String name) async {
    await _analytics.logScreenView(
      screenName: name,
      screenClass: name,
    );
  }

  Future<void> logEvent(String name) async {
    await _analytics.logEvent(name: name);
  }

  Future<void> logSignupCompleted() => logEvent('signup_completed');
  Future<void> logEduserveOpened() => logEvent('eduserve_opened');
  Future<void> logResultsOpened() => logEvent('results_opened');
  Future<void> logAiChatOpened() => logEvent('ai_chat_opened');
  Future<void> logAiMessageSent() => logEvent('ai_message_sent');
  Future<void> logNotificationOpened() => logEvent('notification_opened');
  Future<void> logAppShared() => logEvent('app_shared');
}
