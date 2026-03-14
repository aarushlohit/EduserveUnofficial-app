import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../providers/portal_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EduServeWebViewBody
//
// Renders the EduServe portal inside an InAppWebView.
// Key features:
//  • Spoofed User-Agent (removes "wv" WebView marker).
//  • Dark-mode CSS injection when the user has enabled it.
//  • Session-expiry detection via URL monitoring.
//  • Progress bar showing page load.
// ─────────────────────────────────────────────────────────────────────────────

class EduServeWebViewBody extends StatefulWidget {
  const EduServeWebViewBody({super.key, this.initialUrl});
  final String? initialUrl;

  @override
  State<EduServeWebViewBody> createState() => _EduServeWebViewBodyState();
}

class _EduServeWebViewBodyState extends State<EduServeWebViewBody> {
  InAppWebViewController? _webController;
  double _loadProgress = 0;
  bool _isLoading = true;

  @override
  Widget build(BuildContext context) {
    final portalProvider = context.watch<PortalProvider>();

    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri(widget.initialUrl ?? AppConstants.dashboardUrl),
          ),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            domStorageEnabled: true,
            databaseEnabled: true,
            cacheEnabled: true,
            // Removes the Android "wv" WebView identifier so Google OAuth
            // treats this as a standard Chrome browser.
            userAgent: AppConstants.desktopUserAgent,
            // Allow mixed content for portals that load HTTP sub-resources.
            mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
            mediaPlaybackRequiresUserGesture: false,
            useShouldOverrideUrlLoading: true,
          ),
          onWebViewCreated: (controller) {
            _webController = controller;
          },
          onLoadStart: (controller, url) {
            setState(() => _isLoading = true);
            _detectSessionExpiry(url?.toString());
          },
          onLoadStop: (controller, url) async {
            setState(() {
              _isLoading = false;
              _loadProgress = 1;
            });
            // Inject dark mode CSS after page loads if enabled.
            if (portalProvider.darkWebMode) {
              await _injectDarkMode(controller);
            }
          },
          onProgressChanged: (controller, progress) {
            setState(() => _loadProgress = progress / 100);
          },
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            final url = navigationAction.request.url?.toString() ?? '';
            // Let all portal URLs through; block external redirects.
            if (url.startsWith(AppConstants.portalBaseUrl) ||
                url.startsWith('https://accounts.google.com')) {
              return NavigationActionPolicy.ALLOW;
            }
            // External links: open in Chrome instead.
            return NavigationActionPolicy.CANCEL;
          },
          onReceivedError: (controller, request, error) {
            // Silently ignore ERR_CACHE_MISS on navigating back.
          },
        ),

        // ── Progress bar ────────────────────────────────────────────────
        if (_isLoading)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              value: _loadProgress == 0 ? null : _loadProgress,
              minHeight: 3,
              backgroundColor: Colors.transparent,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
      ],
    );
  }

  // ── Dark mode injection ────────────────────────────────────────────────────

  Future<void> _injectDarkMode(InAppWebViewController controller) async {
    await controller.evaluateJavascript(
      source: AppConstants.darkModeScript,
    );
  }

  // ── Session expiry detection ───────────────────────────────────────────────

  void _detectSessionExpiry(String? url) {
    if (url == null) return;
    final isLoginPage = AppConstants.loginIndicators
        .any((indicator) => url.toLowerCase().contains(indicator.toLowerCase()));
    if (isLoginPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<AuthProvider>().onSessionExpired();
        }
      });
    }
  }

  // ── Public helpers used by parent ──────────────────────────────────────────

  Future<void> navigateTo(String url) async {
    await _webController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(url)),
    );
  }

  Future<void> reload() async {
    await _webController?.reload();
  }

  Future<void> goBack() async {
    await _webController?.goBack();
  }
}
