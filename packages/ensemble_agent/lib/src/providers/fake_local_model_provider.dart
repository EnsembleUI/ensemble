import 'dart:async';

import '../capabilities/agent_capabilities.dart';
import '../errors/agent_exception.dart';
import '../tools/agent_tool.dart';
import 'local_model_provider.dart';
import 'model_types.dart';

/// Scripted response used by [FakeLocalModelProvider].
class FakeModelTurn {
  const FakeModelTurn({
    this.text,
    this.toolCalls = const [],
    this.structuredOutput,
    this.textDeltas = const [],
    this.error,
  });

  final String? text;
  final List<ToolCall> toolCalls;
  final dynamic structuredOutput;
  final List<String> textDeltas;
  final Object? error;
}

/// Deterministic in-memory provider for unit tests.
class FakeLocalModelProvider implements LocalModelProvider {
  FakeLocalModelProvider({
    this.id = 'fake',
    this.capabilities = const AgentCapabilities(
      available: true,
      provider: 'fake',
      textGeneration: true,
      streaming: true,
      toolCalling: true,
      nativeToolCalling: false,
      structuredOutput: true,
    ),
    List<FakeModelTurn>? turns,
  }) : _turns = List<FakeModelTurn>.from(turns ?? const []);

  @override
  final String id;

  final AgentCapabilities capabilities;
  final List<FakeModelTurn> _turns;
  final Set<String> _cancelled = {};

  int get remainingTurns => _turns.length;

  void enqueue(FakeModelTurn turn) => _turns.add(turn);

  @override
  Future<AgentCapabilities> getCapabilities() async => capabilities;

  @override
  Future<ModelResponse> generate(ModelRequest request) async {
    final turn = _nextTurn(request.requestId);
    if (turn.error != null) {
      final error = turn.error!;
      if (error is Exception) throw error;
      throw ModelExecutionException(message: error.toString());
    }
    return ModelResponse(
      text: turn.text,
      toolCalls: turn.toolCalls,
      structuredOutput: turn.structuredOutput,
    );
  }

  @override
  Stream<ModelEvent> stream(ModelRequest request) async* {
    final turn = _nextTurn(request.requestId);
    if (turn.error != null) {
      final error = turn.error!;
      yield ModelFailedEvent(
        message: error is Exception ? error.toString() : error.toString(),
      );
      return;
    }

    for (final delta in turn.textDeltas) {
      if (_cancelled.contains(request.requestId)) {
        yield const ModelCancelledEvent();
        return;
      }
      yield ModelTextDeltaEvent(delta: delta);
      await Future<void>.delayed(Duration.zero);
    }

    for (final call in turn.toolCalls) {
      yield ModelToolCallEvent(call: call);
    }

    yield ModelCompletedEvent(
      response: ModelResponse(
        text: turn.text ??
            (turn.textDeltas.isEmpty ? null : turn.textDeltas.join()),
        toolCalls: turn.toolCalls,
        structuredOutput: turn.structuredOutput,
      ),
    );
  }

  @override
  Future<void> cancel(String requestId) async {
    _cancelled.add(requestId);
  }

  FakeModelTurn _nextTurn(String requestId) {
    if (_cancelled.contains(requestId)) {
      throw const AgentCancelledException(message: 'Request was cancelled.');
    }
    if (_turns.isEmpty) {
      throw const ModelExecutionException(
        message: 'FakeLocalModelProvider has no scripted turns remaining.',
      );
    }
    return _turns.removeAt(0);
  }
}
