import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eduserveapp/core/constants/app_config.dart';
import 'package:eduserveapp/core/services/analytics_service.dart';
import 'package:eduserveapp/core/services/topic_push_service.dart';

class HackathonService {
  HackathonService._();

  static final HackathonService instance = HackathonService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createPost({
    required String title,
    required String description,
    required String url,
    required DateTime startDate,
    required DateTime endDate,
    required String createdBy,
    bool isDraft = false,
  }) async {
    await _firestore.collection(AppConfig.hackathonsCollection).add(
      <String, dynamic>{
        'title': title,
        'description': description,
        'url': url,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'isDraft': isDraft,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
      },
    );

    var pushSent = false;
    if (!isDraft) {
      await _firestore
          .collection(AppConfig.notificationsCollection)
          .add(<String, dynamic>{
        'title': 'New Hackathon 🚀',
        'message': 'Innovation Challenge announced',
        'createdAt': FieldValue.serverTimestamp(),
      });

      pushSent = await TopicPushService.instance.sendHackathonPush(
        title: 'New Hackathon 🚀',
        message: 'Innovation Challenge announced',
      );
    }

    await AnalyticsService.instance.logEvent(
      pushSent
          ? 'hackathon_notification_sent'
          : 'hackathon_notification_queued',
    );

    await cleanupExpiredPosts();
    await _enforceMaxPosts();
  }

  Future<void> updatePost({
    required String docId,
    required String title,
    required String description,
    required String url,
    required DateTime startDate,
    required DateTime endDate,
    required bool isDraft,
  }) async {
    await _firestore.collection(AppConfig.hackathonsCollection).doc(docId).set(
      <String, dynamic>{
        'title': title,
        'description': description,
        'url': url,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'isDraft': isDraft,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> cleanupExpiredPosts() async {
    final now = Timestamp.fromDate(DateTime.now());
    final expired = await _firestore
        .collection(AppConfig.hackathonsCollection)
        .where('endDate', isLessThan: now)
        .limit(50)
        .get();

    if (expired.docs.isEmpty) {
      return;
    }

    final batch = _firestore.batch();
    for (final doc in expired.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> deletePost(String docId) async {
    await _firestore
        .collection(AppConfig.hackathonsCollection)
        .doc(docId)
        .delete();
  }

  Future<void> _enforceMaxPosts() async {
    final snapshot = await _firestore
        .collection(AppConfig.hackathonsCollection)
        .orderBy('createdAt', descending: true)
        .get();

    if (snapshot.docs.length <= 10) {
      return;
    }

    final batch = _firestore.batch();
    for (final doc in snapshot.docs.skip(10)) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
