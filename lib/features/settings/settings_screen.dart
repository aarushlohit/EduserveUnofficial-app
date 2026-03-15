import 'package:eduserveapp/features/settings/theme_controller.dart';
import 'package:eduserveapp/features/settings/privacy_policy_screen.dart';
import 'package:eduserveapp/features/settings/terms_screen.dart';
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
          const _SectionCard(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('About App'),
                  subtitle: Text(
                    'Unofficial student utility app for Karunya students.',
                  ),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.person_outline),
                  title: Text('About Author'),
                  subtitle: Text('EduServe Companion Team'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const _SectionHeader('Legal'),
          _SectionCard(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Terms and Conditions'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TermsScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PrivacyPolicyScreen(),
                    ),
                  ),
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
