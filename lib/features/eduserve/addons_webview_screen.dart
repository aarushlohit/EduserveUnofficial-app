import 'package:eduserveapp/core/constants/app_config.dart';
import 'package:eduserveapp/core/services/analytics_service.dart';
import 'package:eduserveapp/features/eduserve/shared_webview_screen.dart';
import 'package:flutter/material.dart';

class AddonsWebViewScreen extends StatefulWidget {
  const AddonsWebViewScreen({
    super.key,
    required this.uid,
  });

  final String uid;

  @override
  State<AddonsWebViewScreen> createState() => _AddonsWebViewScreenState();
}

class _AddonsWebViewScreenState extends State<AddonsWebViewScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logEvent('addons_opened');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const SharedWebViewScreen(
      initialTitle: 'Add-ons',
      initialUrl: AppConfig.addonsUrl,
      allowedUrlPrefixes: <String>[
        AppConfig.addonsUrl,
        AppConfig.eduserveBaseUrl,
        'https://accounts.google.com',
      ],
    );
  }
}
