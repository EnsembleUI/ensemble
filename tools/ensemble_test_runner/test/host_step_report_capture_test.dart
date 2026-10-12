import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/entry/application_test_entry_support.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'excluded host step skips capture setup and benchmark spans',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Text('fixture')));
      final context = EnsembleTestContext.fromTestCase(
        const EnsembleTestCase(id: 'fixture', steps: []),
        config: const EnsembleTestConfig(
          screenshots: ScreenshotConfig(
            enabled: true,
            excludeSteps: ['tap'],
          ),
        ),
      );
      final assertions = AssertionEngine(tester: tester, context: context);
      final executor = TestStepExecutor(
        tester: tester,
        context: context,
        assertions: assertions,
      );
      final session = LocalTestExecutionSession.attach(
        tester: tester,
        context: context,
        assertions: assertions,
        executor: executor,
      );
      final collector = BenchmarkCollector(
        caseId: 'excluded-host-capture',
        sample: 0,
        processId: 'test',
      );

      try {
        final didCapture = await RunnerBenchmark.collect(
          collector,
          () => captureHostStepReportArtifactsSafely(
            tester: tester,
            context: context,
            session: session,
            step: const TestStep(type: 'tap', args: {'id': 'target'}),
            stepIndex: 0,
            secondaryFailures: [],
          ),
        );

        expect(didCapture, isFalse);
        expect(collector.spans, isEmpty);
        expect(context.runtime.screenshotSheetFrames, isEmpty);
      } finally {
        await session.close();
      }
    },
  );
}
