// ─────────────────────────────────────────────────────────────────────────────
// App Constants
// Update these if the portal reorganises its URL structure.
// ─────────────────────────────────────────────────────────────────────────────

class AppConstants {
  AppConstants._();

  // ── Portal URLs ────────────────────────────────────────────────────────────
  static const String portalBaseUrl = 'https://eduserve.karunya.edu';
  static const String loginUrl = 'https://eduserve.karunya.edu/Account/Login';
  static const String dashboardUrl =
      'https://eduserve.karunya.edu/Student/home';
  static const String attendanceUrl =
      'https://eduserve.karunya.edu/Student/Attendance';
  static const String timetableUrl =
      'https://eduserve.karunya.edu/Student/TimeTable';
  static const String assignmentUrl =
      'https://eduserve.karunya.edu/Student/Assignment';

  // ── Custom URI scheme used for deep-link callback (AndroidManifest.xml) ───
  // Register this in your Google Cloud Console as an authorised redirect URI
  // if you later add a first-party OAuth client.
  static const String redirectScheme = 'eduserve';
  static const String redirectHost = 'callback';
  static const String redirectUri = '$redirectScheme://$redirectHost';

  // ── SecureStorage keys ────────────────────────────────────────────────────
  static const String keyCookies = 'session_cookies';
  static const String keyDarkMode = 'dark_mode_injected';
  static const String keyLastLogin = 'last_login_timestamp';

  // ── SharedPreferences keys ────────────────────────────────────────────────
  static const String prefThemeMode = 'theme_mode';
  static const String prefDarkWebMode = 'dark_web_mode';
  static const String prefNotificationsEnabled = 'notifications_enabled';

  // ── Session detection ─────────────────────────────────────────────────────
  // URL fragments that indicate the WebView has been redirected to the login
  // page (i.e. the session has expired).
  static const List<String> loginIndicators = [
    '/Account/Login',
    '/login',
    'signin',
    'google.com/accounts',
  ];

  // ── User-Agent ────────────────────────────────────────────────────────────
  // Remove the "wv" (WebView) marker so Google's OAuth does not reject the
  // browser.  Keep it realistic so the portal's responsive CSS triggers.
  static const String desktopUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro Build/AP2A.240905.003) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/129.0.6668.100 Mobile Safari/537.36';

  // ── App meta ──────────────────────────────────────────────────────────────
  static const String appName = 'EduServe';
  static const String appVersion = '1.0.0';

  // ── Dark-mode CSS injected into the WebView ───────────────────────────────
  // A minimal, non-destructive dark stylesheet. Students can extend this.
  static const String darkModeCSS = '''
    :root {
      --bg: #121212 !important;
      --surface: #1e1e2e !important;
      --text: #e0e0e0 !important;
      --muted: #9e9e9e !important;
      --accent: #7eb6ff !important;
      --border: #333344 !important;
    }
    body, html {
      background-color: var(--bg) !important;
      color: var(--text) !important;
    }
    .navbar, .navbar-default, nav, header {
      background-color: var(--surface) !important;
      border-color: var(--border) !important;
    }
    .navbar-default .navbar-brand,
    .navbar-default .navbar-nav > li > a {
      color: var(--text) !important;
    }
    .sidebar, .sidebar-left, #sidebar {
      background-color: var(--surface) !important;
    }
    .panel, .card, .box, .well {
      background-color: var(--surface) !important;
      border-color: var(--border) !important;
      color: var(--text) !important;
    }
    .panel-heading, .card-header, .box-header {
      background-color: #1a1a2e !important;
      border-color: var(--border) !important;
    }
    table, th, td {
      background-color: var(--surface) !important;
      color: var(--text) !important;
      border-color: var(--border) !important;
    }
    tr:nth-child(even) td { background-color: #1a1a2e !important; }
    a { color: var(--accent) !important; }
    input, select, textarea, .form-control {
      background-color: #2a2a3e !important;
      color: var(--text) !important;
      border-color: var(--border) !important;
    }
    .btn-default {
      background-color: #2a2a3e !important;
      color: var(--text) !important;
      border-color: var(--border) !important;
    }
    img { filter: brightness(0.85); }
    ::-webkit-scrollbar { background: var(--bg); }
    ::-webkit-scrollbar-thumb { background: var(--border); }
  ''';

  // ── Dark-mode JavaScript wrapper ──────────────────────────────────────────
  static String get darkModeScript => '''
    (function() {
      if (document.getElementById('_eduserve_dark_mode')) return;
      const style = document.createElement('style');
      style.id = '_eduserve_dark_mode';
      style.textContent = `${darkModeCSS.replaceAll('`', r'\`')}`;
      document.head.appendChild(style);
    })();
  ''';
}
