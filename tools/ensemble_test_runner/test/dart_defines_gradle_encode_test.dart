import 'dart:convert';

import 'package:ensemble_test_runner/execution/remote/native_build_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encodeDartDefinesForGradle matches flutter_tools per-define base64', () {
    final pairs = [
      'ensembleTestExecutionMode=integration',
      'ensembleTestArtifactRoot=${AndroidFtlPackager.onDeviceArtifactRoot}',
    ];
    final encoded = encodeDartDefinesForGradle(pairs);
    expect(
      encoded,
      pairs.map((p) => base64Encode(utf8.encode(p))).join(','),
    );
    final wrong = base64Encode(utf8.encode(pairs.join(',')));
    expect(encoded, isNot(wrong));
  });
}
