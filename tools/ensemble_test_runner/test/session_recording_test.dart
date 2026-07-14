import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/session_recording.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('writes suite recording gif and manifest', () async {
    final directory = Directory('build/ensemble_test_runner/recordings');
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }

    final png = img.encodePng(
      img.Image(width: 2, height: 2)..clear(img.ColorRgb8(0, 255, 0)),
    );

    final path = await writeSessionRecording(
      config: const RecordConfig(enabled: true),
      frames: [
        RecordingFrame(
          testId: 'login_test',
          label: 'login_test startup',
          pngBytes: Uint8List.fromList(png),
          timestamp: DateTime.parse('2026-07-14T10:00:00Z'),
          durationMs: 250,
        ),
        RecordingFrame(
          testId: 'login_test',
          label: 'login_test step 1 tap(login_button)',
          pngBytes: Uint8List.fromList(png),
          timestamp: DateTime.parse('2026-07-14T10:00:01Z'),
          durationMs: 1000,
        ),
      ],
    );

    expect(path, 'build/ensemble_test_runner/recordings/recording.gif');
    final gif = File(path!);
    expect(gif.existsSync(), isTrue);
    expect(gif.readAsBytesSync().take(6), utf8.encode('GIF89a'));

    final manifest = jsonDecode(
      File('build/ensemble_test_runner/recordings/recording.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(manifest, isNot(contains('frameDurationMs')));
    expect(manifest, isNot(contains('frameIntervalMs')));
    expect(manifest, isNot(contains('maxFrames')));
    expect(manifest['frames'], hasLength(2));
    expect((manifest['frames'] as List).last['label'],
        'login_test step 1 tap(login_button)');
    expect((manifest['frames'] as List).last['durationMs'], 1000);
  });
}
