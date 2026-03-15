import 'dart:async';

import 'package:eduserveapp/core/constants/app_config.dart';
import 'package:eduserveapp/core/constants/colors.dart';
import 'package:eduserveapp/core/services/activity_log_service.dart';
import 'package:eduserveapp/core/services/analytics_service.dart';
import 'package:eduserveapp/core/services/app_stats_service.dart';
import 'package:eduserveapp/core/services/hackathon_service.dart';
import 'package:eduserveapp/core/services/firestore_user_service.dart';
import 'package:eduserveapp/core/services/notification_center_service.dart';
import 'package:eduserveapp/core/services/update_config_service.dart';
import 'package:eduserveapp/core/utils/version_utils.dart';
import 'package:eduserveapp/features/admin/admin_dashboard_screen.dart';
import 'package:eduserveapp/features/ai_chat/ai_chat_screen.dart';
import 'package:eduserveapp/features/eduserve/addons_webview_screen.dart';
import 'package:eduserveapp/features/eduserve/eduserve_webview_screen.dart';
import 'package:eduserveapp/features/home/home_screen.dart';
import 'package:eduserveapp/features/onboarding/onboarding_screen.dart';
import 'package:eduserveapp/features/results/results_webview_screen.dart';
import 'package:eduserveapp/features/settings/settings_screen.dart';
import 'package:eduserveapp/features/settings/theme_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';

class EduServeCompanionApp extends StatefulWidget {
  const EduServeCompanionApp({super.key});

  @override
  State<EduServeCompanionApp> createState() => _EduServeCompanionAppState();
}

class _EduServeCompanionAppState extends State<EduServeCompanionApp> {
  final ThemeController _themeController = ThemeController();
  bool _loading = true;
  bool _onboardingComplete = false;
  bool _hasUnreadNotifications = false;
  bool _isAdmin = false;
  String _uid = '';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await _themeController.load();

      final prefs = await SharedPreferences.getInstance();
      _onboardingComplete =
          prefs.getBool(AppConfig.onboardingCompleteKey) ?? false;
      _uid = prefs.getString(AppConfig.profileDocIdKey) ?? '';

      if (_uid.isNotEmpty) {
        await _safeRun(_refreshRole);
        await _safeRun(_refreshNotificationUnread);
        await _safeRun(ActivityLogService.instance.cleanupLogsIfDue);
        await _safeRun(
            () => AppStatsService.instance.updateOnAppOpen(uid: _uid));
        await _safeRun(HackathonService.instance.cleanupExpiredPosts);
      }

      await _safeRun(() async {
        final info = await PackageInfo.fromPlatform();
        await UpdateConfigService.instance
            .ensureDefaultConfig(currentVersion: info.version);
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }

    if (mounted && _onboardingComplete) {
      unawaited(_checkForUpdates());
    }
  }

  Future<void> _refreshRole() async {
    final currentEmail =
        FirebaseAuth.instance.currentUser?.email?.toLowerCase();
    if (currentEmail == AppConfig.adminEmail) {
      _isAdmin = true;
      return;
    }

    final profile = await FirestoreUserService.instance.getUserById(_uid);
    _isAdmin = (profile?.role.toLowerCase() == 'admin');
  }

  Future<void> _refreshNotificationUnread() async {
    _hasUnreadNotifications =
        await NotificationCenterService.instance.hasUnread();
  }

  Future<void> _checkForUpdates() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final installed = info.version;

      final config = await UpdateConfigService.instance
          .getConfig()
          .timeout(const Duration(seconds: 8));
      if (!mounted || config == null) {
        return;
      }

      final remote = config.latestVersion;
      final minSupported = config.minSupportedVersion;
      if (remote == null || remote.isEmpty) {
        return;
      }

      final hasNewer = VersionUtils.isRemoteVersionNewer(
        installed: installed,
        remote: remote,
      );

      final requiresUpgrade = minSupported != null &&
          minSupported.isNotEmpty &&
          VersionUtils.isRemoteVersionNewer(
            installed: installed,
            remote: minSupported,
          );

      if (!hasNewer && !requiresUpgrade) {
        return;
      }

      final apkUrl = (config.apkUrl ?? '').trim();
      final title = requiresUpgrade ? 'Update Required' : 'Update Available';
      final body = requiresUpgrade
          ? 'Version $minSupported or newer is required to continue. You are on $installed.'
          : 'Version $remote is available. You are on $installed.';

      await showDialog<void>(
        context: context,
        barrierDismissible: !requiresUpgrade,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: <Widget>[
            if (!requiresUpgrade)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Later'),
              ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                if (apkUrl.isNotEmpty) {
                  await _launchUrl(apkUrl);
                }
              },
              child: Text(apkUrl.isNotEmpty ? 'Download APK' : 'Update'),
            ),
          ],
        ),
      );
    } catch (_) {
      // Ignore remote update failures.
    }
  }

  Future<void> _onOnboardingCompleted() async {
    if (!mounted) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    _uid = prefs.getString(AppConfig.profileDocIdKey) ?? '';
    _onboardingComplete = true;

    if (_uid.isNotEmpty) {
      await _safeRun(_refreshRole);
      await _safeRun(_refreshNotificationUnread);
    }

    if (mounted) {
      setState(() {});
    }
    unawaited(_checkForUpdates());
  }

  Future<void> _safeRun(Future<void> Function() action) async {
    try {
      await action().timeout(const Duration(seconds: 10));
    } catch (error, stackTrace) {
      debugPrint('[bootstrap] non-fatal startup step failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConfig.onboardingCompleteKey, false);
    await prefs.remove(AppConfig.profileDocIdKey);

    if (mounted) {
      setState(() {
        _onboardingComplete = false;
        _isAdmin = false;
        _uid = '';
      });
    }
  }

  Future<void> _onNotificationsViewed() async {
    await AnalyticsService.instance.logNotificationOpened();
    await NotificationCenterService.instance.markSeenNow();
    await _refreshNotificationUnread();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }

    final launched = await launchUrlString(
      url,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open download link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeController,
      builder: (_, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'EduServe',
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: _themeController.themeMode,
          home: _loading
              ? const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                )
              : _onboardingComplete
                  ? (_isAdmin
                      ? AdminDashboardScreen(
                          uid: _uid,
                          themeController: _themeController,
                          onLogout: _logout,
                        )
                      : _MainShell(
                          uid: _uid,
                          hasUnreadNotifications: _hasUnreadNotifications,
                          onNotificationsViewed: _onNotificationsViewed,
                          themeController: _themeController,
                          onLogout: _logout,
                        ))
                  : OnboardingScreen(onCompleted: _onOnboardingCompleted),
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // Use vibrant light blue against true dark colors for a modern, sleek contrast
    const lightPrimaryColor = AppColors.emeraldPrimary;
    const lightAccentColor = AppColors.emeraldAccent;
    const darkPrimaryColor = Color(0xFF38BDF8); // Vibrant Light Blue
    const darkAccentColor = Color(0xFF7DD3FC); // Soft teal/light blue accent
    const darkBackground = Color(0xFF0A0A0A); // Near True Black
    const darkSurface = Color(0xFF141414); // Dark Gray card surface
    const darkInput = Color(0xFF1E1E1E); // Elevated dark gray input

    final primaryColor = isDark ? darkPrimaryColor : lightPrimaryColor;
    final accentColor = isDark ? darkAccentColor : lightAccentColor;

    final scheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: brightness,
      primary: primaryColor,
      secondary: accentColor,
      surface: isDark ? darkSurface : Colors.white,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? darkBackground : AppColors.backgroundLight,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor:
            isDark ? darkBackground : AppColors.backgroundLight,
        foregroundColor: isDark ? Colors.white : Colors.black,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? darkSurface : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFEFEFEF),
            width: 0.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? darkInput : const Color(0xFFFAFAFA),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? accentColor : primaryColor, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : Colors.black,
          side: BorderSide(
            color: isDark
                ? AppColors.emeraldPrimary.withValues(alpha: 0.40)
                : AppColors.emeraldPrimary.withValues(alpha: 0.35),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? darkBackground : AppColors.backgroundLight,
        selectedItemColor: isDark ? darkPrimaryColor : AppColors.emeraldPrimary,
        unselectedItemColor: isDark ? const Color(0xFF737373) : Colors.black45,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? darkSurface : const Color(0xFF111111),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      fontFamily: 'Inter',
    );
  }
}

class _MainShell extends StatefulWidget {
  const _MainShell({
    required this.uid,
    required this.hasUnreadNotifications,
    required this.onNotificationsViewed,
    required this.themeController,
    required this.onLogout,
  });

  final String uid;
  final bool hasUnreadNotifications;
  final Future<void> Function() onNotificationsViewed;
  final ThemeController themeController;
  final Future<void> Function() onLogout;

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _index = 0;
  final Map<int, bool> _tabRedDots = <int, bool>{
    1: true,
    2: true,
    3: true,
    4: true,
  };

  @override
  void initState() {
    super.initState();
    ActivityLogService.instance.logCurrentUserAction(
      uid: widget.uid,
      action: 'open_home',
      tab: 'home',
    );
    AppStatsService.instance.logTabOpen('home');
  }

  void _openTab(int value) {
    setState(() {
      _index = value;
      if (_tabRedDots[value] == true) {
        _tabRedDots[value] = false;
      }
    });

    final tab = switch (value) {
      0 => 'home',
      1 => 'eduserve',
      2 => 'results',
      3 => 'ai',
      _ => 'addons',
    };
    final action = switch (value) {
      0 => 'open_home',
      1 => 'open_eduserve',
      2 => 'open_results',
      3 => 'open_ai',
      _ => 'open_addons',
    };

    ActivityLogService.instance.logCurrentUserAction(
      uid: widget.uid,
      action: action,
      tab: tab,
    );
    AppStatsService.instance.logTabOpen(tab);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(
        uid: widget.uid,
        hasUnreadNotifications: widget.hasUnreadNotifications,
        onNotificationsViewed: widget.onNotificationsViewed,
        onOpenSettings: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SettingsScreen(
                themeController: widget.themeController,
                onLogout: widget.onLogout,
              ),
            ),
          );
        },
        onOpenEduserve: () => _openTab(1),
        onOpenResults: () => _openTab(2),
        onOpenAi: () => _openTab(3),
        onOpenAddons: () => _openTab(4),
      ),
      EduserveWebViewScreen(uid: widget.uid),
      ResultsWebViewScreen(uid: widget.uid),
      AiChatScreen(uid: widget.uid),
      AddonsWebViewScreen(uid: widget.uid),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF262626) : Color(0xFFEFEFEF),
              width: 0.5,
            ),
          )
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: _openTab,
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(_index == 0 ? Icons.home_filled : Icons.home_outlined),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: _TabIconWithDot(
                icon: _index == 1 ? Icons.language : Icons.language_outlined,
                showDot: _tabRedDots[1] == true,
              ),
              label: 'EduServe',
            ),
            BottomNavigationBarItem(
              icon: _TabIconWithDot(
                icon: _index == 2 ? Icons.bar_chart : Icons.bar_chart_outlined,
                showDot: _tabRedDots[2] == true,
              ),
              label: 'Results',
            ),
            BottomNavigationBarItem(
              icon: _TabIconWithDot(
                icon: _index == 3 ? Icons.auto_awesome : Icons.auto_awesome_outlined,
                showDot: _tabRedDots[3] == true,
              ),
              label: 'AI',
            ),
            BottomNavigationBarItem(
              icon: _TabIconWithDot(
                icon: _index == 4 ? Icons.grid_view_sharp : Icons.grid_view_outlined,
                showDot: _tabRedDots[4] == true,
              ),
              label: 'Add-ons',
            ),
          ],
        ),
      ),
    );
  }
}

class _TabIconWithDot extends StatelessWidget {
  const _TabIconWithDot({
    required this.icon,
    required this.showDot,
  });

  final IconData icon;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Icon(icon),
        if (showDot)
          const Positioned(
            top: -2,
            right: -2,
            child: CircleAvatar(radius: 3, backgroundColor: AppColors.danger),
          ),
      ],
    );
  }
}
