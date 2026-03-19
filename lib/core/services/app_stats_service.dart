import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eduserveapp/core/constants/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStatsService {
  AppStatsService._();

  static final AppStatsService instance = AppStatsService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _globalStatsRef => _firestore
      .collection(AppConfig.analyticsGlobalCollection)
      .doc(AppConfig.analyticsGlobalDoc);

  CollectionReference<Map<String, dynamic>> get _dailyStatsCol =>
      _firestore.collection(AppConfig.analyticsDailyCollection);

  String _todayKey() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  Future<void> updateOnAppOpen({required String uid}) async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _todayKey();

    debugPrint('[stats] updateOnAppOpen uid=$uid day=$todayKey');

    // Increment daily app opens counter.
    await _dailyStatsCol.doc(todayKey).set(
      <String, dynamic>{
        'appOpens': FieldValue.increment(1),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    debugPrint('[stats] incremented appOpens for $todayKey');

    // Cache last active day locally to avoid double-counting active users.
    final lastActiveDay = prefs.getString(AppConfig.lastActiveDayKey);
    final shouldCountActiveToday = lastActiveDay != todayKey;
    if (shouldCountActiveToday) {
      await prefs.setString(AppConfig.lastActiveDayKey, todayKey);
      await _globalStatsRef.set(
        <String, dynamic>{
          'activeUsersToday': FieldValue.increment(1),
          'activeUsersDate': todayKey,
          'lastOpenUid': uid,
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      debugPrint('[stats] counted active user for $todayKey');
    } else {
      await _globalStatsRef.set(
        <String, dynamic>{
          'lastOpenUid': uid,
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
  }

  Future<void> logAiMessage() async {
    await _globalStatsRef.set(
      <String, dynamic>{
        'aiMessages': FieldValue.increment(1),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> logTabOpen(String tab) async {
    final todayKey = _todayKey();
    final tabField = switch (tab) {
      'eduserve' => 'eduserveOpens',
      'results' => 'resultsOpens',
      'ai' => 'aiOpens',
      'fees' => 'feesOpens',
      'externalEvents' => 'externalEventsOpens',
      'website' => 'websiteOpens',
      _ => 'homeOpens',
    };

    debugPrint('[stats] logTabOpen tab=$tab field=$tabField day=$todayKey');

    await _dailyStatsCol.doc(todayKey).set(
      <String, dynamic>{
        tabField: FieldValue.increment(1),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    debugPrint('[stats] incremented $tabField for $todayKey');
  }

  Future<void> incrementTotalUsers() async {
    debugPrint('[stats] incrementTotalUsers');
    await _globalStatsRef.set(
      <String, dynamic>{
        'totalUsers': FieldValue.increment(1),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
