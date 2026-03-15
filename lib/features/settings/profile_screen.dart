import 'package:eduserveapp/core/constants/app_config.dart';
import 'package:eduserveapp/core/constants/colors.dart';
import 'package:eduserveapp/core/services/firestore_user_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.onLogout});

  final Future<void> Function()? onLogout;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  StudentProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(AppConfig.profileDocIdKey) ?? '';
    if (uid.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final profile = await FirestoreUserService.instance.getUserById(uid);
    if (mounted) {
      setState(() {
        _profile = profile;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final profile = _profile;
    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('Profile not found.')),
      );
    }

    final avatarUrl = profile.avatar ?? AppConfig.avatarPresets.first;
    final dobText = profile.dob.toLocal().toString().split(' ').first;

    // Modern dashboard profile
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.emeraldPrimary.withAlpha(50),
                        width: 4,
                      ),
                    ),
                  ),
                  CircleAvatar(
                    radius: 54,
                    backgroundColor: AppColors.emeraldLight,
                    backgroundImage: NetworkImage(avatarUrl),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              profile.name,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              profile.email,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 32),
            const _SectionHeader(title: 'ACADEMIC'),
            const SizedBox(height: 12),
            _InfoTile(
              label: 'Department',
              value: profile.dept,
              icon: Icons.school_outlined,
            ),
            _InfoTile(
              label: 'Year',
              value: '${profile.year}',
              icon: Icons.calendar_today_outlined,
            ),
            _InfoTile(
              label: 'Email',
              value: profile.email,
              icon: Icons.email_outlined,
            ),
            _InfoTile(
              label: 'Date of Birth',
              value: dobText,
              icon: Icons.cake_outlined,
            ),
            const SizedBox(height: 32),
            const _SectionHeader(title: 'ACCOUNT'),
            const SizedBox(height: 12),
            _ActionTile(
              label: 'Edit details',
              icon: Icons.edit_outlined,
              onTap: () {
                // Placeholder
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Edit feature coming soon.')),
                );
              },
            ),
            if (widget.onLogout != null)
              _ActionTile(
                label: 'Log out',
                icon: Icons.logout,
                isDanger: true,
                onTap: () {
                  _showLogoutDialog(context);
                },
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              if (widget.onLogout != null) {
                await widget.onLogout!();
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}


class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Theme.of(context).hintColor,
            ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withAlpha(10)
                  : Colors.black.withAlpha(10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.emeraldPrimary, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.label,
    required this.icon,
    this.isDanger = false,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isDanger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDanger
                    ? AppColors.danger.withAlpha(20)
                    : (isDark
                        ? Colors.white.withAlpha(10)
                        : Colors.black.withAlpha(10)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color: isDanger ? AppColors.danger : theme.hintColor,
                  size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: isDanger ? AppColors.danger : theme.textTheme.bodyMedium?.color,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: isDanger ? AppColors.danger.withAlpha(100) : theme.hintColor),
          ],
        ),
      ),
    );
  }
}
