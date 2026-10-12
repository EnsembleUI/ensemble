import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('does not allocate widget storage before a channel needs it', () {
    expect(EnsembleTestHarness.testStoragePathCreatedForTest, isFalse);
  });
}
