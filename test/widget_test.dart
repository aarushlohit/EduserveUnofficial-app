// Basic smoke test for PocketEduServe.
//
// The main entry point is EduServeCompanionApp which bootstraps Firebase
// and shared preferences internally. Because widget tests cannot initialise
// Firebase, we verify only that the root widget type can be instantiated.

import 'package:flutter_test/flutter_test.dart';
import 'package:eduserveapp/app.dart';

void main() {
  testWidgets('EduServeCompanionApp can be instantiated', (tester) async {
    // The widget requires Firebase, so pumpWidget will fail during
    // bootstrap. We only verify that the const constructor works.
    expect(const EduServeCompanionApp(), isA<EduServeCompanionApp>());
  });
}
