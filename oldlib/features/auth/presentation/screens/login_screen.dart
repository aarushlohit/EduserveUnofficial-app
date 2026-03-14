import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LoginScreen
//
// Landing page with a "Continue" button.  Tapping it pushes the in-app
// WebView login sheet.  The WebView lives inside the app so cookies are
// captured from the same WKWebView / android.webkit.WebView session.
// ─────────────────────────────────────────────────────────────────────────────

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // ── Branding ───────────────────────────────────────────────
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.school_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'EduServe',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Karunya Institute of Technology & Sciences',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withAlpha(153),
                    ),
              ),
              const Spacer(),

              // ── Info card ──────────────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 18, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'How login works',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        icon: Icons.web,
                        text:
                            'Sign in with your Karunya Google account inside the app.',
                      ),
                      const SizedBox(height: 6),
                      _InfoRow(
                        icon: Icons.lock_outline,
                        text:
                            'Your session is saved securely so you stay logged in.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Action area ────────────────────────────────────────────
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  if (auth.status == AuthStatus.checkingSession) {
                    return const _LoadingButton(label: 'Verifying session…');
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (auth.status == AuthStatus.error &&
                          auth.errorMessage != null)
                        _ErrorBanner(
                          message: auth.errorMessage!,
                          onDismiss: auth.clearError,
                        ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () => _openLoginWebView(context),
                        icon: const Icon(Icons.login_rounded),
                        label: const Text(
                          'Continue with Karunya Portal',
                          style: TextStyle(fontSize: 15),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const Spacer(flex: 2),

              // ── Footer ─────────────────────────────────────────────────
              Text(
                'Unofficial app · Not affiliated with Karunya University',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurface.withAlpha(102),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _openLoginWebView(BuildContext context) {
    debugPrint('[LOGIN] Opening in-app login WebView');
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const _LoginWebViewScreen(),
        fullscreenDialog: true,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// In-app login WebView
//
// Loads the portal login page inside the app.  Monitors URL changes to
// detect when the user has successfully authenticated (landing on a page
// that is NOT the login or Google OAuth page), then captures cookies and
// notifies AuthProvider.
// ─────────────────────────────────────────────────────────────────────────────

class _LoginWebViewScreen extends StatefulWidget {
  const _LoginWebViewScreen();

  @override
  State<_LoginWebViewScreen> createState() => _LoginWebViewScreenState();
}

class _LoginWebViewScreenState extends State<_LoginWebViewScreen> {
  double _progress = 0;
  bool _capturing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in to EduServe'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: () {
            debugPrint('[LOGIN-WV] User cancelled login');
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri(AppConstants.loginUrl),
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              databaseEnabled: true,
              cacheEnabled: true,
              // Spoof User-Agent: removes "wv" WebView marker so Google OAuth
              // does not block the sign-in flow.
              userAgent: AppConstants.desktopUserAgent,
              useShouldOverrideUrlLoading: true,
              // Required for Google sign-in to work correctly inside WebView.
              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
            ),
            onLoadStart: (controller, url) {
              debugPrint('[LOGIN-WV] onLoadStart: $url');
            },
            onLoadStop: (controller, url) async {
              debugPrint('[LOGIN-WV] onLoadStop: $url');
              if (!_capturing) {
                await _checkIfLoggedIn(controller, url?.toString());
              }
            },
            onProgressChanged: (controller, progress) {
              setState(() => _progress = progress / 100);
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final url = navigationAction.request.url?.toString() ?? '';
              debugPrint('[LOGIN-WV] shouldOverride: $url');
              // Allow everything — we need Google OAuth redirects to proceed.
              return NavigationActionPolicy.ALLOW;
            },
            onReceivedError: (controller, request, error) {
              debugPrint(
                  '[LOGIN-WV] ERROR ${error.type}: ${error.description} @ ${request.url}');
            },
            onConsoleMessage: (controller, msg) {
              debugPrint('[LOGIN-WV] console[${msg.messageLevel}]: ${msg.message}');
            },
          ),
          if (_progress < 1)
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
          if (_capturing)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Saving session…',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _checkIfLoggedIn(
      InAppWebViewController controller, String? url) async {
    if (url == null) return;
    debugPrint('[LOGIN-WV] _checkIfLoggedIn: $url');

    // Still on login / OAuth pages — not done yet.
    final onAuthPage = AppConstants.loginIndicators
        .any((s) => url.toLowerCase().contains(s.toLowerCase()));
    if (onAuthPage) {
      debugPrint('[LOGIN-WV] Still on auth page, waiting…');
      return;
    }

    // Must be on the portal domain to be a successful login.
    if (!url.startsWith(AppConstants.portalBaseUrl)) {
      debugPrint('[LOGIN-WV] Not on portal domain, ignoring: $url');
      return;
    }

    debugPrint('[LOGIN-WV] Detected portal page — capturing cookies');
    setState(() => _capturing = true);

    // Read cookies directly from this WebView instance.
    final cookieManager = CookieManager.instance();
    final cookies = await cookieManager.getCookies(
      url: WebUri(AppConstants.portalBaseUrl),
    );
    debugPrint('[LOGIN-WV] Cookies found: ${cookies.length}');
    for (final c in cookies) {
      debugPrint('[LOGIN-WV]   cookie: ${c.name}=${c.value}  domain=${c.domain}');
    }

    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    await auth.onInAppLoginComplete(cookies);

    if (!mounted) return;
    Navigator.of(context).pop();
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _LoadingButton extends StatelessWidget {
  const _LoadingButton({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: colorScheme.primary.withAlpha(26),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.primary.withAlpha(77)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: colorScheme.primary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close, size: 16, color: Colors.red),
          ),
        ],
      ),
    );
  }
}
