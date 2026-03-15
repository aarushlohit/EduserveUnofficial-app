class AppConfig {
  AppConfig._();

    static const String appName = 'PocketEduServe';
  static const String appShareMessage =
      'Try EduServe Companion for faster EduServe access and semester utilities.';

  static const String onboardingCompleteKey = 'onboarding_complete';
  static const String themeModeKey = 'theme_mode';
  static const String profileDocIdKey = 'profile_doc_id';
  static const String profileSyncPendingKey = 'profile_sync_pending';
  static const String fcmTokenKey = 'fcm_token';
  static const int minSignupAge = 17;
  static const String kmailDomain = '@karunya.edu.in';
  static const String adminEmail = 'abhimanyu_dev@karunya.edu.in';

  static const String eduserveBaseUrl = 'https://eduserve.karunya.edu';
  static const String eduserveDashboardUrl =
      'https://eduserve.karunya.edu';
  static const String eduserveLoginUrl =
      'https://eduserve.karunya.edu/Account/Login';
  static const String addonsUrl =
      'https://eduserve.karunya.edu/Online/ExternalEvents.aspx';
  // Spoofed User-Agent that removes the Android "wv" WebView marker so
  // Google OAuth treats the InAppWebView as a standard Chrome browser.
    // Mobile Chrome UA (mirrors oldlib behavior and keeps OAuth happy)
    static const String desktopUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 7 Pro) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/120.0.0.0 Mobile Safari/537.36';

    static const String resultsUrl = 'https://web.karunya.edu/exam/results.asp';
  static const String authCallbackScheme = 'eduserve';

  static const String aiEndpoint =
      'https://gen.pollinations.ai/v1/chat/completions';
  static const String aiModel = 'openai';

    static const List<String> aiGreetings = <String>[
        'How can I help you today?',
        'Need help with assignments?',
        'Stuck with homework?',
        'Ready to solve something together?',
    ];

    static const List<String> loginGreetings = <String>[
        'Welcome back to PocketEduServe!',
        'Great to see you again!',
        'Let us make today productive.',
        'Your learning dashboard is ready.',
        'Time to unlock a great study session.',
        'Hello! PocketEduServe is ready for you.',
        'Another day, another achievement.',
        'You are all set. Keep building momentum.',
        'Your classes and tools are one tap away.',
        'Welcome! Let us crush your goals today.',
        'Glad you are here. Let us get started.',
        'Ready to check EduServe and results?',
        'Stay focused, stay consistent, keep winning.',
        'A smart study day starts now.',
        'PocketEduServe says hi!',
        'Welcome in. Your progress matters.',
        'Small steps today, big results tomorrow.',
        'Let us turn plans into completed tasks.',
        'You have got this. Keep going.',
        'Back again? Awesome. Let us learn.',
    ];

  // Firestore document that stores remote app version.
  static const String updateCollection = 'system';
  static const String updateDocument = 'app_config';
  static const String updateVersionField = 'latestVersion';
  static const String updateMinSupportedField = 'minSupportedVersion';
  static const String updateUpdatedAtField = 'updatedAt';
  static const String updateApkUrlField = 'apkUrl';

    static const String usersCollection = 'users';
    static const String notificationsCollection = 'notifications';
    static const String hackathonsCollection = 'hackathons';
    static const String userActivityCollection = 'user_activity';
    static const String appStatsCollection = 'app_stats';
    static const String analyticsDailyCollection = 'analytics_daily';
    static const String analyticsGlobalCollection = 'analytics_global';
    static const String analyticsGlobalDoc = 'app_stats';
    static const String analyticsConfigCollection = 'analytics_config';
    static const String analyticsLoggingDoc = 'logging';
    static const String postsCollection = 'posts';

    static const String notificationLastSeenKey = 'notifications_last_seen_ms';
    static const String dailyCleanupLastRunKey = 'daily_cleanup_last_run';
    static const String localGreetingFeedKey = 'local_greeting_feed';
    static const String lastActiveDayKey = 'last_active_day';
    static const String lastUserCountDayKey = 'last_user_count_day';

    // Optional relay endpoint to send topic notifications from trusted backend.
    // Keep empty in client-only mode.
    static const String topicPushRelayEndpoint = '';

    // Avatar presets for onboarding selection.
    static const List<String> avatarPresets = <String>[
      'https://api.dicebear.com/8.x/thumbs/svg?seed=aurora',
      'https://api.dicebear.com/8.x/thumbs/svg?seed=cosmo',
      'https://api.dicebear.com/8.x/thumbs/svg?seed=ember',
      'https://api.dicebear.com/8.x/thumbs/svg?seed=zephyr',
      'https://api.dicebear.com/8.x/thumbs/svg?seed=solstice',
    ];
}
