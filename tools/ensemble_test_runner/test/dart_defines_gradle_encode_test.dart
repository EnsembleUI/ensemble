import 'dart:convert';

import 'package:ensemble_test_runner/execution/remote/native_build_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encodeDartDefinesForGradle matches flutter_tools per-define base64', () {
    final encoded = encodeDartDefinesForGradle(const [
      'ensembleTestExecutionMode=integration',
      'ensembleTestArtifactRoot=/data/local/tmp/ensemble_test_remote',
    ]);
    expect(
      encoded,
      'ZW5zZW1ibGVUZXN0RXhlY3V0aW9uTW9kZT1pbnRlZ3JhdGlvbg==,'
      'ZW5zZW1ibGVUZXN0QXJ0aWZhY3RSb290PS9kYXRhL2xvY2FsL3RtcC9lbnNlbWJsZV90ZXN0X3JlbW90ZQ==',
    );
    // Wrong joined-then-base64 form must not be used.
    final wrong = base64Encode(
      utf8.encode(
        'ensembleTestExecutionMode=integration,'
        'ensembleTestArtifactRoot=/data/local/tmp/ensemble_test_remote',
      ),
    );
    expect(encoded, isNot(wrong));
  });
}
