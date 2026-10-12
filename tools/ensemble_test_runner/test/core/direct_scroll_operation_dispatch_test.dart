import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/test_bootstrap.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/session_capabilities.dart';
import 'package:ensemble_test_runner/src/runtime/flutter_test_runtime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/session_operation.dart';

void main() {
  testWidgets('scroll and scrollUntilVisible dispatch directly',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView.builder(
          key: const ValueKey('scroll_target'),
          controller: controller,
          itemCount: 40,
          itemBuilder: (_, index) => SizedBox(
            height: 48,
            child: Text('Item $index', key: ValueKey('item_$index')),
          ),
        ),
      ),
    ));

    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'direct-scroll', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      permissions: SessionPermissions.testController,
    );
    final runtime = FlutterTestRuntime(session);
    final offsetsAtEvidence = <double>[];
    var conditionMatched = false;
    runtime.bindEvidenceBoundaryEmitter((_, operation) {
      offsetsAtEvidence.add(controller.offset);
      if (operation == 'scrollUntilVisible') {
        conditionMatched = true;
        expect(
          find.byKey(const ValueKey('item_25')).hitTestable(),
          findsOneWidget,
        );
      }
    });

    final scroll = await runtime.execute(sessionOperation(
      'scroll',
      input: const {'delta': -300},
    ));
    expect(scroll.succeeded, isTrue, reason: scroll.error);
    expect(offsetsAtEvidence, [0]);
    expect(controller.offset, greaterThan(0));

    final scrollUntilVisible = await runtime.execute(sessionOperation(
      'scrollUntilVisible',
      input: const {
        'id': 'item_25',
        'scrollableId': 'scroll_target',
        'timeoutMs': 1000,
      },
    ));
    expect(scrollUntilVisible.succeeded, isTrue,
        reason: scrollUntilVisible.error);
    expect(conditionMatched, isTrue);

    await runtime.close();
  });
}
