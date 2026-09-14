import 'dart:async';

import 'package:uuid/uuid.dart';

import '../agent/agent_event.dart';
import '../agent/agent_types.dart';
import '../capabilities/agent_capabilities.dart';
import '../errors/agent_exception.dart';
import '../providers/local_model_provider.dart';
import '../providers/model_types.dart';
import '../tools/agent_tool.dart';
import '../tracing/agent_trace.dart';
import 'tool_call_protocol.dart';

const _uuid = Uuid();

/// Executes the agent loop against a [LocalModelProvider].
///
/// Tool strategy:
/// - Path A: [AgentCapabilities.nativeToolCalling] (Apple FM / future)
/// - Path B: tools without native FC → Ensemble JSON protocol (Android Nano)
/// - Structured [ModelResponse.toolCalls] (e.g. fakes) still drive the loop
class AgentLoop {
  AgentLoop({
    required this.provider,
    required this.instructions,
    required this.tools,
    required this.options,
    this.onToolCall,
    this.tracer,
  });

  final LocalModelProvider provider;
  final String instructions;
  final List<AgentTool> tools;
  final AgentOptions options;
  final ToolHandler? onToolCall;
  final AgentTracer? tracer;

  Future<AgentResult> run({
    required String sessionId,
    required List<ModelMessage> history,
    required AgentInput input,
    Map<String, dynamic>? outputSchema,
    void Function(AgentEvent event)? onEvent,
  }) async {
    await for (final event in stream(
      sessionId: sessionId,
      history: history,
      input: input,
      outputSchema: outputSchema,
    )) {
      onEvent?.call(event);
      if (event is AgentCompleted) return event.result;
      if (event is AgentFailed) {
        final error = event.error;
        if (error is AgentException) throw error;
        throw ModelExecutionException(message: error.toString(), cause: error);
      }
      if (event is AgentCancelled) {
        throw const AgentCancelledException(message: 'Agent run cancelled.');
      }
    }
    throw const ModelExecutionException(
      message: 'Agent stream ended without a terminal event.',
    );
  }

  Stream<AgentEvent> stream({
    required String sessionId,
    required List<ModelMessage> history,
    required AgentInput input,
    Map<String, dynamic>? outputSchema,
  }) {
    final invocationId = _uuid.v4();
    final controller = StreamController<AgentEvent>();
    var cancelled = false;
    String? activeRequestId;

    Future<void> cancelActive() async {
      cancelled = true;
      final requestId = activeRequestId;
      if (requestId != null) {
        await provider.cancel(requestId);
      }
    }

    controller.onCancel = cancelActive;

    Future<void> execute() async {
      final startedAt = DateTime.now();
      void emit(AgentEvent event) {
        if (!controller.isClosed) controller.add(event);
      }

      void fail(Object error) {
        emit(AgentFailed(
          sessionId: sessionId,
          invocationId: invocationId,
          error: error,
        ));
      }

      emit(AgentStarted(sessionId: sessionId, invocationId: invocationId));
      tracer?.emit(AgentTraceEvent(
        sessionId: sessionId,
        invocationId: invocationId,
        provider: provider.id,
        event: 'invocation_started',
      ));

      final messages = List<ModelMessage>.from(history);
      if (input is AgentTextInput) {
        messages.add(ModelMessage.user(input.text));
      } else {
        fail(const UnsupportedCapabilityException(
          message: 'Unsupported AgentInput type for V1.',
        ));
        await controller.close();
        return;
      }

      var iterations = 0;
      var toolCallCount = 0;
      AgentUsage? usage;
      var pathBRetryUsed = false;

      try {
        final capabilities = await provider.getCapabilities();
        if (!capabilities.available) {
          throw AgentUnavailableException(
            message: 'On-device model is unavailable.',
            reason: capabilities.unavailableReason ??
                AgentUnavailableReason.modelUnavailable,
          );
        }

        // Path A (native tools) is reserved for providers that expose FC.
        // Android Nano uses Path B below. Future iOS Path A hooks go here.
        final usePathB = tools.isNotEmpty && !capabilities.nativeToolCalling;
        if (tools.isNotEmpty &&
            capabilities.nativeToolCalling &&
            onToolCall == null) {
          throw const ToolExecutionException(
            message:
                'Model tools require an onToolCall handler for native tool calling.',
          );
        }

        final effectiveInstructions = usePathB
            ? '$instructions\n\n${ToolCallProtocol.instructionsFor(tools)}'
            : instructions;
        final allowedTools = tools.map((t) => t.name).toSet();

        while (true) {
          if (cancelled) {
            emit(AgentCancelled(
              sessionId: sessionId,
              invocationId: invocationId,
            ));
            break;
          }
          if (iterations >= options.maxIterations) {
            throw AgentLoopLimitException(
              message: 'Exceeded maxIterations (${options.maxIterations}).',
              maxIterations: options.maxIterations,
              maxToolCalls: options.maxToolCalls,
            );
          }
          iterations++;

          final requestId = _uuid.v4();
          activeRequestId = requestId;
          final request = ModelRequest(
            requestId: requestId,
            messages: List<ModelMessage>.from(messages),
            instructions: effectiveInstructions,
            tools: tools,
            outputSchema: outputSchema,
            stream: !usePathB,
          );

          tracer?.emit(AgentTraceEvent(
            sessionId: sessionId,
            invocationId: invocationId,
            provider: provider.id,
            event: 'model_request_started',
            metadata: {
              'requestId': requestId,
              'iteration': iterations,
              'pathB': usePathB,
            },
          ));

          emit(AgentProcessing(
            sessionId: sessionId,
            invocationId: invocationId,
            message: usePathB ? 'model_path_b' : 'model',
          ));

          var response = await _awaitModelResponse(
            request: request,
            sessionId: sessionId,
            invocationId: invocationId,
            emit: emit,
            isCancelled: () => cancelled,
            timeout: options.timeout,
            preferGenerate: usePathB,
          );

          if (cancelled) {
            emit(AgentCancelled(
              sessionId: sessionId,
              invocationId: invocationId,
            ));
            break;
          }

          usage = response.usage ?? usage;

          // Path B: parse JSON when provider did not emit structured toolCalls.
          if (usePathB && !response.hasToolCalls) {
            try {
              final parsed = ToolCallProtocol.parse(
                response.text ?? '',
                allowedToolNames: allowedTools,
              );
              switch (parsed) {
                case ProtocolFinal(:final text):
                  response = ModelResponse(
                    text: text,
                    usage: response.usage,
                  );
                case ProtocolToolCall(:final call):
                  response = ModelResponse(
                    text: null,
                    toolCalls: [call],
                    usage: response.usage,
                  );
              }
              pathBRetryUsed = false;
            } on ProtocolParseException catch (e) {
              if (!pathBRetryUsed) {
                pathBRetryUsed = true;
                messages.add(ModelMessage.assistant(text: response.text));
                messages.add(ModelMessage.user(
                  'Your previous response was invalid ($e). '
                  'Reply with only a valid protocol JSON object.',
                ));
                continue;
              }
              throw ModelExecutionException(
                message: 'Path B protocol parse failed: $e',
                cause: e,
              );
            }
          }

          messages.add(ModelMessage.assistant(
            text: response.text,
            toolCalls: response.hasToolCalls ? response.toolCalls : null,
          ));

          if (!response.hasToolCalls) {
            final elapsed = DateTime.now().difference(startedAt);
            history
              ..clear()
              ..addAll(messages);
            emit(AgentCompleted(
              sessionId: sessionId,
              invocationId: invocationId,
              result: AgentResult(
                text: response.text,
                usage: AgentUsage(
                  inputTokens: usage?.inputTokens,
                  outputTokens: usage?.outputTokens,
                  duration: usage?.duration ?? elapsed,
                  provider: usage?.provider ?? provider.id,
                ),
                finishReason: AgentFinishReason.completed,
              ),
            ));
            tracer?.emit(AgentTraceEvent(
              sessionId: sessionId,
              invocationId: invocationId,
              provider: provider.id,
              event: 'agent_completed',
              duration: elapsed,
            ));
            break;
          }

          if (onToolCall == null) {
            throw const ToolExecutionException(
              message:
                  'Model requested a tool call but no onToolCall handler was provided.',
            );
          }

          for (final call in response.toolCalls) {
            if (cancelled) break;
            if (toolCallCount >= options.maxToolCalls) {
              throw AgentLoopLimitException(
                message: 'Exceeded maxToolCalls (${options.maxToolCalls}).',
                maxIterations: options.maxIterations,
                maxToolCalls: options.maxToolCalls,
              );
            }
            toolCallCount++;

            emit(AgentToolCallStarted(
              sessionId: sessionId,
              invocationId: invocationId,
              call: call,
            ));
            tracer?.emit(AgentTraceEvent(
              sessionId: sessionId,
              invocationId: invocationId,
              provider: provider.id,
              event: 'tool_requested',
              metadata: {'tool': call.name, 'callId': call.id},
            ));

            try {
              final result = await onToolCall!(call);
              emit(AgentToolCallCompleted(
                sessionId: sessionId,
                invocationId: invocationId,
                call: call,
                result: result,
              ));
              messages.add(ModelMessage.tool(
                toolCallId: call.id,
                result: result,
              ));
              if (usePathB) {
                messages.add(ModelMessage.user(
                  'Tool result for ${call.name} (${call.id}): ${result.toMap()}. '
                  'Continue with protocol JSON only.',
                ));
              }
              tracer?.emit(AgentTraceEvent(
                sessionId: sessionId,
                invocationId: invocationId,
                provider: provider.id,
                event: 'tool_completed',
                metadata: {'tool': call.name, 'callId': call.id},
              ));
            } catch (error) {
              emit(AgentToolCallFailed(
                sessionId: sessionId,
                invocationId: invocationId,
                call: call,
                error: error,
              ));
              throw ToolExecutionException(
                message: 'Tool "${call.name}" failed: $error',
                toolName: call.name,
                toolCallId: call.id,
                cause: error,
              );
            }
          }
        }
      } on AgentCancelledException {
        emit(AgentCancelled(
          sessionId: sessionId,
          invocationId: invocationId,
        ));
      } on TimeoutException catch (e) {
        fail(AgentTimeoutException(
          message: e.message ?? 'Agent timed out.',
          cause: e,
        ));
      } catch (error) {
        fail(error);
      } finally {
        await controller.close();
      }
    }

    unawaited(execute());
    return controller.stream;
  }

  Future<ModelResponse> _awaitModelResponse({
    required ModelRequest request,
    required String sessionId,
    required String invocationId,
    required void Function(AgentEvent event) emit,
    required bool Function() isCancelled,
    required Duration timeout,
    bool preferGenerate = false,
  }) async {
    final capabilities = await provider.getCapabilities();
    if (!capabilities.available) {
      throw AgentUnavailableException(
        message: 'On-device model is unavailable.',
        reason: capabilities.unavailableReason ??
            AgentUnavailableReason.modelUnavailable,
      );
    }

    if (preferGenerate || !capabilities.streaming) {
      return provider.generate(request).timeout(timeout);
    }

    final toolCalls = <ToolCall>[];
    final text = StringBuffer();
    dynamic structuredOutput;
    AgentUsage? usage;

    await for (final event in provider.stream(request).timeout(timeout)) {
      if (isCancelled()) {
        throw const AgentCancelledException(message: 'Cancelled.');
      }
      switch (event) {
        case ModelTextDeltaEvent(:final delta):
          text.write(delta);
          emit(AgentTextDelta(
            sessionId: sessionId,
            invocationId: invocationId,
            delta: delta,
          ));
        case ModelToolCallEvent(:final call):
          toolCalls.add(call);
        case ModelCompletedEvent(:final response):
          return ModelResponse(
            text: response.text ?? (text.isEmpty ? null : text.toString()),
            toolCalls:
                response.toolCalls.isNotEmpty ? response.toolCalls : toolCalls,
            structuredOutput: response.structuredOutput ?? structuredOutput,
            usage: response.usage ?? usage,
            finishReason: response.finishReason,
          );
        case ModelFailedEvent(:final message, :final code):
          throw ModelExecutionException(
            message: message,
            providerCode: code,
          );
        case ModelCancelledEvent():
          throw const AgentCancelledException(message: 'Cancelled.');
      }
    }

    return ModelResponse(
      text: text.isEmpty ? null : text.toString(),
      toolCalls: toolCalls,
      structuredOutput: structuredOutput,
      usage: usage,
    );
  }
}
