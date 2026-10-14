import 'dart:async';

import 'package:ensemble_test_runner/src/core/step_capture_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StepCaptureGuard', () {
    test('allows only one successful capture for a step', () async {
      final guard = StepCaptureGuard();
      var captures = 0;

      expect(
          await guard.capture(() async {
            captures++;
            return true;
          }),
          isTrue);
      expect(
          await guard.capture(() async {
            captures++;
            return true;
          }),
          isFalse);

      expect(captures, 1);
      expect(guard.captured, isTrue);
    });

    test('permits a later boundary to retry a failed capture', () async {
      final guard = StepCaptureGuard();
      var captures = 0;

      expect(
          await guard.capture(() async {
            captures++;
            return false;
          }),
          isFalse);
      expect(
          await guard.capture(() async {
            captures++;
            return true;
          }),
          isTrue);

      expect(captures, 2);
      expect(guard.captured, isTrue);
    });

    test('can adopt a frame captured at an earlier boundary', () async {
      final guard = StepCaptureGuard()..markCaptured();
      var captures = 0;

      expect(
          await guard.capture(() async {
            captures++;
            return true;
          }),
          isFalse);
      expect(captures, 0);
    });

    test('coalesces concurrent boundaries for the same step', () async {
      final guard = StepCaptureGuard();
      final releaseCapture = Completer<bool>();
      var captures = 0;

      final first = guard.capture(() {
        captures++;
        return releaseCapture.future;
      });
      final second = guard.capture(() async {
        captures++;
        return true;
      });
      releaseCapture.complete(true);

      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(captures, 1);
    });
  });
}
