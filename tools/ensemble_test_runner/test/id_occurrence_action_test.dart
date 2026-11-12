import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/session/local/flutter_target_resolver.dart';
import 'package:ensemble_test_runner/session/local/observation_registry.dart';
import 'package:ensemble_test_runner/session/operation_target.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('wait and tap use the same repeated ID occurrence',
      (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Column(
              children: [
                KeyedSubtree(
                  key: const ValueKey('repeated_card'),
                  child: InkWell(
                    onTap: () => taps.add('first'),
                    child: const Text('First card'),
                  ),
                ),
              ],
            ),
            Column(
              children: [
                KeyedSubtree(
                  key: const ValueKey('repeated_card'),
                  child: InkWell(
                    onTap: () => taps.add('second'),
                    child: const Text('Second card'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ));

    final resolver = FlutterTargetResolver(
      tester: tester,
      assertions: AssertionEngine(tester: tester),
      registry: ObservationRegistry(),
    );
    const target = ElementTarget(
      locator: ElementLocator(id: 'repeated_card', occurrence: 1),
    );

    final visibleMatch = resolver.resolveFinder(
      target,
      requireInteractive: false,
    );
    expect(visibleMatch.evaluate(), hasLength(1));

    final tapMatch = resolver.resolveFinder(target);
    expect(tapMatch.evaluate(), hasLength(1));
    await tester.tap(tapMatch);
    expect(taps, ['second']);
  });
}
