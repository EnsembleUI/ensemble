import 'dart:ui' as ui;

import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('visual report artifacts detach into one stable snapshot',
      (tester) async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(Colors.black, ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(1, 1);
    picture.dispose();

    final frame = ScreenshotSheetFrame(
      stepIndex: 2,
      label: 'tap(target)',
      image: image,
    );
    final observer = StepObserverArtifact(
      stepIndex: 2,
      elements: const [],
      observationJson: const {},
    );
    final state = TestRuntimeState()
      ..screenshotSheetFrames.add(frame)
      ..stepObservers.add(observer);

    final artifacts = state.takeScreenshotArtifacts();

    expect(artifacts.frames, [same(frame)]);
    expect(artifacts.stepObservers, [same(observer)]);
    expect(state.screenshotSheetFrames, isEmpty);
    expect(state.stepObservers, isEmpty);

    state.screenshotSheetFrames.add(frame);
    state.stepObservers.add(observer);
    expect(artifacts.frames, hasLength(1));
    expect(artifacts.stepObservers, hasLength(1));
    state.screenshotSheetFrames.clear();
    state.stepObservers.clear();
    image.dispose();
  });
}
