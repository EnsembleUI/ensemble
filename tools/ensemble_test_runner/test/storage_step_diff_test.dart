import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:ensemble_test_runner/runner/storage_step_diff.dart';
import 'package:ensemble_test_runner/src/core/kernel.dart';
import 'package:ensemble_test_runner/src/runtime/compiled_plan.dart';
import 'package:ensemble_test_runner/src/core/execution_kernel_runner.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:ensemble_test_runner/src/core/runtime.dart';
import 'package:ensemble_test_runner/parser/ensemble_test_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disabled storage logging captures no snapshots', () async {
    final collector = BenchmarkCollector(
      caseId: 'disabled-storage',
      sample: 0,
      processId: 'test',
    );

    final snapshot = await RunnerBenchmark.collect(
      collector,
      () => captureStorageStepSnapshot(enabled: false),
    );

    expect(snapshot, isNull);
    expect(collector.spans, isEmpty);
  });

  test('storage subscriber captures and flushes each step once', () async {
    final recorded = <int, StorageStepSnapshot>{};
    var captures = 0;
    final snapshot = StorageStepSnapshot(
      publicValues: const {'before': 1},
      secureValues: const {},
      keychainValues: const {},
    );
    final subscriber = StorageStepDiffSubscriber(
      enabled: true,
      capture: () async {
        captures++;
        return snapshot;
      },
      recordDiff: (index, before) async => recorded[index] = before,
    );

    await subscriber.call(const ExecutionEvent(
      sequence: 1,
      kind: ExecutionEventKind.stepStarted,
      stepIndex: 3,
    ));
    await subscriber.flush(3);
    await subscriber.flush(3);

    expect(captures, 1);
    expect(recorded, {3: snapshot});
  });

  test('disabled storage subscriber does no capture or recording', () async {
    var captures = 0;
    var records = 0;
    final subscriber = StorageStepDiffSubscriber(
      enabled: false,
      capture: () async {
        captures++;
        return null;
      },
      recordDiff: (_, __) async => records++,
    );

    await subscriber.call(const ExecutionEvent(
      sequence: 1,
      kind: ExecutionEventKind.stepStarted,
      stepIndex: 0,
    ));
    await subscriber.flush(0);

    expect(captures, 0);
    expect(records, 0);
  });

  test('completed step event records the diff exactly once', () async {
    final snapshot = StorageStepSnapshot(
      publicValues: const {'before': 1},
      secureValues: const {},
      keychainValues: const {},
    );
    var captures = 0;
    final recorded = <int>[];
    final subscriber = StorageStepDiffSubscriber(
      enabled: true,
      capture: () async {
        captures++;
        return snapshot;
      },
      recordDiff: (stepIndex, before) async {
        recorded.add(stepIndex);
        expect(identical(before, snapshot), isTrue);
      },
    );

    await subscriber.call(const ExecutionEvent(
      sequence: 1,
      kind: ExecutionEventKind.stepStarted,
      stepIndex: 4,
    ));
    await subscriber.call(const ExecutionEvent(
      sequence: 2,
      kind: ExecutionEventKind.stepFinished,
      stepIndex: 4,
    ));
    await subscriber.flush(4);

    expect(captures, 1);
    expect(recorded, [4]);
  });

  test('attempt-finished event flushes interrupted steps exactly once',
      () async {
    final snapshot = StorageStepSnapshot(
      publicValues: const {'before': 'active'},
      secureValues: const {},
      keychainValues: const {},
    );
    final recorded = <int>[];
    final subscriber = StorageStepDiffSubscriber(
      enabled: true,
      capture: () async => snapshot,
      recordDiff: (stepIndex, _) async => recorded.add(stepIndex),
    );

    await subscriber.call(const ExecutionEvent(
      sequence: 1,
      kind: ExecutionEventKind.stepStarted,
      stepIndex: 6,
    ));
    await subscriber.call(const ExecutionEvent(
      sequence: 2,
      kind: ExecutionEventKind.attemptFinished,
      detail: 'failed',
    ));
    await subscriber.flush(6);

    expect(recorded, [6]);
  });

  test('kernel failure persists active storage diff through attempt events',
      () async {
    final testCase = EnsembleTestParser.parseString('''
id: interrupted_storage
startScreen: Home
steps:
  - tap: {id: save}
''');
    final plan = CompiledPlanCompiler().compile(testCase);
    final snapshot = StorageStepSnapshot(
      publicValues: const {'token': 'before'},
      secureValues: const {},
      keychainValues: const {},
    );
    final recorded = <int>[];
    final storage = StorageStepDiffSubscriber(
      enabled: true,
      capture: () async => snapshot,
      recordDiff: (stepIndex, before) async {
        expect(identical(before, snapshot), isTrue);
        recorded.add(stepIndex);
      },
    );
    final events = <ExecutionEvent>[];

    final result = await ExecutionKernelRunner(
      plan: plan,
      runtime: _FailingStorageRuntime(),
      eventSubscribers: [storage.call, events.add],
    ).run();

    expect(result.outcome, AttemptOutcome.failed);
    expect(
      events.map((event) => event.kind),
      containsAllInOrder([
        ExecutionEventKind.stepStarted,
        ExecutionEventKind.attemptFinished,
      ]),
    );
    expect(recorded, [0]);
  });

  group('diffStorage', () {
    test('detects added keys', () {
      final changes = diffStorage(
        {'a': 1},
        {'a': 1, 'b': 'new'},
      );
      expect(changes, hasLength(1));
      expect(changes.single.key, 'b');
      expect(changes.single.change, 'added');
      expect(changes.single.after, 'new');
      expect(changes.single.before, isNull);
    });

    test('detects modified keys', () {
      final changes = diffStorage(
        {
          'token': {'v': 1},
        },
        {
          'token': {'v': 2},
        },
      );
      expect(changes, hasLength(1));
      expect(changes.single.change, 'modified');
      expect(changes.single.before, {'v': 1});
      expect(changes.single.after, {'v': 2});
    });

    test('detects removed keys', () {
      final changes = diffStorage(
        {'gone': true, 'keep': 1},
        {'keep': 1},
      );
      expect(changes, hasLength(1));
      expect(changes.single.key, 'gone');
      expect(changes.single.change, 'removed');
      expect(changes.single.before, true);
    });

    test('returns empty when unchanged', () {
      expect(
        diffStorage(
          {
            'a': [1, 2],
          },
          {
            'a': [1, 2],
          },
        ),
        isEmpty,
      );
    });
  });
}

final class _FailingStorageRuntime implements TestRuntime {
  @override
  RuntimeCapabilities get capabilities =>
      RuntimeCapabilities({'interaction.tap'});

  @override
  Future<RuntimeView> observe(ObservationRequest request) async => RuntimeView(
        revision: 1,
        level: request.level,
        target: request.target,
        targetVisible: true,
      );

  @override
  Future<OperationResult> execute(TestOperation operation) async =>
      const OperationResult.failure(
        'simulated storage-writing operation failure',
        recoverable: false,
      );

  @override
  Future<void> close() async {}
}
