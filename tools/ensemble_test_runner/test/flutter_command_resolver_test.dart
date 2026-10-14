import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/cli/flutter_command_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the Flutter SDK recorded by the package graph', () {
    final root = Directory.systemTemp.createTempSync('flutter_resolver_');
    addTearDown(() => root.deleteSync(recursive: true));
    final sdk = Directory('${root.path}/sdk')..createSync(recursive: true);
    final packageRoot = Directory('${sdk.path}/packages/flutter')
      ..createSync(recursive: true);
    final executable = File('${sdk.path}/bin/flutter')
      ..createSync(recursive: true);
    final config = File('${root.path}/.dart_tool/package_config.json')
      ..createSync(recursive: true);
    config.writeAsStringSync(jsonEncode({
      'configVersion': 2,
      'packages': [
        {'name': 'flutter', 'rootUri': packageRoot.uri.toString()},
      ],
    }));

    expect(resolveFlutterExecutable(root.path, fallback: 'fallback'),
        executable.path);
  });

  test('falls back when no usable package graph exists', () {
    final root = Directory.systemTemp.createTempSync('flutter_resolver_');
    addTearDown(() => root.deleteSync(recursive: true));
    expect(
        resolveFlutterExecutable(root.path, fallback: 'fallback'), 'fallback');
  });
}
