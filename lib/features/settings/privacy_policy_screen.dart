import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const <Widget>[
          _SectionTitle('What we collect'),
          _Paragraph(
            'Profile details you provide (name, email, avatar) and limited usage telemetry '
            '(app opens, feature taps, anonymized analytics).',
          ),
          _SectionTitle('Why we collect it'),
          _Paragraph(
            'To personalize your experience, maintain feature usage insights, and improve reliability. '
            'No data is sold or shared for advertising.',
          ),
          _SectionTitle('Storage & retention'),
          _Paragraph(
            'Data is stored in Firebase. Activity logs are trimmed automatically after a few days to reduce footprint.',
          ),
          _SectionTitle('Notifications'),
          _Paragraph(
            'If enabled, we may send announcements or hackathon alerts. You can clear notifications in-app.',
          ),
          _SectionTitle('Security'),
          _Paragraph(
            'We rely on Firebase Auth/Firestore security rules. Avoid sharing accounts and always use official logins.',
          ),
          _SectionTitle('Your choices'),
          _Paragraph(
            'You can request deletion of your stored data by contacting the maintainer and signing out of the app.',
          ),
          _SectionTitle('Contact'),
          _Paragraph('For privacy questions, contact the maintainer directly.'),
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
