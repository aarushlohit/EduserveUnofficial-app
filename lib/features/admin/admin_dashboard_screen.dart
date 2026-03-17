import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eduserveapp/core/constants/app_config.dart';
import 'package:eduserveapp/core/services/activity_log_service.dart';
import 'package:eduserveapp/core/services/post_service.dart';
import 'package:eduserveapp/features/settings/settings_screen.dart';
import 'package:eduserveapp/features/settings/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.uid,
    required this.themeController,
    required this.onLogout,
  });

  final String uid;
  final ThemeController themeController;
  final Future<void> Function() onLogout;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<_DashboardInsight> _dashboardInsightFuture;
  int _activeTabIndex = 0;
  bool _clearingLogs = false;
  String _activityStreamKey = 'activity';
  String _sessionsStreamKey = 'sessions';

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _userDocs =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  DocumentSnapshot<Map<String, dynamic>>? _lastUserDoc;
  bool _loadingUsers = false;
  bool _loadingMoreUsers = false;
  bool _hasMoreUsers = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _activeTabIndex = _tabController.index);
      }
    });
    _dashboardInsightFuture = _loadDashboardInsight();
    ActivityLogService.instance.logCurrentUserAction(
      uid: widget.uid,
      action: 'open_admin_dashboard',
      tab: 'admin',
    );
    unawaited(ActivityLogService.instance.cleanupLogsIfDue());
    _loadInitialUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '-';
    return DateFormat('MMM d, y').format(ts.toDate());
  }

  String _formatDateTime(Timestamp? ts) {
    if (ts == null) return '-';
    return DateFormat('MMM d, h:mm a').format(ts.toDate());
  }

  String _formatDuration(num? seconds) {
    if (seconds == null) return '-';
    final total = seconds.toInt();
    final mins = total ~/ 60;
    final secs = total % 60;
    if (mins == 0) return '${secs}s';
    return '${mins}m ${secs.toString().padLeft(2, '0')}s';
  }

  String _mostUsedTabFromUsage(Map<dynamic, dynamic>? usage) {
    final counts = _extractTabUsageCounts(usage);

    String topTab = 'home';
    var maxCount = 0;
    counts.forEach((tab, opens) {
      if (opens > maxCount) {
        maxCount = opens;
        topTab = tab;
      }
    });

    return maxCount == 0 ? '-' : topTab;
  }

  Map<String, int> _extractTabUsageCounts(Map<dynamic, dynamic>? usage) {
    final tabUsage = usage ?? <dynamic, dynamic>{};
    return <String, int>{
      'home': (tabUsage['home'] as num?)?.toInt() ?? 0,
      'eduserve': (tabUsage['eduserve'] as num?)?.toInt() ?? 0,
      'results': (tabUsage['results'] as num?)?.toInt() ?? 0,
      'ai': (tabUsage['ai'] as num?)?.toInt() ?? 0,
      'addons': (tabUsage['addons'] as num?)?.toInt() ?? 0,
    };
  }

  String _tabLabel(String tabKey) {
    switch (tabKey) {
      case 'home':
        return 'Home';
      case 'eduserve':
        return 'EduServe';
      case 'results':
        return 'Results';
      case 'ai':
        return 'AI';
      case 'addons':
        return 'Add-ons';
      default:
        return tabKey;
    }
  }

  Future<_DashboardInsight> _loadDashboardInsight() async {
    final usersFuture = FirebaseFirestore.instance
        .collection(AppConfig.usersCollection)
        .count()
        .get();

    final sessionDocsFuture = FirebaseFirestore.instance
        .collection(AppConfig.userSessionsCollection)
        .orderBy('start', descending: true)
        .limit(200)
        .get();

    final results = await Future.wait<dynamic>(
      <Future<dynamic>>[
        usersFuture,
        sessionDocsFuture,
      ],
    );

    final usersCount = (results[0] as AggregateQuerySnapshot).count ?? 0;
    final sessionDocs =
        (results[1] as QuerySnapshot<Map<String, dynamic>>).docs;

    final todayStart = DateTime.now();
    final todayCutoff =
        DateTime(todayStart.year, todayStart.month, todayStart.day);

    final validSessions = sessionDocs.where((doc) {
      final duration = (doc.data()['duration'] as num?)?.toInt() ?? 0;
      return duration >= 2;
    }).toList();

    final activeUsersToday = <String>{};
    for (final doc in validSessions) {
      final uid = (doc.data()['uid'] as String?)?.trim() ?? '';
      final start = doc.data()['start'] as Timestamp?;
      if (uid.isNotEmpty &&
          start != null &&
          start.toDate().isAfter(todayCutoff)) {
        activeUsersToday.add(uid);
      }
    }

    num totalDurationSeconds = 0;
    var durationDocsCount = 0;
    for (final doc in validSessions) {
      final duration = doc.data()['duration'] as num?;
      if (duration != null && duration >= 0) {
        totalDurationSeconds += duration;
        durationDocsCount += 1;
      }
    }

    final averageDurationSeconds = durationDocsCount == 0
        ? 0
        : (totalDurationSeconds / durationDocsCount).round();

    final aggregatedTabUsage = <String, int>{
      'home': 0,
      'eduserve': 0,
      'results': 0,
      'ai': 0,
      'addons': 0,
    };
    for (final doc in validSessions) {
      final tabCounts = _extractTabUsageCounts(
          doc.data()['tabCounts'] as Map<dynamic, dynamic>?);
      tabCounts.forEach((tab, opens) {
        aggregatedTabUsage[tab] = (aggregatedTabUsage[tab] ?? 0) + opens;
      });
    }

    debugPrint('[AdminDashboard] Extracted opens=$aggregatedTabUsage');

    var mostUsedTab = '-';
    var mostUsedCount = 0;
    aggregatedTabUsage.forEach((tab, opens) {
      if (opens > mostUsedCount) {
        mostUsedCount = opens;
        mostUsedTab = _tabLabel(tab);
      }
    });

    final totalTabUsage =
        aggregatedTabUsage.values.fold<int>(0, (total, value) => total + value);
    final tabUsagePercentages = <String, double>{};
    aggregatedTabUsage.forEach((tab, opens) {
      if (totalTabUsage == 0) {
        tabUsagePercentages[tab] = 0;
      } else {
        tabUsagePercentages[tab] = (opens / totalTabUsage) * 100;
      }
    });

    debugPrint(
      '[AdminDashboard] Tab opens: $aggregatedTabUsage, '
      'total=$totalTabUsage, percentages=$tabUsagePercentages',
    );

    return _DashboardInsight(
      totalUsers: usersCount,
      activeSessions: activeUsersToday.length,
      averageSessionDurationSeconds: averageDurationSeconds,
      mostUsedTab: mostUsedTab,
      tabUsagePercentages: tabUsagePercentages,
      hasAnalyticsData: validSessions.isNotEmpty,
    );
  }

  Future<void> _showUserDetail(Map<String, dynamic> data) async {
    final name = (data['name'] as String?)?.trim() ?? 'User';
    final tabUsage =
        _extractTabUsageCounts(data['tabUsage'] as Map<dynamic, dynamic>?);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$name - Usage Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Home: ${tabUsage['home'] ?? 0}'),
              Text('EduServe: ${tabUsage['eduserve'] ?? 0}'),
              Text('Results: ${tabUsage['results'] ?? 0}'),
              Text('AI: ${tabUsage['ai'] ?? 0}'),
              Text('Add-ons: ${tabUsage['addons'] ?? 0}'),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadInitialUsers() async {
    setState(() {
      _loadingUsers = true;
      _hasMoreUsers = true;
      _userDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      _lastUserDoc = null;
    });

    final query = FirebaseFirestore.instance
        .collection(AppConfig.usersCollection)
        .orderBy('createdAt', descending: true)
        .limit(50);
    final snap = await query.get();
    setState(() {
      _userDocs = snap.docs;
      _lastUserDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
      _hasMoreUsers = snap.docs.length == 50;
      _loadingUsers = false;
    });
  }

  Future<void> _loadMoreUsers() async {
    if (_loadingMoreUsers || !_hasMoreUsers || _lastUserDoc == null) return;
    setState(() => _loadingMoreUsers = true);

    final query = FirebaseFirestore.instance
        .collection(AppConfig.usersCollection)
        .orderBy('createdAt', descending: true)
        .startAfterDocument(_lastUserDoc!)
        .limit(50);
    final snap = await query.get();
    setState(() {
      _userDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[
        ..._userDocs,
        ...snap.docs,
      ];
      _lastUserDoc = snap.docs.isNotEmpty ? snap.docs.last : _lastUserDoc;
      _hasMoreUsers = snap.docs.length == 50;
      _loadingMoreUsers = false;
    });
  }

  Future<void> _createPost() async {
    final result = await showDialog<_PostPayload>(
      context: context,
      builder: (context) => const _PostEditorDialog(),
    );
    if (result == null) {
      return;
    }
    await PostService.instance.createPost(
      title: result.title,
      description: result.description,
      imageUrl: result.imageUrl,
      link: result.link,
      isDraft: result.isDraft,
      createdBy: widget.uid,
    );

    await ActivityLogService.instance.logCurrentUserAction(
      uid: widget.uid,
      action: result.isDraft ? 'draft_post' : 'create_post',
      tab: 'admin',
    );
  }

  Future<void> _editPost(String docId, Map<String, dynamic> data) async {
    final result = await showDialog<_PostPayload>(
      context: context,
      builder: (context) => _PostEditorDialog(initialData: data),
    );
    if (result == null) {
      return;
    }

    await PostService.instance.updatePost(
      docId: docId,
      title: result.title,
      description: result.description,
      imageUrl: result.imageUrl,
      link: result.link,
      isDraft: result.isDraft,
    );

    await ActivityLogService.instance.logCurrentUserAction(
      uid: widget.uid,
      action: result.isDraft ? 'draft_post' : 'edit_post',
      tab: 'admin',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const <Widget>[
            Tab(text: 'Overview'),
            Tab(text: 'Users'),
            Tab(text: 'Activity'),
            Tab(text: 'Sessions'),
            Tab(text: 'Posts'),
          ],
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SettingsScreen(
                    themeController: widget.themeController,
                    onLogout: widget.onLogout,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: IndexedStack(
        index: _activeTabIndex,
        children: <Widget>[
          _buildOverviewTab(),
          _buildUsersTab(),
          _buildActivityTab(),
          _buildSessionsTab(),
          _buildPostsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _dashboardInsightFuture = _loadDashboardInsight();
        });
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(child: _SectionTitle('Overview')),
              IconButton(
                onPressed: () {
                  setState(() {
                    _dashboardInsightFuture = _loadDashboardInsight();
                  });
                },
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh analytics',
              ),
            ],
          ),
          FutureBuilder<_DashboardInsight>(
            future: _dashboardInsightFuture,
            builder: (context, snapshot) {
              final data = snapshot.data;

              if (snapshot.connectionState == ConnectionState.waiting &&
                  data == null) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError && data == null) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Failed to load analytics: ${snapshot.error}'),
                  ),
                );
              }

              if (data == null) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No analytics available.'),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      _InsightCard(
                        label: 'Total Users',
                        value: data.totalUsers.toString(),
                      ),
                      _InsightCard(
                        label: 'Active Users',
                        value: data.activeSessions.toString(),
                      ),
                      _InsightCard(
                        label: 'Avg Session Duration',
                        value:
                            _formatDuration(data.averageSessionDurationSeconds),
                      ),
                      _InsightCard(
                        label: 'Most Used Tab',
                        value: data.mostUsedTab,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const _SectionTitle('Tab Usage Distribution'),
                  if (!data.hasAnalyticsData)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No analytics data yet'),
                      ),
                    )
                  else
                    ...<MapEntry<String, double>>[
                      MapEntry(
                        'eduserve',
                        data.tabUsagePercentages['eduserve'] ?? 0,
                      ),
                      MapEntry('ai', data.tabUsagePercentages['ai'] ?? 0),
                      MapEntry(
                        'results',
                        data.tabUsagePercentages['results'] ?? 0,
                      ),
                      MapEntry(
                        'addons',
                        data.tabUsagePercentages['addons'] ?? 0,
                      ),
                      MapEntry('home', data.tabUsagePercentages['home'] ?? 0),
                    ].map((entry) {
                      return _UsageBarRow(
                        label: _tabLabel(entry.key),
                        percentage: entry.value,
                      );
                    }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    return RefreshIndicator(
      onRefresh: _loadInitialUsers,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const _SectionTitle('Users'),
          const SizedBox(height: 4),
          if (_loadingUsers)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator()))
          else if (_userDocs.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No users yet.'),
              ),
            )
          else
            Column(
              children: [
                ..._userDocs.map((doc) {
                  final data = doc.data();
                  final name = (data['name'] as String?)?.trim() ?? 'User';
                  final email = (data['email'] as String?)?.trim() ?? '';
                  final reg = (data['registerNumber'] as String?)?.trim() ?? '';
                  final dept = (data['dept'] as String?)?.trim() ?? '';
                  final year = (data['year'] as num?)?.toInt();
                  final gender = (data['gender'] as String?)?.trim();
                  final phone = (data['phone'] as String?)?.trim();
                  final createdAt = data['createdAt'];
                  final tabUsage = data['tabUsage'] as Map<String, dynamic>?;
                  final mostUsedTab = _mostUsedTabFromUsage(tabUsage);

                  final subtitleLines = <String>[
                    if (email.isNotEmpty) email,
                    if (reg.isNotEmpty) 'Reg: $reg',
                    if (dept.isNotEmpty || year != null)
                      '${dept.toUpperCase()} • Year ${year ?? '-'}',
                    if (gender != null && gender.isNotEmpty) 'Gender: $gender',
                    if (phone != null && phone.isNotEmpty) 'Phone: $phone',
                    'Most used tab: $mostUsedTab',
                    'Joined: ${_formatDate(createdAt is Timestamp ? createdAt : null)}',
                  ]..removeWhere((e) => e.trim().isEmpty);

                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(name.isEmpty ? 'User' : name),
                      subtitle: Text(subtitleLines.join('\n')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showUserDetail(data),
                    ),
                  );
                }),
                if (_hasMoreUsers)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: FilledButton.icon(
                      onPressed: _loadingMoreUsers ? null : _loadMoreUsers,
                      icon: _loadingMoreUsers
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.expand_more),
                      label:
                          Text(_loadingMoreUsers ? 'Loading...' : 'Load more'),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActivityTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(child: _SectionTitle('Recent Tab Activity')),
            IconButton(
              onPressed: () {
                setState(() {
                  _activityStreamKey =
                      DateTime.now().millisecondsSinceEpoch.toString();
                });
              },
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh activity',
            ),
          ],
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: _clearingLogs ? null : _clearActivityLogs,
              icon: _clearingLogs
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_forever_outlined),
              label: Text(_clearingLogs ? 'Clearing...' : 'Clear sessions'),
            ),
            OutlinedButton.icon(
              onPressed: _loadInitialUsers,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh users'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          key: ValueKey(_activityStreamKey),
          stream: FirebaseFirestore.instance
              .collection(AppConfig.userSessionsCollection)
              .orderBy('start', descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            final docs = (snapshot.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                .where(
                  (doc) =>
                      ((doc.data()['duration'] as num?)?.toInt() ?? 0) >= 2,
                )
                .toList();
            if (docs.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No recent activity.'),
                ),
              );
            }

            return Column(
              children: docs.map((doc) {
                final data = doc.data();
                final email = (data['email'] as String?)?.trim() ?? '';
                final uid = (data['uid'] as String?)?.trim() ?? '';
                final startTime = data['start'] as Timestamp?;
                final endTime = data['end'] as Timestamp?;
                final duration = data['duration'] as num?;
                final tabCounts = _extractTabUsageCounts(
                    data['tabCounts'] as Map<dynamic, dynamic>?);
                final totalOpens = (data['totalTabs'] as num?)?.toInt() ??
                    tabCounts.values
                        .fold<int>(0, (total, value) => total + value);

                var topTab = '-';
                var topCount = 0;
                tabCounts.forEach((tab, opens) {
                  if (opens > topCount) {
                    topCount = opens;
                    topTab = _tabLabel(tab);
                  }
                });

                final subtitleLines = <String>[
                  if (email.isNotEmpty) 'Email: $email',
                  if (uid.isNotEmpty) 'UID: $uid',
                  'Start: ${_formatDateTime(startTime)}',
                  'End: ${_formatDateTime(endTime)}',
                  'Duration: ${_formatDuration(duration)}',
                  'Total tab opens: $totalOpens',
                  'Most used tab: $topTab',
                ];

                return Card(
                  child: ListTile(
                    title: Text(uid.isEmpty ? 'Session' : uid),
                    subtitle: Text(subtitleLines.join('\n')),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSessionsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(child: _SectionTitle('Recent Sessions')),
            IconButton(
              onPressed: () => setState(
                () => _sessionsStreamKey =
                    DateTime.now().millisecondsSinceEpoch.toString(),
              ),
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh sessions',
            ),
          ],
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          key: ValueKey(_sessionsStreamKey),
          stream: FirebaseFirestore.instance
              .collection(AppConfig.userSessionsCollection)
              .orderBy('start', descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            final docs = (snapshot.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                .where(
                  (doc) =>
                      ((doc.data()['duration'] as num?)?.toInt() ?? 0) >= 2,
                )
                .toList();
            if (docs.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No recent sessions.'),
                ),
              );
            }

            return Column(
              children: docs.map((doc) {
                final data = doc.data();
                final uid = (data['uid'] as String?)?.trim() ?? '';
                final email = (data['email'] as String?)?.trim() ?? '';
                final sessionStart = data['start'] as Timestamp?;
                final sessionEnd = data['end'] as Timestamp?;
                final duration = data['duration'] as num?;
                final tabCounts = _extractTabUsageCounts(
                    data['tabCounts'] as Map<dynamic, dynamic>?);
                final totalOpens = (data['totalTabs'] as num?)?.toInt() ??
                    tabCounts.values
                        .fold<int>(0, (total, value) => total + value);
                final mostUsedTab =
                    (data['mostUsedTab'] as String?)?.trim() ?? '-';

                final subtitleLines = <String>[
                  if (email.isNotEmpty) 'Email: $email',
                  if (uid.isNotEmpty) 'UID: $uid',
                  'Start: ${_formatDateTime(sessionStart)}',
                  'End: ${_formatDateTime(sessionEnd)}',
                  'Duration: ${_formatDuration(duration)}',
                  'Total tab opens: $totalOpens',
                  'Most used tab: ${_tabLabel(mostUsedTab)}',
                ];

                return Card(
                  child: ListTile(
                    title: Text(uid.isEmpty ? 'Session' : uid),
                    subtitle: Text(subtitleLines.join('\n')),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPostsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(child: _SectionTitle('Posts')),
            FilledButton.icon(
              onPressed: _createPost,
              icon: const Icon(Icons.add),
              label: const Text('Create'),
            ),
          ],
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(AppConfig.postsCollection)
              .orderBy('createdAt', descending: true)
              .limit(20)
              .snapshots(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            if (docs.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No posts yet.'),
                ),
              );
            }

            return Column(
              children: docs.map((doc) {
                final data = doc.data();
                final title = (data['title'] as String?) ?? 'Untitled';
                final description = (data['description'] as String?) ?? '';
                final link = (data['link'] as String?) ?? '';
                final imageUrl = (data['imageUrl'] as String?) ?? '';
                final isDraft = data['isDraft'] == true;
                final createdAt = data['createdAt'];
                final createdBy = (data['createdBy'] as String?) ?? '';

                final when = createdAt is Timestamp
                    ? DateFormat('MMM d, h:mm a').format(createdAt.toDate())
                    : '-';

                final subtitleLines = <String>[
                  description,
                  if (link.isNotEmpty) link,
                  'Created: $when',
                  if (createdBy.isNotEmpty) 'By: $createdBy',
                  if (isDraft) 'Status: Draft',
                ]..removeWhere((e) => e.trim().isEmpty);

                return Card(
                  child: ListTile(
                    leading: imageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              height: 42,
                              width: 42,
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          )
                        : const Icon(Icons.campaign_outlined),
                    title: Text(title),
                    subtitle: Text(subtitleLines.join('\n')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _editPost(doc.id, data),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await PostService.instance.deletePost(doc.id);
                            await ActivityLogService.instance
                                .logCurrentUserAction(
                              uid: widget.uid,
                              action: 'delete_post',
                              tab: 'admin',
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Future<void> _clearActivityLogs() async {
    setState(() => _clearingLogs = true);
    try {
      await ActivityLogService.instance.purgeAllLogsNow();
      await ActivityLogService.instance.purgeAllLogsOnce();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sessions cleared')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear sessions: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _clearingLogs = false);
      }
    }
  }
}

class _DashboardInsight {
  const _DashboardInsight({
    required this.totalUsers,
    required this.activeSessions,
    required this.averageSessionDurationSeconds,
    required this.mostUsedTab,
    required this.tabUsagePercentages,
    required this.hasAnalyticsData,
  });

  final int totalUsers;
  final int activeSessions;
  final int averageSessionDurationSeconds;
  final String mostUsedTab;
  final Map<String, double> tabUsagePercentages;
  final bool hasAnalyticsData;
}

class _UsageBarRow extends StatelessWidget {
  const _UsageBarRow({
    required this.label,
    required this.percentage,
  });

  final String label;
  final double percentage;

  String _buildBlocks(double clampedPercentage) {
    const totalBlocks = 20;
    final filledBlocks = ((clampedPercentage / 100) * totalBlocks).round();
    final filled = List<String>.filled(filledBlocks, '█').join();
    final empty = List<String>.filled(totalBlocks - filledBlocks, '░').join();
    return '$filled$empty';
  }

  @override
  Widget build(BuildContext context) {
    final clamped = percentage.clamp(0, 100).toDouble();
    final blocks = _buildBlocks(clamped);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        '$label  $blocks ${clamped.round()}%',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        width: 165,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostPayload {
  const _PostPayload({
    required this.title,
    required this.description,
    this.imageUrl,
    this.link,
    required this.isDraft,
  });

  final String title;
  final String description;
  final String? imageUrl;
  final String? link;
  final bool isDraft;
}

class _PostEditorDialog extends StatefulWidget {
  const _PostEditorDialog({this.initialData});

  final Map<String, dynamic>? initialData;

  @override
  State<_PostEditorDialog> createState() => _PostEditorDialogState();
}

class _PostEditorDialogState extends State<_PostEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _imageUrl;
  late final TextEditingController _link;
  bool _isDraft = false;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    _title = TextEditingController(text: (data?['title'] as String?) ?? '');
    _description =
        TextEditingController(text: (data?['description'] as String?) ?? '');
    _imageUrl =
        TextEditingController(text: (data?['imageUrl'] as String?) ?? '');
    _link = TextEditingController(text: (data?['link'] as String?) ?? '');
    _isDraft = data?['isDraft'] == true;

    _imageUrl.addListener(() => setState(() {}));
    _link.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _imageUrl.dispose();
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialData == null ? 'Create Post' : 'Edit Post'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'title'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'description'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _imageUrl,
              decoration:
                  const InputDecoration(labelText: 'Image URL (optional)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _link,
              decoration: const InputDecoration(labelText: 'Link (optional)'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Save as draft'),
              value: _isDraft,
              onChanged: (value) => setState(() => _isDraft = value),
            ),
            const SizedBox(height: 12),
            _PreviewCard(
              title: _title.text.trim(),
              description: _description.text.trim(),
              imageUrl: _imageUrl.text.trim(),
              link: _link.text.trim(),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final title = _title.text.trim();
            final description = _description.text.trim();
            final imageUrl = _imageUrl.text.trim();
            final link = _link.text.trim();
            if (title.isEmpty || description.isEmpty) {
              return;
            }
            Navigator.of(context).pop(
              _PostPayload(
                title: title,
                description: description,
                imageUrl: imageUrl.isEmpty ? null : imageUrl,
                link: link.isEmpty ? null : link,
                isDraft: _isDraft,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.link,
  });

  final String title;
  final String description;
  final String imageUrl;
  final String link;

  bool get hasImage => imageUrl.startsWith('http');
  bool get hasLink => link.startsWith('http');

  @override
  Widget build(BuildContext context) {
    final subtitleLines = <String>[
      if (description.isNotEmpty) description,
      if (hasLink) link,
    ]..removeWhere((e) => e.trim().isEmpty);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.campaign_outlined),
            title: Text(title.isEmpty ? 'Preview Title' : title),
            subtitle: Text(
              subtitleLines.isEmpty
                  ? 'Preview description'
                  : subtitleLines.join('\n'),
            ),
            trailing: hasLink ? const Icon(Icons.open_in_new, size: 18) : null,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
