import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/mocks/real_network_http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('creates a real client under the widget-test HTTP override', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final responseReady = server.first;
    final responseFuture = responseReady.then((request) async {
      request.response
        ..statusCode = HttpStatus.ok
        ..write('live response');
      await request.response.close();
    });
    final client = createRealNetworkHttpClient();
    final uri = Uri(
      scheme: 'http',
      host: server.address.address,
      port: server.port,
    );

    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      await responseFuture;

      expect(response.statusCode, HttpStatus.ok);
      expect(body, 'live response');
    } finally {
      client.close(force: true);
      await server.close(force: true);
    }
  });

  testWidgets('package:http uses the real client inside tester.runAsync', (
    tester,
  ) async {
    final response = await tester.runAsync(() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final responseReady = server.first;
      final responseFuture = responseReady.then((request) async {
        request.response
          ..statusCode = HttpStatus.ok
          ..write('live response');
        await request.response.close();
      });
      final uri = Uri(
        scheme: 'http',
        host: server.address.address,
        port: server.port,
      );

      try {
        return await runWithRealNetworkHttpClient(() => http.get(uri));
      } finally {
        await responseFuture;
        await server.close(force: true);
      }
    });

    expect(response?.statusCode, HttpStatus.ok);
    expect(response?.body, 'live response');
  });
}
