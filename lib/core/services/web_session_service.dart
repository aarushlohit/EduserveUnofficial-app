import 'dart:convert';

import 'package:eduserveapp/core/constants/app_config.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WebSessionService {
  WebSessionService._();

  static final WebSessionService instance = WebSessionService._();

  static const String _cookiesKey = 'eduserve_web_cookies';
  final CookieManager _cookieManager = CookieManager.instance();

  Future<void> restoreCookies() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cookiesKey);
    if (raw == null || raw.isEmpty) {
      return;
    }

    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .cast<Map<String, dynamic>>();

      if (list.isNotEmpty) {
        for (final map in list) {
          await _cookieManager.setCookie(
            url: WebUri(AppConfig.eduserveDashboardUrl),
            name: (map['name'] as String?) ?? '',
            value: (map['value'] as String?) ?? '',
            domain: map['domain'] as String?,
            path: (map['path'] as String?) ?? '/',
            isSecure: map['isSecure'] as bool?,
            isHttpOnly: map['isHttpOnly'] as bool?,
          );
        }
      }
    } catch (_) {
      // Ignore malformed cookie cache.
    }
  }

  Future<void> persistCookies(String url) async {
    final cookies = await _cookieManager.getCookies(url: WebUri(url));
    final encoded = cookies
        .map(
          (c) => <String, dynamic>{
            'name': c.name,
            'value': c.value ?? '',
            'domain': c.domain,
            'path': c.path,
            'isSecure': c.isSecure,
            'isHttpOnly': c.isHttpOnly,
          },
        )
        .toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cookiesKey, jsonEncode(encoded));
  }
}
