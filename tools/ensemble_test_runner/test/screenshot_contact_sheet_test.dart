import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/screenshot_contact_sheet.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('writes per-step PNGs and frames.json (no composite sheet)',
      (tester) async {
    const testId = 'contact_sheet_passed_test';
    final legacyFile = File(
      'build/ensemble_test_runner/screenshots/${testId}_sheet.png',
    )..createSync(recursive: true);
    final legacyComposite = File(
      'build/ensemble_test_runner/screenshots/$testId.png',
    )..createSync(recursive: true);

    final image = await _testImage(color: Colors.blue);
    final path = await tester.runAsync(
      () => writeScreenshotFrames(
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
      ),
    );

    expect(path, endsWith('/${testId}_frames.json'));
    expect(legacyFile.existsSync(), isFalse);
    expect(legacyComposite.existsSync(), isFalse);

    final framesManifest = File(
      'build/ensemble_test_runner/screenshots/${testId}_frames.json',
    );
    expect(framesManifest.existsSync(), isTrue);
    final framesJson =
        jsonDecode(framesManifest.readAsStringSync()) as Map<String, dynamic>;
    expect(framesJson['status'], 'passed');
    final frames = framesJson['frames'] as List<dynamic>;
    expect(frames, hasLength(1));
    expect(frames.single['stepIndex'], 0);
    expect(frames.single['file'], '${testId}_step0_0.png');
    expect(frames.single['failed'], isNull);
    final stepPng = File(
      'build/ensemble_test_runner/screenshots/${testId}_step0_0.png',
    );
    expect(stepPng.existsSync(), isTrue);
    expect(stepPng.lengthSync(), greaterThan(100));

    framesManifest.deleteSync();
    stepPng.deleteSync();
  });

  testWidgets('marks failed step in frames.json', (tester) async {
    const testId = 'contact_sheet_failed_test';
    final image0 = await _testImage(color: Colors.red);
    final image1 = await _testImage(color: Colors.grey);
    final path = await tester.runAsync(
      () => writeScreenshotFrames(
        testId: testId,
        config: const ScreenshotConfig(enabled: true),
        frames: [
          ScreenshotSheetFrame(
            stepIndex: 0,
            label: '1. tap(button)',
            image: image0,
          ),
          ScreenshotSheetFrame(
            stepIndex: 1,
            label: '2. expectVisible(title)',
            image: image1,
          ),
        ],
        status: TestStatus.failed,
        failedStepIndex: 0,
        failedStepLabel: 'tap(button)',
        failureMessage: 'Expected button to be visible.',
      ),
    );

    expect(path, endsWith('/${testId}_frames.json'));
    final framesManifest = File(
      'build/ensemble_test_runner/screenshots/${testId}_frames.json',
    );
    final framesJson =
        jsonDecode(framesManifest.readAsStringSync()) as Map<String, dynamic>;
    expect(framesJson['status'], 'failed');
    expect(framesJson['failedStepIndex'], 0);
    final frames = framesJson['frames'] as List<dynamic>;
    expect(frames, hasLength(2));
    expect(frames[0]['failed'], isTrue);
    expect(frames[1]['failed'], isNull);

    framesManifest.deleteSync();
    File('build/ensemble_test_runner/screenshots/${testId}_step0_0.png')
        .deleteSync();
    File('build/ensemble_test_runner/screenshots/${testId}_step1_0.png')
        .deleteSync();
  });

  testWidgets('pending status keeps frame images intact', (tester) async {
    const testId = 'contact_sheet_pending_test';
    final image = await _testImage(color: Colors.amber);
    final path = await tester.runAsync(
      () => writeScreenshotFrames(
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
      ),
    );

    expect(path, endsWith('/${testId}_frames.json'));
    // Verify image was NOT disposed during pending run
    expect(image.width, greaterThan(0));

    final framesManifest = File(
      'build/ensemble_test_runner/screenshots/${testId}_frames.json',
    );
    if (framesManifest.existsSync()) framesManifest.deleteSync();
    final stepPng = File(
      'build/ensemble_test_runner/screenshots/${testId}_step0_0.png',
    );
    if (stepPng.existsSync()) stepPng.deleteSync();
    image.dispose();
  });

  testWidgets('records multi-device labels on frames', (tester) async {
    const testId = 'contact_sheet_multi_device';
    final android = await _testImage(color: Colors.green);
    final iphone = await _testImage(color: Colors.blue);
    final path = await tester.runAsync(
      () => writeScreenshotFrames(
        testId: testId,
        config: const ScreenshotConfig(enabled: true),
        frames: [
          ScreenshotSheetFrame(
            stepIndex: 0,
            label: '1. tap(button)',
            image: android,
            deviceId: 'android_nl',
            deviceLabel: 'Samsung Galaxy S20 · nl',
            platform: 'android',
            model: 'Samsung Galaxy S20',
          ),
          ScreenshotSheetFrame(
            stepIndex: 0,
            label: '1. tap(button)',
            image: iphone,
            deviceId: 'iphone_en',
            deviceLabel: 'iPhone 15 Pro · en',
            platform: 'ios',
            model: 'iPhone 15 Pro',
          ),
        ],
        status: TestStatus.passed,
      ),
    );

    expect(path, endsWith('/${testId}_frames.json'));
    final framesManifest = File(
      'build/ensemble_test_runner/screenshots/${testId}_frames.json',
    );
    final framesJson =
        jsonDecode(framesManifest.readAsStringSync()) as Map<String, dynamic>;
    final frames = framesJson['frames'] as List<dynamic>;
    expect(frames, hasLength(2));
    expect(frames[0]['deviceId'], 'android_nl');
    expect(frames[1]['deviceLabel'], 'iPhone 15 Pro · en');

    framesManifest.deleteSync();
    File('build/ensemble_test_runner/screenshots/${testId}_step0_0.png')
        .deleteSync();
    File('build/ensemble_test_runner/screenshots/${testId}_step0_1.png')
        .deleteSync();
  });
}

Future<ui.Image> _testImage({Color color = Colors.white}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 390, 844),
    Paint()..color = color,
  );
  canvas.drawRect(
    const Rect.fromLTWH(20, 100, 350, 60),
    Paint()..color = Colors.grey.withValues(alpha: 0.3),
  );
  canvas.drawRect(
    const Rect.fromLTWH(20, 200, 350, 400),
    Paint()..color = Colors.grey.withValues(alpha: 0.1),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(390, 844);
  picture.dispose();
  return image;
}
