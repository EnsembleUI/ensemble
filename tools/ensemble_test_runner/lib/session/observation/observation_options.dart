/// How far to synchronize before capturing a [UiObservation].
enum ObservationSynchronization {
  /// Return the current frame without extra pumping.
  immediate,

  /// Advance at least one frame.
  nextFrame,

  /// Boundedly wait until the UI appears stable (or timeout → partial).
  untilStable,
}

/// Controls how much UI state an observation is allowed to collect.
///
/// Minimal observations are intended for control flow and locator-backed
/// checks. Standard observations retain the complete report-oriented shape.
/// Diagnostic observations are reserved for explicit failure investigation.
enum ObservationDetailLevel { minimal, standard, diagnostic }

/// Options for [TestExecutionSession.observe].
class ObservationOptions {
  final ObservationDetailLevel detail;
  final ObservationSynchronization synchronization;
  final Duration? stableTimeout;
  final bool includeScreenshot;
  final bool includeBounds;
  final bool allowPartial;

  /// When true, only elements with a qualifying [ValueKey] string id are
  /// collected — used as a performance baseline for unified observation.
  final bool keyedOnly;

  const ObservationOptions({
    this.detail = ObservationDetailLevel.standard,
    this.synchronization = ObservationSynchronization.untilStable,
    this.stableTimeout,
    this.includeScreenshot = false,
    this.includeBounds = true,
    this.allowPartial = false,
    this.keyedOnly = false,
  });

  Map<String, dynamic> toJson() => {
        'detail': detail.name,
        'synchronization': synchronization.name,
        if (stableTimeout != null)
          'stableTimeoutMs': stableTimeout!.inMilliseconds,
        'includeScreenshot': includeScreenshot,
        'includeBounds': includeBounds,
        'allowPartial': allowPartial,
        'keyedOnly': keyedOnly,
      };

  factory ObservationOptions.fromJson(Map<String, dynamic> json) {
    final detailName = json['detail']?.toString() ?? 'standard';
    final detail = ObservationDetailLevel.values.firstWhere(
      (v) => v.name == detailName,
      orElse: () => ObservationDetailLevel.standard,
    );
    final syncName = json['synchronization']?.toString() ?? 'untilStable';
    final sync = ObservationSynchronization.values.firstWhere(
      (v) => v.name == syncName,
      orElse: () => ObservationSynchronization.untilStable,
    );
    final timeoutMs = json['stableTimeoutMs'];
    return ObservationOptions(
      detail: detail,
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
