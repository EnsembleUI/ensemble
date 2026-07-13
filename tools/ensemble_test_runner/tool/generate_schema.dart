import 'dart:io';

import 'package:ensemble_test_runner/schema/ensemble_test_schema_builder.dart';

/// Regenerates JSON Schemas from the step registry.
///
/// Run from this package:
///   dart run tool/generate_schema.dart
void main() {
  final packageRoot = Directory.current;
  if (!File('${packageRoot.path}/pubspec.yaml').existsSync()) {
    stderr.writeln('Run from tools/ensemble_test_runner');
    exit(1);
  }

  final outFile = File('assets/schema/ensemble_tests_schema.json');
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync('${EnsembleTestSchemaBuilder.buildJson()}\n');
  stdout.writeln('Wrote ${outFile.path}');

  final configOutFile = File('assets/schema/ensemble_test_config_schema.json');
  configOutFile.parent.createSync(recursive: true);
  configOutFile.writeAsStringSync(
    '${EnsembleTestSchemaBuilder.buildConfigJson()}\n',
  );
  stdout.writeln('Wrote ${configOutFile.path}');
}
