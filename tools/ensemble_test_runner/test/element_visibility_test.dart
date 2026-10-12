import 'package:ensemble_test_runner/session/local/element_visibility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reports rendered bounds and viewport visibility',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox(
            key: ValueKey('visible'),
            width: 40,
            height: 30,
          ),
        ),
      ),
    );

    final element = tester.element(find.byKey(const ValueKey('visible')));
    final bounds = boundsFor(element);

    expect(bounds, isNotNull);
    expect(bounds!.width, 40);
    expect(bounds.height, 30);
    expect(inViewport(tester, bounds), isTrue);
    expect(isElementGeometricallyVisible(element, tester), isTrue);
    expect(isUnderOffstageAncestor(element), isFalse);
  });

  testWidgets('rejects offstage and transparent elements', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Offstage(
                offstage: true,
                child: const SizedBox(
                  key: ValueKey('offstage'),
                  width: 40,
                  height: 30,
                ),
              ),
              const Opacity(
                opacity: 0,
                child: SizedBox(
                  key: ValueKey('transparent'),
                  width: 40,
                  height: 30,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final offstage = tester.element(
      find.byKey(const ValueKey('offstage'), skipOffstage: false),
    );
    final transparent =
        tester.element(find.byKey(const ValueKey('transparent')));

    expect(isUnderOffstageAncestor(offstage), isTrue);
    expect(isElementGeometricallyVisible(offstage, tester), isFalse);
    expect(effectiveElementOpacity(transparent), 0);
    expect(isElementGeometricallyVisible(transparent, tester), isFalse);
  });
}
