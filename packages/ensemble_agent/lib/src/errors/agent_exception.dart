import '../capabilities/agent_capabilities.dart';

/// Base class for all agent domain errors.
sealed class AgentException implements Exception {
  const AgentException({
    required this.message,
    this.providerCode,
    this.cause,
    this.metadata,
  });

  final String message;
  final String? providerCode;
  final Object? cause;
  final Map<String, dynamic>? metadata;

  @override
  String toString() => '$runtimeType: $message';
}

class AgentUnavailableException extends AgentException {
  const AgentUnavailableException({
    required super.message,
    this.reason = AgentUnavailableReason.modelUnavailable,
    super.providerCode,
    super.cause,
    super.metadata,
  });

  final AgentUnavailableReason reason;
}

class UnsupportedDeviceException extends AgentException {
  const UnsupportedDeviceException({
    required super.message,
    super.providerCode,
    super.cause,
    super.metadata,
  });
}

class UnsupportedCapabilityException extends AgentException {
  const UnsupportedCapabilityException({
    required super.message,
    super.providerCode,
    super.cause,
    super.metadata,
  });
}

class ModelExecutionException extends AgentException {
  const ModelExecutionException({
    required super.message,
    super.providerCode,
    super.cause,
    super.metadata,
  });
}

class ToolExecutionException extends AgentException {
  const ToolExecutionException({
    required super.message,
    this.toolName,
    this.toolCallId,
    super.providerCode,
    super.cause,
    super.metadata,
  });

  final String? toolName;
  final String? toolCallId;
}

class AgentTimeoutException extends AgentException {
  const AgentTimeoutException({
    required super.message,
    super.providerCode,
    super.cause,
    super.metadata,
  });
}

class AgentCancelledException extends AgentException {
  const AgentCancelledException({
    required super.message,
    super.providerCode,
    super.cause,
    super.metadata,
  });
}

class AgentLoopLimitException extends AgentException {
  const AgentLoopLimitException({
    required super.message,
    this.maxIterations,
    this.maxToolCalls,
    super.providerCode,
    super.cause,
    super.metadata,
  });

  final int? maxIterations;
  final int? maxToolCalls;
}

/// Thrown when a session rejects a concurrent turn.
class AgentBusyException extends AgentException {
  const AgentBusyException({required super.message});
}
