import 'dart:async';

/// Stops a benchmark worker when a single workload stops making progress.
///
/// A case marker starts the clock. The parent process can then terminate a
/// worker blocked in fixture setup or teardown instead of leaving a quick run
/// stalled indefinitely.
final class BenchmarkWorkerCaseWatchdog {
  BenchmarkWorkerCaseWatchdog({
    required this.timeout,
    required this.markerPrefix,
    required this.onTimeout,
  });

  final Duration timeout;
  final String markerPrefix;
  final void Function(String caseId) onTimeout;

  Timer? _timer;
  String? currentCase;
  String? timedOutCase;

  void observeLine(String line) {
    final marker = line.indexOf(markerPrefix);
    if (marker < 0) return;

    final payload = line.substring(marker + markerPrefix.length);
    if (!payload.startsWith('case:')) return;
    final caseId = payload.substring('case:'.length).trim();
    if (caseId.isEmpty) return;

    _timer?.cancel();
    currentCase = caseId;
    timedOutCase = null;
    _timer = Timer(timeout, () {
      timedOutCase = caseId;
      onTimeout(caseId);
    });
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
