import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/session_capabilities.dart';
import 'package:ensemble_test_runner/src/core/plan.dart';
import 'package:ensemble_test_runner/src/core/operation_registry.dart';
import 'package:ensemble_test_runner/src/core/plan_wire_transport.dart';
import 'package:ensemble_test_runner/src/runtime/compiled_plan.dart';
import 'package:ensemble_test_runner/src/runtime/flutter_test_runtime.dart';
import 'package:ensemble_test_runner/src/runtime/operation_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'compiled operations match every production runtime handler route',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Text('Home')));
      final session = LocalTestExecutionSession.attach(
        tester: tester,
        context: EnsembleTestContext(
          testCase: const EnsembleTestCase(id: 'registry-parity', steps: []),
          apiOverlay: TestApiProviderOverlay(mocks: const {}),
          logger: TestLogger(),
          setup: const EnsembleTestSetup(),
        ),
        permissions: SessionPermissions.testController,
      );

      // Construction validates that FlutterTestRuntime supplies a handler
      // for every descriptor key, including specialized overrides.
      final runtime = FlutterTestRuntime(session);
      final compiler = CompiledPlanCompiler();

      void expectRoutesMatch(
        OperationDescriptor descriptor,
        String authoredName,
      ) {
        final plan = compiler.compile(EnsembleTestCase(
          id: 'compiled-$authoredName',
          steps: [TestStep(type: authoredName, args: const {})],
          sourcePath: 'registry.test.yaml',
        ));
        final decodedPlan = ExecutionPlanWireTransport.decode(
          ExecutionPlanWireTransport.encode(plan),
        );
        final directOperation =
            plan.nodes.values.whereType<OperationNode>().single.operation;
        final wireOperation = decodedPlan.nodes.values
            .whereType<OperationNode>()
            .single
            .operation;

        for (final operation in [directOperation, wireOperation]) {
          expect(operation.name, descriptor.name, reason: authoredName);
          expect(operation.kind, descriptor.kind, reason: authoredName);
          expect(operation.handlerKey, descriptor.handlerKey,
              reason: authoredName);
          expect(runtime.capabilities.supports(operation), isTrue,
              reason: authoredName);
        }
        expect(wireOperation.input, directOperation.input,
            reason: '$authoredName wire input');
      }

      expect(
        runtime.capabilities.handlerKeys,
        operationRegistry.handlerKeys,
      );
      for (final descriptor in operationRegistry.descriptors) {
        expectRoutesMatch(descriptor, descriptor.name);
      }

      for (final descriptor in operationRegistry.descriptors) {
        for (final alias in descriptor.aliases) {
          expectRoutesMatch(descriptor, alias);
        }
      }

      await runtime.close();
    },
  );
}
