/// Structured failure information shared by execution and report models.
library;

enum TestFailureKind {
  assertion,
  elementNotFound,
  ambiguousTarget,
  unsupportedCapability,
  bootstrap,
  crash,
  cleanup,
  incompleteExecution,
  internal,
}

class TestFailureDetails {
  final TestFailureKind kind;
  final String message;
  final Map<String, dynamic> target;
  final String? phase;

  const TestFailureDetails({
    required this.kind,
    required this.message,
    this.target = const {},
    this.phase,
  });

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'message': message,
        if (target.isNotEmpty) 'target': target,
        if (phase != null) 'phase': phase,
      };

  factory TestFailureDetails.fromJson(Map<String, dynamic> json) {
    final kindName = json['kind']?.toString();
    return TestFailureDetails(
      kind: TestFailureKind.values.firstWhere(
        (value) => value.name == kindName,
        orElse: () => TestFailureKind.internal,
      ),
      message: json['message']?.toString() ?? 'Test failed',
      target: json['target'] is Map
          ? Map<String, dynamic>.from(json['target'] as Map)
          : const {},
      phase: json['phase']?.toString(),
    );
  }

  /// Best-effort structured kind from a free-form failure message.
  factory TestFailureDetails.fromMessage(
    String text, {
    String? phase,
    Map<String, dynamic> target = const {},
  }) {
    final lower = text.toLowerCase();
    final TestFailureKind kind;
    if (lower.contains('ambiguous')) {
      kind = TestFailureKind.ambiguousTarget;
    } else if (lower.contains('not found') ||
        lower.contains('could not find') ||
        lower.contains('missing')) {
      kind = TestFailureKind.elementNotFound;
    } else if (lower.contains('capability') ||
        lower.contains('unavailable') ||
        lower.contains('unsupported')) {
      kind = TestFailureKind.unsupportedCapability;
    } else if (lower.contains('crash') || lower.contains('application error')) {
      kind = TestFailureKind.crash;
    } else if (lower.contains('cleanup') || lower.contains('teardown')) {
      kind = TestFailureKind.cleanup;
    } else if (lower.contains('bootstrap') || lower.contains('launch')) {
      kind = TestFailureKind.bootstrap;
    } else if (lower.contains('incomplete') || lower.contains('transport')) {
      kind = TestFailureKind.incompleteExecution;
    } else {
      kind = TestFailureKind.assertion;
    }
    return TestFailureDetails(
      kind: kind,
      message: text,
      phase: phase,
      target: target,
    );
  }

  /// Preserves the execution kernel's machine classification at the report
  /// boundary instead of guessing from wording alone.
  factory TestFailureDetails.fromExecutionCode(
    String? code,
    String text, {
    String? phase,
    Map<String, dynamic> target = const {},
  }) {
    final kind = switch (code) {
      'elementNotFound' => TestFailureKind.elementNotFound,
      'ambiguousTarget' => TestFailureKind.ambiguousTarget,
      'unsupportedAction' ||
      'executionUnavailable' ||
      'permissionDenied' =>
        TestFailureKind.unsupportedCapability,
      'actionTimeout' ||
      'cancelled' ||
      'limitExceeded' ||
      'loopLimitExceeded' =>
        TestFailureKind.incompleteExecution,
      'closeFailed' => TestFailureKind.cleanup,
      'internalError' || 'operationException' => TestFailureKind.internal,
      _ => null,
    };
    return kind == null
        ? TestFailureDetails.fromMessage(text, phase: phase, target: target)
        : TestFailureDetails(
            kind: kind,
            message: text,
            phase: phase,
            target: target,
          );
  }

  /// Classifies a non-primary kernel diagnostic without treating it as the
  /// test's assertion failure.
  factory TestFailureDetails.fromSecondaryMessage(String text) {
    if (text.startsWith('Runtime close failed:')) {
      return TestFailureDetails(
        kind: TestFailureKind.cleanup,
        message: text,
        phase: 'cleanup',
      );
    }
    if (text.startsWith('Event subscriber ')) {
      return TestFailureDetails(
        kind: TestFailureKind.internal,
        message: text,
        phase: 'reporting',
      );
    }
    return TestFailureDetails.fromMessage(text, phase: 'secondary');
  }
}
