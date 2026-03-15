import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eduserveapp/core/constants/app_config.dart';
import 'package:eduserveapp/core/services/firestore_user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ActivityLogService {
  ActivityLogService._();

  static final ActivityLogService instance = ActivityLogService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> logCurrentUserAction({
    required String uid,
    required String action,
    required String tab,
  }) async {
    if (uid.isEmpty) {
      return;
    }

    final profile = await FirestoreUserService.instance.getUserById(uid);
    await _firestore.collection(AppConfig.userActivityCollection).add(<String, dynamic>{
      'uid': uid,
      'name': profile?.name ?? 'Unknown User',
      'email': profile?.email ?? '',
      'action': action,
      'tab': tab,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cleanupLogsIfDue() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month}-${today.day}';
    final lastRun = prefs.getString(AppConfig.dailyCleanupLastRunKey);
    if (lastRun == dateKey) {
      return;
    }

    final cutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: 4)).toUtc(),
    );

    final oldLogs = await _firestore
        .collection(AppConfig.userActivityCollection)
        .where('timestamp', isLessThan: cutoff)
        .limit(400)
        .get();

    if (oldLogs.docs.isNotEmpty) {
      final batch = _firestore.batch();
      for (final doc in oldLogs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    await prefs.setString(AppConfig.dailyCleanupLastRunKey, dateKey);
  }

}
