import 'dart:async';

import 'package:eduserveapp/features/eduserve/external_events_screen.dart';
import 'package:eduserveapp/features/eduserve/fees_screen.dart';
import 'package:eduserveapp/features/settings/theme_controller.dart';
import 'package:eduserveapp/features/settings/legal_screen.dart';
import 'package:eduserveapp/features/web/common_webview_page.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.themeController,
    required this.onLogout,
  });

  final ThemeController themeController;
  final Future<void> Function() onLogout;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '-';
  int _aboutAuthorTapCount = 0;
  Timer? _aboutAuthorResetTimer;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = '${info.version}+${info.buildNumber}';
      });
    }
  }

  void _handleAboutAuthorTap() {
    _aboutAuthorResetTimer?.cancel();
    _aboutAuthorTapCount += 1;
    _aboutAuthorResetTimer = Timer(const Duration(seconds: 2), () {
      _aboutAuthorTapCount = 0;
    });

    if (_aboutAuthorTapCount >= 3) {
      _aboutAuthorTapCount = 0;
      _aboutAuthorResetTimer?.cancel();
      _showAuthorEasterEgg();
    }
  }

  Future<void> _showAuthorEasterEgg() async {
    if (!mounted) {
      return;
    }

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'About Author',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, __, ___) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOut);
        return FadeTransition(
          opacity: curved,
          child: Center(
            child: Material(
              color: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'About the Author',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "I had a crush on her but she didn't understand. It's okay… at least my app is on her phone.",
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Aww'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showTermsAndPrivacy() async {
    if (!mounted) {
      return;
    }
    
    // We navigate to the new legal screen instead of dialog
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const LegalScreen()),
    );
  }

  @override
  void dispose() {
    _aboutAuthorResetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeController.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFF111111), Color(0xFF2A2A2A)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Preferences',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Personalize your EduServe Companion experience.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          const _SectionHeader('Appearance'),
          _SectionCard(
            child: SwitchListTile(
              value: isDark,
              title: const Text('Dark Mode'),
              subtitle: const Text('Switch between dark and light mode'),
              onChanged: (value) => widget.themeController
                  .setThemeMode(value ? ThemeMode.dark : ThemeMode.light),
            ),
          ),
          _SectionCard(
            child: ListTile(
              leading: const Icon(Icons.light_mode),
              title: const Text('Light Mode'),
              onTap: () => widget.themeController.setThemeMode(ThemeMode.light),
            ),
          ),
          const SizedBox(height: 6),
          const _SectionHeader('Account'),
          _SectionCard(
            child: ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                Navigator.of(context).pop();
                await widget.onLogout();
              },
            ),
          ),
          const SizedBox(height: 6),
          const _SectionHeader('About'),
          _SectionCard(
            child: Column(
              children: <Widget>[
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('About App'),
                  subtitle: Text(
                    'Unofficial student utility app for Karunya students.',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('About Author'),
                  subtitle: const Text('EduServe Companion Team'),
                  onTap: _handleAboutAuthorTap,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const _SectionHeader('Legal'),
          _SectionCard(
            child: ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Terms & Privacy'),
              subtitle:
                  const Text('How we handle usage, visibility, and trust'),
              onTap: _showTermsAndPrivacy,
            ),
          ),
          const SizedBox(height: 6),
          const _SectionHeader('Portals'),
          _SectionCard(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: const Text('Fees'),
                  subtitle: const Text('Regular and add-ons fee payment'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const FeesScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.event_available_outlined),
                  title: const Text('External Events'),
                  subtitle: const Text('Open external events portal'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ExternalEventsScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.public_outlined),
                  title: const Text('Karunya Website'),
                  subtitle: const Text('https://karunya.edu'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CommonWebViewPage(
                          title: 'Karunya Website',
                          url: 'https://karunya.edu',
                          tabKey: 'website',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const _SectionHeader('System'),
          _SectionCard(
            child: ListTile(
              leading: const Icon(Icons.verified_outlined),
              title: const Text('App Version'),
              subtitle: Text(_version),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
