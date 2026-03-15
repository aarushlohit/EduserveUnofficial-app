import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eduserveapp/core/constants/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStatsService {
  AppStatsService._();

  static final AppStatsService instance = AppStatsService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _statsRef =>
      _firestore.collection(AppConfig.appStatsCollection).doc('global');

  Future<void> updateOnAppOpen({required String uid}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month}-${now.day}';

    final statsSnap = await _statsRef.get();
    final statsData = statsSnap.data() ?? <String, dynamic>{};
    final storedDay = statsData['activeUsersDate'] as String?;
    if (storedDay != todayKey) {
      await _statsRef.set(
        <String, dynamic>{
          'activeUsersToday': 0,
          'activeUsersDate': todayKey,
        },
        SetOptions(merge: true),
      );
    }

    final lastActiveDay = prefs.getString(AppConfig.lastActiveDayKey);
    final shouldCountActiveToday = lastActiveDay != todayKey;
    if (shouldCountActiveToday) {
      await prefs.setString(AppConfig.lastActiveDayKey, todayKey);
    }

    int? totalUsers;
    final lastUserCountDay = prefs.getString(AppConfig.lastUserCountDayKey);
    final shouldRefreshUserCount = lastUserCountDay != todayKey;
    if (shouldRefreshUserCount) {
      final usersSnapshot =
          await _firestore.collection(AppConfig.usersCollection).count().get();
      totalUsers = usersSnapshot.count ?? 0;
      await prefs.setString(AppConfig.lastUserCountDayKey, todayKey);
    }

    await _statsRef.set(
      <String, dynamic>{
        if (totalUsers != null) 'totalUsers': totalUsers,
        'appOpens': FieldValue.increment(1),
        if (shouldCountActiveToday)
          'activeUsersToday': FieldValue.increment(1),
        'activeUsersDate': todayKey,
        'lastOpenUid': uid,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> logAiMessage() async {
    await _statsRef.set(
      <String, dynamic>{
        'aiMessages': FieldValue.increment(1),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> logTabOpen(String tab) async {
    final snap = await _statsRef.get();
    final data = snap.data() ?? <String, dynamic>{};
    final tabUsageRaw = data['tabUsage'];
    final usage = <String, int>{};
    if (tabUsageRaw is Map<String, dynamic>) {
      for (final entry in tabUsageRaw.entries) {
        usage[entry.key] = (entry.value as num?)?.toInt() ?? 0;
      }
    }

    usage[tab] = (usage[tab] ?? 0) + 1;
    var mostUsedTab = 'home';
    var maxCount = 0;
    for (final entry in usage.entries) {
      if (entry.value > maxCount) {
        mostUsedTab = entry.key;
        maxCount = entry.value;
      }
    }

    await _statsRef.set(
      <String, dynamic>{
        'tabUsage': usage,
        'mostUsedTab': mostUsedTab,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
