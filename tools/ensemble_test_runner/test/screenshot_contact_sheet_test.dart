import 'dart:io';
import 'dart:ui' as ui;

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/screenshot_contact_sheet.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  testWidgets('writes a passed sheet using only the test id', (tester) async {
    const testId = 'contact_sheet_passed_test';
    final legacyFile = File(
      'build/ensemble_test_runner/screenshots/${testId}_sheet.png',
    )..createSync(recursive: true);

    final image = await _testImage(color: Colors.blue);
    final path = await tester.runAsync(
      () => writeScreenshotContactSheet(
        testId: testId,
        config: const ScreenshotConfig(enabled: true),
        frames: [
          ScreenshotSheetFrame(
            stepIndex: 0,
            label: '1. tap(button)',
            image: image,
          ),
        ],
        status: TestStatus.passed,
        durationMs: 8421,
      ),
    );

    expect(path, endsWith('/$testId.png'));
    expect(path, isNot(contains('_sheet.png')));
    expect(legacyFile.existsSync(), isFalse);

    final sheet = img.decodePng(File(path!).readAsBytesSync())!;
    final accent = sheet.getPixel(20, 20);
    expect(accent.g, greaterThan(accent.r));

    // Copy to artifact directory for visual inspection
    final artifactFile = File('/Users/sharjeelyunus/Desktop/Ensemble/ensemble/generated_passed_sheet.png');
    artifactFile.writeAsBytesSync(File(path).readAsBytesSync());

    File(path).deleteSync();
  });

  testWidgets('marks a failed sheet and its failed step in red',
      (tester) async {
    const testId = 'contact_sheet_failed_test';
    final image = await _testImage(color: Colors.red);
    final path = await tester.runAsync(
      () => writeScreenshotContactSheet(
        testId: testId,
        config: const ScreenshotConfig(enabled: true),
        frames: [
          ScreenshotSheetFrame(
            stepIndex: 0,
            label: '1. tap(button)',
            image: image,
          ),
        ],
        status: TestStatus.failed,
        durationMs: 97321,
        failedStepIndex: 0,
        failedStepLabel: 'tap(button)',
        failureMessage: 'Expected button to be visible.',
      ),
    );

    final sheet = img.decodePng(File(path!).readAsBytesSync())!;
    final headerAccent = sheet.getPixel(20, 20);
    expect(headerAccent.r, greaterThan(headerAccent.g));

    const columns = 5;
    const tileWidth = 420;
    const gap = 16;
    const headerHeight = 220;
    final tileX =
        ((columns * tileWidth + (columns + 1) * gap - tileWidth) / 2).round();
    final tileBorder = sheet.getPixel(tileX, headerHeight + gap * 2);
    expect(tileBorder.r, greaterThan(tileBorder.g));

    // Copy to artifact directory for visual inspection
    final artifactFile = File('/Users/sharjeelyunus/Desktop/Ensemble/ensemble/generated_failed_sheet.png');
    artifactFile.writeAsBytesSync(File(path).readAsBytesSync());

    File(path).deleteSync();
  });

  testWidgets('writes a pending sheet with Amber RUNNING status and keeps frame images intact',
      (tester) async {
    const testId = 'contact_sheet_pending_test';
    final image = await _testImage(color: Colors.amber);
    final path = await tester.runAsync(
      () => writeScreenshotContactSheet(
        testId: testId,
        config: const ScreenshotConfig(enabled: true),
        frames: [
          ScreenshotSheetFrame(
            stepIndex: 0,
            label: '1. tap(button)',
            image: image,
          ),
        ],
        status: TestStatus.pending,
        durationMs: 0,
      ),
    );

    expect(path, endsWith('/$testId.png'));
    final sheet = img.decodePng(File(path!).readAsBytesSync())!;
    final headerAccent = sheet.getPixel(20, 20);
    expect(headerAccent.r, greaterThan(200));
    expect(headerAccent.g, greaterThan(140));

    // Verify image was NOT disposed during pending run
    expect(image.width, greaterThan(0));

    File(path).deleteSync();
    image.dispose();
  });
}

Future<ui.Image> _testImage({Color color = Colors.white}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 390, 844),
    Paint()..color = color,
  );
  // Draw some basic contents to look like a screen mock
  canvas.drawRect(
    const Rect.fromLTWH(20, 100, 350, 60),
    Paint()..color = Colors.grey.withOpacity(0.3),
  );
  canvas.drawRect(
    const Rect.fromLTWH(20, 200, 350, 400),
    Paint()..color = Colors.grey.withOpacity(0.1),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(390, 844);
  picture.dispose();
  return image;
}
