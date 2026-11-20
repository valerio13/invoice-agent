import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_agent/api/api_client.dart';
import 'package:invoice_agent/api/models.dart';
import 'package:invoice_agent/app_state.dart';
import 'package:invoice_agent/files.dart';
import 'package:invoice_agent/main.dart';
import 'package:invoice_agent/shell/drop_zone.dart';
import 'package:invoice_agent/shell/reading_scene.dart';
import 'package:invoice_agent/shell/sidebar.dart';
import 'package:invoice_agent/theme/text.dart' as text;
import 'package:material_ui/material_ui.dart';

import 'fixtures.dart';

/// Answers the dialogs as a person would, without opening any.
class FakeFiles extends FileAccess {
  FakeFiles({this.picked = const [], this.saveTo});

  final List<InvoiceUpload> picked;
  final String? saveTo;
  final saved = <Workbook>[];

  @override
  Future<List<InvoiceUpload>> pickInvoices() async => picked;

  @override
  Future<String?> saveWorkbook(Workbook workbook) async {
    if (saveTo != null) saved.add(workbook);
    return saveTo;
  }
}

Future<void> open(
  WidgetTester tester,
  String entry, {
  FileAccess files = const FileAccess(),
  List<String>? requests,
  List<Object?>? bodies,
  Map<String, Object?> summary = exportSummaryJson,
  Size size = const Size(1336, 1000),
  List<Map<String, Object?>>? afterUpload,
  Map<String, Object?>? uploadResult,
  SceneTiming timing = SceneTiming.instant,
}) async {
  text.useGoogleFonts = false;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final client = fakeBackend(
    requests: requests,
    bodies: bodies,
    exportSummary: summary,
    invoicesAfterUpload: afterUpload,
    uploadResult: uploadResult ?? const {'stored': 2, 'skipped': 1, 'failed': [], 'rejected': []},
  );
  final state = AppState(ApiClient(client: client, baseUrl: 'http://test'));
  await tester.pumpWidget(InvoiceAgentApp(state: state, files: files, sceneTiming: timing));
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: find.byType(Sidebar), matching: find.text(entry)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows one row per sheet with its totals, and what stays out', (tester) async {
    await open(tester, 'EXPORT');

    expect(find.text('SHEETS (2)'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2 SHEETS, ONE PER MONTH'), findsOneWidget);
    expect(find.text('LEFT OUT UNTIL APPROVED'), findsOneWidget);
    expect(find.text('SHEET 2026-11'), findsOneWidget);
    expect(find.text('2 INVOICES'), findsOneWidget);
    expect(find.text('€3,898.40'), findsOneWidget);
    expect(find.text('100.00 USD'), findsNWidgets(2));
    expect(find.text('invoices-2026-11-18.xlsx'), findsOneWidget);
  });

  testWidgets('saves the workbook where the person chooses', (tester) async {
    final files = FakeFiles(saveTo: '/Users/demo/Desktop/invoices-2026-11-18.xlsx');
    final requests = <String>[];
    await open(tester, 'EXPORT', files: files, requests: requests);

    await tester.tap(find.text('SAVE EXCEL'));
    await tester.pumpAndSettle();

    expect(requests, contains('GET /export'));
    expect(files.saved.single.fileName, 'invoices-2026-11-18.xlsx');
    expect(files.saved.single.bytes, workbookBytes);
    expect(find.text('Saved to Desktop'), findsOneWidget);
  });

  testWidgets('cancelling the dialog saves nothing', (tester) async {
    final files = FakeFiles();
    await open(tester, 'EXPORT', files: files);

    await tester.tap(find.text('SAVE EXCEL'));
    await tester.pumpAndSettle();

    expect(files.saved, isEmpty);
    expect(find.text('Built from the database each time you save it.'), findsOneWidget);
  });

  testWidgets('sends the reviewer to the invoices left out', (tester) async {
    await open(tester, 'EXPORT');

    await tester.tap(find.text('REVIEW 1 FIRST'));
    await tester.pumpAndSettle();
    expect(find.text('REVIEW (1 OF 1)'), findsOneWidget);
  });

  testWidgets('cannot save an empty workbook', (tester) async {
    await open(tester, 'EXPORT', summary: emptyExportSummaryJson);

    expect(find.text('No invoice is ready for the Excel yet.'), findsOneWidget);
    expect(find.text('REVIEW 0 FIRST'), findsNothing);
    final save = tester.widget<InkWell>(
      find.ancestor(of: find.text('SAVE EXCEL'), matching: find.byType(InkWell)),
    );
    expect(save.onTap, isNull);
  });

  testWidgets('add files sends the picked files and says what happened', (tester) async {
    final files = FakeFiles(
      picked: const [
        InvoiceUpload('june.pdf', [37, 80, 68, 70]),
        InvoiceUpload('scan.png', [1, 2, 3]),
      ],
    );
    final requests = <String>[];
    final bodies = <Object?>[];
    await open(tester, 'INVOICES', files: files, requests: requests, bodies: bodies);
    requests.clear();

    await tester.tap(find.text('ADD FILES'));
    await tester.pumpAndSettle();

    expect(requests.first, 'POST /ingest/upload');
    expect(bodies.last, ['june.pdf', 'scan.png']);
    // The list is asked for again, so the new invoices show up.
    expect(requests, contains('GET /invoices'));
    expect(find.text('2 new invoices read. 1 already stored.'), findsOneWidget);
  });

  group('the reading robot', () {
    const timing = SceneTiming();
    final files = FakeFiles(
      picked: const [
        InvoiceUpload('atlas-as-0690.pdf', [37, 80, 68, 70]),
        InvoiceUpload('june.pdf', [1, 2, 3]),
      ],
    );

    testWidgets('reads with filling bars, says how sure it is, then the notice', (tester) async {
      await open(
        tester,
        'INVOICES',
        files: files,
        timing: timing,
        afterUpload: [
          ...invoicesJson,
          invoiceJson(
            50,
            'Atlas Software',
            'AS-0690',
            '2026-11-18',
            '119.00',
            '143.99',
            file: 'atlas-as-0690.pdf',
          ),
          invoiceJson(
            51,
            'Cobalt Office',
            'CO-1',
            '2026-11-17',
            '10.00',
            '12.10',
            file: 'june.pdf',
          ),
        ],
      );

      await tester.tap(find.text('ADD FILES'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ReadingScene), findsOneWidget);
      expect(find.text('AI IS READING…'), findsOneWidget);
      expect(find.text('2 files'), findsOneWidget);
      expect(find.text('SUPPLIER'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);

      // The robot reads for a moment even though the backend answered at once.
      await tester.pump(timing.minReading);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('READ BY AI · 96% SURE'), findsOneWidget);
      // Bars that fill up, not the values: the list behind shows those.
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(4));
      expect(
        find.descendant(of: find.byType(ReadingScene), matching: find.text('AS-0690')),
        findsNothing,
      );
      expect(find.text('+1 more read'), findsOneWidget);

      await tester.pump(timing.hold);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ReadingScene), findsNothing);
      expect(find.text('2 new invoices read. 1 already stored.'), findsOneWidget);
    });

    testWidgets('closes without the fields when nothing new was read', (tester) async {
      await open(
        tester,
        'INVOICES',
        files: files,
        timing: timing,
        uploadResult: const {
          'stored': 0,
          'skipped': 0,
          'failed': ['june.pdf'],
          'rejected': [],
        },
      );

      await tester.tap(find.text('ADD FILES'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('AI IS READING…'), findsOneWidget);
      await tester.pump(timing.minReading);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ReadingScene), findsNothing);
      expect(find.text('No new invoices. Could not read june.pdf.'), findsOneWidget);
    });

    for (final size in const [Size(1180, 820), Size(1000, 600)]) {
      testWidgets('fits a window of ${size.width.toInt()} x ${size.height.toInt()}', (
        tester,
      ) async {
        text.useGoogleFonts = false;
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReadingScene(
                files: 1,
                timing: SceneTiming.instant,
                read: Invoice.fromJson(invoicesJson.first),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('READ BY AI · 96% SURE'), findsOneWidget);
      });
    }
  });

  test('the notice names what was left out', () {
    const result = IngestResult(
      stored: 0,
      skipped: 0,
      failed: ['blurry.jpg'],
      rejected: ['notes.docx'],
    );
    expect(
      uploadNotice(result),
      'No new invoices. Could not read blurry.jpg. '
      'Left out notes.docx (only PDF, PNG or JPG up to 10 MB).',
    );
  });

  for (final size in const [Size(1280, 888), Size(1180, 820), Size(1000, 600)]) {
    testWidgets('fits a window of ${size.width.toInt()} x ${size.height.toInt()}', (tester) async {
      await open(tester, 'EXPORT', size: size);
      expect(find.text('SHEETS (2)'), findsOneWidget);
    });
  }
}
