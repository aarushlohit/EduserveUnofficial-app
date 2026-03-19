import 'package:eduserveapp/features/web/common_webview_page.dart';
import 'package:flutter/material.dart';

class FeesScreen extends StatelessWidget {
  const FeesScreen({super.key});

  static const String _regularFeesUrl =
      'https://eduserve.karunya.edu/online/payfees.aspx';
  static const String _addonsFeesUrl =
      'https://eduserve.karunya.edu/online/PayAddOnFees.aspx';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fees')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text('Regular Fees'),
              subtitle: const Text('Pay standard semester fees'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CommonWebViewPage(
                      title: 'Regular Fees',
                      url: _regularFeesUrl,
                      tabKey: 'fees',
                    ),
                  ),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.extension_outlined),
              title: const Text('Add-ons Fees'),
              subtitle: const Text('Pay fees for add-ons'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CommonWebViewPage(
                      title: 'Add-ons Fees',
                      url: _addonsFeesUrl,
                      tabKey: 'fees',
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
