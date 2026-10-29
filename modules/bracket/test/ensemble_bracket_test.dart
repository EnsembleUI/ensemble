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

  test('bracketSnapPageOffset clamps trailing pages to reachable range', () {
    // 7 rounds at viewportFraction 0.4 in a 960pt viewport: content is 2688pt,
    // so maxScrollExtent is 1728. Page 6 maps to 2304 unclamped and page 5 to
    // 1920; both must clamp, or jumpTo() springs back (the "rapid throw").
    const viewport = 960.0;
    const fraction = 0.4;
    const max = 1728.0;

    expect(
      bracketSnapPageOffset(
        page: 6,
        viewportDimension: viewport,
        viewportFraction: fraction,
        minScrollExtent: 0,
        maxScrollExtent: max,
      ),
      max,
    );
    expect(
      bracketSnapPageOffset(
        page: 5,
        viewportDimension: viewport,
        viewportFraction: fraction,
        minScrollExtent: 0,
        maxScrollExtent: max,
      ),
      max,
    );
    // Reachable pages keep their exact offset.
    expect(
      bracketSnapPageOffset(
        page: 4,
        viewportDimension: viewport,
        viewportFraction: fraction,
        minScrollExtent: 0,
        maxScrollExtent: max,
      ),
      1536,
    );
    // viewportFraction > 1 keeps the centering initial offset.
    expect(
      bracketSnapPageOffset(
        page: 0,
        viewportDimension: 100,
        viewportFraction: 2,
        minScrollExtent: 0,
        maxScrollExtent: 1000,
      ),
      50,
    );
  });
}
