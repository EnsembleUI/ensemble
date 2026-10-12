import 'dart:async';

import 'operation.dart';

typedef EvidenceBoundaryEmitter = FutureOr<void> Function(
  int? stepIndex,
  String stepType,
);

/// Runtime capability for publishing target-ready/pre-mutation boundaries into
/// the kernel's ordered event stream.
abstract interface class EvidenceBoundaryEventSource {
  void bindEvidenceBoundaryEmitter(EvidenceBoundaryEmitter? emitter);
}

enum ObservationLevel { minimal, standard, diagnostic }

final class ObservationRequest {
  ObservationRequest({
    this.level = ObservationLevel.minimal,
    Map<String, Object?> target = const {},
  }) : target = freezeInput(target);

  /// The lightweight observation used by standard control flow.
  ///
  /// Keeping this constructor explicit makes the cheap branch check part of
  /// the execution contract. Richer views belong to evidence and failure
  /// capture paths, which use the session observation API separately.
  ObservationRequest.minimal({Map<String, Object?> target = const {}})
      : this(level: ObservationLevel.minimal, target: target);

  final ObservationLevel level;
  final Map<String, Object?> target;
}

final class RuntimeView {
  RuntimeView({
    required this.revision,
    required this.level,
    required Map<String, Object?> target,
    required this.targetVisible,
  }) : target = freezeInput(target);

  final int revision;
  final ObservationLevel level;
  final Map<String, Object?> target;
  final bool targetVisible;
}

final class RuntimeCapabilities {
  RuntimeCapabilities(Iterable<String> handlerKeys)
      : handlerKeys = Set.unmodifiable(handlerKeys);

  /// Runtime dispatch capabilities use the registry-selected operation key.
  /// Source names and aliases remain plan metadata, not a second dispatch map.
  final Set<String> handlerKeys;

  bool supports(TestOperation operation) =>
      handlerKeys.contains(operation.handlerKey);
}

final class OperationResult {
  const OperationResult.success()
      : error = null,
        errorCode = null,
        recoverable = false,
        cause = null,
        stackTrace = null;
  const OperationResult.failure(String message,
      {this.errorCode = 'operationFailed',
      this.recoverable = true,
      this.cause,
      this.stackTrace})
      : error = message;

  final String? error;
  final String? errorCode;
  final bool recoverable;
  final Object? cause;
  final StackTrace? stackTrace;
  bool get succeeded => error == null;
}

abstract interface class TestRuntime {
  RuntimeCapabilities get capabilities;

  Future<RuntimeView> observe(ObservationRequest request);

  Future<OperationResult> execute(TestOperation operation);

  Future<void> close();
}
