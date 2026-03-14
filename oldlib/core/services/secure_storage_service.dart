import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as fss;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../constants/app_constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SecureStorageService
//
// Wraps flutter_secure_storage (Android Keystore / iOS Keychain) to persist
// session cookies and user preferences between app launches.
// ─────────────────────────────────────────────────────────────────────────────

class SecureStorageService {
  SecureStorageService._();

  static final SecureStorageService instance = SecureStorageService._();

  final fss.FlutterSecureStorage _storage = const fss.FlutterSecureStorage(
    aOptions: fss.AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: fss.IOSOptions(
      accessibility: fss.KeychainAccessibility.first_unlock,
    ),
  );

  // ── Cookie persistence ─────────────────────────────────────────────────────

  /// Serialize and write cookies obtained from the shared Android cookie store.
  Future<void> saveCookies(List<Cookie> cookies) async {
    final list = cookies
        .map<Map<String, dynamic>>((c) => {
              'name': c.name,
              'value': c.value?.toString() ?? '',
              'domain': c.domain,
              'path': c.path,
              'expiresDate': c.expiresDate,
              'isSecure': c.isSecure,
              'isHttpOnly': c.isHttpOnly,
            })
        .toList();
    await _storage.write(
      key: AppConstants.keyCookies,
      value: jsonEncode(list),
    );
    // Store timestamp so we can detect stale sessions.
    await _storage.write(
      key: AppConstants.keyLastLogin,
      value: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  /// Read back the persisted cookies, or [] if none exist.
  Future<List<Map<String, dynamic>>> loadRawCookies() async {
    final raw = await _storage.read(key: AppConstants.keyCookies);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// True if cookies were saved less than [maxAgeHours] hours ago.
  Future<bool> isCookieFresh({int maxAgeHours = 168}) async {
    final raw = await _storage.read(key: AppConstants.keyLastLogin);
    if (raw == null) return false;
    final savedAt = int.tryParse(raw) ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - savedAt;
    return age < Duration(hours: maxAgeHours).inMilliseconds;
  }

  /// Wipe all stored cookies and session metadata (logout).
  Future<void> clearSession() async {
    await _storage.delete(key: AppConstants.keyCookies);
    await _storage.delete(key: AppConstants.keyLastLogin);
  }

  // ── Generic helpers ────────────────────────────────────────────────────────

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> delete(String key) => _storage.delete(key: key);
}
