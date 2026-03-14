import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eduserveapp/core/constants/app_config.dart';
import 'package:eduserveapp/core/constants/colors.dart';
import 'package:eduserveapp/core/services/activity_log_service.dart';
import 'package:eduserveapp/core/services/firestore_user_service.dart';
import 'package:eduserveapp/core/services/notification_center_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.uid,
    required this.hasUnreadNotifications,
    required this.onNotificationsViewed,
    required this.onOpenProfile,
    required this.onOpenSettings,
    required this.onOpenEduserve,
    required this.onOpenResults,
    required this.onOpenAi,
    required this.onOpenAddons,
  });

  final String uid;
  final bool hasUnreadNotifications;
  final Future<void> Function() onNotificationsViewed;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenEduserve;
  final VoidCallback onOpenResults;
  final VoidCallback onOpenAi;
  final VoidCallback onOpenAddons;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Notifications',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Expanded(
                child: feed.isEmpty
                    ? const Center(child: Text('No new updates.'))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: feed.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = feed[index];
                          final title = (item['title'] as String?) ?? 'Update';
                          final message = (item['message'] as String?) ?? '';
                          final ms =
                              (item['createdAtMs'] as num?)?.toInt() ?? 0;
                          final dt = DateTime.fromMillisecondsSinceEpoch(ms);
                          final timeText =
                              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.emeraldLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.notifications_active_outlined,
                                color: AppColors.emeraldPrimary,
                                size: 20,
                              ),
                            ),
                            title: Text(title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(message),
                            trailing: Text(timeText,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              'PocketEduServe',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : Colors.black,
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
                icon: const CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.emeraldPrimary,
                  child: Icon(Icons.person, size: 18, color: Colors.white),
                ),
                onPressed: widget.onOpenProfile,
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
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildQuickAccessGrid(context),
                  const SizedBox(height: 24),
                  Text(
                    'Updates',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildHackathonFeed(context),
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
              _greeting(),
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).hintColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                height: 1.1,
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
            color: Colors.purple,
            width: itemWidth,
            height: itemHeight,
            onTap: widget.onOpenResults,
          ),
          _DashboardCard(
            title: 'AI Assistant',
            subtitle: 'Get Help',
            icon: Icons.auto_awesome,
            color: Colors.blue,
            width: itemWidth,
            height: itemHeight,
            onTap: widget.onOpenAi,
          ),
          _DashboardCard(
            title: 'Add-ons',
            subtitle: 'More Tools',
            icon: Icons.grid_view_rounded,
            color: Colors.orange,
            width: itemWidth,
            height: itemHeight,
            onTap: widget.onOpenAddons,
          ),
        ],
      );
    });
  }

  Widget _buildHackathonFeed(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(AppConfig.hackathonsCollection)
          .where('endDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
          .orderBy('endDate')
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LinearProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Text('No active events right now.'),
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _EventCard(
                title: (data['title'] as String?) ?? 'Event',
                description: (data['description'] as String?) ?? 'No details',
                endDate: (data['endDate'] as Timestamp?)?.toDate(),
                onTap: () async {
                  await ActivityLogService.instance.logCurrentUserAction(
                    uid: widget.uid,
                    action: 'hackathon_click',
                    tab: 'home',
                  );
                  final url = data['url'] as String?;
                  if (url != null && await canLaunchUrl(Uri.parse(url))) {
                    await launchUrl(Uri.parse(url));
                  }
                },
              ),
            );
          }).toList(),
        );
      },
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
      elevation: 0, // Flat premium look
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark ? Colors.white12 : Colors.black12,
          width: 0.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: width,
          height: height,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withAlpha(30), // Subtle wash
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

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.title,
    required this.description,
    this.endDate,
    required this.onTap,
  });

  final String title;
  final String description;
  final DateTime? endDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black12,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: Colors.redAccent, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'EVENT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).hintColor,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.arrow_forward_ios,
                size: 16, color: Theme.of(context).hintColor),
          ],
        ),
      ),
    );
  }
}
