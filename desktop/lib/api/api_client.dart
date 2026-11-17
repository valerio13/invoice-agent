import 'dart:convert';

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

  Future<Map<String, dynamic>> _json(String method, String path) async =>
      await _send(method, path) as Map<String, dynamic>;

  Future<List<dynamic>> _jsonList(String method, String path) async =>
      await _send(method, path) as List<dynamic>;

  Future<Object?> _send(String method, String path) async {
    final http.Response response;
    try {
      response = await _client
          .send(http.Request(method, _base.resolve(path)))
          .then(http.Response.fromStream);
    } on Exception {
      throw ApiException('Cannot reach the backend at $_base. Start it and try again.');
    }
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode >= 400) {
      throw ApiException(_detail(body) ?? 'The backend answered ${response.statusCode}.');
    }
    return jsonDecode(body);
  }

  /// The sentence the backend puts in "detail", when there is one.
  static String? _detail(String body) {
    try {
      final detail = (jsonDecode(body) as Map<String, dynamic>)['detail'];
      return detail is String ? detail : null;
    } on FormatException {
      return null;
    }
  }
}
