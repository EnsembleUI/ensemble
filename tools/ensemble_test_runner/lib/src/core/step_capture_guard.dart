/// Coordinates concurrent evidence boundaries for one authored step.
///
/// A successful capture consumes the guard; a failed or skipped capture leaves
/// it open so a later boundary can retry.
final class StepCaptureGuard {
  bool _captured = false;
  Future<bool>? _captureInFlight;

  bool get captured => _captured;

  void markCaptured() => _captured = true;

  Future<bool> capture(Future<bool> Function() capture) async {
    if (_captured) return false;
    final inFlight = _captureInFlight;
    if (inFlight != null) return inFlight;

    final pending = capture();
    _captureInFlight = pending;
    try {
      final didCapture = await pending;
      if (didCapture) _captured = true;
      return didCapture;
    } finally {
      _captureInFlight = null;
    }
  }
}
