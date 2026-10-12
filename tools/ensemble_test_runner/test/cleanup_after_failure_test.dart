import 'package:ensemble_test_runner/src/core/cleanup_after_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cleanup failure is reported without replacing body failure', () async {
    final bodyFailure = StateError('launch failed');
    final cleanupFailure = StateError('listener teardown failed');
    Object? reportedCleanupFailure;
    var cleanupCalls = 0;
    Object? thrown;

    try {
      await runWithCleanupPreservingPrimary<void>(
        body: () async => throw bodyFailure,
        cleanup: () async {
          cleanupCalls++;
          throw cleanupFailure;
        },
        onCleanupFailure: (error, _) => reportedCleanupFailure = error,
      );
    } catch (error) {
      thrown = error;
    }

    expect(thrown, same(bodyFailure));
    expect(reportedCleanupFailure, same(cleanupFailure));
    expect(cleanupCalls, 1);
  });

  test('diagnostic failure does not replace body failure', () async {
    final bodyFailure = StateError('launch failed');
    Object? thrown;

    try {
      await runWithCleanupPreservingPrimary<void>(
        body: () async => throw bodyFailure,
        cleanup: () async => throw StateError('cleanup failed'),
        onCleanupFailure: (_, __) => throw StateError('logger failed'),
      );
    } catch (error) {
      thrown = error;
    }

    expect(thrown, same(bodyFailure));
  });
}
