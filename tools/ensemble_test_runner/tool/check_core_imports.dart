import 'dart:io';

/// Enforces the pure Dart dependency boundary within the single package.
void main() {
  final core = Directory('lib/src/core');
  if (!core.existsSync()) {
    stderr.writeln('Core directory not found: ${core.path}');
    exitCode = 2;
    return;
  }

  final violations = <String>[];
  final corePrefix = core.absolute.uri.path.endsWith('/')
      ? core.absolute.uri.path
      : '${core.absolute.uri.path}/';
  const allowedDartLibraries = {
    'dart:async',
    'dart:collection',
    'dart:convert',
    'dart:core',
    'dart:math',
    'dart:typed_data',
  };
  for (final file in core.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;
    final lines = file.readAsLinesSync();
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index].trim();
      final match = RegExp(r'''^(?:import|export|part)\s+['"]([^'"]+)['"]''')
          .firstMatch(line);
      if (match == null) continue;
      final uri = match.group(1)!;
      final relativeTarget =
          uri.contains(':') ? null : file.absolute.uri.resolve(uri).path;
      final allowed = allowedDartLibraries.contains(uri) ||
          uri.startsWith('package:ensemble_test_runner/src/core/') ||
          (relativeTarget != null && relativeTarget.startsWith(corePrefix));
      if (!allowed) {
        violations.add('${file.path}:${index + 1}: $uri');
      }
    }
  }

  if (violations.isNotEmpty) {
    stderr.writeln('Core import boundary violated:');
    for (final violation in violations) {
      stderr.writeln('  $violation');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln('Core import boundary OK.');
}
