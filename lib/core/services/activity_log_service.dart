import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eduserveapp/core/constants/app_config.dart';
import 'package:eduserveapp/core/services/firestore_user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ActivityLogService {
  ActivityLogService._();

  static final ActivityLogService instance = ActivityLogService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, StudentProfile?> _profileCache =
      <String, StudentProfile?>{};

  String? _activeUid;
  String _activeUserEmail = '';
  DateTime? _sessionStartLocal;
  final Map<String, int> _sessionTabCounts = <String, int>{
    'home': 0,
    'eduserve': 0,
    'results': 0,
    'ai': 0,
    'addons': 0,
  };

  bool _cachedEnabled = true;
  bool _configLoaded = false;
  static const int _batchSize = 50;
  static const Set<String> _trackableTabs = <String>{
    'home',
    'eduserve',
    'results',
    'ai',
    'addons',
  };

  String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  bool isAdminUser(User user) {
    return user.email?.toLowerCase() == AppConfig.adminEmail.toLowerCase();
  }

  Future<void> logCurrentUserAction({
    required String uid,
    required String action,
    required String tab,
  }) async {
    if (!_trackableTabs.contains(tab)) {
      return;
    }

    await startSessionIfNeeded(uid: uid);
    await logTabOpened(uid: uid, tab: tab);
  }

  Future<void> initializeLoggingConfig() async {
    if (_configLoaded) {
      return;
    }

    try {
      final doc = await _firestore
          .collection(AppConfig.systemConfigCollection)
          .doc(AppConfig.systemLoggingDoc)
          .get();
      final data = doc.data();
      _cachedEnabled = (data?['enabled'] as bool?) ?? true;
      _configLoaded = true;
      debugPrint('[analytics] logging config enabled=$_cachedEnabled');
    } catch (e) {
      debugPrint(
          '[analytics] logging config fetch failed, default enabled: $e');
      _cachedEnabled = true;
      _configLoaded = true;
    }
  }

  Future<void> startSessionIfNeeded({required String uid}) async {
    if (uid.isEmpty) {
      return;
    }

    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null && isAdminUser(authUser)) {
      return;
    }

    await initializeLoggingConfig();
    if (!_cachedEnabled) {
      return;
    }

    if (_activeUid == uid && _sessionStartLocal != null) {
      return;
    }

    if (_activeUid != null && _activeUid != uid) {
      await endSessionIfActive();
    }

    final cached = _profileCache[uid];
    final profile =
        cached ?? await FirestoreUserService.instance.getUserById(uid);
    if (profile != null) {
      if (profile.email.toLowerCase() == AppConfig.adminEmail.toLowerCase()) {
        return;
      }
      _profileCache[uid] = profile;
      _activeUserEmail = profile.email;
    } else {
      _activeUserEmail = authUser?.email ?? '';
    }

    _activeUid = uid;
    _sessionStartLocal = DateTime.now();
    _resetSessionTabCounts();
    unawaited(_markActiveUserToday(uid));
    debugPrint('[session] started local session uid=$uid');
  }

  Future<void> _markActiveUserToday(String uid) async {
    final todayKey = _todayKey();
    final prefs = await SharedPreferences.getInstance();
    final markerKey = '${AppConfig.lastActiveDayKey}_$uid';
    final lastMarked = prefs.getString(markerKey);
    if (lastMarked == todayKey) {
      return;
    }

    // Mark first to ensure we never increment more than once per user/day.
    await prefs.setString(markerKey, todayKey);

    try {
      await _firestore
          .collection(AppConfig.analyticsGlobalCollection)
          .doc(AppConfig.analyticsGlobalDoc)
          .set(
        <String, dynamic>{
          'activeUsersToday': FieldValue.increment(1),
          'activeUsersDate': todayKey,
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('[session] activeUsersToday increment skipped: $e');
    }
  }

  Future<void> logTabOpened({required String uid, required String tab}) async {
    if (uid.isEmpty || !_trackableTabs.contains(tab)) {
      return;
    }

    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null && isAdminUser(authUser)) {
      return;
    }

    await initializeLoggingConfig();
    if (!_cachedEnabled) {
      return;
    }

    if (_activeUid != uid || _sessionStartLocal == null) {
      await startSessionIfNeeded(uid: uid);
      if (_activeUid != uid || _sessionStartLocal == null) {
        return;
      }
    }

    _sessionTabCounts[tab] = (_sessionTabCounts[tab] ?? 0) + 1;
  }

  Future<void> endSessionIfActive() async {
    final uid = _activeUid;
    final started = _sessionStartLocal;

    if (uid == null || started == null) {
      return;
    }

    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null && isAdminUser(authUser)) {
      _clearActiveSession();
      return;
    }

    final durationSeconds = DateTime.now().difference(started).inSeconds;
    final safeDuration = durationSeconds < 0 ? 0 : durationSeconds;

    if (safeDuration < 2) {
      debugPrint(
          '[session] ignored short session uid=$uid duration=${safeDuration}s');
      _clearActiveSession();
      return;
    }

    final totalTabs =
        _sessionTabCounts.values.fold<int>(0, (total, value) => total + value);
    String mostUsedTab = '-';
    var mostUsedCount = 0;
    _sessionTabCounts.forEach((tab, opens) {
      if (opens > mostUsedCount) {
        mostUsedCount = opens;
        mostUsedTab = tab;
      }
    });

    try {
      await _firestore
          .collection(AppConfig.userSessionsCollection)
          .add(<String, dynamic>{
        'uid': uid,
        'email': _activeUserEmail,
        'start': Timestamp.fromDate(started),
        'end': FieldValue.serverTimestamp(),
        'duration': safeDuration,
        'totalTabs': totalTabs,
        'mostUsedTab': mostUsedTab,
        'tabCounts': Map<String, int>.from(_sessionTabCounts),
      });

      if (totalTabs > 0) {
        final increments = <String, dynamic>{};
        for (final entry in _sessionTabCounts.entries) {
          if (entry.value > 0) {
            increments[entry.key] = FieldValue.increment(entry.value);
          }
        }
        if (increments.isNotEmpty) {
          await _firestore.collection(AppConfig.usersCollection).doc(uid).set(
            <String, dynamic>{
              'tabUsage': increments,
            },
            SetOptions(merge: true),
          );
        }
      }

      debugPrint(
        '[session] saved uid=$uid duration=${safeDuration}s totalTabs=$totalTabs mostUsedTab=$mostUsedTab',
      );
    } catch (e) {
      debugPrint('[session] save failed uid=$uid error=$e');
    } finally {
      _clearActiveSession();
    }
  }

  void _resetSessionTabCounts() {
    for (final tab in _trackableTabs) {
      _sessionTabCounts[tab] = 0;
    }
  }

  void _clearActiveSession() {
    _activeUid = null;
    _activeUserEmail = '';
    _sessionStartLocal = null;
    _resetSessionTabCounts();
  }

  Future<void> cleanupLogsIfDue() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month}-${today.day}';
    final lastRun = prefs.getString(AppConfig.dailyCleanupLastRunKey);
    if (lastRun == dateKey) {
      return;
    }

    final sessionCutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: 30)).toUtc(),
    );

    await _deleteSessionsOlderThan(sessionCutoff);

    await prefs.setString(AppConfig.dailyCleanupLastRunKey, dateKey);
  }

  Future<void> purgeAllLogsOnce() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyPurged =
        prefs.getBool(AppConfig.activityLogsPurgedKey) ?? false;
    if (alreadyPurged) {
      return;
    }

    try {
      await purgeAllLogsNow();
    } catch (e) {
      debugPrint('[activity] purge all logs failed: $e');
      return;
    }

    await prefs.setBool(AppConfig.activityLogsPurgedKey, true);
  }

  Future<void> purgeAllLogsNow() async {
    try {
      await _deleteCollection(AppConfig.userSessionsCollection);
    } catch (e) {
      debugPrint('[activity] force purge failed: $e');
    }
  }

  Future<void> cleanupLogsOlderThan(Duration maxAge) async {
    final cutoff = Timestamp.fromDate(DateTime.now().subtract(maxAge).toUtc());
    await _deleteSessionsOlderThan(cutoff);
  }

  Future<void> _deleteCollection(String collection) async {
    while (true) {
      final batchDocs =
          await _firestore.collection(collection).limit(_batchSize).get();
      if (batchDocs.docs.isEmpty) {
        break;
      }

      final batch = _firestore.batch();
      for (final doc in batchDocs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _deleteSessionsOlderThan(Timestamp cutoff) async {
    while (true) {
      final oldLogs = await _firestore
          .collection(AppConfig.userSessionsCollection)
          .where('start', isLessThan: cutoff)
          .limit(_batchSize)
          .get();

      if (oldLogs.docs.isEmpty) {
        break;
      }

      final batch = _firestore.batch();
      for (final doc in oldLogs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
