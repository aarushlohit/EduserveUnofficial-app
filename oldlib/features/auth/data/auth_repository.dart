import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../domain/user_session.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/cookie_service.dart';
import '../../../core/services/secure_storage_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuthRepository
//
// Responsible for:
//  • Checking whether an existing cookie-based session is still valid.
//  • Saving / loading the session.
//  • Extracting basic student info from the portal HTML.
// ─────────────────────────────────────────────────────────────────────────────

class AuthRepository {
  AuthRepository._();
  static final AuthRepository instance = AuthRepository._();

  // ── Session validation ─────────────────────────────────────────────────────

  /// Returns true when the portal responds with the authenticated dashboard
  /// (not a redirect to the login page).
  Future<bool> validateSession() async {
    try {
      final cookieHeader = await CookieService.instance.buildCookieHeader();
      if (cookieHeader.isEmpty) return false;

      final response = await http
          .get(
            Uri.parse(AppConstants.dashboardUrl),
            headers: {
              'Cookie': cookieHeader,
              'User-Agent': AppConstants.desktopUserAgent,
              'Accept': 'text/html,application/xhtml+xml',
            },
          )
          .timeout(const Duration(seconds: 10));

      // If the final URL is a login page the session has expired.
      final body = response.body.toLowerCase();
      final isLoginPage = AppConstants.loginIndicators
          .any((s) => body.contains(s.toLowerCase()));

      return response.statusCode == 200 && !isLoginPage;
    } catch (_) {
      return false;
    }
  }

  /// Check both the native cookie store and secure storage for a live session.
  Future<bool> hasStoredSession() async {
    final hasCookie = await CookieService.instance.hasLiveSessionCookie();
    final isFresh = await SecureStorageService.instance.isCookieFresh();
    return hasCookie && isFresh;
  }

  // ── Post-login ─────────────────────────────────────────────────────────────

  /// Called right after ChromeSafariBrowser closes.
  /// Reads the native cookie store, persists cookies, then does a live check.
  Future<bool> captureSessionAfterLogin() async {
    await CookieService.instance.captureAndSaveCookies();
    return validateSession();
  }

  // ── Student info extraction ────────────────────────────────────────────────

  /// Parse basic student info from the portal dashboard HTML.
  ///
  /// ⚠ REVERSE ENGINEERING NOTE
  /// ──────────────────────────
  /// To find the correct CSS selectors:
  ///   1. Open https://eduserve.karunya.edu in Chrome while logged in.
  ///   2. Press F12 → Elements tab.
  ///   3. Use Ctrl+F to search for your student name or roll number.
  ///   4. Note the element id/class (e.g. "#lblStudentName", ".student-roll").
  ///   5. Update the querySelector calls below accordingly.
  Future<UserSession> extractStudentInfo() async {
    try {
      final cookieHeader = await CookieService.instance.buildCookieHeader();
      final response = await http.get(
        Uri.parse(AppConstants.dashboardUrl),
        headers: {
          'Cookie': cookieHeader,
          'User-Agent': AppConstants.desktopUserAgent,
        },
      ).timeout(const Duration(seconds: 10));

      final doc = html_parser.parse(response.body);

      // ── Adjust selectors to match actual portal HTML ──
      final name = doc.querySelector('#lblStudentName')?.text.trim() ??
          doc.querySelector('.student-name')?.text.trim() ??
          doc.querySelector('[id*="StudentName"]')?.text.trim();

      final roll = doc.querySelector('#lblRollNo')?.text.trim() ??
          doc.querySelector('.roll-number')?.text.trim() ??
          doc.querySelector('[id*="RollNo"]')?.text.trim();

      final branch = doc.querySelector('#lblBranch')?.text.trim() ??
          doc.querySelector('[id*="Branch"]')?.text.trim();

      final semester = doc.querySelector('#lblSemester')?.text.trim() ??
          doc.querySelector('[id*="Semester"]')?.text.trim();

      return UserSession(
        isAuthenticated: true,
        lastLoginAt: DateTime.now(),
        studentName: name,
        rollNumber: roll,
        branch: branch,
        semester: semester,
      );
    } catch (_) {
      return UserSession(
        isAuthenticated: true,
        lastLoginAt: DateTime.now(),
      );
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    // Optionally hit the portal logout endpoint first.
    try {
      final cookieHeader = await CookieService.instance.buildCookieHeader();
      await http.get(
        Uri.parse('${AppConstants.portalBaseUrl}/Account/Logout'),
        headers: {'Cookie': cookieHeader},
      ).timeout(const Duration(seconds: 5));
    } catch (_) {/* ignore – clear locally regardless */}

    await CookieService.instance.clearAllCookies();
  }
}
