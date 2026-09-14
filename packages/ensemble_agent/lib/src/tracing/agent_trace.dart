/// Lightweight observability events. Does not log prompts or tool bodies.
class AgentTraceEvent {
  AgentTraceEvent({
    required this.sessionId,
    required this.invocationId,
    required this.provider,
    required this.event,
    DateTime? timestamp,
    this.duration,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  final DateTime timestamp;
  final String sessionId;
  final String invocationId;
  final String provider;
  final String event;
  final Duration? duration;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toMap() => {
        'timestamp': timestamp.toIso8601String(),
        'sessionId': sessionId,
        'invocationId': invocationId,
        'provider': provider,
        'event': event,
        if (duration != null) 'durationMs': duration!.inMilliseconds,
        if (metadata != null) 'metadata': metadata,
      };
}

/// Receives [AgentTraceEvent]s from the runtime.
abstract class AgentTracer {
  void emit(AgentTraceEvent event);
}

/// In-memory tracer useful for tests and local debugging.
class MemoryAgentTracer implements AgentTracer {
  final List<AgentTraceEvent> events = [];

  @override
  void emit(AgentTraceEvent event) => events.add(event);
}
