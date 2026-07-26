import 'dart:io';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/test_service_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('starts a service, waits for readiness, and stops it', () async {
    final portProbe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = portProbe.port;
    await portProbe.close();

    final temp = await Directory.systemTemp.createTemp('ensemble_service_test');
    final script = File('${temp.path}/server.dart');
    await script.writeAsString('''
import 'dart:io';
Future<void> main(List<String> args) async {
  final server = await HttpServer.bind(
    InternetAddress.loopbackIPv4,
    int.parse(Platform.environment['PORT']!),
  );
  await for (final request in server) {
    request.response.write('ready');
    await request.response.close();
  }
}
''');

    final manager = TestServiceManager([
      TestServiceConfig(
        name: 'testServer',
        command:
            '${Platform.environment['FLUTTER_ROOT']}/bin/cache/dart-sdk/bin/dart',
        arguments: [script.path],
        url: 'http://127.0.0.1:$port',
        readyUrl: '/',
      ),
    ]);

    try {
      await manager.startAll();
      final response = await http.get(Uri.parse('http://127.0.0.1:$port'));
      expect(response.body, 'ready');
    } finally {
      await manager.stopAll();
      await temp.delete(recursive: true);
    }
  });
}
