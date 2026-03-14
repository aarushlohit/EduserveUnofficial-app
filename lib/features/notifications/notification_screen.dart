import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eduserveapp/core/constants/app_config.dart';
import 'package:eduserveapp/core/services/notification_service.dart';
import 'package:flutter/material.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({
    super.key,
    required this.onMarkedRead,
    required this.isAdmin,
  });

  final VoidCallback onMarkedRead;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              NotificationService.instance.markAllAsRead();
              onMarkedRead();
              Navigator.of(context).pop();
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection(AppConfig.notificationsCollection)
            .orderBy('createdAt', descending: true)
            .limit(30)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs =
              snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          if (docs.isEmpty) {
            return const Center(
              child: Text('No notifications available.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final title = (data['title'] as String?) ?? 'Notification';
              final message = (data['message'] as String?) ?? '';
              final createdAt = data['createdAt'];

              String time = '-';
              if (createdAt is Timestamp) {
                final dt = createdAt.toDate();
                time =
                    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
              }

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.notifications_active,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                  title: Text(title),
                  subtitle: Text(message),
                  trailing: Text(time),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showPushDialog(context),
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Push'),
            )
          : null,
    );
  }

  Future<void> _showPushDialog(BuildContext context) async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();

    final pushed = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Push Notification'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(labelText: 'Message'),
                maxLines: 3,
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );

    if (pushed != true) return;

    await FirebaseFirestore.instance
        .collection(AppConfig.notificationsCollection)
        .add(<String, dynamic>{
      'title': titleController.text.trim(),
      'message': messageController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
