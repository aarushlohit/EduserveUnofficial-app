import 'dart:convert';

import 'package:eduserveapp/core/constants/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationCenterService {
  NotificationCenterService._();

  static final NotificationCenterService instance =
      NotificationCenterService._();

  Future<List<Map<String, dynamic>>> getGreetingFeed() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConfig.localGreetingFeedKey);
    if (raw == null || raw.trim().isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      return <Map<String, dynamic>>[];
    }

    final parsed =
        decoded.whereType<Map<String, dynamic>>().toList(growable: false);
    parsed.sort((a, b) {
      final at = (a['createdAtMs'] as num?)?.toInt() ?? 0;
      final bt = (b['createdAtMs'] as num?)?.toInt() ?? 0;
      return bt.compareTo(at);
    });
    return parsed;
  }

  Future<void> appendLoginGreeting(String message) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getGreetingFeed();

    final item = <String, dynamic>{
      'title': 'Welcome',
      'message': message,
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    };

    final updated = <Map<String, dynamic>>[item, ...current].take(20).toList();
    await prefs.setString(AppConfig.localGreetingFeedKey, jsonEncode(updated));
  }

  Future<void> removeAt(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getGreetingFeed();
    if (index < 0 || index >= current.length) {
      return;
    }
    current.removeAt(index);
    await prefs.setString(AppConfig.localGreetingFeedKey, jsonEncode(current));
  }

  Future<void> removeByCreatedAtMs(int createdAtMs) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getGreetingFeed();
    current.removeWhere((item) {
      final ms = (item['createdAtMs'] as num?)?.toInt();
      return ms == createdAtMs;
    });
    await prefs.setString(AppConfig.localGreetingFeedKey, jsonEncode(current));
  }

  Future<DateTime> _lastSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(AppConfig.notificationLastSeenKey);
    if (ms == null) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> markSeenNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      AppConfig.notificationLastSeenKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<bool> hasUnread() async {
    final lastSeen = await _lastSeen();
    final feed = await getGreetingFeed();
    return feed.any((item) {
      final ms = (item['createdAtMs'] as num?)?.toInt() ?? 0;
      return DateTime.fromMillisecondsSinceEpoch(ms).isAfter(lastSeen);
    });
  }
}
