import 'package:ensemble_test_runner/assertions/assertion_target_diagnostics.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reports visible ids and nearest target matches', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Text('Welcome back'),
              SizedBox(key: ValueKey('login_button'), width: 10, height: 10),
              SizedBox(key: ValueKey('logout_button'), width: 10, height: 10),
            ],
          ),
        ),
      ),
    );

    final diagnostics = AssertionTargetDiagnostics(
      tester: tester,
      isVisuallyActionable: (_) => true,
    );

    expect(
      diagnostics.closestVisibleWidgetIds('login_buton'),
      contains('login_button'),
    );
    expect(
      diagnostics.visibleWidgetIdSummary(),
      'Visible widget ids: login_button, logout_button.',
    );
    expect(
      diagnostics.widgetIdFailureHint('login_buton'),
      contains('Closest visible ids: login_button.'),
    );
  });

  testWidgets('formats visible text diagnostics and validates candidates',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Welcome back')),
      ),
    );

    final diagnostics = AssertionTargetDiagnostics(
      tester: tester,
      isVisuallyActionable: (_) => true,
    );

    expect(
      diagnostics.visibleTextSummary(),
      'Visible text: "Welcome back".',
    );
    expect(
      diagnostics.textFailureHint(const ['Welcome']),
      contains('Visible text: "Welcome back".'),
    );
    expect(
      () => diagnostics.textFailureHint(const [' ', '']),
      throwsA(isA<EnsembleTestFailure>()),
    );
  });
}
