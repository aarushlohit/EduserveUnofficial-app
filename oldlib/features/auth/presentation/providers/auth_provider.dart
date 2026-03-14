import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../domain/user_session.dart';
import '../../data/auth_repository.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/cookie_service.dart';
import '../../../../core/services/secure_storage_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuthStatus
// ─────────────────────────────────────────────────────────────────────────────

enum AuthStatus {
  initial,
  checkingSession,
  authenticated,
  unauthenticated,
  loginInProgress,
  error,
}

// ─────────────────────────────────────────────────────────────────────────────
// AuthProvider — ChangeNotifier
// ─────────────────────────────────────────────────────────────────────────────

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repo = AuthRepository.instance;

  AuthStatus _status = AuthStatus.initial;
  UserSession _session = UserSession.empty;
  String? _errorMessage;

  // ── Getters ────────────────────────────────────────────────────────────────

  AuthStatus get status => _status;
  UserSession get session => _session;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String? get errorMessage => _errorMessage;

  // ── Auto-login on app start ────────────────────────────────────────────────

  /// Called from SplashScreen.  Rehydrates cookies and validates the session.
  Future<void> tryAutoLogin() async {
    debugPrint('[AUTH] tryAutoLogin start');
    _setStatus(AuthStatus.checkingSession);

    // Re-inject persisted cookies into the native WebView cookie store so
    // InAppWebView picks them up immediately.
    await CookieService.instance.injectStoredCookies();
    debugPrint('[AUTH] cookies re-injected into WebView store');

    final hasSession = await _repo.hasStoredSession();
    debugPrint('[AUTH] hasStoredSession=$hasSession');
    if (!hasSession) {
      _setStatus(AuthStatus.unauthenticated);
      return;
    }

    final isValid = await _repo.validateSession();
    debugPrint('[AUTH] validateSession=$isValid');
    if (isValid) {
      _session = await _repo.extractStudentInfo();
      debugPrint('[AUTH] session valid — name=${_session.studentName}');
      _setStatus(AuthStatus.authenticated);
    } else {
      debugPrint('[AUTH] session invalid, going to login');
      _setStatus(AuthStatus.unauthenticated);
    }
  }

  // ── In-app WebView login callback ─────────────────────────────────────────

  /// Called by the login WebView screen once it detects the user has landed on
  /// an authenticated portal page.  Cookies are passed directly from the
  /// WebView's cookie store — no external browser round-trip needed.
  Future<void> onInAppLoginComplete(List<Cookie> cookies) async {
    debugPrint('[AUTH] onInAppLoginComplete: ${cookies.length} cookies');
    _setStatus(AuthStatus.checkingSession);

    // Persist cookies to secure storage so they survive app restarts.
    await SecureStorageService.instance.saveCookies(cookies);
    debugPrint('[AUTH] cookies saved to secure storage');

    // Also ensure the native WebView cookie store has them (for injectStoredCookies on restart).
    final cookieManager = CookieManager.instance();
    for (final c in cookies) {
      await cookieManager.setCookie(
        url: WebUri(AppConstants.portalBaseUrl),
        name: c.name,
        value: c.value?.toString() ?? '',
        domain: c.domain,
        path: c.path ?? '/',
        isSecure: c.isSecure,
        isHttpOnly: c.isHttpOnly,
      );
    }
    debugPrint('[AUTH] cookies re-written into WebView cookie store');

    final isValid = await _repo.validateSession();
    debugPrint('[AUTH] post-login validateSession=$isValid');
    if (isValid) {
      _session = await _repo.extractStudentInfo();
      debugPrint('[AUTH] authenticated — name=${_session.studentName}');
      _setStatus(AuthStatus.authenticated);
    } else {
      debugPrint('[AUTH] session validation failed after login');
      _setStatus(AuthStatus.unauthenticated);
      _setError('Login not detected. Please try again.');
    }
  }

  // ── Session expiry detected by WebView ─────────────────────────────────────

  /// Called by WebViewScreen when the portal redirects to the login page.
  Future<void> onSessionExpired() async {
    debugPrint('[AUTH] onSessionExpired — clearing cookies');
    await CookieService.instance.clearAllCookies();
    _session = UserSession.empty;
    _setStatus(AuthStatus.unauthenticated);
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    debugPrint('[AUTH] logout');
    await _repo.logout();
    _session = UserSession.empty;
    _setStatus(AuthStatus.unauthenticated);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _setStatus(AuthStatus s) {
    _status = s;
    notifyListeners();
  }

  void _setError(String msg) {
    _errorMessage = msg;
    _status = AuthStatus.error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }
}
