import 'dart:io';

import 'package:ensemble_test_runner/schema/ensemble_test_schema_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('committed schema matches generator output', () {
    final path = 'assets/schema/ensemble_tests_schema.json';
    final committed = File(path).readAsStringSync().trim();
    final generated = EnsembleTestSchemaBuilder.buildJson().trim();
    expect(
      committed,
      generated,
      reason:
          'Run: cd tools/ensemble_test_runner && dart run tool/generate_schema.dart',
    );
  });
}
