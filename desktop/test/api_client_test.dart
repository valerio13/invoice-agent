import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:invoice_agent/api/api_client.dart';

import 'fixtures.dart';

void main() {
  test('reads health and metrics', () async {
    final api = ApiClient(client: fakeBackend(), baseUrl: 'http://test');

    expect((await api.health()).demoMode, isTrue);
    final metrics = await api.metrics();
    expect(metrics.invoices, 38);
    expect(metrics.spendThisMonth, 9200.50);
    expect(metrics.spendByMonth.last.month, DateTime(2026, 11));
    expect(metrics.topSuppliers.first.supplier, 'Meridian Freight');
  });

  test('turns the detail of an error into the message', () async {
    final client = MockClient(
      (_) async => http.Response(jsonEncode({'detail': 'Demo mode is off.'}), 403),
    );
    final api = ApiClient(client: client, baseUrl: 'http://test');

    expect(
      api.loadDemo(),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Demo mode is off.')),
    );
  });

  test('says so when the backend cannot be reached', () async {
    final client = MockClient((_) async => throw const SocketLikeException());
    final api = ApiClient(client: client, baseUrl: 'http://test');

    expect(
      api.health(),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('Cannot reach'))),
    );
  });
}

class SocketLikeException implements Exception {
  const SocketLikeException();
}
