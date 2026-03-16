import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:install_plugin/install_plugin.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';

class _RemoteUpdateInfo {
  const _RemoteUpdateInfo({
    required this.version,
    required this.apkUrl,
    required this.force,
    required this.notes,
  });

  final String version;
  final String apkUrl;
  final bool force;
  final String notes;
}

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
  bool _updateChecked = false;

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

      // Force purge legacy activity logs to start production clean.
      await _safeRun(ActivityLogService.instance.purgeAllLogsNow);
      await _safeRun(ActivityLogService.instance.purgeAllLogsOnce);

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

    if (mounted) {
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
    if (!mounted || _updateChecked) {
      return;
    }

    _updateChecked = true;

    if (!Platform.isAndroid) {
      return; // In-app APK updates only make sense on Android builds.
    }

    try {
      final payload = await _fetchRemoteUpdateInfo();
      if (payload == null || !mounted) {
        return;
      }

      final info = await PackageInfo.fromPlatform();
      final installed = info.version.trim();

      final isNewer = VersionUtils.isRemoteVersionNewer(
        installed: installed,
        remote: payload.version,
      );

      if (!isNewer) {
        return;
      }

      await _showUpdateDialog(
        payload: payload,
        installed: installed,
        packageName: info.packageName,
      );
    } catch (error, stackTrace) {
      debugPrint('[update] skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<_RemoteUpdateInfo?> _fetchRemoteUpdateInfo() async {
    final uri = Uri.tryParse(AppConfig.updateGistUrl);
    if (uri == null) {
      return null;
    }

    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final version = (decoded['version'] as String?)?.trim() ?? '';
    final apkUrl = (decoded['apk'] as String?)?.trim() ?? '';
    final notes = (decoded['notes'] as String?)?.trim() ?? '';
    final force = decoded['force'] == true;

    if (version.isEmpty || apkUrl.isEmpty) {
      return null;
    }

    return _RemoteUpdateInfo(
      version: version,
      apkUrl: apkUrl,
      force: force,
      notes: notes,
    );
  }

  Future<void> _showUpdateDialog({
    required _RemoteUpdateInfo payload,
    required String installed,
    required String packageName,
  }) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: !payload.force,
      builder: (context) => AlertDialog(
        title: const Text('Update Available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Version ${payload.version} is available. You are on $installed.'),
            if (payload.notes.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(payload.notes),
            ],
          ],
        ),
        actions: <Widget>[
          if (!payload.force)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _downloadAndInstallApk(
                payload: payload,
                packageName: packageName,
              );
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAndInstallApk({
    required _RemoteUpdateInfo payload,
    required String packageName,
  }) async {
    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final progress = ValueNotifier<double>(0);
    final savePath = '${Directory.systemTemp.path}/eduserve-${payload.version}.apk';

    final dio = Dio();
    Object? error;

    final download = dio.download(
      payload.apkUrl,
      savePath,
      onReceiveProgress: (received, total) {
        if (total <= 0) {
          return;
        }
        progress.value = received / total;
      },
    );

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (_, value, __) => AlertDialog(
          title: const Text('Downloading update'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              LinearProgressIndicator(
                value: value <= 0 ? null : value.clamp(0, 1),
              ),
              const SizedBox(height: 12),
              Text(
                value <= 0
                    ? 'Starting download...'
                    : '${(value * 100).clamp(0, 100).toStringAsFixed(0)}%',
              ),
            ],
          ),
        ),
      ),
    );

    try {
      await download;
    } catch (e) {
      error = e;
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
      }
    }

    if (error != null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Update download failed. Please try again later.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      await InstallPlugin.installApk(savePath);
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not start install. Opening download link.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _launchUrl(payload.apkUrl);
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
              ? const _StartupLoader()
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

class _StartupLoader extends StatefulWidget {
  const _StartupLoader();

  @override
  State<_StartupLoader> createState() => _StartupLoaderState();
}

class _StartupLoaderState extends State<_StartupLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final gradient = LinearGradient(
      colors: isDark
          ? const <Color>[Color(0xFF0A0A0A), Color(0xFF0F172A)]
          : <Color>[Colors.white, AppColors.emeraldPrimary.withValues(alpha: 0.08)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final surfaceColor = isDark ? const Color(0xFF111111) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF1F2933)
        : AppColors.emeraldPrimary.withValues(alpha: 0.08);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final scale = 0.92 + (_controller.value * 0.12);

              return Transform.scale(
                scale: scale,
                child: Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: borderColor, width: 1),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
                        blurRadius: 28,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: isDark
                                ? const <Color>[AppColors.emeraldPrimary, Color(0xFF22D3EE)]
                                : const <Color>[AppColors.emeraldPrimary, AppColors.emeraldDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'EduServe',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Preparing your portal...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          color: theme.colorScheme.primary.withValues(alpha: 0.90),
                          backgroundColor:
                              theme.colorScheme.primary.withValues(alpha: 0.18),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
