import 'dart:io';

import 'package:ensemble_test_runner/execution/device_discovery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('discovers devices through the selected Flutter executable', () async {
    if (Platform.isWindows) return;

    final directory = await Directory.systemTemp.createTemp('flutter-device-');
    addTearDown(() => directory.delete(recursive: true));

    final executable = File('${directory.path}/flutter');
    await executable.writeAsString('''
#!/bin/sh
printf '%s\\n' '[{"id":"simulator-1","name":"iPhone 17","targetPlatform":"ios","emulator":true}]'
''');
    await Process.run('chmod', ['+x', executable.path]);

    final devices = await discoverFlutterDevices(executable: executable.path);

    expect(devices, hasLength(1));
    expect(devices.single.id, 'simulator-1');
    expect(devices.single.isIos, isTrue);
  });
}
