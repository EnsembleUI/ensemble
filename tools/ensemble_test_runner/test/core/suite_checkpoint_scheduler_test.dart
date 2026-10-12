import 'package:ensemble_test_runner/src/core/suite_checkpoint_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unknown dependencies do not block suite execution', () {
    final scheduler = SuiteCheckpointScheduler<Object>();

    expect(scheduler.dependencyFailed('missing'), isFalse);
    expect(scheduler.checkpointFor('missing'), isNull);
  });

  test('failed result blocks its dependent and has no checkpoint by default',
      () {
    final scheduler = SuiteCheckpointScheduler<Object>();
    scheduler.recordResult('setup', failed: true);

    expect(scheduler.dependencyFailed('setup'), isTrue);
    expect(scheduler.checkpointFor('setup'), isNull);
  });

  test(
      'successful result permits dependency and makes its checkpoint available',
      () {
    final scheduler = SuiteCheckpointScheduler<Object>();
    final checkpoint = Object();
    scheduler.recordCheckpoint('setup', checkpoint);
    scheduler.recordResult('setup', failed: false);

    expect(scheduler.dependencyFailed('setup'), isFalse);
    expect(identical(scheduler.checkpointFor('setup'), checkpoint), isTrue);
  });

  test('failed result invalidates a checkpoint captured before completion', () {
    final scheduler = SuiteCheckpointScheduler<Object>();
    final checkpoint = Object();

    scheduler.recordCheckpoint('setup', checkpoint);
    scheduler.recordResult('setup', failed: true);

    expect(scheduler.checkpointFor('setup'), isNull);
  });

  test('failed producer cannot publish a late checkpoint', () {
    final scheduler = SuiteCheckpointScheduler<Object>();
    scheduler.recordResult('setup', failed: true);

    expect(
      () => scheduler.recordCheckpoint('setup', Object()),
      throwsStateError,
    );
    expect(scheduler.checkpointFor('setup'), isNull);
  });
}
