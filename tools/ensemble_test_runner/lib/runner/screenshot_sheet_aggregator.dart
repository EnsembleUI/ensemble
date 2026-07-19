import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/screenshot_contact_sheet.dart';
import 'package:ensemble_test_runner/runner/screenshot_sheet_write_queue.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';

/// Accumulates device-matrix screenshot frames into one contact sheet per
/// logical test id.
class ScreenshotSheetAggregator {
  ScreenshotSheetAggregator({
    required this.screenshots,
    required this.devices,
    ScreenshotSheetWriteQueue? writeQueue,
  }) : _writeQueue = writeQueue ?? ScreenshotSheetWriteQueue();

  final ScreenshotConfig screenshots;
  final List<TestDeviceTarget> devices;
  final ScreenshotSheetWriteQueue _writeQueue;
  final Map<String, _SheetGroup> _groups = {};

  int get expectedRunsPerSheet => devices.isEmpty ? 1 : devices.length;

  void schedulePending({
    required EnsembleTestCase testCase,
    required List<ScreenshotSheetFrame> frames,
  }) {
    if (!screenshots.enabled || frames.isEmpty) return;
    final sheetId = testCase.resolvedScreenshotSheetId;
    final group = _groupFor(sheetId);
    final pendingFrames = [
      ...group.frames,
      ...frames,
    ];
    _writeQueue.schedulePending(
      testId: sheetId,
      config: screenshots,
      frames: pendingFrames,
    );
  }

  /// Merges [frames] from one device/test run. Writes the final sheet when all
  /// expected runs for the sheet id have completed.
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
      _writeQueue.schedulePending(
        testId: sheetId,
        config: screenshots,
        frames: List<ScreenshotSheetFrame>.from(group.frames),
      );
      return null;
    }

    _writeQueue.invalidate(sheetId);
    await _writeQueue.drain();

    final path = await writeScreenshotContactSheet(
      testId: sheetId,
      config: screenshots,
      frames: List<ScreenshotSheetFrame>.from(group.frames),
      status: group.status,
      durationMs: group.totalDurationMs,
      failedStepIndex: group.failedStepIndex,
      failedStepLabel: group.failedStepLabel,
      failureMessage: group.failureMessage,
      failedDeviceId: group.failedDeviceId,
    );
    _groups.remove(sheetId);
    return path;
  }

  Future<void> flushRemaining() async {
    await _writeQueue.drain();
    for (final entry in _groups.entries.toList()) {
      final sheetId = entry.key;
      final group = entry.value;
      if (group.frames.isEmpty) {
        _groups.remove(sheetId);
        continue;
      }
      _writeQueue.invalidate(sheetId);
      await _writeQueue.drain();
      await writeScreenshotContactSheet(
        testId: sheetId,
        config: screenshots,
        frames: List<ScreenshotSheetFrame>.from(group.frames),
        status: group.status == TestStatus.pending
            ? TestStatus.failed
            : group.status,
        durationMs: group.totalDurationMs,
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
