import 'package:flutter/material.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Privacy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TERMS OF USE',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Effective Date: March 2026\n\n'
              '1. Independent Nature\n'
              'EduServe is an independent, student-developed interface designed to streamline access to publicly available institutional web resources.\n'
              'It operates strictly as a convenience layer and does not alter, replicate, or interfere with underlying systems.\n'
              'TEAM X is not affiliated with, endorsed by, or acting on behalf of any institution, including Karunya Institute of Technology and Sciences.\n\n'
              '2. Neutral Access Platform\n'
              'EduServe functions as a passive access facilitator.\n'
              'All user interactions, authentications, and transactions occur directly between the user and the respective official platforms.\n'
              'At no point does EduServe:\n'
              '- intercept credentials\n'
              '- modify data\n'
              '- store institutional records\n\n'
              '3. User Autonomy and Accountability\n'
              'Users access EduServe voluntarily and retain full responsibility for their actions.\n'
              'Use of the application constitutes acknowledgment that:\n'
              '- all actions performed are user-initiated\n'
              '- all outcomes remain the user\'s responsibility\n'
              '- compliance with institutional policies remains the user\'s obligation\n\n'
              '4. No Institutional Interference\n'
              'EduServe does not:\n'
              '- bypass security mechanisms\n'
              '- automate restricted processes\n'
              '- provide unauthorized access pathways\n'
              'It merely surfaces publicly reachable endpoints through a structured interface.\n\n'
              '5. Limitation of Liability\n'
              'To the fullest extent permitted by applicable law:\n'
              'TEAM X shall not be liable for:\n'
              '- service interruptions\n'
              '- access issues\n'
              '- institutional restrictions\n'
              '- account-related actions taken by third-party systems\n'
              '- interpretation or use of displayed information\n\n'
              '6. Third-Party Governance\n'
              'All external services accessed through EduServe are governed solely by their respective terms and policies.\n'
              'Users acknowledge that institutional platforms retain full authority over:\n'
              '- access control\n'
              '- account status\n'
              '- system usage\n\n'
              '7. No Operational Control\n'
              'TEAM X does not exercise control over institutional systems and cannot:\n'
              '- influence administrative decisions\n'
              '- modify institutional outcomes\n'
              '- intervene in user account actions\n\n'
              '8. Risk Acknowledgment\n'
              'Use of aggregated access tools may be subject to interpretation under institutional frameworks.\n'
              'Users voluntarily assume all associated risks arising from their use of such tools.\n\n'
              '9. Service Modification\n'
              'TEAM X reserves the right to:\n'
              '- modify features\n'
              '- restrict access\n'
              '- discontinue services\n'
              'at any time without prior notice.\n\n'
              '10. Acceptance\n'
              'Continued use of EduServe constitutes full acceptance of these terms.\n\n'
              'TEAM X\n'
              'Independent Student Initiative',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            const Text(
              'PRIVACY POLICY',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Effective Date: March 2026\n\n'
              '1. Minimal Data Principle\n'
              'EduServe follows a strict minimal data approach.\n'
              'We only process data necessary for:\n'
              '- authentication continuity\n'
              '- basic usage analytics\n'
              'We do NOT collect:\n'
              '- passwords\n'
              '- academic records\n'
              '- sensitive personal data\n\n'
              '2. Credential Isolation\n'
              'All authentication processes occur directly with official systems.\n'
              'EduServe does not:\n'
              '- store credentials\n'
              '- access secure input fields\n'
              '- log authentication data\n\n'
              '3. Localized Processing\n'
              'Where applicable, session-related data may be temporarily maintained on-device to improve user experience.\n'
              'Such data remains under user device control.\n\n'
              '4. Analytics (Non-Intrusive)\n'
              'We collect limited, non-identifiable usage metrics such as:\n'
              '- feature usage frequency\n'
              '- session duration\n'
              '- tab interaction counts\n'
              'No behavioral profiling or sensitive tracking is performed.\n\n'
              '5. External Systems Disclaimer\n'
              'EduServe interacts with third-party institutional platforms.\n'
              'We do not control or assume responsibility for:\n'
              '- their data handling practices\n'
              '- their security policies\n'
              '- their user management actions\n\n'
              '6. Data Sharing\n'
              'We do not:\n'
              '- sell data\n'
              '- share data with third parties\n'
              '- use data for advertising\n\n'
              '7. Security Posture\n'
              'Reasonable safeguards are implemented; however, no digital system guarantees absolute security.\n\n'
              '8. User Control\n'
              'Users retain full control by:\n'
              '- discontinuing app usage\n'
              '- clearing local app data\n\n'
              '9. Policy Updates\n'
              'This policy may be updated without prior notice.\n\n'
              '10. Consent\n'
              'Use of EduServe implies informed consent to this policy.\n\n'
              'TEAM X\n'
              '"We build quietly. We build responsibly."',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
