import 'package:eduserveapp/core/constants/app_config.dart';
import 'package:eduserveapp/core/services/activity_log_service.dart';
import 'package:eduserveapp/core/services/analytics_service.dart';
import 'package:eduserveapp/features/eduserve/shared_webview_screen.dart';
import 'package:flutter/material.dart';

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
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logResultsOpened();
    ActivityLogService.instance.logCurrentUserAction(
      uid: widget.uid,
      action: 'open_results',
      tab: 'results',
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const SharedWebViewScreen(
      initialTitle: 'Semester Results',
      initialUrl: AppConfig.resultsUrl,
      allowedUrlPrefixes: <String>[
        AppConfig.resultsUrl,
        'https://web.karunya.edu',
        'http://web.karunya.edu',
        AppConfig.eduserveBaseUrl,
        'https://accounts.google.com',
      ],
    );
  }
}
