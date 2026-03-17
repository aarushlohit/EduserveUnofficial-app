import 'package:eduserveapp/core/constants/app_config.dart';
import 'package:eduserveapp/core/services/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ResultsWebViewScreen extends StatefulWidget {
  const ResultsWebViewScreen({
    super.key,
    required this.uid,
  });

  final String uid;

  @override
  State<ResultsWebViewScreen> createState() => _ResultsWebViewScreenState();
}

class _ResultsWebViewScreenState extends State<ResultsWebViewScreen>
    with AutomaticKeepAliveClientMixin {
  late final WebViewController _controller;
  bool _openingFallback = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logResultsOpened();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) => NavigationDecision.navigate,
          onWebResourceError: (error) {
            _handleWebError(error.description);
          },
        ),
      )
      ..loadRequest(Uri.parse(AppConfig.resultsUrl));
  }

  Future<void> _handleWebError(String reason) async {
    if (_openingFallback || !mounted) {
      return;
    }

    _openingFallback = true;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content:
            Text('This site uses outdated security. Opening in browser...'),
      ),
    );

    final launched = await launchUrl(
      Uri.parse(AppConfig.resultsUrl),
      mode: LaunchMode.externalApplication,
    );

    if (!mounted) {
      return;
    }

    if (!launched) {
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to open browser. Error: $reason')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Semester Results'),
        actions: <Widget>[
          IconButton(
            onPressed: () => _controller.reload(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: () => launchUrl(
              Uri.parse(AppConfig.resultsUrl),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open in browser',
          ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
