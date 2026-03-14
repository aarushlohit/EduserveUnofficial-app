import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../constants/app_constants.dart';
import 'secure_storage_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CookieService
//
// Architecture note — Android cookie sharing
// ────────────────────────────────────────────
// Chrome Custom Tabs (ChromeSafariBrowser) and android.webkit.WebView share
// the same underlying android.webkit.CookieManager.  When the user
// authenticates through Chrome Custom Tabs the portal's session cookies are
// therefore automatically available to the InAppWebView without any extra
// work — they live in the same store.
//
// This service:
//  • Reads cookies from that shared store after the browser session ends.
//  • Persists them to encrypted storage so they survive app restarts.
//  • Re-injects them into a fresh WebView instance (e.g. after app restart).
//  • Builds a Cookie header string for raw HTTP requests.
//
// iOS note
// ─────────
// WKWebView and SFSafariViewController do NOT share a cookie store.
// After login on iOS you must call [injectStoredCookies] manually.
// ─────────────────────────────────────────────────────────────────────────────

class CookieService {
  CookieService._();

  static final CookieService instance = CookieService._();

  final _manager = CookieManager.instance();

  // ── Save ───────────────────────────────────────────────────────────────────

  /// Read all cookies for the portal origin from the native cookie store and
  /// persist them to secure storage.
  Future<void> captureAndSaveCookies() async {
    final cookies = await _manager.getCookies(
      url: WebUri(AppConstants.portalBaseUrl),
    );
    debugPrint('[COOKIE] captureAndSaveCookies: found ${cookies.length} cookies');
    for (final c in cookies) {
      debugPrint('[COOKIE]   ${c.name}=${c.value}');
    }
    if (cookies.isNotEmpty) {
      await SecureStorageService.instance.saveCookies(cookies);
    }
  }

  // ── Load & inject ──────────────────────────────────────────────────────────

  /// Re-inject saved cookies into the native cookie store.
  /// Call this once before creating an InAppWebView on app launch.
  Future<void> injectStoredCookies() async {
    final rawList = await SecureStorageService.instance.loadRawCookies();
    debugPrint('[COOKIE] injectStoredCookies: injecting ${rawList.length} cookies');
    for (final map in rawList) {
      debugPrint('[COOKIE]   inject: ${map['name']}=${map['value']}');
      await _manager.setCookie(
        url: WebUri(AppConstants.portalBaseUrl),
        name: (map['name'] as String?) ?? '',
        value: (map['value'] as String?) ?? '',
        domain: map['domain'] as String?,
        path: (map['path'] as String?) ?? '/',
        isSecure: map['isSecure'] as bool?,
        isHttpOnly: map['isHttpOnly'] as bool?,
      );
    }
  }

  // ── Session checks ─────────────────────────────────────────────────────────

  /// Returns true if the portal's native cookie store contains at least one
  /// recognisable session cookie.
  Future<bool> hasLiveSessionCookie() async {
    final cookies = await _manager.getCookies(
      url: WebUri(AppConstants.portalBaseUrl),
    );
    debugPrint('[COOKIE] hasLiveSessionCookie: ${cookies.length} cookies in store');
    for (final c in cookies) {
      debugPrint('[COOKIE]   ${c.name}');
    }
    return cookies.any((c) =>
        c.name == 'ASP.NET_SessionId' ||
        c.name == '.ASPXAUTH' ||
        c.name == 'session' ||
        c.name == 'sessionid' ||
        c.name.toLowerCase().contains('auth') ||
        c.name.toLowerCase().contains('session'));
  }

  // ── HTTP helper ────────────────────────────────────────────────────────────

  /// Build a Cookie header value from persisted cookies.
  /// Use this when making raw http.get / http.post requests.
  Future<String> buildCookieHeader() async {
    final rawList = await SecureStorageService.instance.loadRawCookies();
    final header = rawList.map((m) => '${m['name']}=${m['value']}').join('; ');
    debugPrint('[COOKIE] buildCookieHeader: ${rawList.length} cookies → header length ${header.length}');
    return header;
  }

  // ── Clear ──────────────────────────────────────────────────────────────────

  /// Delete all cookies for the portal domain and clear secure storage.
  Future<void> clearAllCookies() async {
    await _manager.deleteCookies(url: WebUri(AppConstants.portalBaseUrl));
    await SecureStorageService.instance.clearSession();
  }
}
