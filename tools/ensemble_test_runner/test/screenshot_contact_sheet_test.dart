import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/screenshot_contact_sheet.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('writes compressed per-step images and frames.json',
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
            highlight: const ScreenshotHighlight(
              kind: 'action',
              left: 10,
              top: 20,
              width: 30,
              height: 5,
            ),
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
    expect(frames.single['file'], startsWith('shot_'));
    expect(
      frames.single['file'],
      anyOf(endsWith('.jpg'), endsWith('.png')),
    );
    expect(frames.single['highlight']['kind'], 'action');
    expect(frames.single['highlight']['left'], 10);
    expect(frames.single['failed'], isNull);
    final stepImage = File(
      'build/ensemble_test_runner/screenshots/${frames.single['file']}',
    );
    expect(stepImage.existsSync(), isTrue);
    expect(stepImage.lengthSync(), greaterThan(100));

    framesManifest.deleteSync();
    stepImage.deleteSync();
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

    _deleteArtifacts(framesManifest, frames);
  });

  testWidgets('deduplicates identical encoded screenshots', (tester) async {
    const testId = 'contact_sheet_dedupe_test';
    final image0 = await _testImage(color: Colors.purple);
    final image1 = await _testImage(color: Colors.purple);
    final path = await tester.runAsync(
      () => writeScreenshotFrames(
        testId: testId,
        config: const ScreenshotConfig(enabled: true),
        frames: [
          ScreenshotSheetFrame(
            stepIndex: 0,
            label: '1. waitFor(title)',
            image: image0,
          ),
          ScreenshotSheetFrame(
            stepIndex: 1,
            label: '2. expectVisible(title)',
            image: image1,
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
    expect(frames[0]['file'], frames[1]['file']);
    expect({for (final frame in frames) (frame as Map)['file']}, hasLength(1));
    expect(
      File('build/ensemble_test_runner/screenshots/${frames[0]['file']}')
          .existsSync(),
      isTrue,
    );

    _deleteArtifacts(framesManifest, frames);
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
    final framesJson =
        jsonDecode(framesManifest.readAsStringSync()) as Map<String, dynamic>;
    final frames = framesJson['frames'] as List<dynamic>;
    _deleteArtifacts(framesManifest, frames);
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

    _deleteArtifacts(framesManifest, frames);
  });
}

void _deleteArtifacts(File framesManifest, List<dynamic> frames) {
  final files = {
    for (final frame in frames)
      if (frame is Map && frame['file'] != null) frame['file'].toString(),
  };
  if (framesManifest.existsSync()) framesManifest.deleteSync();
  for (final file in files) {
    final image = File('build/ensemble_test_runner/screenshots/$file');
    if (image.existsSync()) image.deleteSync();
  }
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
