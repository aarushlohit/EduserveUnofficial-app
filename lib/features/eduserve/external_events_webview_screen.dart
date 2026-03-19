import 'package:eduserveapp/core/constants/app_config.dart';
import 'package:eduserveapp/core/services/analytics_service.dart';
import 'package:eduserveapp/features/web/common_pdf_viewer_page.dart';
import 'package:eduserveapp/features/web/common_webview_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

class ExternalEventsWebViewScreen extends StatefulWidget {
  const ExternalEventsWebViewScreen({
    super.key,
    required this.uid,
  });

  final String uid;

  @override
  State<ExternalEventsWebViewScreen> createState() =>
      _ExternalEventsWebViewScreenState();
}

class _ExternalEventsWebViewScreenState
    extends State<ExternalEventsWebViewScreen>
    with AutomaticKeepAliveClientMixin {
  InAppWebViewController? _controller;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _openingFallback = false;
  double _progress = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logEvent('external_events_opened');
  }

  Future<void> _openExternally(String url) async {
    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _handleDownload(String url) async {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Downloading via browser...')),
    );

    await _openExternally(url);
  }

  Future<void> _handleSslOrNetworkFailure(String reason) async {
    if (_openingFallback || !mounted) {
      return;
    }

    _openingFallback = true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This page uses legacy security. Opening in browser...'),
      ),
    );

    final launched = await launchUrl(
      Uri.parse(AppConfig.externalEventsUrl),
      mode: LaunchMode.externalApplication,
    );

    if (!mounted) {
      return;
    }

    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open browser. Error: $reason')),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('External Events'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Portals',
            icon: const Icon(Icons.apps_outage_outlined),
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (_) {
                  return SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        ListTile(
                          leading: const Icon(Icons.payments_outlined),
                          title: const Text('Regular Fees'),
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const CommonWebViewPage(
                                  title: 'Regular Fees',
                                  url:
                                      'https://eduserve.karunya.edu/online/payfees.aspx',
                                  tabKey: 'fees',
                                ),
                              ),
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.extension_outlined),
                          title: const Text('Add-ons Fees'),
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const CommonWebViewPage(
                                  title: 'Add-ons Fees',
                                  url:
                                      'https://eduserve.karunya.edu/online/PayAddOnFees.aspx',
                                  tabKey: 'fees',
                                ),
                              ),
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.event_available_outlined),
                          title: const Text('External Events'),
                          onTap: () {
                            Navigator.of(context).pop();
                            _controller?.loadUrl(
                              urlRequest: URLRequest(
                                  url: WebUri(AppConfig.externalEventsUrl)),
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.public_outlined),
                          title: const Text('Karunya Website'),
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const CommonPdfViewerPage(
                                  title: 'Karunya Calendar 2026',
                                  url:
                                      'https://karunya.edu/sites/default/files/img/calendar/calendar.pdf?v=2615380319',
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          IconButton(
            onPressed: _canGoBack
                ? () async {
                    await _controller?.goBack();
                    await _refreshNavigationState();
                  }
                : null,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
          ),
          IconButton(
            onPressed: _canGoForward
                ? () async {
                    await _controller?.goForward();
                    await _refreshNavigationState();
                  }
                : null,
            icon: const Icon(Icons.arrow_forward),
            tooltip: 'Forward',
          ),
          IconButton(
            onPressed: () => _controller?.reload(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: () => _openExternally(AppConfig.externalEventsUrl),
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open in browser',
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          InAppWebView(
            initialUrlRequest:
                URLRequest(url: WebUri(AppConfig.externalEventsUrl)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              userAgent: AppConfig.desktopUserAgent,
              useShouldOverrideUrlLoading: true,
              javaScriptCanOpenWindowsAutomatically: true,
              supportMultipleWindows: true,
            ),
            onWebViewCreated: (controller) {
              _controller = controller;
            },
            onLoadStart: (controller, url) {
              // ignore: avoid_print
              print('Loading: $url');
            },
            onProgressChanged: (controller, progress) {
              if (!mounted) {
                return;
              }
              setState(() => _progress = progress / 100);
            },
            onLoadStop: (controller, url) async {
              _controller = controller;
              await _refreshNavigationState();
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final url = navigationAction.request.url?.toString() ?? '';
              final lower = url.toLowerCase();
              final isDownload = lower.endsWith('.pdf') ||
                  lower.endsWith('.zip') ||
                  lower.endsWith('.doc') ||
                  lower.endsWith('.xls') ||
                  lower.contains('download');

              if (isDownload) {
                await _handleDownload(url);
                return NavigationActionPolicy.CANCEL;
              }

              return NavigationActionPolicy.ALLOW;
            },
            onDownloadStartRequest: (controller, request) async {
              await _handleDownload(request.url.toString());
            },
            onCreateWindow: (controller, createWindowRequest) async {
              final uri = createWindowRequest.request.url;
              if (uri != null) {
                await controller.loadUrl(urlRequest: URLRequest(url: uri));
              }
              return true;
            },
            onReceivedServerTrustAuthRequest: (controller, challenge) async {
              return ServerTrustAuthResponse(
                action: ServerTrustAuthResponseAction.PROCEED,
              );
            },
            onReceivedError: (controller, request, error) {
              _handleSslOrNetworkFailure(error.description);
            },
          ),
          if (_progress > 0 && _progress < 1)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 3,
              ),
            ),
        ],
      ),
    );
  }
}
