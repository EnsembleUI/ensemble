import '../providers/local_model_provider.dart';
import '../session/agent_session.dart';
import '../tools/agent_tool.dart';
import '../tracing/agent_trace.dart';
import 'agent_event.dart';
import 'agent_types.dart';

/// Primary entry point for running on-device AI agents.
class EnsembleAgent implements EnsembleAgentRef {
  EnsembleAgent({
    required this.provider,
    this.instructions = '',
    this.tools = const [],
    this.options = const AgentOptions(),
    this.onToolCall,
    this.tracer,
  });

  @override
  final LocalModelProvider provider;

  @override
  final String instructions;

  @override
  final List<AgentTool> tools;

  @override
  final AgentOptions options;

  @override
  final ToolHandler? onToolCall;

  final AgentTracer? tracer;

  final List<AgentSession> _sessions = [];

  /// Creates a conversational session bound to this agent.
  AgentSession createSession({String? id}) {
    final session = AgentSession(agent: this, id: id, tracer: tracer);
    _sessions.add(session);
    tracer?.emit(AgentTraceEvent(
      sessionId: session.id,
      invocationId: session.id,
      provider: provider.id,
      event: 'session_created',
    ));
    return session;
  }

  /// Stateless one-shot run (creates an ephemeral session).
  Future<AgentResult> run(
    AgentInput input, {
    Map<String, dynamic>? outputSchema,
  }) async {
    final session = createSession();
    try {
      return await session.send(input, outputSchema: outputSchema);
    } finally {
      await session.close();
      _sessions.remove(session);
    }
  }

  /// Stateless streaming run.
  Stream<AgentEvent> stream(
    AgentInput input, {
    Map<String, dynamic>? outputSchema,
  }) async* {
    final session = createSession();
    try {
      yield* session.sendStream(input, outputSchema: outputSchema);
    } finally {
      await session.close();
      _sessions.remove(session);
    }
  }

  /// Cancels all active sessions.
  Future<void> cancel() async {
    await Future.wait(_sessions.map((s) => s.cancel()));
  }
}
