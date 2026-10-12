import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/src/core/compiler.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:ensemble_test_runner/src/runtime/compiled_plan.dart';
import 'package:ensemble_test_runner/src/runtime/operation_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejects child steps attached to a regular operation', () {
    final compiler = CompiledPlanCompiler();
    final testCase = EnsembleTestCase(
      id: 'invalid_nested_operation',
      steps: [
        TestStep(
          type: 'tap',
          args: const {'id': 'parent'},
          nestedSteps: const [
            TestStep(type: 'tap', args: {'id': 'child'}),
          ],
        ),
      ],
    );

    expect(
      () => compiler.compile(testCase),
      throwsA(isA<FormatException>().having(
        (error) => error.message,
        'message',
        allOf(contains('steps[0]'), contains('cannot contain nested steps')),
      )),
    );
  });

  test('unknown operations retain their unknown-operation diagnostic', () {
    final compiler = PlanCompiler(operationRegistry);

    expect(
      () => compiler.compile('unknown_nested', [
        PlanStep(
          name: 'missingOperation',
          source: const SourceLocation('case', 'steps[0]'),
          children: [
            PlanStep(
              name: 'tap',
              input: const {'id': 'child'},
              source: const SourceLocation('case', 'steps[0].steps[0]'),
            ),
          ],
        ),
      ]),
      throwsA(isA<FormatException>().having(
        (error) => error.message,
        'message',
        contains('unknown step "missingOperation"'),
      )),
    );
  });
}
