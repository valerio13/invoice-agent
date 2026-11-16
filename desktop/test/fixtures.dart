import 'dart:convert';

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

/// A backend that answers from memory. [requests] records what the app asked for.
MockClient fakeBackend({
  Map<String, Object?> metrics = metricsJson,
  bool demoMode = true,
  List<String>? requests,
}) => MockClient((request) async {
  final key = '${request.method} ${request.url.path}';
  requests?.add(key);
  final body = switch (key) {
    'GET /health' => {'status': 'ok', 'demo_mode': demoMode},
    'GET /metrics' => metrics,
    'POST /ingest/demo' => {'stored': 38, 'skipped': 0, 'failed': []},
    _ => null,
  };
  if (body == null) return http.Response(jsonEncode({'detail': 'Not found'}), 404);
  return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
});
