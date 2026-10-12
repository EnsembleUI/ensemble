import 'package:ensemble_test_runner/src/core/attempt_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AttemptCoordinator', () {
    test('keeps retry outcome and aggregates attempts', () async {
      final executed = <int>[];
      final result = await AttemptCoordinator<_Outcome>(retries: 2).run(
        executeAttempt: (attempt) async {
          executed.add(attempt.number);
          return _Outcome(
            succeeded: attempt.number == 2,
            durationMs: attempt.number * 10,
            logs: ['attempt-${attempt.number}'],
          );
        },
        succeeded: (outcome) => outcome.succeeded,
        durationMs: (outcome) => outcome.durationMs,
        logs: (outcome) => outcome.logs,
      );

      expect(executed, [1, 2]);
      expect(result.attempts, 2);
      expect(result.retry, 2);
      expect(result.durationMs, 30);
      expect(result.outcome.succeeded, isTrue);
      expect(result.logsByAttempt, [
        ['attempt-1'],
        ['attempt-2'],
      ]);
    });

    test('returns final failed outcome after exhausting retries', () async {
      final executed = <int>[];
      final result = await AttemptCoordinator<_Outcome>(retries: 1).run(
        executeAttempt: (attempt) async {
          executed.add(attempt.number);
          return _Outcome(
            succeeded: false,
            durationMs: 7,
            logs: ['failure-${attempt.number}'],
          );
        },
        succeeded: (outcome) => outcome.succeeded,
        durationMs: (outcome) => outcome.durationMs,
        logs: (outcome) => outcome.logs,
      );

      expect(executed, [1, 2]);
      expect(result.attempts, 2);
      expect(result.durationMs, 14);
      expect(result.outcome.succeeded, isFalse);
      expect(result.logsByAttempt, [
        ['failure-1'],
        ['failure-2'],
      ]);
    });

    test('provides stable report number and driver index', () async {
      final descriptors = <AttemptDescriptor>[];
      await AttemptCoordinator<_Outcome>(retries: 2).run(
        executeAttempt: (attempt) async {
          descriptors.add(attempt);
          return const _Outcome(succeeded: true, durationMs: 1, logs: []);
        },
        succeeded: (outcome) => outcome.succeeded,
        durationMs: (outcome) => outcome.durationMs,
        logs: (outcome) => outcome.logs,
      );

      expect(descriptors.single.number, 1);
      expect(descriptors.single.index, 0);
      expect(descriptors.single.total, 3);
    });
  });
}

final class _Outcome {
  const _Outcome({
    required this.succeeded,
    required this.durationMs,
    required this.logs,
  });

  final bool succeeded;
  final int durationMs;
  final List<String> logs;
}
