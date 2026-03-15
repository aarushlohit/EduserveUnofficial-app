import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eduserveapp/core/constants/app_config.dart';
import 'package:eduserveapp/core/services/activity_log_service.dart';
import 'package:eduserveapp/core/services/hackathon_service.dart';
import 'package:eduserveapp/features/settings/settings_screen.dart';
import 'package:eduserveapp/features/settings/theme_controller.dart';
import 'package:flutter/material.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.uid,
    required this.themeController,
    required this.onCheckUpdates,
    required this.onOpenProfile,
    required this.onBootstrapUpdateConfig,
    required this.onLogout,
  });

  final String uid;
  final ThemeController themeController;
  final Future<void> Function() onCheckUpdates;
  final Future<void> Function() onOpenProfile;
  final Future<void> Function() onBootstrapUpdateConfig;
  final Future<void> Function() onLogout;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    ActivityLogService.instance.logCurrentUserAction(
      uid: widget.uid,
      action: 'open_admin_dashboard',
      tab: 'admin',
    );

    unawaited(HackathonService.instance.cleanupExpiredPosts());
  }

  Future<void> _createPost() async {
    final result = await showDialog<_PostPayload>(
      context: context,
      builder: (context) => const _PostEditorDialog(),
    );
    if (result == null) {
      return;
    }

    await HackathonService.instance.createPost(
      title: result.title,
      description: result.description,
      url: result.url,
      startDate: result.startDate,
      endDate: result.endDate,
      createdBy: widget.uid,
      isDraft: result.isDraft,
    );

    await ActivityLogService.instance.logCurrentUserAction(
      uid: widget.uid,
      action: result.isDraft ? 'draft_hackathon' : 'create_hackathon',
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

    await HackathonService.instance.updatePost(
      docId: docId,
      title: result.title,
      description: result.description,
      url: result.url,
      startDate: result.startDate,
      endDate: result.endDate,
      isDraft: result.isDraft,
    );

    await ActivityLogService.instance.logCurrentUserAction(
      uid: widget.uid,
      action: 'edit_hackathon',
      tab: 'admin',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: <Widget>[
          IconButton(
            onPressed: _createPost,
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Create post',
          ),
          IconButton(
            onPressed: widget.onOpenProfile,
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
          ),
          IconButton(
            onPressed: () {
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
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const _SectionTitle('Analytics'),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection(AppConfig.appStatsCollection)
                .doc('global')
                .snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data() ?? <String, dynamic>{};
              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.35,
                children: <Widget>[
                  _StatCard(
                    label: 'Active Users Today',
                    value: '${(data['activeUsersToday'] ?? 0)}',
                  ),
                  _StatCard(
                    label: 'Total Users',
                    value: '${(data['totalUsers'] ?? 0)}',
                  ),
                  _StatCard(
                    label: 'App Opens',
                    value: '${(data['appOpens'] ?? 0)}',
                  ),
                  _StatCard(
                    label: 'AI Messages',
                    value: '${(data['aiMessages'] ?? 0)}',
                  ),
                  _StatCard(
                    label: 'Most Used Tab',
                    value: '${(data['mostUsedTab'] ?? 'home')}',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              const Expanded(child: _SectionTitle('Hackathon Posts')),
              FilledButton.icon(
                onPressed: _createPost,
                icon: const Icon(Icons.add),
                label: const Text('Create'),
              ),
            ],
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection(AppConfig.hackathonsCollection)
                .orderBy('createdAt', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ??
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              if (docs.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No hackathon posts yet.'),
                  ),
                );
              }

              return Column(
                children: docs.map((doc) {
                  final data = doc.data();
                  final isDraft = data['isDraft'] == true;
                  final endDate = data['endDate'];
                  final endText = endDate is Timestamp
                      ? endDate.toDate().toIso8601String().split('T').first
                      : '-';

                  return Card(
                    child: ListTile(
                      leading: Icon(
                        isDraft ? Icons.description_outlined : Icons.rocket_launch,
                      ),
                      title: Text((data['title'] as String?) ?? 'Untitled'),
                      subtitle: Text(
                        '${(data['description'] as String?) ?? ''}\nEnd: $endText',
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            onPressed: () => _editPost(doc.id, data),
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            tooltip: 'Delete',
                            onPressed: () async {
                              await HackathonService.instance.deletePost(doc.id);
                              await ActivityLogService.instance.logCurrentUserAction(
                                uid: widget.uid,
                                action: 'delete_hackathon',
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
      ),
    );
  }
}

class _PostPayload {
  const _PostPayload({
    required this.title,
    required this.description,
    required this.url,
    required this.startDate,
    required this.endDate,
    required this.isDraft,
  });

  final String title;
  final String description;
  final String url;
  final DateTime startDate;
  final DateTime endDate;
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
  late final TextEditingController _url;
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isDraft = false;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    _title = TextEditingController(text: (data?['title'] as String?) ?? '');
    _description =
        TextEditingController(text: (data?['description'] as String?) ?? '');
    _url = TextEditingController(text: (data?['url'] as String?) ?? '');

    final start = data?['startDate'];
    final end = data?['endDate'];
    _startDate = start is Timestamp ? start.toDate() : DateTime.now();
    _endDate = end is Timestamp
        ? end.toDate()
        : DateTime.now().add(const Duration(days: 10));
    _isDraft = data?['isDraft'] == true;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final base = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
    );
    if (picked == null) {
      return;
    }

    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
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
              controller: _url,
              decoration: const InputDecoration(labelText: 'url'),
            ),
            const SizedBox(height: 8),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('startDate: ${_startDate.toIso8601String().split('T').first}'),
              trailing: const Icon(Icons.calendar_month),
              onTap: () => _pickDate(isStart: true),
            ),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('endDate: ${_endDate.toIso8601String().split('T').first}'),
              trailing: const Icon(Icons.calendar_month),
              onTap: () => _pickDate(isStart: false),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Save as draft'),
              value: _isDraft,
              onChanged: (value) => setState(() => _isDraft = value),
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
            final url = _url.text.trim();
            if (title.isEmpty || description.isEmpty || url.isEmpty) {
              return;
            }
            Navigator.of(context).pop(
              _PostPayload(
                title: title,
                description: description,
                url: url,
                startDate: _startDate,
                endDate: _endDate,
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
