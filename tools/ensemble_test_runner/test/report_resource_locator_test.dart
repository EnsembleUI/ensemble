import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/reporters/src/report_resource_locator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ensemble_report_resources_');
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  test('resolves package resources from a workspace-relative root URI', () {
    final package = _createPackage(root, 'workspace/ensemble_test_runner');
    final config = _writeConfig(
      root,
      'app/.dart_tool/package_config.json',
      '../../workspace/ensemble_test_runner/',
    );

    expect(findReportResourceRoot([config]),
        package.uri.resolve('resources/report/'));
  });

  test('resolves package resources from a path dependency file URI', () {
    final package = _createPackage(root, 'path/ensemble_test_runner');
    final config = _writeConfig(
      root,
      'consumer/.dart_tool/package_config.json',
      package.uri.toString(),
    );

    expect(findReportResourceRoot([config]),
        package.uri.resolve('resources/report/'));
  });

  test('skips a stale config and resolves a Git-cache relative root URI', () {
    final package = _createPackage(root, '.pub-cache/git/ensemble-abc');
    final stale = _writeConfig(
      root,
      'consumer/.dart_tool/stale_package_config.json',
      '../missing/ensemble_test_runner/',
    );
    final git = _writeConfig(
      root,
      'consumer/.dart_tool/package_config.json',
      '../../.pub-cache/git/ensemble-abc/',
    );

    expect(findReportResourceRoot([stale, git]),
        package.uri.resolve('resources/report/'));
  });

  test('skips a non-file package root and resolves a later local config', () {
    final package = _createPackage(root, 'workspace/ensemble_test_runner');
    final remote = _writeConfig(
      root,
      'consumer/.dart_tool/remote_package_config.json',
      'https://example.invalid/ensemble_test_runner/',
    );
    final local = _writeConfig(
      root,
      'consumer/.dart_tool/package_config.json',
      '../../workspace/ensemble_test_runner/',
    );

    expect(findReportResourceRoot([remote, local]),
        package.uri.resolve('resources/report/'));
  });
}

Directory _createPackage(Directory root, String relativePath) {
  final package = Directory('${root.path}/$relativePath')
    ..createSync(recursive: true);
  final resources = Directory('${package.path}/resources/report')
    ..createSync(recursive: true);
  File('${resources.path}/report.css').writeAsStringSync('/* test */');
  File('${resources.path}/report.js').writeAsStringSync('// test');
  return package;
}

File _writeConfig(Directory root, String relativePath, String rootUri) {
  final config = File('${root.path}/$relativePath')
    ..parent.createSync(recursive: true);
  config.writeAsStringSync(jsonEncode({
    'configVersion': 2,
    'packages': [
      {
        'name': 'ensemble_test_runner',
        'rootUri': rootUri,
        'packageUri': 'lib/',
        'languageVersion': '3.5',
      },
    ],
  }));
  return config;
}
