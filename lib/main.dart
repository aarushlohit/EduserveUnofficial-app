import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:eduserveapp/core/services/analytics_service.dart';
import 'package:eduserveapp/core/services/notification_service.dart';
import 'package:eduserveapp/app.dart';
import 'package:eduserveapp/firebase_options.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await _loadEnvSafely();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await _initializeCrashlytics();

  // Lock orientation only on phones.
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Enable WebView remote debugging on debug builds via Chrome devtools
  // (chrome://inspect on desktop Chrome).
  await InAppWebViewController.setWebContentsDebuggingEnabled(true);

  // Initialise local notifications (channels, permissions).
  await _initNotificationsSafely();

  await _logAppOpenSafely();

  runApp(const EduServeCompanionApp());
}

Future<void> _loadEnvSafely() async {
  try {
    await dotenv.load(fileName: 'lib/.env');
    debugPrint('[startup] loaded env from lib/.env');
    return;
  } catch (_) {
    // Try fallback path below.
  }

  try {
    await dotenv.load(fileName: '.env');
    debugPrint('[startup] loaded env from .env');
  } catch (error, stackTrace) {
    debugPrint('[startup] env load skipped: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

Future<void> _initNotificationsSafely() async {
  try {
    await NotificationService.instance
        .init()
        .timeout(const Duration(seconds: 10));
  } catch (error, stackTrace) {
    debugPrint('[startup] notifications init skipped: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

Future<void> _logAppOpenSafely() async {
  try {
    await AnalyticsService.instance
        .logAppOpen()
        .timeout(const Duration(seconds: 8));
  } catch (error, stackTrace) {
    debugPrint('[startup] analytics app_open skipped: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Future<void> _initializeCrashlytics() async {
  if (!_supportsCrashlytics()) {
    return;
  }

  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

  FlutterError.onError = (FlutterErrorDetails details) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
}

bool _supportsCrashlytics() {
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
