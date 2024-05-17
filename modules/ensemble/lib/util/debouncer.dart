import 'dart:async';
import 'dart:ui';

/// Use this class to reduce excessive executions (e.g. API called too many times)
/// using the run() method will ensure the execution happens only after the
/// delay. Additional runs within this delay will reset the delay.
class Debouncer {
  final Duration delay;
  Debouncer(this.delay);

  Timer? _timer;
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  // make sure to call this on UI State's dispose()
  void cancel() {
    _timer?.cancel();
  }
}
