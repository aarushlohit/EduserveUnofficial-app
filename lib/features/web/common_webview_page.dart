import 'dart:async';

import 'package:eduserveapp/core/constants/app_config.dart';
import 'package:eduserveapp/core/services/activity_log_service.dart';
import 'package:eduserveapp/core/services/app_stats_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class CommonWebViewPage extends StatefulWidget {
  const CommonWebViewPage({
    super.key,
    required this.url,
    required this.title,
    this.tabKey,
    this.useDesktopUserAgent = true,
  });

  final String url;
  final String title;
  final String? tabKey;
  final bool useDesktopUserAgent;

  @override
  State<CommonWebViewPage> createState() => _CommonWebViewPageState();
}

class _CommonWebViewPageState extends State<CommonWebViewPage> {
  late InAppWebViewController _webViewController;
  bool _hasController = false;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _isLoading = true;
  bool _fallbackInProgress = false;
  double _progress = 0;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    unawaited(_logOpenAnalytics());
  }

  Future<void> _logOpenAnalytics() async {
    final tab = widget.tabKey;
    if (tab == null || tab.isEmpty) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString(AppConfig.profileDocIdKey) ?? '';

      if (uid.isNotEmpty) {
        await ActivityLogService.instance.logCurrentUserAction(
          uid: uid,
          action: 'open_$tab',
          tab: tab,
        );
      }

      await AppStatsService.instance.logTabOpen(tab);
    } catch (_) {
      // Keep portal access resilient even if analytics logging fails.
    }
  }

  Future<void> _openInBrowser({String? overrideUrl}) async {
    final source = overrideUrl ?? widget.url;
    final uri = Uri.tryParse(source);
    if (uri == null) {
      return;
    }

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _handleLoadFailure(String reason, {String? fallbackUrl}) async {
    if (_fallbackInProgress || !mounted) {
      return;
    }

    _fallbackInProgress = true;

    setState(() {
      _isLoading = false;
      _errorText = reason;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Secure connection issue. Opening in browser...'),
      ),
    );

    await _openInBrowser(overrideUrl: fallbackUrl);
  }

  Future<void> _refreshNavigationState() async {
    if (!_hasController) {
      return;
    }

    final canGoBack = await _webViewController.canGoBack();
    final canGoForward = await _webViewController.canGoForward();
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: _canGoBack
                ? () async {
                    await _webViewController.goBack();
                    await _refreshNavigationState();
                  }
                : null,
          ),
          IconButton(
            tooltip: 'Forward',
            icon: const Icon(Icons.arrow_forward),
            onPressed: _canGoForward
                ? () async {
                    await _webViewController.goForward();
                    await _refreshNavigationState();
                  }
                : null,
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _hasController
                ? () async {
                    setState(() {
                      _isLoading = true;
                      _errorText = null;
                      _fallbackInProgress = false;
                    });
                    await _webViewController.reload();
                    await _refreshNavigationState();
                  }
                : null,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Open in browser',
            onPressed: _openInBrowser,
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.url)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              databaseEnabled: true,
              cacheEnabled: true,
              useShouldOverrideUrlLoading: true,
              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              userAgent: widget.useDesktopUserAgent
                  ? AppConfig.desktopUserAgent
                  : null,
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
              _hasController = true;
            },
            onLoadStart: (_, __) {
              setState(() {
                _isLoading = true;
                _errorText = null;
              });
            },
            onLoadStop: (controller, url) async {
              _webViewController = controller;
              _hasController = true;
              final canGoBack = await controller.canGoBack();
              final canGoForward = await controller.canGoForward();
              if (!mounted) {
                return;
              }
              setState(() {
                _isLoading = false;
                _progress = 1;
                _canGoBack = canGoBack;
                _canGoForward = canGoForward;
              });
            },
            onProgressChanged: (_, progress) {
              if (!mounted) {
                return;
              }
              setState(() {
                _progress = progress / 100;
              });
            },
            onDownloadStartRequest: (controller, request) async {
              await launchUrl(
                Uri.parse(request.url.toString()),
                mode: LaunchMode.externalApplication,
              );
            },
            onReceivedServerTrustAuthRequest: (_, __) async {
              return ServerTrustAuthResponse(
                action: ServerTrustAuthResponseAction.PROCEED,
              );
            },
            onReceivedError: (_, request, error) {
              final requestUrl = request.url.toString();
              _handleLoadFailure(
                error.description,
                fallbackUrl: requestUrl,
              );
            },
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
          if (!_isLoading && _errorText != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Unable to load page. Opening in browser...\n$_errorText',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          if (_progress > 0 && _progress < 1)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(value: _progress),
            ),
        ],
      ),
    );
  }
}
