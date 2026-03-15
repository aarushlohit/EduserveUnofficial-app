import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Conditions')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const <Widget>[
          _SectionTitle('Using the app'),
          _Paragraph(
            'PocketEduServe is an unofficial companion for Karunya students. '
            'Use it responsibly and alongside official university portals.',
          ),
          _SectionTitle('Accounts'),
          _Paragraph(
            'You are responsible for keeping your account and credentials secure. '
            'Do not share login details. If you suspect misuse, log out and reset your password.',
          ),
          _SectionTitle('Content'),
          _Paragraph(
            'Information shown in the app may rely on third-party sources (e.g., EduServe, college systems). '
            'We do not guarantee accuracy or availability of external systems.',
          ),
          _SectionTitle('Updates'),
          _Paragraph(
            'We may require you to update the app for security or compatibility reasons. '
            'Continued use means you accept the latest terms.',
          ),
          _SectionTitle('Acceptable use'),
          _Paragraph(
            'Do not attempt to reverse engineer, scrape, or abuse the service. '
            'Do not upload harmful, illegal, or abusive content.',
          ),
          _SectionTitle('Liability'),
          _Paragraph(
            'The app is provided on a best-effort basis without warranties. '
            'We are not liable for data loss, missed deadlines, or service outages.',
          ),
          _SectionTitle('Contact'),
          _Paragraph(
            'For questions, feedback, or issue reports, reach out to the maintainer directly.',
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
