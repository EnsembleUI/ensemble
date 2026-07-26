import 'dart:io';

import 'package:ensemble_test_runner/schema/ensemble_test_schema_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('committed schema matches generator output', () {
    final schemas = {
      'assets/schema/ensemble_tests_schema.json':
          EnsembleTestSchemaBuilder.buildJson(),
      'assets/schema/ensemble_test_config_schema.json':
          EnsembleTestSchemaBuilder.buildConfigJson(),
    };

    for (final entry in schemas.entries) {
      final committed = File(entry.key).readAsStringSync().trim();
      final generated = entry.value.trim();
      expect(
        committed,
        generated,
        reason:
            'Run: cd tools/ensemble_test_runner && dart run tool/generate_schema.dart',
      );
    }
  });
}
