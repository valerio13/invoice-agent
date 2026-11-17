import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const metricsJson = {
  'invoices': 38,
  'ok': 31,
  'needs_review': 5,
  'duplicates': 2,
  'invoices_this_month': 6,
  'spend_this_month': '9200.50',
  'spend_last_month': '8000.00',
  'spend_by_month': [
    {'month': '2026-06-01', 'total': '7000.00'},
    {'month': '2026-07-01', 'total': '7500.00'},
    {'month': '2026-08-01', 'total': '6100.00'},
    {'month': '2026-09-01', 'total': '8800.00'},
    {'month': '2026-10-01', 'total': '8000.00'},
    {'month': '2026-11-01', 'total': '9200.50'},
  ],
  'suppliers': 8,
  'top_suppliers': [
    {'supplier': 'Meridian Freight', 'total': '4600.25'},
    {'supplier': 'Northlake Paper', 'total': '3000.00'},
  ],
};

const emptyMetricsJson = {
  'invoices': 0,
  'ok': 0,
  'needs_review': 0,
  'duplicates': 0,
  'invoices_this_month': 0,
  'spend_this_month': '0',
  'spend_last_month': '0',
  'spend_by_month': [
    {'month': '2026-11-01', 'total': '0'},
  ],
  'suppliers': 0,
  'top_suppliers': [],
};

Map<String, Object?> invoiceJson(
  int id,
  String supplier,
  String number,
  String date,
  String net,
  String total, {
  String status = 'ok',
  String file = 'invoice.pdf',
  List<String> reasons = const [],
  List<String> doubtful = const [],
}) => {
  'id': id,
  'file_name': file,
  'file_hash': 'h$id',
  'supplier': supplier,
  'invoice_number': number,
  'issue_date': date,
  'net_amount': net,
  'vat_rate': '21.00',
  'vat_amount': '0.00',
  'total': total,
  'currency': 'EUR',
  'confidence': 0.96,
  'status': status,
  'review_reasons': reasons,
  'approved': false,
  'doubtful_fields': doubtful,
  'created_at': '2026-11-16T10:00:00Z',
};

final invoicesJson = [
  invoiceJson(1, 'Northlake Paper', 'INV-2026-0412', '2026-11-12', '1240.00', '1500.40'),
  invoiceJson(
    2,
    'Brightwave Hosting',
    'BW-88217',
    '2026-11-09',
    '349.00',
    '432.29',
    status: 'needs_review',
    reasons: ['Net amount plus VAT is 422.29, but the total says 432.29.'],
    doubtful: ['total'],
  ),
  invoiceJson(
    3,
    'Meridian Freight',
    'MF/11/0093',
    '2026-11-05',
    '2180.00',
    '2398.00',
    file: 'mf.png',
  ),
  invoiceJson(
    4,
    'Northlake Paper',
    'INV-2026-0412',
    '2026-10-12',
    '1240.00',
    '1500.40',
    status: 'duplicate',
    reasons: ['Same supplier and invoice number as northlake.pdf.'],
  ),
];

/// A backend that answers from memory. [requests] records what the app asked for.
MockClient fakeBackend({
  Map<String, Object?> metrics = metricsJson,
  bool demoMode = true,
  List<Map<String, Object?>>? invoices,
  List<String>? requests,
  List<Object?>? bodies,
  String? reviewError,
}) => MockClient((request) async {
  final key = '${request.method} ${request.url.path}';
  requests?.add(key);
  if (request.body.isNotEmpty) bodies?.add(jsonDecode(request.body));
  final list = invoices ?? invoicesJson;
  final id = int.tryParse(request.url.pathSegments.length > 1 ? request.url.pathSegments[1] : '');
  if (key.endsWith('/preview')) return http.Response.bytes(onePixelPng, 200);
  if (request.method == 'PUT' && id != null) {
    if (reviewError != null) {
      return http.Response(jsonEncode({'detail': reviewError}), 422);
    }
    final invoice = list.firstWhere((item) => item['id'] == id);
    return http.Response(jsonEncode({...invoice, 'status': 'ok', 'approved': true}), 200);
  }
  if (key.endsWith('/duplicate') && id != null) {
    final invoice = list.firstWhere((item) => item['id'] == id);
    return http.Response(jsonEncode({...invoice, 'status': 'duplicate'}), 200);
  }
  final body = switch (key) {
    'GET /health' => {'status': 'ok', 'demo_mode': demoMode},
    'GET /metrics' => metrics,
    'GET /invoices' => list,
    'POST /ingest/demo' => {'stored': 38, 'skipped': 0, 'failed': []},
    _ => null,
  };
  if (body == null) {
    return http.Response(jsonEncode({'detail': 'Not found'}), 404);
  }
  return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
});

/// A valid 1 x 1 PNG, for the document preview.
final onePixelPng = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  ),
);
