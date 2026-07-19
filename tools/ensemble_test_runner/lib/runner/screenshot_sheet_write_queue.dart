import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/screenshot_contact_sheet.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';

class ScreenshotSheetWriteQueue {
  final Map<String, int> _versionsByTestId = {};
  Future<void> _queue = Future<void>.value();

  void schedulePending({
    required String testId,
    required ScreenshotConfig config,
    required List<ScreenshotSheetFrame> frames,
  }) {
    if (frames.isEmpty) return;

    final version = (_versionsByTestId[testId] ?? 0) + 1;
    _versionsByTestId[testId] = version;
    final frameSnapshot = List<ScreenshotSheetFrame>.from(frames);

    _queue = _queue.then((_) async {
      if (_versionsByTestId[testId] != version) return;
      try {
        await writeScreenshotContactSheet(
          testId: testId,
          config: config,
          frames: frameSnapshot,
          status: TestStatus.pending,
          durationMs: 0,
        );
      } catch (_) {
        // Pending screenshots are a live developer aid. The final per-test
        // sheet is written through the normal result path.
      }
    });
  }

  void invalidate(String testId) {
    _versionsByTestId[testId] = (_versionsByTestId[testId] ?? 0) + 1;
  }

  Future<void> drain() async {
    try {
      await _queue;
    } catch (_) {
      // Pending write failures must not affect test execution.
    }
  }
}
