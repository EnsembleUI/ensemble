import 'dart:ui' as ui;

import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/runner/step_visual_snapshot.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:ensemble_test_runner/session/observation/ui_observation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('screenshot and Observer freeze before queued route change',
      (tester) async {
    tester.view.physicalSize = const Size(80, 80);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey<_SnapshotAppState>();
    await tester.pumpWidget(_SnapshotApp(key: key));
    key.currentState!.replaceAfterNextFrame();

    final snapshot = captureStepVisualSnapshot(
      tester: tester,
      assertions: AssertionEngine(tester: tester),
    );
    addTearDown(snapshot.image.dispose);

    final observation = snapshot.observerSnapshot!.observation;
    expect(_texts(observation), contains('Before'));
    expect(_texts(observation), isNot(contains('After')));

    final bytes = await tester.runAsync(
      () => snapshot.image.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    expect(bytes, isNotNull);
    final pixel = bytes!.buffer.asUint8List();
    final background = (40 * snapshot.image.width + 5) * 4;
    expect(pixel[background], greaterThan(200));
    expect(pixel[background + 1], lessThan(100));
    expect(pixel[background + 2], lessThan(100));

    await tester.pump();
    await tester.pump();
    expect(find.text('After'), findsOneWidget);
  });
}

Set<String> _texts(UiObservation observation) {
  final texts = <String>{};
  void visit(List<UiElement> elements) {
    for (final element in elements) {
      final text = element.text;
      if (text != null) texts.add(text);
      visit(element.children);
    }
  }

  visit(observation.elements);
  return texts;
}

class _SnapshotApp extends StatefulWidget {
  const _SnapshotApp({super.key});

  @override
  State<_SnapshotApp> createState() => _SnapshotAppState();
}

class _SnapshotAppState extends State<_SnapshotApp> {
  var _changed = false;

  void replaceAfterNextFrame() {
    WidgetsBinding.instance.scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _changed = true);
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          backgroundColor: _changed ? Colors.blue : Colors.red,
          body: Center(child: Text(_changed ? 'After' : 'Before')),
        ),
      );
}
