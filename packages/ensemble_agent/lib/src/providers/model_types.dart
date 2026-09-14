import '../agent/agent_types.dart';
import '../tools/agent_tool.dart';

/// Provider-neutral request sent to a local model.
class ModelRequest {
  const ModelRequest({
    required this.requestId,
    required this.messages,
    this.instructions,
    this.tools = const [],
    this.outputSchema,
    this.stream = false,
  });

  final String requestId;
  final List<ModelMessage> messages;
  final String? instructions;
  final List<AgentTool> tools;
  final Map<String, dynamic>? outputSchema;
  final bool stream;

  Map<String, dynamic> toMap() => {
        'requestId': requestId,
        'messages': messages.map((m) => m.toMap()).toList(),
        if (instructions != null) 'instructions': instructions,
        'tools': tools.map((t) => t.toMap()).toList(),
        if (outputSchema != null) 'outputSchema': outputSchema,
        'stream': stream,
      };
}

/// A single turn in provider conversation history.
class ModelMessage {
  const ModelMessage({
    required this.role,
    this.text,
    this.toolCalls,
    this.toolCallId,
    this.toolResult,
  });

  final ModelMessageRole role;
  final String? text;
  final List<ToolCall>? toolCalls;
  final String? toolCallId;
  final ToolResult? toolResult;

  Map<String, dynamic> toMap() => {
        'role': role.name,
        if (text != null) 'text': text,
        if (toolCalls != null)
          'toolCalls': toolCalls!.map((c) => c.toMap()).toList(),
        if (toolCallId != null) 'toolCallId': toolCallId,
        if (toolResult != null) 'toolResult': toolResult!.toMap(),
      };

  factory ModelMessage.user(String text) =>
      ModelMessage(role: ModelMessageRole.user, text: text);

  factory ModelMessage.assistant({
    String? text,
    List<ToolCall>? toolCalls,
  }) =>
      ModelMessage(
        role: ModelMessageRole.assistant,
        text: text,
        toolCalls: toolCalls,
      );

  factory ModelMessage.tool({
    required String toolCallId,
    required ToolResult result,
  }) =>
      ModelMessage(
        role: ModelMessageRole.tool,
        toolCallId: toolCallId,
        toolResult: result,
      );
}

enum ModelMessageRole { system, user, assistant, tool }

/// Non-streaming model response.
class ModelResponse {
  const ModelResponse({
    this.text,
    this.toolCalls = const [],
    this.structuredOutput,
    this.usage,
    this.finishReason = AgentFinishReason.completed,
  });

  final String? text;
  final List<ToolCall> toolCalls;
  final dynamic structuredOutput;
  final AgentUsage? usage;
  final AgentFinishReason finishReason;

  bool get hasToolCalls => toolCalls.isNotEmpty;

  factory ModelResponse.fromMap(Map<String, dynamic> map) {
    final rawCalls = map['toolCalls'];
    return ModelResponse(
      text: map['text'] as String?,
      toolCalls: rawCalls is List
          ? rawCalls
              .whereType<Map>()
              .map((e) => ToolCall.fromMap(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      structuredOutput: map['structuredOutput'],
      usage: map['usage'] is Map
          ? AgentUsage.fromMap(Map<String, dynamic>.from(map['usage'] as Map))
          : null,
      finishReason: _parseFinishReason(map['finishReason'] as String?),
    );
  }

  Map<String, dynamic> toMap() => {
        if (text != null) 'text': text,
        'toolCalls': toolCalls.map((c) => c.toMap()).toList(),
        if (structuredOutput != null) 'structuredOutput': structuredOutput,
        if (usage != null) 'usage': usage!.toMap(),
        'finishReason': finishReason.name,
      };
}

AgentFinishReason _parseFinishReason(String? value) {
  if (value == null) return AgentFinishReason.completed;
  for (final reason in AgentFinishReason.values) {
    if (reason.name == value) return reason;
  }
  return AgentFinishReason.completed;
}

/// Streaming events from a local model provider.
sealed class ModelEvent {
  const ModelEvent();

  factory ModelEvent.fromMap(Map<String, dynamic> map) {
    switch (map['type'] as String?) {
      case 'textDelta':
        return ModelTextDeltaEvent(delta: map['delta'] as String? ?? '');
      case 'toolCall':
        return ModelToolCallEvent(
          call: ToolCall.fromMap(
            Map<String, dynamic>.from(map['toolCall'] as Map? ?? map),
          ),
        );
      case 'completed':
        return ModelCompletedEvent(
          response: ModelResponse.fromMap(
            Map<String, dynamic>.from(map['response'] as Map? ?? map),
          ),
        );
      case 'failed':
        return ModelFailedEvent(
          message: map['message'] as String? ?? 'Model failed.',
          code: map['code'] as String?,
        );
      case 'cancelled':
        return const ModelCancelledEvent();
      default:
        return ModelFailedEvent(
          message: 'Unknown model event type: ${map['type']}',
        );
    }
  }
}

class ModelTextDeltaEvent extends ModelEvent {
  const ModelTextDeltaEvent({required this.delta});

  final String delta;
}

class ModelToolCallEvent extends ModelEvent {
  const ModelToolCallEvent({required this.call});

  final ToolCall call;
}

class ModelCompletedEvent extends ModelEvent {
  const ModelCompletedEvent({required this.response});

  final ModelResponse response;
}

class ModelFailedEvent extends ModelEvent {
  const ModelFailedEvent({required this.message, this.code});

  final String message;
  final String? code;
}

class ModelCancelledEvent extends ModelEvent {
  const ModelCancelledEvent();
}
