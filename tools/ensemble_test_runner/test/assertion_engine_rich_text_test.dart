import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('text assertions match visible RichText', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RichText(
            text: TextSpan(
              text: 'Connect a network cable',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ),
      ),
    );

    final assertions = AssertionEngine(tester: tester);

    expect(() => assertions.expectText('Connect a network cable'),
        returnsNormally);
    expect(
        () => assertions.expectTextContains('network cable'), returnsNormally);
  });

  testWidgets('text assertions ignore offstage RichText', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Offstage(
            offstage: true,
            child: RichText(
              text: TextSpan(
                text: 'Connect a network cable',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ),
        ),
      ),
    );

    final assertions = AssertionEngine(tester: tester);

    expect(
      () => assertions.expectText('Connect a network cable'),
      throwsA(isA<Exception>()),
    );
  });
}
