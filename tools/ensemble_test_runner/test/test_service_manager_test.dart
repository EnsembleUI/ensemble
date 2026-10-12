import 'dart:io';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/test_service_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('reports when the suite has no service processes to start', () {
    expect(TestServiceManager(const []).hasConfiguredServices, isFalse);
    expect(
      TestServiceManager([
        TestServiceConfig(name: 'service', command: 'unused'),
      ]).hasConfiguredServices,
      isTrue,
    );
  });

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
      // Suite teardown can be reached from both the Flutter test lifecycle
      // and the host boundary after a timeout. Overlapping calls must remain
      // safe and must share the child process stop operation.
      await Future.wait([manager.stopAll(), manager.stopAll()]);
      await temp.delete(recursive: true);
    }
  });

  test('stops subprocesses launched by a managed service', () async {
    if (Platform.isWindows) return;
    final temp = await Directory.systemTemp.createTemp('ensemble_service_tree');
    final pidFile = File('${temp.path}/child.pid');
    const script = r'sleep 600 & echo $! > "$1"; wait';
    final manager = TestServiceManager(
      [
        TestServiceConfig(
          name: 'treeService',
          command: '/bin/sh',
          arguments: ['-c', script, 'service', pidFile.path],
        ),
      ],
      artifactRoot: temp.path,
    );

    try {
      await manager.startAll();
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (!pidFile.existsSync() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(pidFile.existsSync(), isTrue);
      final childPid = int.parse(pidFile.readAsStringSync().trim());

      await manager.stopAll();

      final liveness =
          await Process.run('ps', ['-p', '$childPid', '-o', 'pid=']);
      expect((liveness.stdout as String).trim(), isEmpty);
    } finally {
      await manager.stopAll();
      await temp.delete(recursive: true);
    }
  });
}
