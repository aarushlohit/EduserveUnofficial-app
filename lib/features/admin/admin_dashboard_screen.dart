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
  late final String _todayDocId;
  late final TabController _tabController;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _userDocs =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  DocumentSnapshot<Map<String, dynamic>>? _lastUserDoc;
  bool _loadingUsers = false;
  bool _loadingMoreUsers = false;
  bool _hasMoreUsers = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _todayDocId = _formatTodayDocId();
    ActivityLogService.instance.logCurrentUserAction(
      uid: widget.uid,
      action: 'open_admin_dashboard',
      tab: 'admin',
    );
    unawaited(ActivityLogService.instance.cleanupLogsIfDue());
    unawaited(_primeAnalyticsDocuments());
    _loadInitialUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _primeAnalyticsDocuments() async {
    final dailyRef = FirebaseFirestore.instance
        .collection(AppConfig.analyticsDailyCollection)
        .doc(_todayDocId);
    final globalRef = FirebaseFirestore.instance
        .collection(AppConfig.analyticsGlobalCollection)
        .doc(AppConfig.analyticsGlobalDoc);

    // Ensure today's doc exists with zeroed counters so the dashboard never renders empty.
    await dailyRef.set(
      <String, dynamic>{
        'appOpens': FieldValue.increment(0),
        'homeOpens': FieldValue.increment(0),
        'eduserveOpens': FieldValue.increment(0),
        'resultsOpens': FieldValue.increment(0),
        'aiOpens': FieldValue.increment(0),
        'addonsOpens': FieldValue.increment(0),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Ensure global doc exists with zeroed counters.
    await globalRef.set(
      <String, dynamic>{
        'activeUsersToday': FieldValue.increment(0),
        'totalUsers': FieldValue.increment(0),
        'aiMessages': FieldValue.increment(0),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  String _formatTodayDocId() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  String _deriveMostUsedTab(Map<String, dynamic> daily) {
    final tabCounts = <String, int>{
      'home': (daily['homeOpens'] as num?)?.toInt() ?? 0,
      'eduserve': (daily['eduserveOpens'] as num?)?.toInt() ?? 0,
      'results': (daily['resultsOpens'] as num?)?.toInt() ?? 0,
      'ai': (daily['aiOpens'] as num?)?.toInt() ?? 0,
      'addons': (daily['addonsOpens'] as num?)?.toInt() ?? 0,
    };

    var maxTab = 'home';
    var maxCount = -1;
    tabCounts.forEach((tab, count) {
      if (count > maxCount) {
        maxCount = count;
        maxTab = tab;
      }
    });
    return maxTab;
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '-';
    return DateFormat('MMM d, y').format(ts.toDate());
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
            Tab(text: 'Users'),
            Tab(text: 'Activity'),
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
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          _buildUsersTab(),
          _buildActivityTab(),
          _buildPostsTab(),
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
          if (_loadingUsers)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
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

                  final subtitleLines = <String>[
                    if (email.isNotEmpty) email,
                    if (reg.isNotEmpty) 'Reg: $reg',
                    if (dept.isNotEmpty || year != null)
                      '${dept.toUpperCase()} • Year ${year ?? '-'}',
                    if (gender != null && gender.isNotEmpty) 'Gender: $gender',
                    if (phone != null && phone.isNotEmpty) 'Phone: $phone',
                    'Joined: ${_formatDate(createdAt is Timestamp ? createdAt : null)}',
                  ]..removeWhere((e) => e.trim().isEmpty);

                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(name.isEmpty ? 'User' : name),
                      subtitle: Text(subtitleLines.join('\n')),
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
                      label: Text(_loadingMoreUsers ? 'Loading...' : 'Load more'),
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
        const _SectionTitle('Recent Activity'),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(AppConfig.userActivityCollection)
              .orderBy('timestamp', descending: true)
              .limit(50)
              .snapshots(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            final filtered = docs.where((doc) {
              final role = doc.data()['role'];
              return role != 'admin';
            }).toList();

            if (filtered.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No recent activity.'),
                ),
              );
            }

            return Column(
              children: filtered.map((doc) {
                final data = doc.data();
                final ts = data['timestamp'];
                DateTime? time;
                if (ts is Timestamp) {
                  time = ts.toDate();
                }
                final formatter = DateFormat('MMM d, h:mm a');
                final when = time != null ? formatter.format(time) : '-';
                final name = (data['name'] as String?)?.trim() ?? 'User';
                final reg = (data['registerNumber'] as String?)?.trim();
                final dept = (data['dept'] as String?)?.trim();
                final action = (data['action'] as String?) ?? 'activity';

                final title = [
                  name,
                  if (reg != null && reg.isNotEmpty) '($reg)',
                ].join(' ').trim();

                final subtitleLines = <String>[
                  if (dept != null && dept.isNotEmpty) dept.toUpperCase(),
                  action.replaceFirst('open_', 'Opened '),
                  when,
                ]..removeWhere((e) => e.trim().isEmpty);

                return Card(
                  child: ListTile(
                    title: Text(title.isEmpty ? 'User' : title),
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
                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
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
                            await ActivityLogService.instance.logCurrentUserAction(
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
    _imageUrl = TextEditingController(text: (data?['imageUrl'] as String?) ?? '');
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
              decoration: const InputDecoration(labelText: 'Image URL (optional)'),
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
                    color: Theme.of(context).colorScheme.surfaceVariant,
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
              subtitleLines.isEmpty ? 'Preview description' : subtitleLines.join('\n'),
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
        style:
            Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text(
            value,
            style:
                Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
