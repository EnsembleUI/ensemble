import 'package:ensemble_test_runner/src/runtime/compiled_plan.dart';
import 'package:ensemble_test_runner/src/core/plan.dart';
import 'package:ensemble_test_runner/src/core/plan_wire_transport.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reuses a successfully compiled plan across execution attempts', () {
    var compileCount = 0;
    final plan = ExecutionPlan(
      id: 'retry-case',
      start: 'end',
      nodes: const {'end': EndNode('end')},
    );
    final reuse = CompiledPlanReuse(() {
      compileCount++;
      return plan;
    });

    final attemptPlans = [
      for (var attempt = 0; attempt < 4; attempt++) reuse.plan
    ];

    expect(compileCount, 1);
    expect(attemptPlans, everyElement(same(plan)));
  });

  test('retries plan compilation after a failed compile', () {
    var compileCount = 0;
    final plan = ExecutionPlan(
      id: 'retry-case',
      start: 'end',
      nodes: const {'end': EndNode('end')},
    );
    final reuse = CompiledPlanReuse(() {
      compileCount++;
      if (compileCount == 1) throw const FormatException('invalid test');
      return plan;
    });

    expect(() => reuse.plan, throwsFormatException);
    expect(reuse.plan, same(plan));
    expect(compileCount, 2);
  });

  test('decodes a process hand-off payload once and reuses the plan', () {
    final plan = _plan('wire-case');
    final reuse = CompiledPlanReuse.fromWire(
      ExecutionPlanWireTransport.encode(plan),
      expectedId: plan.id,
    );

    expect(reuse.plan.toWire(), plan.toWire());
    expect(reuse.plan, same(reuse.plan));
  });

  test('rejects a process hand-off payload for another test', () {
    final payload = ExecutionPlanWireTransport.encode(_plan('other-case'));
    final reuse = CompiledPlanReuse.fromWire(payload, expectedId: 'selected');

    expect(() => reuse.plan, throwsFormatException);
  });

  test('batch compiles selected test plans before dispatch and retains them',
      () {
    final first = _testCase('first');
    final second = _testCase('second');
    final plans = <String, ExecutionPlan>{
      for (final test in [first, second]) test.id: _plan(test.id),
    };
    final compiledIds = <String>[];
    final batch = CompiledPlanBatch(
      [first, second],
      compile: (test) {
        compiledIds.add(test.id);
        return plans[test.id]!;
      },
    );

    expect(compiledIds, ['first', 'second']);
    // A suite may retry a case or revisit a dependency checkpoint. All
    // successful plans must still be compiled exactly once at the batch
    // boundary, regardless of how many execution attempts request them.
    for (var attempt = 0; attempt < 3; attempt++) {
      expect(batch.forTest('first').plan, same(plans['first']));
      expect(batch.forTest('second').plan, same(plans['second']));
    }
    expect(compiledIds, ['first', 'second']);
  });

  test('batch reuses serialized plans for selected tests', () {
    final first = _testCase('first');
    final second = _testCase('second');
    final plans = <String, ExecutionPlan>{
      'first': _plan('first'),
      'second': _plan('second'),
    };
    var compileCount = 0;
    final batch = CompiledPlanBatch(
      [first, second],
      compile: (_) {
        compileCount++;
        throw StateError('serialized plan should avoid compilation');
      },
      serializedPlans: {
        for (final entry in plans.entries)
          entry.key: ExecutionPlanWireTransport.encode(entry.value),
      },
    );

    expect(batch.forTest('first').plan.toWire(), plans['first']!.toWire());
    expect(batch.forTest('second').plan.toWire(), plans['second']!.toWire());
    expect(compileCount, 0);
  });

  test('batch rejects serialized plans for unselected tests', () {
    expect(
      () => CompiledPlanBatch(
        [_testCase('selected')],
        serializedPlans: {
          'other': ExecutionPlanWireTransport.encode(_plan('other')),
        },
      ),
      throwsArgumentError,
    );
  });

  test('batch compile failures remain retryable for the affected test', () {
    final test = _testCase('invalid');
    var compileCount = 0;
    final plan = _plan(test.id);
    final batch = CompiledPlanBatch(
      [test],
      compile: (_) {
        compileCount++;
        if (compileCount == 1) throw const FormatException('retry compile');
        return plan;
      },
    );

    expect(compileCount, 1);
    expect(batch.forTest(test.id).plan, same(plan));
    expect(compileCount, 2);
  });
}

EnsembleTestCase _testCase(String id) => EnsembleTestCase(
      id: id,
      steps: const [TestStep(type: 'tap', args: {})],
    );

ExecutionPlan _plan(String id) => ExecutionPlan(
      id: id,
      start: 'end',
      nodes: const {'end': EndNode('end')},
    );
