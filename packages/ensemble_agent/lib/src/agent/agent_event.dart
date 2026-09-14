import '../agent/agent_types.dart';
import '../tools/agent_tool.dart';

/// Streaming / lifecycle events emitted by the agent runtime.
sealed class AgentEvent {
  const AgentEvent({required this.sessionId, required this.invocationId});

  final String sessionId;
  final String invocationId;
}

class AgentStarted extends AgentEvent {
  const AgentStarted({
    required super.sessionId,
    required super.invocationId,
  });
}

class AgentTextDelta extends AgentEvent {
  const AgentTextDelta({
    required super.sessionId,
    required super.invocationId,
    required this.delta,
  });

  final String delta;
}

class AgentToolCallStarted extends AgentEvent {
  const AgentToolCallStarted({
    required super.sessionId,
    required super.invocationId,
    required this.call,
  });

  final ToolCall call;
}

class AgentToolCallCompleted extends AgentEvent {
  const AgentToolCallCompleted({
    required super.sessionId,
    required super.invocationId,
    required this.call,
    required this.result,
  });

  final ToolCall call;
  final ToolResult result;
}

class AgentToolCallFailed extends AgentEvent {
  const AgentToolCallFailed({
    required super.sessionId,
    required super.invocationId,
    required this.call,
    required this.error,
  });

  final ToolCall call;
  final Object error;
}

class AgentProcessing extends AgentEvent {
  const AgentProcessing({
    required super.sessionId,
    required super.invocationId,
    this.message,
  });

  final String? message;
}

class AgentCompleted extends AgentEvent {
  const AgentCompleted({
    required super.sessionId,
    required super.invocationId,
    required this.result,
  });

  final AgentResult result;
}

class AgentFailed extends AgentEvent {
  const AgentFailed({
    required super.sessionId,
    required super.invocationId,
    required this.error,
  });

  final Object error;
}

class AgentCancelled extends AgentEvent {
  const AgentCancelled({
    required super.sessionId,
    required super.invocationId,
  });
}
