/// How far to synchronize before capturing a [UiObservation].
enum ObservationSynchronization {
  /// Return the current frame without extra pumping.
  immediate,

  /// Advance at least one frame.
  nextFrame,

  /// Boundedly wait until the UI appears stable (or timeout → partial).
  untilStable,
}

/// Options for [TestExecutionSession.observe].
class ObservationOptions {
  final ObservationSynchronization synchronization;
  final Duration? stableTimeout;
  final bool includeScreenshot;
  final bool includeBounds;
  final bool allowPartial;

  /// When true, only elements with a qualifying [ValueKey] string id are
  /// collected — used as a performance baseline for unified observation.
  final bool keyedOnly;

  const ObservationOptions({
    this.synchronization = ObservationSynchronization.untilStable,
    this.stableTimeout,
    this.includeScreenshot = false,
    this.includeBounds = true,
    this.allowPartial = false,
    this.keyedOnly = false,
  });

  Map<String, dynamic> toJson() => {
        'synchronization': synchronization.name,
        if (stableTimeout != null)
          'stableTimeoutMs': stableTimeout!.inMilliseconds,
        'includeScreenshot': includeScreenshot,
        'includeBounds': includeBounds,
        'allowPartial': allowPartial,
        'keyedOnly': keyedOnly,
      };

  factory ObservationOptions.fromJson(Map<String, dynamic> json) {
    final syncName = json['synchronization']?.toString() ?? 'untilStable';
    final sync = ObservationSynchronization.values.firstWhere(
      (v) => v.name == syncName,
      orElse: () => ObservationSynchronization.untilStable,
    );
    final timeoutMs = json['stableTimeoutMs'];
    return ObservationOptions(
      synchronization: sync,
      stableTimeout:
          timeoutMs is int ? Duration(milliseconds: timeoutMs) : null,
      includeScreenshot: json['includeScreenshot'] == true,
      includeBounds: json['includeBounds'] != false,
      allowPartial: json['allowPartial'] == true,
      keyedOnly: json['keyedOnly'] == true,
    );
  }
}
