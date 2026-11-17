import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Where the backend listens. Change it with --dart-define=API_URL=http://127.0.0.1:8000
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://127.0.0.1:8000');

/// The backend answered with an error, or could not be reached.
class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Talks to the backend REST API. It holds no logic: every decision is made by the backend.
class ApiClient {
  ApiClient({http.Client? client, String baseUrl = apiUrl})
    : _client = client ?? http.Client(),
      _base = Uri.parse(baseUrl);

  final http.Client _client;
  final Uri _base;

  Future<Health> health() async => Health.fromJson(await _json('GET', '/health'));

  Future<Metrics> metrics() async => Metrics.fromJson(await _json('GET', '/metrics'));

  /// Every stored invoice, newest first. Filtering is done on screen.
  Future<List<Invoice>> invoices() async => [
    for (final item in await _jsonList('GET', '/invoices'))
      Invoice.fromJson(item as Map<String, dynamic>),
  ];

  Future<IngestResult> loadDemo() async =>
      IngestResult.fromJson(await _json('POST', '/ingest/demo'));

  /// The first page of the document as an image (PNG for a PDF).
  Future<Uint8List> preview(int invoiceId) async =>
      (await _request('GET', '/invoices/$invoiceId/preview')).bodyBytes;

  /// Store the reviewer's fields. With [approve] the invoice becomes ok; without it the backend
  /// checks the new fields again. The backend validates them and says what is wrong.
  Future<Invoice> review(int invoiceId, InvoiceFields fields, {required bool approve}) async =>
      Invoice.fromJson(
        await _json(
          'PUT',
          '/invoices/$invoiceId',
          body: {'fields': fields.toJson(), 'approve': approve},
        ),
      );

  Future<Invoice> markDuplicate(int invoiceId) async =>
      Invoice.fromJson(await _json('POST', '/invoices/$invoiceId/duplicate'));

  Future<Map<String, dynamic>> _json(String method, String path, {Object? body}) async =>
      jsonDecode(utf8.decode((await _request(method, path, body: body)).bodyBytes))
          as Map<String, dynamic>;

  Future<List<dynamic>> _jsonList(String method, String path) async =>
      jsonDecode(utf8.decode((await _request(method, path)).bodyBytes)) as List<dynamic>;

  Future<http.Response> _request(String method, String path, {Object? body}) async {
    final request = http.Request(method, _base.resolve(path));
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final http.Response response;
    try {
      response = await _client.send(request).then(http.Response.fromStream);
    } on Exception {
      throw ApiException('Cannot reach the backend at $_base. Start it and try again.');
    }
    if (response.statusCode >= 400) {
      final detail = _detail(utf8.decode(response.bodyBytes, allowMalformed: true));
      throw ApiException(detail ?? 'The backend answered ${response.statusCode}.');
    }
    return response;
  }

  /// The sentence the backend puts in "detail". A validation error is a list, one per field.
  static String? _detail(String body) {
    try {
      final detail = (jsonDecode(body) as Map<String, dynamic>)['detail'];
      if (detail is String) return detail;
      if (detail is List) {
        return detail
            .whereType<Map<String, dynamic>>()
            .map((error) {
              final field = (error['loc'] as List?)?.last;
              return field is String
                  ? '${fieldLabels[field] ?? field}: ${error['msg']}'
                  : error['msg'];
            })
            .join('\n');
      }
      return null;
    } on FormatException {
      return null;
    }
  }
}
