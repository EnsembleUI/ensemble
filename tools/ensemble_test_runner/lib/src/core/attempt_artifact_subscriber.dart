import 'dart:async';

import 'kernel.dart';

/// Publishes attempt-level sidecars at the kernel's single terminal boundary.
///
/// The callback is guarded locally as well as by the artifact coordinator so
/// repeated compatibility events cannot write API or console sidecars twice.
/// This subscriber does not observe step boundaries and therefore cannot add
/// per-step publication work.
final class AttemptArtifactSubscriber {
  AttemptArtifactSubscriber({required FutureOr<void> Function() publish})
      : _publish = publish;

  final FutureOr<void> Function() _publish;
  bool _published = false;

  FutureOr<void> call(ExecutionEvent event) {
    if (event.kind != ExecutionEventKind.attemptFinished || _published) {
      return null;
    }
    _published = true;
    return _publish();
  }
}
