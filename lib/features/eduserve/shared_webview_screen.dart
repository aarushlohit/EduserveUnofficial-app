import 'package:eduserveapp/core/constants/app_config.dart';
import 'package:eduserveapp/core/services/web_session_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// List of URL indicators that show the session has expired (user redirected to login).
const List<String> _sessionExpiryIndicators = [
  '/Account/Login',
  '/login',
  'signin',
  'google.com/accounts',
];

/// Dark mode CSS (reused from oldlib pattern).
const String _darkModeCSS = '''
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

class SharedWebViewScreen extends StatefulWidget {
  const SharedWebViewScreen({
    super.key,
    required this.initialTitle,
    required this.initialUrl,
    required this.allowedUrlPrefixes,
    this.enableDarkMode = false,
  });

  final String initialTitle;
  final String initialUrl;
  final List<String> allowedUrlPrefixes;
  final bool enableDarkMode;

  @override
  State<SharedWebViewScreen> createState() => _SharedWebViewScreenState();
}

class _SharedWebViewScreenState extends State<SharedWebViewScreen> {
  InAppWebViewController? _controller;
  String _title = '';
  bool _loading = true;
  double _progress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;

  @override
  void initState() {
    super.initState();
    _title = widget.initialTitle;
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    await WebSessionService.instance.restoreCookies();
  }

  Future<void> _refreshNavigationState() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    final canGoBack = await controller.canGoBack();
    final canGoForward = await controller.canGoForward();
    if (!mounted) {
      return;
    }

    setState(() {
      _canGoBack = canGoBack;
      _canGoForward = canGoForward;
    });
  }

  /// Injects dark mode CSS if enabled (reused from oldlib pattern).
  Future<void> _injectDarkMode(InAppWebViewController controller) async {
    if (!widget.enableDarkMode) return;
    await controller.evaluateJavascript(
      source: '''
        (function() {
          if (document.getElementById('_eduserve_dark_mode')) return;
          const style = document.createElement('style');
          style.id = '_eduserve_dark_mode';
          style.textContent = `${_darkModeCSS.replaceAll('`', r'\`')}`;
          document.head.appendChild(style);
        })();
      ''',
    );
  }

  /// Detects if the user session has expired and callback redirected to login.
  void _detectSessionExpiry(String? url) {
    if (url == null) return;
    final isLoginPage = _sessionExpiryIndicators
        .any((indicator) => url.toLowerCase().contains(indicator.toLowerCase()));
    if (isLoginPage) {
      // If redirected to login, session has likely expired.
      // Optionally notify parent or show snackbar.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your session has expired. Please log in again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _goBack() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    if (await controller.canGoBack()) {
      await controller.goBack();
    }
    await _refreshNavigationState();
  }

  Future<void> _goForward() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    if (await controller.canGoForward()) {
      await controller.goForward();
    }
    await _refreshNavigationState();
  }

  Future<void> _reload() async {
    await _controller?.reload();
    await _refreshNavigationState();
  }

  bool _isAllowed(String url) {
    return widget.allowedUrlPrefixes.any(url.startsWith);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: <Widget>[
          IconButton(
            tooltip: 'Back',
            onPressed: _canGoBack ? _goBack : null,
            icon: const Icon(Icons.arrow_back),
          ),
          IconButton(
            tooltip: 'Forward',
            onPressed: _canGoForward ? _goForward : null,
            icon: const Icon(Icons.arrow_forward),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              databaseEnabled: true,
              cacheEnabled: true,
              clearSessionCache: false,
              thirdPartyCookiesEnabled: true,
              userAgent: AppConfig.desktopUserAgent,
              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              useShouldOverrideUrlLoading: true,
              supportMultipleWindows: true,
              javaScriptCanOpenWindowsAutomatically: true,
            ),
            onWebViewCreated: (controller) {
              _controller = controller;
            },
            onLoadStart: (controller, url) {
              if (mounted) {
                setState(() => _loading = true);
              }
              _detectSessionExpiry(url?.toString());
              _refreshNavigationState();
            },
            onLoadStop: (controller, url) async {
              if (url != null) {
                await WebSessionService.instance.persistCookies(url.toString());
              }

              // Inject dark mode CSS if enabled.
              await _injectDarkMode(controller);

              final title = await controller.getTitle();
              if (mounted) {
                setState(() {
                  _loading = false;
                  _progress = 1;
                  if (title != null && title.trim().isNotEmpty) {
                    _title = title;
                  }
                });
              }
              await _refreshNavigationState();
            },
            onProgressChanged: (controller, progress) {
              if (mounted) {
                setState(() => _progress = progress / 100);
              }
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final url = navigationAction.request.url?.toString() ?? '';
              // Reuse oldlib behavior: allow expected portal/login URLs and
              // block unknown external redirects, but if disallowed try to load
              // it in the same WebView instead of dropping the navigation.
              if (_isAllowed(url)) {
                return NavigationActionPolicy.ALLOW;
              }

              // If a target="_blank" or window.open tries to load an external link,
              // keep it inside this WebView to avoid a stalled login flow.
              await _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
              return NavigationActionPolicy.CANCEL;
            },
            onCreateWindow: (controller, createWindowAction) async {
              final url = createWindowAction.request.url?.toString() ?? '';
              if (url.isNotEmpty) {
                // Always load popups in the same WebView to support OAuth/login flows.
                await _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
              }
              return false;
            },
            onReceivedError: (controller, request, error) {
              if (mounted) {
                setState(() => _loading = false);
              }
            },
          ),
          if (_loading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _progress == 0 ? null : _progress,
                minHeight: 3,
                backgroundColor: Colors.transparent,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}
