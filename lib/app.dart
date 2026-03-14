import 'dart:async';

import 'package:eduserveapp/core/constants/app_config.dart';
import 'package:eduserveapp/core/constants/colors.dart';
import 'package:eduserveapp/core/services/activity_log_service.dart';
import 'package:eduserveapp/core/services/analytics_service.dart';
import 'package:eduserveapp/core/services/app_stats_service.dart';
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
import 'package:eduserveapp/features/settings/profile_screen.dart';
import 'package:eduserveapp/features/settings/settings_screen.dart';
import 'package:eduserveapp/features/settings/theme_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      final remote = await UpdateConfigService.instance
          .getLatestVersion()
          .timeout(const Duration(seconds: 8));
      if (remote == null || !mounted) {
        return;
      }

      if (VersionUtils.isRemoteVersionNewer(
        installed: installed,
        remote: remote,
      )) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Update Available'),
            content:
                Text('Version $remote is available. You are on $installed.'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Update'),
              ),
            ],
          ),
        );
      }
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

  Future<void> _openProfile() async {
    final navigator = Navigator.of(context);
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(onLogout: _logout),
      ),
    );
  }

  Future<void> _bootstrapUpdateConfig() async {
    try {
      final info = await PackageInfo.fromPlatform();
      await UpdateConfigService.instance
          .ensureDefaultConfig(currentVersion: info.version);

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Update config bootstrap completed.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to bootstrap update config.')),
      );
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeController,
      builder: (_, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'PocketEduServe',
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
                          onCheckUpdates: _checkForUpdates,
                          onOpenProfile: _openProfile,
                          onBootstrapUpdateConfig: _bootstrapUpdateConfig,
                          onLogout: _logout,
                        )
                      : _MainShell(
                          uid: _uid,
                          hasUnreadNotifications: _hasUnreadNotifications,
                          onNotificationsViewed: _onNotificationsViewed,
                          onCheckUpdates: _checkForUpdates,
                          themeController: _themeController,
                          onOpenProfile: _openProfile,
                          onBootstrapUpdateConfig: _bootstrapUpdateConfig,
                          onLogout: _logout,
                        ))
                  : OnboardingScreen(onCompleted: _onOnboardingCompleted),
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    
    // Emerald Palette - Extreme
    const primaryColor = AppColors.emeraldPrimary; 
    // const darkPrimaryColor = AppColors.emeraldPrimary; // Unused
    const accentColor = AppColors.emeraldAccent;

    final scheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: brightness,
      primary: primaryColor,
      secondary: accentColor,
      surface: isDark ? AppColors.inputBackgroundDark : Colors.white,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor:
            isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        foregroundColor: isDark ? Colors.white : Colors.black,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.cardDark : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF),
            width: 0.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF262626) : const Color(0xFFFAFAFA),
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
          backgroundColor: isDark ? primaryColor : primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        selectedItemColor: isDark ? Colors.white : Colors.black, // Instagram style: Black/White selected
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF262626) : const Color(0xFF111111),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      fontFamily: 'Inter', // Try modern font if available, else Roboto logs warning but works
    );
  }
}

class _MainShell extends StatefulWidget {
  const _MainShell({
    required this.uid,
    required this.hasUnreadNotifications,
    required this.onNotificationsViewed,
    required this.onCheckUpdates,
    required this.themeController,
    required this.onOpenProfile,
    required this.onBootstrapUpdateConfig,
    required this.onLogout,
  });

  final String uid;
  final bool hasUnreadNotifications;
  final Future<void> Function() onNotificationsViewed;
  final Future<void> Function() onCheckUpdates;
  final ThemeController themeController;
  final Future<void> Function() onOpenProfile;
  final Future<void> Function() onBootstrapUpdateConfig;
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
        onOpenProfile: () => widget.onOpenProfile(),
        onOpenSettings: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SettingsScreen(
                themeController: widget.themeController,
                onCheckUpdates: widget.onCheckUpdates,
                onOpenProfile: widget.onOpenProfile,
                onBootstrapUpdateConfig: widget.onBootstrapUpdateConfig,
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
              color: isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF),
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
