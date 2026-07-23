import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/schema/ensemble_test_schema_builder.dart';

/// Regenerates JSON Schemas from the step registry and shared config defs.
///
/// Run from this package:
///   dart run tool/generate_schema.dart
void main() {
  final packageRoot = Directory.current;
  if (!File('${packageRoot.path}/pubspec.yaml').existsSync()) {
    stderr.writeln('Run from tools/ensemble_test_runner');
    exit(1);
  }

  final outputs = <String, String>{
    'assets/schema/ensemble_tests_schema.json':
        EnsembleTestSchemaBuilder.buildJson(),
    'assets/schema/ensemble_test_config_schema.json':
        EnsembleTestSchemaBuilder.buildConfigJson(),
  };

  for (final entry in outputs.entries) {
    final file = File(entry.key);
    file.parent.createSync(recursive: true);
    final content = '${entry.value.trim()}\n';
    file.writeAsStringSync(content);
    _verifyWrittenSchema(file: file, expected: content);
    stdout.writeln('Wrote ${file.path}');
  }
}

void _verifyWrittenSchema({
  required File file,
  required String expected,
}) {
  final written = file.readAsStringSync();
  if (written != expected) {
    stderr.writeln('Schema write verification failed for ${file.path}');
    exit(1);
  }

  final decoded = json.decode(expected);
  if (decoded is! Map) {
    stderr.writeln('Schema root must be a JSON object: ${file.path}');
    exit(1);
  }

  final defs = decoded['\$defs'];
  if (defs is! Map) {
    stderr.writeln('Schema must define \$defs: ${file.path}');
    exit(1);
  }

  if (file.path.endsWith('ensemble_test_config_schema.json')) {
    for (final key in ['mockResponse', 'inlineMocks', 'wifi']) {
      if (!defs.containsKey(key)) {
        stderr.writeln('Config schema missing \$defs/$key');
        exit(1);
      }
    }

    final mockResponse = defs['mockResponse'];
    if (mockResponse is Map) {
      final properties = mockResponse['properties'];
      if (properties is! Map || !properties.containsKey(r'$merge')) {
        stderr.writeln('Config schema mockResponse must include \$merge');
        exit(1);
      }
    }

    final inlineMocks = defs['inlineMocks'];
    if (inlineMocks is Map) {
      final properties = inlineMocks['properties'];
      if (properties is! Map || !properties.containsKey(r'$extends')) {
        stderr.writeln('Config schema inlineMocks must include \$extends');
        exit(1);
      }
    }
  }
}
