import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/screenshot_contact_sheet.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';

/// Accumulates screenshot frames and writes per-step PNGs + a frames manifest.
///
/// Device-matrix runs use distinct test ids (e.g. `home[android_nl]`), so each
/// device gets its own frames set rather than a shared multi-device PNG.
class ScreenshotSheetAggregator {
  ScreenshotSheetAggregator({
    required this.screenshots,
    required this.devices,
  });

  final ScreenshotConfig screenshots;
  final List<TestDeviceTarget> devices;
  final Map<String, _SheetGroup> _groups = {};

  static const expectedRunsPerSheet = 1;

  /// Merges [frames] from one device/test run. Writes step PNGs when all
  /// expected runs for the sheet id have completed.
  ///
  /// Returns the display path of `*_frames.json`, or null if not ready / disabled.
  Future<String?> completeRun({
    required EnsembleTestCase testCase,
    required List<ScreenshotSheetFrame> frames,
    required TestStatus status,
    required int durationMs,
    int? failedStepIndex,
    String? failedStepLabel,
    String? failureMessage,
  }) async {
    if (!screenshots.enabled) {
      _disposeFrames(frames);
      return null;
    }
    if (frames.isEmpty && devices.isEmpty) return null;

    final sheetId = testCase.resolvedScreenshotSheetId;
    final runId = testCase.id;
    final group = _groupFor(sheetId);
    final deviceId = testCase.deviceTarget?.id;

    if (group.completedRunIds.contains(runId)) {
      if (deviceId != null) {
        group.frames.removeWhere((frame) => frame.deviceId == deviceId);
      } else {
        group.frames.clear();
      }
    } else {
      group.completedRunIds.add(runId);
    }

    group.frames.addAll(frames);
    group.durationByRunId[runId] = durationMs;
    if (status == TestStatus.failed) {
      group.status = TestStatus.failed;
      group.failedStepIndex = failedStepIndex;
      group.failedStepLabel = failedStepLabel;
      group.failureMessage = failureMessage;
      group.failedDeviceId = deviceId;
    } else if (group.status != TestStatus.failed) {
      group.status = status;
      if (deviceId != null && group.failedDeviceId == deviceId) {
        group.failedStepIndex = null;
        group.failedStepLabel = null;
        group.failureMessage = null;
        group.failedDeviceId = null;
      }
    }

    final ready = group.completedRunIds.length >= expectedRunsPerSheet;
    if (!ready) {
      return null;
    }

    final path = await writeScreenshotFrames(
      testId: sheetId,
      config: screenshots,
      frames: List<ScreenshotSheetFrame>.from(group.frames),
      status: group.status,
      failedStepIndex: group.failedStepIndex,
      failedStepLabel: group.failedStepLabel,
      failureMessage: group.failureMessage,
      failedDeviceId: group.failedDeviceId,
    );
    _groups.remove(sheetId);
    return path;
  }

  Future<void> flushRemaining() async {
    for (final entry in _groups.entries.toList()) {
      final sheetId = entry.key;
      final group = entry.value;
      if (group.frames.isEmpty) {
        _groups.remove(sheetId);
        continue;
      }
      await writeScreenshotFrames(
        testId: sheetId,
        config: screenshots,
        frames: List<ScreenshotSheetFrame>.from(group.frames),
        status: group.status == TestStatus.pending
            ? TestStatus.failed
            : group.status,
        failedStepIndex: group.failedStepIndex,
        failedStepLabel: group.failedStepLabel,
        failureMessage: group.failureMessage ??
            'Incomplete device matrix '
                '(${group.completedRunIds.length}/$expectedRunsPerSheet runs)',
        failedDeviceId: group.failedDeviceId,
      );
      _groups.remove(sheetId);
    }
  }

  _SheetGroup _groupFor(String sheetId) =>
      _groups.putIfAbsent(sheetId, _SheetGroup.new);

  void _disposeFrames(List<ScreenshotSheetFrame> frames) {
    for (final frame in frames) {
      try {
        frame.image.dispose();
      } catch (_) {}
    }
  }
}

class _SheetGroup {
  final List<ScreenshotSheetFrame> frames = [];
  final Set<String> completedRunIds = {};
  final Map<String, int> durationByRunId = {};
  TestStatus status = TestStatus.pending;
  int? failedStepIndex;
  String? failedStepLabel;
  String? failureMessage;
  String? failedDeviceId;

  int get totalDurationMs =>
      durationByRunId.values.fold<int>(0, (sum, value) => sum + value);
}
