import 'package:eduserveapp/core/constants/app_config.dart';
import 'package:eduserveapp/core/services/analytics_service.dart';
import 'package:eduserveapp/features/eduserve/shared_webview_screen.dart';
import 'package:flutter/material.dart';

class EduserveWebViewScreen extends StatefulWidget {
  const EduserveWebViewScreen({
    super.key,
    required this.uid,
  });

  final String uid;

  @override
  State<EduserveWebViewScreen> createState() => _EduserveWebViewScreenState();
}

class _EduserveWebViewScreenState extends State<EduserveWebViewScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logEduserveOpened();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const SharedWebViewScreen(
      initialTitle: 'EduServe Dashboard',
      initialUrl: AppConfig.eduserveBaseUrl,
      allowedUrlPrefixes: <String>[
        AppConfig.eduserveBaseUrl,
        'https://accounts.google.com',
      ],
    );
  }
}
