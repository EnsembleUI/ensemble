import 'package:ensemble_bracket/ensemble_bracket.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PageController recreation with no rounds is safe',
      (tester) async {
    final initialController = BracketController();
    final updatedController = BracketController();
    updatedController.setters()['scale']?.call(0.5);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BracketsView(data: const [], controller: initialController),
      ),
    ));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BracketsView(data: const [], controller: updatedController),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
