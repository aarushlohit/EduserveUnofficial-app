import 'package:eduserveapp/features/web/common_webview_page.dart';
import 'package:flutter/material.dart';

class ExternalEventsScreen extends StatelessWidget {
  const ExternalEventsScreen({super.key});

  static const String _externalEventsUrl =
      'https://eduserve.karunya.edu/Online/ExternalEvents.aspx';

  @override
  Widget build(BuildContext context) {
    return const CommonWebViewPage(
      title: 'External Events',
      url: _externalEventsUrl,
      tabKey: 'externalEvents',
    );
  }
}
