import 'dart:async';

import 'package:uuid/uuid.dart';

import '../agent/agent_event.dart';
import '../agent/agent_types.dart';
import '../errors/agent_exception.dart';
import '../providers/local_model_provider.dart';
import '../providers/model_types.dart';
import '../runtime/agent_loop.dart';
import '../tools/agent_tool.dart';
import '../tracing/agent_trace.dart';

const _uuid = Uuid();

/// Conversational session that owns history and one active generation.
class AgentSession {
  AgentSession({
    required this.agent,
    String? id,
    AgentTracer? tracer,
  })  : id = id ?? _uuid.v4(),
        _tracer = tracer;

  final EnsembleAgentRef agent;
  final String id;
  final AgentTracer? _tracer;

  final List<ModelMessage> _history = [];
  Completer<void>? _activeCompleter;
  var _cancelRequested = false;

  List<ModelMessage> get history => List.unmodifiable(_history);

  bool get isBusy => _activeCompleter != null;

  Future<AgentResult> send(
    AgentInput input, {
    Map<String, dynamic>? outputSchema,
  }) async {
    final completer = Completer<AgentResult>();
    final subscription = sendStream(input, outputSchema: outputSchema).listen(
      (event) {
        if (event is AgentCompleted) {
          if (!completer.isCompleted) completer.complete(event.result);
        } else if (event is AgentFailed) {
          if (!completer.isCompleted) completer.completeError(event.error);
        } else if (event is AgentCancelled) {
          if (!completer.isCompleted) {
            completer.completeError(
              const AgentCancelledException(message: 'Session turn cancelled.'),
            );
          }
        }
      },
      onError: (Object e, StackTrace st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.completeError(
            const ModelExecutionException(
              message: 'Session stream ended without a result.',
            ),
          );
        }
      },
      cancelOnError: true,
    );

    try {
      return await completer.future;
    } finally {
      await subscription.cancel();
    }
  }

  Stream<AgentEvent> sendStream(
    AgentInput input, {
    Map<String, dynamic>? outputSchema,
  }) {
    final controller = StreamController<AgentEvent>();
    var started = false;

    Future<void> start() async {
      if (started) return;
      started = true;
      _cancelRequested = false;

      try {
        await _acquireSlot();
      } catch (e, st) {
        if (!controller.isClosed) {
          controller.addError(e, st);
          await controller.close();
        }
        return;
      }

      final loop = AgentLoop(
        provider: agent.provider,
        instructions: agent.instructions,
        tools: agent.tools,
        options: agent.options,
        onToolCall: agent.onToolCall,
        tracer: _tracer,
      );

      try {
        await for (final event in loop.stream(
          sessionId: id,
          history: _history,
          input: input,
          outputSchema: outputSchema,
        )) {
          if (_cancelRequested) break;
          if (!controller.isClosed) controller.add(event);
        }
      } catch (e, st) {
        if (!controller.isClosed) controller.addError(e, st);
      } finally {
        _releaseSlot();
        if (!controller.isClosed) await controller.close();
      }
    }

    controller.onListen = () {
      unawaited(start());
    };
    controller.onCancel = () async {
      _cancelRequested = true;
    };

    return controller.stream;
  }

  Future<void> cancel() async {
    _cancelRequested = true;
    final active = _activeCompleter;
    if (active != null) {
      await active.future;
    }
  }

  Future<void> close() async {
    await cancel();
    _history.clear();
  }

  Future<void> _acquireSlot() async {
    if (_activeCompleter == null) {
      _activeCompleter = Completer<void>();
      return;
    }

    switch (agent.options.concurrency) {
      case AgentConcurrencyPolicy.reject:
        throw const AgentBusyException(
          message: 'Session already has an active generation.',
        );
      case AgentConcurrencyPolicy.cancelPrevious:
        _cancelRequested = true;
        await _activeCompleter!.future;
        _cancelRequested = false;
        _activeCompleter = Completer<void>();
      case AgentConcurrencyPolicy.queue:
        await _activeCompleter!.future;
        _activeCompleter = Completer<void>();
    }
  }

  void _releaseSlot() {
    final active = _activeCompleter;
    _activeCompleter = null;
    if (active != null && !active.isCompleted) {
      active.complete();
    }
  }
}

/// Narrow interface [AgentSession] needs from [EnsembleAgent].
abstract class EnsembleAgentRef {
  LocalModelProvider get provider;
  String get instructions;
  List<AgentTool> get tools;
  AgentOptions get options;
  ToolHandler? get onToolCall;
}
