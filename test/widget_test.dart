// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:eduserveapp/app.dart';
import 'package:eduserveapp/features/auth/presentation/providers/auth_provider.dart';
import 'package:eduserveapp/features/portal/presentation/providers/portal_provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
          ChangeNotifierProvider<PortalProvider>(create: (_) => PortalProvider()),
        ],
        child: const EduServeApp(),
      ),
    );
    await tester.pumpAndSettle();
  });
}
