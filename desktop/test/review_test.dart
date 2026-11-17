import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_agent/api/api_client.dart';
import 'package:invoice_agent/app_state.dart';
import 'package:invoice_agent/shell/sidebar.dart';
import 'package:invoice_agent/widgets/buttons.dart';
import 'package:material_ui/material_ui.dart';

import 'fixtures.dart';
import 'overview_test.dart' show pumpApp;

Future<void> openFromSidebar(
  WidgetTester tester,
  String entry, {
  List<String>? requests,
  List<Object?>? bodies,
  String? reviewError,
  Size size = const Size(1336, 1000),
}) async {
  final client = fakeBackend(requests: requests, bodies: bodies, reviewError: reviewError);
  final state = AppState(ApiClient(client: client, baseUrl: 'http://test'));
  await pumpApp(tester, state, size: size);
  await tester.tap(find.descendant(of: find.byType(Sidebar), matching: find.text(entry)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens the first invoice waiting, with the doubtful field in gold', (tester) async {
    await openFromSidebar(tester, 'REVIEW');

    expect(find.text('REVIEW (1 OF 1)'), findsOneWidget);
    expect(find.text('BRIGHTWAVE HOSTING'), findsOneWidget);
    expect(find.text('432.29'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Net amount plus VAT is 422.29, but the total says 432.29.'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('save and approve sends the corrected fields', (tester) async {
    final requests = <String>[];
    final bodies = <Object?>[];
    await openFromSidebar(tester, 'REVIEW', requests: requests, bodies: bodies);

    await tester.enterText(find.widgetWithText(TextField, '432.29'), '422.29');
    await tester.tap(find.text('SAVE AND APPROVE'));
    await tester.pumpAndSettle();

    expect(requests, contains('PUT /invoices/2'));
    final body = bodies.last! as Map<String, dynamic>;
    expect(body['approve'], isTrue);
    expect((body['fields'] as Map)['total'], '422.29');
    expect((body['fields'] as Map)['issue_date'], '2026-11-09');
  });

  testWidgets('shows what the backend says is wrong', (tester) async {
    await openFromSidebar(tester, 'REVIEW', reviewError: 'Total: Input should be a valid decimal');

    await tester.tap(find.text('SAVE AND APPROVE'));
    await tester.pumpAndSettle();
    expect(find.text('Total: Input should be a valid decimal'), findsOneWidget);
  });

  testWidgets('marks an invoice as duplicate', (tester) async {
    final requests = <String>[];
    await openFromSidebar(tester, 'REVIEW', requests: requests);

    await tester.tap(find.text('MARK AS DUPLICATE'));
    await tester.pumpAndSettle();
    expect(requests, contains('POST /invoices/2/duplicate'));
  });

  testWidgets('an invoice opened from Invoices joins the queue', (tester) async {
    await openFromSidebar(tester, 'INVOICES');

    await tester.tap(find.widgetWithText(AppButton, 'REVIEW').first);
    await tester.pumpAndSettle();
    expect(find.text('REVIEW (1 OF 2)'), findsOneWidget);
    expect(find.text('NORTHLAKE PAPER'), findsOneWidget);

    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    expect(find.text('REVIEW (2 OF 2)'), findsOneWidget);
    expect(find.text('BRIGHTWAVE HOSTING'), findsOneWidget);
  });

  testWidgets('zoom opens a menu to choose the level', (tester) async {
    await openFromSidebar(tester, 'REVIEW');

    final page = find.descendant(of: find.byType(InteractiveViewer), matching: find.byType(Image));
    final before = tester.getRect(page);

    await tester.tap(find.text('ZOOM 100%'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(MenuItemButton, '400%'), findsOneWidget);

    await tester.tap(find.widgetWithText(MenuItemButton, '200%'));
    await tester.pumpAndSettle();
    expect(find.text('ZOOM 200%'), findsOneWidget);
    expect(find.widgetWithText(MenuItemButton, '400%'), findsNothing);

    // The page grows evenly left and right and keeps its top edge in place.
    final after = tester.getRect(page);
    expect(after.width, closeTo(before.width * 2, 0.01));
    expect(after.center.dx, closeTo(before.center.dx, 0.01));
    expect(after.top, closeTo(before.top, 0.01));
  });

  for (final size in const [Size(1280, 888), Size(1180, 820), Size(1000, 600)]) {
    testWidgets('fits a window of ${size.width.toInt()} x ${size.height.toInt()}', (tester) async {
      await openFromSidebar(tester, 'REVIEW', size: size);
      expect(find.text('REVIEW (1 OF 1)'), findsOneWidget);
    });
  }
}
