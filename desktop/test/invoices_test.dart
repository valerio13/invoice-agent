import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_agent/api/api_client.dart';
import 'package:invoice_agent/app_state.dart';
import 'package:invoice_agent/shell/sidebar.dart';
import 'package:invoice_agent/widgets/buttons.dart';
import 'package:material_ui/material_ui.dart';

import 'fixtures.dart';
import 'overview_test.dart' show pumpApp;

Future<void> openInvoices(WidgetTester tester, {Size size = const Size(1336, 1000)}) async {
  final state = AppState(ApiClient(client: fakeBackend(), baseUrl: 'http://test'));
  await pumpApp(tester, state, size: size);
  // The sidebar entry; the Overview also has an "Invoices" tile.
  await tester.tap(find.descendant(of: find.byType(Sidebar), matching: find.text('INVOICES')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists every invoice as a ticket, newest first', (tester) async {
    await openInvoices(tester);

    expect(find.text('INVOICES (4)'), findsOneWidget);
    expect(find.text('BW-88217'), findsOneWidget);
    expect(find.text('TO REVIEW'), findsWidgets);
    expect(find.text('€1,500.40'), findsNWidgets(2));
    final dates = tester.widgetList<Text>(find.textContaining(' NOV')).map((t) => t.data).toList();
    expect(dates.take(3), ['12 NOV', '09 NOV', '05 NOV']);
  });

  testWidgets('filters by status and by number', (tester) async {
    await openInvoices(tester);

    await tester.tap(find.text('DUPLICATES'));
    await tester.pumpAndSettle();
    expect(find.text('INVOICES (1)'), findsOneWidget);

    await tester.tap(find.text('ALL'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'mf/11');
    await tester.pumpAndSettle();
    expect(find.text('INVOICES (1)'), findsOneWidget);
    expect(find.text('MF/11/0093'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'nothing like this');
    await tester.pumpAndSettle();
    expect(find.text('No invoice matches these filters.'), findsOneWidget);
  });

  testWidgets('filters by file type and sorts oldest first', (tester) async {
    await openInvoices(tester);

    await tester.tap(find.text('IMAGE'));
    await tester.pumpAndSettle();
    expect(find.text('INVOICES (1)'), findsOneWidget);

    await tester.tap(find.text('ANY TYPE'));
    await tester.tap(find.text('NEWEST FIRST'));
    await tester.pumpAndSettle();
    expect(find.text('OLDEST FIRST'), findsOneWidget);
    final dates = tester.widgetList<Text>(find.textContaining(' OCT')).map((t) => t.data);
    expect(dates.first, '12 OCT');
  });

  testWidgets('shows the selected invoice in the panel', (tester) async {
    await openInvoices(tester);

    await tester.tap(find.text('BW-88217'));
    await tester.pumpAndSettle();
    expect(find.text('Net amount plus VAT is 422.29, but the total says 432.29.'), findsOneWidget);
  });

  testWidgets('review opens the review screen with that invoice', (tester) async {
    await openInvoices(tester);

    await tester.tap(find.widgetWithText(AppButton, 'REVIEW').first);
    await tester.pumpAndSettle();
    expect(find.text('REVIEW (1 OF 2)'), findsOneWidget);
  });

  for (final size in const [Size(1280, 888), Size(1180, 820), Size(1000, 600)]) {
    testWidgets('fits a window of ${size.width.toInt()} x ${size.height.toInt()}', (tester) async {
      await openInvoices(tester, size: size);
      expect(find.text('INVOICES (4)'), findsOneWidget);
    });
  }

  testWidgets('a cross clears the date and supplier filters', (tester) async {
    await openInvoices(tester);

    await tester.tap(find.text('ALL DATES'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    expect(find.text('ALL DATES'), findsNothing);
    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('ALL DATES'), findsOneWidget);

    await tester.tap(find.text('SUPPLIERS'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Meridian Freight'));
    await tester.pumpAndSettle();
    expect(find.text('INVOICES (1)'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('INVOICES (4)'), findsOneWidget);
  });
}
