import 'package:ensemble_test_runner/models/test_failure_details.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('execution codes retain the kernel failure category', () {
    expect(
      TestFailureDetails.fromExecutionCode(
        'elementNotFound',
        'Target lookup failed',
      ).kind,
      TestFailureKind.elementNotFound,
    );
    expect(
      TestFailureDetails.fromExecutionCode(
        'actionTimeout',
        'Operation exceeded its time limit',
      ).kind,
      TestFailureKind.incompleteExecution,
    );
    expect(
      TestFailureDetails.fromExecutionCode(
        'closeFailed',
        'Runtime close failed',
      ).kind,
      TestFailureKind.cleanup,
    );
  });

  test('kernel secondary diagnostics distinguish cleanup and subscriber faults',
      () {
    expect(
      TestFailureDetails.fromSecondaryMessage('Runtime close failed: closed')
          .kind,
      TestFailureKind.cleanup,
    );
    expect(
      TestFailureDetails.fromSecondaryMessage(
        'Event subscriber 1 failed: reporter failed',
      ).kind,
      TestFailureKind.internal,
    );
  });
}
