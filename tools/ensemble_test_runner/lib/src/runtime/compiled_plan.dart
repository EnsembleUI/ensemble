import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/src/runtime/operation_registry.dart';
import 'package:ensemble_test_runner/src/core/compiler.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:ensemble_test_runner/src/core/plan.dart';
import 'package:ensemble_test_runner/src/core/plan_wire_transport.dart';

/// Transition boundary from the current parser model to the compiled plan.
/// The core compiler has no dependency on the current parser or Flutter.
final class CompiledPlanCompiler {
  CompiledPlanCompiler() : _compiler = PlanCompiler(operationRegistry);

  final PlanCompiler _compiler;

  ExecutionPlan compile(EnsembleTestCase test) {
    return compileAs(test, test.id);
  }

  /// Compiles the same authored steps under an expanded worker id.
  ///
  /// Sharding expands scenario/profile/device dimensions at the scheduler
  /// boundary, while the parser model may retain the base test id. Keeping
  /// this override here avoids rebuilding a second parser representation just
  /// to give the wire plan the id the worker will execute.
  ExecutionPlan compileAs(EnsembleTestCase test, String id) {
    final path = test.sourcePath ?? '<memory>';
    return _compiler.compile(id, [
      for (var index = 0; index < test.steps.length; index++)
        _convert(test.steps[index], path, 'steps[$index]'),
    ]);
  }

  static PlanStep _convert(TestStep step, String path, String stepPath) {
    if (step.args.containsKey(resolvedMocksKey)) {
      throw FormatException(
          '$path:$stepPath uses reserved key "$resolvedMocksKey".');
    }
    final control = operationRegistry.isControl(step.type);
    return PlanStep(
      name: step.type,
      input: {
        for (final entry in step.args.entries)
          if (!control || (entry.key != 'steps' && entry.key != 'step'))
            entry.key: entry.value,
        if (step.type == 'mocks' && step.mocks.apis.isNotEmpty)
          resolvedMocksKey: {
            for (final entry in step.mocks.apis.entries)
              entry.key: _encodeResponse(entry.value),
          },
      },
      source: SourceLocation(path, stepPath),
      children: [
        for (var index = 0; index < step.nestedSteps.length; index++)
          _convert(step.nestedSteps[index], path, '$stepPath.steps[$index]'),
      ],
    );
  }

  static Map<String, Object?> _encodeResponse(MockAPIResponse response) => {
        'statusCode': response.statusCode,
        'body': response.body,
        if (response.headers != null) 'headers': response.headers,
        if (response.delayMs != null) 'delayMs': response.delayMs,
        if (response.responses.isNotEmpty)
          'responses': response.responses.map(_encodeResponse).toList(),
      };
}

/// Lazily compiles a test plan once and reuses it across execution attempts.
/// The value is assigned only after a successful compile, preserving retries
/// for invalid plans and keeping compilation inside each attempt's error path.
final class CompiledPlanReuse {
  CompiledPlanReuse(this._compile);

  /// Creates a reuse boundary for a plan received from another process.
  ///
  /// The payload is decoded lazily, just like a local compilation is. This
  /// keeps malformed hand-off data on the normal per-test error path and
  /// retains the existing retry behaviour for a failed first decode. The
  /// optional id check prevents a worker from accidentally executing a plan
  /// belonging to a different selected test.
  CompiledPlanReuse.fromWire(
    String payload, {
    String? expectedId,
  }) : this(() {
          final plan = ExecutionPlanWireTransport.decode(payload);
          if (expectedId != null && plan.id != expectedId) {
            throw FormatException(
              'Execution plan id "${plan.id}" does not match '
              'expected test id "$expectedId".',
            );
          }
          return plan;
        });

  // The compiler closure is needed only until the first successful plan is
  // produced. Releasing it matters for prepared batches: a closure otherwise
  // keeps the parser test case, inputs, and the compiler's temporary graph
  // reachable for the whole suite even though retries only need the plan.
  ExecutionPlan Function()? _compile;
  ExecutionPlan? _plan;

  ExecutionPlan get plan {
    final cached = _plan;
    if (cached != null) return cached;

    final compile = _compile;
    if (compile == null) {
      throw StateError('Compiled plan is unavailable.');
    }
    final compiled = compile();
    _plan = compiled;
    // Preserve retryability for failures while allowing successful plans to
    // drop the closure and everything captured by it immediately.
    _compile = null;
    return compiled;
  }
}

/// Compiles a selected batch before its first case is dispatched.
///
/// A failed compile is deliberately not retained: the case's normal attempt
/// path can retry compilation and report the error with its test result.
final class CompiledPlanBatch {
  CompiledPlanBatch(
    Iterable<EnsembleTestCase> tests, {
    ExecutionPlan Function(EnsembleTestCase test)? compile,
    Map<String, String> serializedPlans = const {},
  }) {
    final compileTest = compile ?? _compileTest;
    final selectedTests = tests.toList(growable: false);
    final selectedIds = selectedTests.map((test) => test.id).toSet();
    final unexpectedIds = serializedPlans.keys.toSet()..removeAll(selectedIds);
    if (unexpectedIds.isNotEmpty) {
      throw ArgumentError(
        'Serialized plans contain unselected test ids: '
        '${unexpectedIds.join(', ')}.',
      );
    }
    for (final test in selectedTests) {
      // A serialized plan is an explicit hand-off from the scheduler. Keep
      // compilation as the fallback for callers that have not crossed that
      // boundary yet. The id check prevents a stale or mis-sharded payload
      // from being applied to a different test with the same worker.
      final payload = serializedPlans[test.id];
      final reuse = payload == null
          ? CompiledPlanReuse(() => compileTest(test))
          : CompiledPlanReuse.fromWire(payload, expectedId: test.id);
      _plans[test.id] = reuse;
      try {
        reuse.plan;
      } on Object {
        // Keep the lazy retry path; invalid plans still fail per case.
      }
    }
  }

  final Map<String, CompiledPlanReuse> _plans = {};

  CompiledPlanReuse forTest(String id) {
    final plan = _plans[id];
    if (plan == null) throw StateError('No prepared plan for test "$id".');
    return plan;
  }

  static ExecutionPlan _compileTest(EnsembleTestCase test) =>
      CompiledPlanCompiler().compile(test);
}

/// Private wire field used only while replacing the current step executor.
const resolvedMocksKey = '__ensembleRunnerResolvedMocks';
