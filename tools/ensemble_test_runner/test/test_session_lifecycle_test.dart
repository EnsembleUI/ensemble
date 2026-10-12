import 'dart:async';

import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble_test_runner/runner/test_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('navigation recorder awaits cancellation and disposes idempotently',
      () async {
    var cancelled = false;
    final changes = StreamController<VisibleScreen?>.broadcast(
      onCancel: () => cancelled = true,
    );
    final recorder =
        NavigationFlowRecorder(screenChanges: () => changes.stream);

    await recorder.startListeningWhenReady();
    expect(changes.hasListener, isTrue);

    await recorder.dispose();

    expect(cancelled, isTrue);
    expect(changes.hasListener, isFalse);
    expect(recorder.flow, isEmpty);
    await recorder.dispose();
    await changes.close();
  });

  test('overlapping teardown callers share the cancellation future', () async {
    final cancellationStarted = Completer<void>();
    final changes = StreamController<VisibleScreen?>.broadcast(
      onCancel: () {
        cancellationStarted.complete();
      },
    );
    final recorder =
        NavigationFlowRecorder(screenChanges: () => changes.stream);
    await recorder.startListeningWhenReady();

    final first = recorder.dispose();
    await cancellationStarted.future;
    final second = recorder.dispose();
    await Future.wait([first, second]);
    expect(changes.hasListener, isFalse);
    await changes.close();
  });
}
