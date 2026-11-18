import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:invoice_agent/api/api_client.dart';
import 'package:invoice_agent/app_state.dart';
import 'package:invoice_agent/main.dart';
import 'package:invoice_agent/theme/text.dart' as text;
import 'package:material_ui/material_ui.dart';

import 'fixtures.dart';

Future<void> pumpApp(
  WidgetTester tester,
  AppState state, {
  Size size = const Size(1336, 1000),
}) async {
  text.useGoogleFonts = false;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(InvoiceAgentApp(state: state));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the figures of the backend', (tester) async {
    final state = AppState(ApiClient(client: fakeBackend(), baseUrl: 'http://test'));
    await pumpApp(tester, state);

    expect(find.text('SPEND IN NOVEMBER'), findsOneWidget);
    expect(find.text('€9,201'), findsOneWidget);
    expect(find.text('+15% VS OCTOBER'), findsOneWidget);
    expect(find.text('38'), findsOneWidget);
    expect(find.text('5 invoices'), findsOneWidget);
    expect(find.text('MERIDIAN FREIGHT'), findsOneWidget);
    expect(find.text('31 of 38 invoices need nothing from you.'), findsOneWidget);
    expect(find.text('NOV'), findsOneWidget);
  });

  testWidgets('loads the demo set from an empty database', (tester) async {
    final requests = <String>[];
    final state = AppState(
      ApiClient(
        client: fakeBackend(metrics: emptyMetricsJson, requests: requests),
        baseUrl: 'http://test',
      ),
    );
    await pumpApp(tester, state);

    expect(find.textContaining('No invoices yet'), findsOneWidget);
    await tester.tap(find.text('LOAD DEMO'));
    await tester.pumpAndSettle();
    expect(requests, contains('POST /ingest/demo'));
  });

  testWidgets('explains when the backend is not running', (tester) async {
    final offline = MockClient((_) async => throw http.ClientException('Connection refused'));
    final state = AppState(ApiClient(client: offline, baseUrl: 'http://test'));
    await pumpApp(tester, state);

    expect(find.textContaining('Cannot reach the backend'), findsOneWidget);
    expect(find.text('TRY AGAIN'), findsOneWidget);
  });

  // A layout error (a RenderFlex overflow) fails the test, so these check every window size.
  for (final size in const [Size(1336, 1000), Size(1280, 888), Size(1180, 820), Size(1000, 600)]) {
    for (final empty in [false, true]) {
      testWidgets('fits a window of ${size.width.toInt()} x ${size.height.toInt()}'
          '${empty ? ' with no invoices' : ''}', (tester) async {
        final client = fakeBackend(
          metrics: empty ? emptyMetricsJson : metricsJson,
          invoices: empty ? const [] : null,
          exportSummary: empty ? emptyExportSummaryJson : exportSummaryJson,
        );
        final state = AppState(ApiClient(client: client, baseUrl: 'http://test'));
        await pumpApp(tester, state, size: size);

        expect(find.text('OVERVIEW'), findsOneWidget);
        await tester.tap(find.text('EXPORT'));
        await tester.pumpAndSettle();
        expect(find.text(empty ? 'SHEETS (0)' : 'SHEETS (2)'), findsOneWidget);
      });
    }
  }
}
