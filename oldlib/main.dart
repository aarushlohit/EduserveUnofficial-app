import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'app.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/portal/presentation/providers/portal_provider.dart';
import 'core/services/notification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait for a phone-friendly layout.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Enable WebView remote debugging on debug builds via Chrome devtools
  // (chrome://inspect on desktop Chrome).
  await InAppWebViewController.setWebContentsDebuggingEnabled(true);

  // Initialise local notifications (channels, permissions).
  await NotificationService.instance.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProvider<PortalProvider>(
          create: (_) => PortalProvider()..loadPreferences(),
        ),
      ],
      child: const EduServeApp(),
    ),
  );
}

