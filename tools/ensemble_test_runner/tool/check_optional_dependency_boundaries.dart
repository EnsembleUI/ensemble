// Dart 3.8 reports deprecated_member_use at RegExp construction sites even though
// the deprecation is specifically about implementing RegExp. Keep construction compatible
// with this SDK without suppressing diagnostics in unrelated files.
// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Verifies that optional runtime integrations stay behind their adapters.
///
/// This is deliberately a source graph check. It runs without Flutter and
/// catches dependency leakage before an integration package becomes part of
/// the execution path by accident.
void main() {
  final rules = <String, List<String>>{
    'ensemble_device_preview': const [
      'lib/src/integrations/device_preview/device_preview_adapter.dart',
    ],
    'image': const ['lib/runner/screenshot_contact_sheet.dart'],
    'http': const [
      'lib/actions/http_request_action.dart',
      'lib/runner/test_service_manager.dart',
    ],
    'get_it': const [
      'lib/mocks/live_sign_in_with_custom_token.dart',
      'lib/mocks/wifi_test_setup.dart',
    ],
    'sqflite_common_ffi': const [
      'lib/reporters/ensemble_test_history_store.dart',
    ],
    'firebase_core': const ['lib/mocks/'],
    'firebase_core_platform_interface': const ['lib/mocks/'],
    'firebase_auth_platform_interface': const ['lib/mocks/'],
    'cloud_functions_platform_interface': const ['lib/mocks/'],
    'cloud_firestore_platform_interface': const ['lib/mocks/'],
  };
  final jsonOutput =
      const String.fromEnvironment('optionalBoundaryJson') == 'true';
  final violations = <String>[];
  final importsByPackage = <String, Set<String>>{};
  var dartFiles = 0;
  final importPattern = RegExp(
    r'''(?:import|export|part)\s+['"]package:([^/'"]+)(?:/[^'"]*)?['"]''',
  );

  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    dartFiles++;
    final relative = p.relative(entity.path, from: Directory.current.path);
    final source = entity.readAsStringSync();
    for (final match in importPattern.allMatches(source)) {
      final package = match.group(1)!;
      importsByPackage.putIfAbsent(package, () => <String>{}).add(relative);
      final allowed = rules[package];
      if (allowed == null ||
          allowed.any(
              (prefix) => relative == prefix || relative.startsWith(prefix))) {
        continue;
      }
      violations.add('$relative imports package:$package');
    }
  }

  if (jsonOutput) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert({
      'dartFiles': dartFiles,
      'optionalPackages': {
        for (final package in rules.keys.toList()..sort())
          package: {
            'imports': (importsByPackage[package] ?? const <String>{}).toList()
              ..sort(),
            'allowedPrefixes': rules[package],
          },
      },
      'violations': violations,
    }));
  }

  if (violations.isNotEmpty) {
    stderr.writeln('Optional dependency boundary violated:');
    for (final violation in violations) {
      stderr.writeln('  $violation');
    }
    exitCode = 1;
    return;
  }
  if (!jsonOutput) {
    stdout
        .writeln('Optional dependency boundaries OK ($dartFiles Dart files).');
  }
}
