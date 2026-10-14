import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/test_bootstrap.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/operation_target.dart';
import 'package:ensemble_test_runner/session/session_capabilities.dart';
import 'package:ensemble_test_runner/src/runtime/flutter_test_runtime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/session_operation.dart';

void main() {
  testWidgets('selectIndex and setSlider dispatch directly', (tester) async {
    var showOptions = false;
    String? selected;
    var idSliderValue = 0.1;
    var structuredSliderValue = 0.1;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          body: ListView(
            children: [
              TextButton(
                key: const ValueKey('select_by_id'),
                onPressed: () => setState(() => showOptions = true),
                child: const Text('Choose by id'),
              ),
              TextButton(
                key: const ValueKey('select_structured'),
                onPressed: () => setState(() => showOptions = true),
                child: const Text('Choose structurally'),
              ),
              if (showOptions) ...[
                ListTile(
                  title: const Text('First'),
                  onTap: () => setState(() => selected = 'First'),
                ),
                ListTile(
                  title: const Text('Second'),
                  onTap: () => setState(() => selected = 'Second'),
                ),
              ],
              KeyedSubtree(
                key: const ValueKey('slider_by_id'),
                child: Slider(
                  value: idSliderValue,
                  onChanged: (value) => setState(() => idSliderValue = value),
                ),
              ),
              KeyedSubtree(
                key: const ValueKey('slider_structured'),
                child: Slider(
                  value: structuredSliderValue,
                  onChanged: (value) =>
                      setState(() => structuredSliderValue = value),
                ),
              ),
            ],
          ),
        ),
      ),
    ));

    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase:
            const EnsembleTestCase(id: 'direct-special-controls', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      permissions: SessionPermissions.testController,
    );
    final runtime = FlutterTestRuntime(session);
    final evidenceStates = <String>[];
    runtime.bindEvidenceBoundaryEmitter((_, operation) {
      evidenceStates.add(
        '$operation:$selected:$idSliderValue:$structuredSliderValue',
      );
    });

    final selectById = await runtime.execute(sessionOperation(
      'selectIndex',
      input: const {'id': 'select_by_id', 'index': 1},
    ));
    expect(selectById.succeeded, isTrue, reason: selectById.error);
    expect(selected, 'Second');

    showOptions = false;
    await tester.pump();
    final selectStructured = await runtime.execute(actionOperation(
      'selectIndex',
      target: const ElementTarget(testId: 'select_structured'),
      input: const {'index': 1},
    ));
    expect(selectStructured.succeeded, isTrue, reason: selectStructured.error);
    expect(selected, 'Second');

    final setById = await runtime.execute(sessionOperation(
      'setSlider',
      input: const {'id': 'slider_by_id', 'value': 0.7},
    ));
    expect(setById.succeeded, isTrue, reason: setById.error);
    expect(idSliderValue, greaterThan(0.1));

    final setStructured = await runtime.execute(actionOperation(
      'setSlider',
      target: const ElementTarget(testId: 'slider_structured'),
      input: const {'value': 0.8},
    ));
    expect(setStructured.succeeded, isTrue, reason: setStructured.error);
    expect(structuredSliderValue, greaterThan(0.1));
    expect(
      evidenceStates,
      [
        'selectIndex:null:0.1:0.1',
        'selectIndex:Second:0.1:0.1',
        'setSlider:Second:0.1:0.1',
        'setSlider:Second:$idSliderValue:0.1',
      ],
    );

    await runtime.close();
  });
}
