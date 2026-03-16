import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eduserveapp/core/constants/app_config.dart';
import 'package:eduserveapp/core/services/firestore_user_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class ActivityLogService {
  ActivityLogService._();

  static final ActivityLogService instance = ActivityLogService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, StudentProfile?> _profileCache = <String, StudentProfile?>{};
  DateTime _lastConfigFetch = DateTime.fromMillisecondsSinceEpoch(0);
  bool _cachedEnabled = true;
  int _cachedThreshold = 100;

  Future<void> logCurrentUserAction({
    required String uid,
    required String action,
    required String tab,
  }) async {
    if (uid.isEmpty) {
      return;
    }

    final shouldLog = await _shouldLog();
    if (!shouldLog) {
      debugPrint('[activity] logging disabled, skip action=$action');
      return;
    }

    debugPrint('[activity] log uid=$uid action=$action tab=$tab');

    final cached = _profileCache[uid];
    final profile = cached ?? await FirestoreUserService.instance.getUserById(uid);
    _profileCache[uid] = profile;
    await _firestore.collection(AppConfig.userActivityCollection).add(<String, dynamic>{
      'uid': uid,
      'name': profile?.name ?? 'Unknown User',
      'email': profile?.email ?? '',
      'registerNumber': profile?.registerNumber ?? '',
      'dept': profile?.dept ?? '',
      'year': profile?.year ?? '',
      'gender': profile?.gender ?? '',
      'role': profile?.role ?? 'user',
      'action': action,
      'tab': tab,
      'timestamp': FieldValue.serverTimestamp(),
    });

    debugPrint('[activity] wrote log for uid=$uid');
  }

  Future<bool> _shouldLog() async {
    final now = DateTime.now();
    if (now.difference(_lastConfigFetch) < const Duration(minutes: 5)) {
      return _sampleAllowed();
    }

    try {
      final doc = await _firestore
          .collection(AppConfig.analyticsConfigCollection)
          .doc(AppConfig.analyticsLoggingDoc)
          .get();
      final data = doc.data();
      _cachedEnabled = (data?['enabled'] as bool?) ?? true;
      _cachedThreshold = (data?['thresholdPercent'] as num?)?.toInt() ?? 100;
      _cachedThreshold = _cachedThreshold.clamp(0, 100);
      _lastConfigFetch = now;
      debugPrint('[activity] logging config enabled=$_cachedEnabled threshold=$_cachedThreshold');
    } catch (e) {
      debugPrint('[activity] logging config fetch failed, defaulting to enabled. $e');
      _cachedEnabled = true;
      _cachedThreshold = 100;
      _lastConfigFetch = now;
    }

    return _sampleAllowed();
  }

  bool _sampleAllowed() {
    if (!_cachedEnabled) return false;
    if (_cachedThreshold >= 100) return true;
    final roll = Random().nextInt(100) + 1;
    final allowed = roll <= _cachedThreshold;
    debugPrint('[activity] sample roll=$roll threshold=$_cachedThreshold allowed=$allowed');
    return allowed;
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

  Future<void> purgeAllLogsOnce() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyPurged = prefs.getBool(AppConfig.activityLogsPurgedKey) ?? false;
    if (alreadyPurged) {
      return;
    }

    try {
      // Delete in batches to avoid timeouts.
      while (true) {
        final batchDocs = await _firestore
            .collection(AppConfig.userActivityCollection)
            .limit(500)
            .get();

        if (batchDocs.docs.isEmpty) {
          break;
        }

        final batch = _firestore.batch();
        for (final doc in batchDocs.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('[activity] purge all logs failed: $e');
      // Do not mark as purged if failed; will retry next startup.
      return;
    }

    await prefs.setBool(AppConfig.activityLogsPurgedKey, true);
    debugPrint('[activity] all logs purged once');
  }

  Future<void> purgeAllLogsNow() async {
    debugPrint('[activity] force purge requested');
    try {
      while (true) {
        final batchDocs = await _firestore
            .collection(AppConfig.userActivityCollection)
            .limit(500)
            .get();

        if (batchDocs.docs.isEmpty) {
          break;
        }

        final batch = _firestore.batch();
        for (final doc in batchDocs.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('[activity] force purge failed: $e');
    }
  }

}
