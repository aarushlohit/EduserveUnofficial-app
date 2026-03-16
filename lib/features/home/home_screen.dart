import 'dart:async';
import 'dart:ui';

import 'package:eduserveapp/core/constants/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eduserveapp/core/services/firestore_user_service.dart';
import 'package:eduserveapp/core/services/notification_center_service.dart';
import 'package:eduserveapp/core/constants/app_config.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.uid,
    required this.hasUnreadNotifications,
    required this.onNotificationsViewed,
    required this.onOpenSettings,
    required this.onOpenEduserve,
    required this.onOpenResults,
    required this.onOpenAi,
    required this.onOpenAddons,
  });

  final String uid;
  final bool hasUnreadNotifications;
  final Future<void> Function() onNotificationsViewed;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenEduserve;
  final VoidCallback onOpenResults;
  final VoidCallback onOpenAi;
  final VoidCallback onOpenAddons;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _titleTapCount = 0;
  Timer? _titleTapResetTimer;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    }
    if (hour < 17) {
      return 'Good Afternoon';
    }
    return 'Good Evening';
  }

  Future<void> _openNotificationsPanel() async {
    await widget.onNotificationsViewed();
    final feed = await NotificationCenterService.instance.getGreetingFeed();
    if (!mounted) return;

    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Notifications',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.15),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, _, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.05),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: kToolbarHeight + 12, right: 12),
              child: SafeArea(
                child: Material(
                  color: Colors.transparent,
                  child: _NotificationPopup(initialFeed: feed),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleTitleTap() {
    _titleTapResetTimer?.cancel();
    _titleTapCount += 1;
    _titleTapResetTimer = Timer(const Duration(seconds: 2), () {
      _titleTapCount = 0;
    });

    if (_titleTapCount >= 3) {
      _titleTapCount = 0;
      _titleTapResetTimer?.cancel();
      _showHomepageEasterEgg();
    }
  }

  Future<void> _showHomepageEasterEgg() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('EduServe'),
        content: const Text('Heyy this app is just for you babe ❤️'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleTapResetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: isDark
                      ? const Color(0xFF0A0A0A).withValues(alpha: 0.88)
                      : Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ),
            title: GestureDetector(
              onTap: _handleTitleTap,
              behavior: HitTestBehavior.opaque,
              child: Text(
                'EduServe',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            centerTitle: false,
            actions: [
              IconButton(
                icon: Badge(
                  isLabelVisible: widget.hasUnreadNotifications,
                  smallSize: 8,
                  child: const Icon(Icons.notifications_outlined),
                ),
                onPressed: _openNotificationsPanel,
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: widget.onOpenSettings,
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeHeader(context),
                  const SizedBox(height: 24),
                  Text(
                    'Quick Access',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildQuickAccessGrid(context),
                  const SizedBox(height: 24),
                  _NewsFeed(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(BuildContext context) {
    return FutureBuilder(
      future: FirestoreUserService.instance.getUserById(widget.uid),
      builder: (context, snapshot) {
        final name = snapshot.data?.name.trim().isNotEmpty == true
            ? snapshot.data!.name.trim().split(' ').first
            : 'Student';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_greeting()}, $name 👋',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: Theme.of(context).brightness == Brightness.dark
                      ? const <Color>[Color(0xFF38BDF8), Color(0xFF0284C7)]
                      : const <Color>[AppColors.emeraldPrimary, AppColors.emeraldDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.emeraldPrimary.withValues(alpha: 0.32)
                      : Colors.transparent,
                  width: 0.5,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.emeraldPrimary.withValues(
                      alpha: Theme.of(context).brightness == Brightness.dark
                          ? 0.10
                          : 0.24,
                    ),
                    blurRadius: 18,
                    offset: const Offset(0, 9),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome to the portal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '1st years Made Eduserve Portal App',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.84),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickAccessGrid(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      // 2 columns
      final itemWidth = (width - 16) / 2;
      final itemHeight = itemWidth * 0.85; // Slightly rectangular cards

      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _DashboardCard(
            title: 'EduServe',
            subtitle: 'Access Portal',
            icon: Icons.language,
            color: AppColors.emeraldPrimary,
            width: itemWidth,
            height: itemHeight,
            onTap: widget.onOpenEduserve,
          ),
          _DashboardCard(
            title: 'Results',
            subtitle: 'Check Grades',
            icon: Icons.bar_chart,
            color: AppColors.emeraldDark,
            width: itemWidth,
            height: itemHeight,
            onTap: widget.onOpenResults,
          ),
          _DashboardCard(
            title: 'AI Assistant',
            subtitle: 'Get Help',
            icon: Icons.auto_awesome,
            color: Color(0xFF0EA5E9),
            width: itemWidth,
            height: itemHeight,
            onTap: widget.onOpenAi,
          ),
          _DashboardCard(
            title: 'Add-ons',
            subtitle: 'More Tools',
            icon: Icons.grid_view_rounded,
            color: Theme.of(context).colorScheme.error,
            width: itemWidth,
            height: itemHeight,
            onTap: widget.onOpenAddons,
          ),
        ],
      );
    });
  }

 
}

class _NewsFeed extends StatelessWidget {
  _NewsFeed();

  final ValueNotifier<bool> _expanded = ValueNotifier<bool>(false);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'News & Hackathons',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(AppConfig.postsCollection)
              .orderBy('createdAt', descending: true)
              .limit(20)
              .snapshots(),
          builder: (context, snapshot) {
            final allDocs = snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            final docs = allDocs.where((d) => d.data()['isDraft'] != true).toList();
            if (docs.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No announcements yet.'),
                ),
              );
            }

            return ValueListenableBuilder<bool>(
              valueListenable: _expanded,
              builder: (context, expanded, _) {
                final visible = expanded ? docs : docs.take(5).toList();
                return Column(
                  children: [
                    ...visible.map((doc) {
                      final data = doc.data();
                      final title = (data['title'] as String?) ?? 'Announcement';
                      final description = (data['description'] as String?) ?? '';
                      final link = (data['link'] as String?) ?? '';
                      final imageUrl = (data['imageUrl'] as String?) ?? '';
                      final ts = data['createdAt'];
                      final when = ts is Timestamp
                          ? ts.toDate().toLocal().toIso8601String().split('T').first
                          : '-';

                      final subtitleLines = <String>[
                        description,
                        if (link.isNotEmpty) link,
                        'Posted: $when',
                      ]..removeWhere((e) => e.trim().isEmpty);

                      return Card(
                        child: InkWell(
                          onTap: link.isNotEmpty
                              ? () async {
                                  final ok = await launchUrlString(link,
                                      mode: LaunchMode.externalApplication);
                                  if (!ok && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Could not open link')),
                                    );
                                  }
                                }
                              : null,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (imageUrl.isNotEmpty)
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                        alignment: Alignment.center,
                                        child: const Icon(Icons.broken_image_outlined),
                                      ),
                                    ),
                                  ),
                                ),
                              ListTile(
                                leading: const Icon(Icons.campaign_outlined),
                                title: Text(title),
                                subtitle: Text(subtitleLines.join('\n')),
                                trailing: link.isNotEmpty
                                    ? const Icon(Icons.open_in_new, size: 18)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (docs.length > 5)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: TextButton.icon(
                          onPressed: () => _expanded.value = !expanded,
                          icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                          label: Text(expanded ? 'Show less' : 'Read more'),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Theme.of(context).cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark
              ? const Color(0xFF2E2E2E)
              : Colors.black12,
          width: isDark ? 0.8 : 0.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: width,
          height: height,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: isDark
                ? null
                : <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _NotificationPopup extends StatefulWidget {
  const _NotificationPopup({required this.initialFeed});

  final List<Map<String, dynamic>> initialFeed;

  @override
  State<_NotificationPopup> createState() => _NotificationPopupState();
}

class _NotificationPopupState extends State<_NotificationPopup> {
  late List<Map<String, dynamic>> _feed;

  @override
  void initState() {
    super.initState();
    _feed = List<Map<String, dynamic>>.from(widget.initialFeed);
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final createdAtMs = (item['createdAtMs'] as num?)?.toInt();
    if (!mounted) return;

    setState(() {
      _feed.remove(item);
    });

    if (createdAtMs != null) {
      await NotificationCenterService.instance.removeByCreatedAtMs(createdAtMs);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 320,
      constraints: const BoxConstraints(maxHeight: 380),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(color: theme.brightness == Brightness.dark ? const Color(0xFF2E2E2E) : Colors.black12.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: <Widget>[
                const Icon(Icons.notifications_active_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Notifications',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _feed.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No new updates.'),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    itemCount: _feed.length,
                    itemBuilder: (context, index) {
                      final item = _feed[index];
                      final title = (item['title'] as String?) ?? 'Update';
                      final message = (item['message'] as String?) ?? '';
                      final ms = (item['createdAtMs'] as num?)?.toInt() ?? 0;
                      final dt = DateTime.fromMillisecondsSinceEpoch(ms);
                      final timeText =
                          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

                      return Dismissible(
                        key: ValueKey('${item['title']}-${item['createdAtMs'] ?? index}'),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) {
                          _deleteItem(item);
                        },
                        background: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.error,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: const Icon(Icons.delete_outline, color: Colors.white),
                        ),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.dividerColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.emeraldLight,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.notifications_none,
                                  size: 18,
                                  color: AppColors.emeraldPrimary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      message,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      timeText,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
