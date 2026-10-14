import 'dart:async';
import 'dart:io';

/// Listens for the first parent interruption signal supported by this platform.
///
/// This is shared by the CLI and process-level lifecycle tests so signal
/// delivery and child teardown use the same watch implementation.
final class ProcessInterruptionWatch {
  final Completer<ProcessSignal> _first = Completer<ProcessSignal>();
  final List<StreamSubscription<ProcessSignal>> _subscriptions = [];

  Future<ProcessSignal> get future => _first.future;

  ProcessInterruptionWatch() {
    _watch(ProcessSignal.sigint);
    _watch(ProcessSignal.sigterm);
  }

  void _watch(ProcessSignal signal) {
    try {
      _subscriptions.add(signal.watch().listen((_) {
        if (!_first.isCompleted) _first.complete(signal);
      }));
    } on UnsupportedError {
      // Some platforms do not expose every process signal.
    }
  }

  Future<void> close() async {
    await Future.wait(
      _subscriptions.map((subscription) => subscription.cancel()),
    );
  }
}
