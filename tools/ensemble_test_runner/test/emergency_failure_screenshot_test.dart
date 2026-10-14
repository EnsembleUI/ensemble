import 'package:ensemble_test_runner/runner/emergency_failure_screenshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('failure frame shares stable report metadata', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('failure')));

    final frame = captureEmergencyFailureScreenshotFrame(
      tester: tester,
      deviceId: 'device-id',
      deviceLabel: 'Test device',
      platform: 'test-platform',
      model: 'test-model',
    );

    expect(frame.stepIndex, 0);
    expect(frame.label, 'Runner failure');
    expect(frame.image.width, greaterThan(0));
    expect(frame.image.height, greaterThan(0));
    expect(frame.deviceId, 'device-id');
    expect(frame.deviceLabel, 'Test device');
    expect(frame.platform, 'test-platform');
    expect(frame.model, 'test-model');
    frame.image.dispose();
  });
}
