// Runs in the real macOS app: flutter test integration_test -d macos
// It types into the search field and into the date picker, which once crashed the app on a
// patched macOS install (see skipFontPanelUpdates in macos/Runner/MainFlutterWindow.swift).
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:invoice_agent/api/api_client.dart';
import 'package:invoice_agent/app_state.dart';
import 'package:invoice_agent/screens/invoices_screen.dart';
import 'package:invoice_agent/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

import '../test/fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('typing in the search field and the date picker', (tester) async {
    final state = AppState(ApiClient(client: fakeBackend(), baseUrl: 'http://test'));
    await state.refresh();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: InvoicesScreen(state: state, onReview: (_) {}, onExport: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'mf');
    await tester.pumpAndSettle();
    expect(find.text('INVOICES (1)'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('ALL DATES'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '11/01/2026');
    await tester.pumpAndSettle();
  });
}
