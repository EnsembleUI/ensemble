// ignore_for_file: avoid_print

/// OpenAI chat completion client and response models.
library openai;

import 'dart:convert';

import 'package:ensemble_chat/ensemble_chat.dart';
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:collection/collection.dart';

/// Base contract for AI chat-completion clients.
abstract class AIClient {
  /// System prompt sent with each completion request.
  final String systemPrompt;

  /// Model identifier used by the completion provider.
  final String model;

  /// Sampling temperature for completions.
  final double? temperature;

  /// Optional tool definitions available to the model.
  final List<Map<String, dynamic>>? tools;

  /// Provider API key.
  final String? apiKey;

  /// Creates an AI client.
  AIClient({
    required this.model,
    required this.temperature,
    this.tools,
    required this.systemPrompt,
    this.apiKey,
  });

  /// Completes a user prompt.
  Future<Completion?> complete(String prompt);
}

/// OpenAI implementation of [AIClient].
class OpenAIClient extends AIClient {
  /// Callback that returns the current conversation history.
  List<InternalMessage> Function() getMessages;

  /// Creates an OpenAI chat-completions client.
  OpenAIClient({
    required super.model,
    required super.temperature,
    super.tools,
    required super.systemPrompt,
    super.apiKey,
    required this.getMessages,
  });

  List<Map<String, dynamic>> _getMessages(String prompt) {
    final List<Map<String, dynamic>> messages = <Map<String, dynamic>>[];
    messages.add({"role": "system", "content": systemPrompt});
    final List<InternalMessage> internalMessage = getMessages();
    for (final InternalMessage message in internalMessage) {
      final String role =
          message.role == MessageRole.system ? "assistant" : message.role.name;
      if (message.content == null) {
        messages.add({
          "role": role,
          "content": message.rawResponse != null
              ? message.rawResponse['message']['tool_calls'].first['function']
                  ['name']
              : message.inlineWidget.keys.last,
        });
      } else {
        messages.add({"role": role, "content": message.content});
      }
    }

    return messages;
  }

  /// Updates a completion choice with tool metadata when a tool was selected.
  void updateTool(Completion response) {
    if (response.choices.firstOrNull?.finishReason == 'tool_calls') {
      final dynamic toolName =
          response.choices.firstOrNull?.inlineWidget?.keys.firstOrNull;
      if (toolName == null) {
        return;
      }

      final Map<String, dynamic>? tool = tools?.firstWhereOrNull(
          (element) => element['function']['name'] == toolName);

      if (tool == null) {
        return;
      }

      response.choices.first.tool = tool;
      final MessageType? newMessageType = MessageType.values.firstWhereOrNull(
          (element) => element.name.toString() == tool['function']['toolType']);
      if (newMessageType == null) {
        return;
      }
      response.choices.first.messageType = newMessageType;
    }
  }

  @override
  Future<Completion?> complete(String prompt) async {
    final url = Uri.parse("https://api.openai.com/v1/chat/completions");
    _getMessages(prompt);
    final data = {
      "model": model,
      "tools": tools,
      "messages": _getMessages(prompt)
    };
    final headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $apiKey"
    };

    final response =
        await http.post(url, body: jsonEncode(data), headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Error: ${response.body}');
    }

    final result = Completion.fromJson(response.body);
    updateTool(result);
    return result;
  }
}

/// Response returned by a chat-completion request.
class Completion {
  /// Creates a completion response.
  Completion({
    required this.id,
    required this.object,
    required this.created,
    required this.model,
    required this.choices,
    required this.usage,
  });

  /// Creates a [Completion] from a JSON string.
  factory Completion.fromJson(String data) {
    return Completion.fromMap(json.decode(data) as Map<String, dynamic>);
  }

  /// Creates a [Completion] from decoded map data.
  factory Completion.fromMap(Map<String, dynamic> data) => Completion(
        id: data['id'] as String,
        object: data['object'] as String,
        created: data['created'] as int,
        model: data['model'] as String,
        choices: (data['choices'] as List<dynamic>)
            .map((e) => Choice.fromMap(e as Map<String, dynamic>))
            .toList(),
        usage: Usage.fromMap(data['usage'] as Map<String, dynamic>),
      );

  /// Completion identifier.
  final String id;

  /// OpenAI object type.
  final String object;

  /// Creation timestamp.
  final int created;

  /// Model that produced the completion.
  final String model;

  /// Completion choices.
  final List<Choice> choices;

  /// Token usage for the completion.
  final Usage usage;

  /// Converts this completion to map data.
  Map<String, dynamic> toMap() => {
        'id': id,
        'object': object,
        'created': created,
        'model': model,
        'choices': choices.map((e) => e.toMap()).toList(),
        'usage': usage.toMap(),
      };

  /// Converts this completion to JSON.
  String toJson() => json.encode(toMap());

  /// Values used for equality-style comparisons.
  List<Object?> get props => [id, object, created, model, choices, usage];
}

/// A single completion choice.
class Choice {
  /// Creates a completion choice.
  Choice({
    this.text,
    this.message,
    required this.index,
    this.logprobs,
    this.finishReason,
    this.messageType = MessageType.message,
  });

  /// Creates a [Choice] from a JSON string.
  factory Choice.fromJson(String data) {
    return Choice.fromMap(json.decode(data) as Map<String, dynamic>);
  }

  /// Creates a [Choice] from decoded map data.
  factory Choice.fromMap(Map<String, dynamic> data) => Choice(
        text: data['text'],
        message: data['message'],
        index: data['index'] as int,
        logprobs: data['logprobs'] as dynamic,
        finishReason: data['finish_reason'] as String?,
      );

  /// Text content for legacy completion responses.
  final String? text;

  /// Chat message payload.
  final Map? message;

  /// Choice index in the response.
  final int index;

  /// Optional log probability payload.
  final dynamic logprobs;

  /// Finish reason returned by the model.
  final String? finishReason;

  /// How Ensemble should render or execute this choice.
  MessageType messageType;

  /// Tool definition associated with this choice.
  dynamic tool;

  /// Converts this choice to map data.
  Map<String, dynamic> toMap() => {
        'text': text,
        'index': index,
        'logprobs': logprobs,
        'finish_reason': finishReason,
        'message': message,
        'messageType': messageType.name,
      };

  /// Values used for equality-style comparisons.
  List<Object?> get props => [text, index, logprobs, finishReason];

  /// Message text returned by this choice.
  String? get getMessage => text ?? message?['content'];

  /// Inline widget tool call requested by this choice, when present.
  Map? get inlineWidget {
    final dynamic function =
        (message?['tool_calls'] as List?)?.firstOrNull?['function'];
    if (function == null) {
      return null;
    }

    return {function['name']: function['arguments']};
  }
}

/// Token usage metadata for a completion.
class Usage {
  /// Creates usage metadata.
  const Usage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });

  /// Creates [Usage] from decoded map data.
  factory Usage.fromMap(Map<String, dynamic> data) => Usage(
        promptTokens: data['prompt_tokens'] as int,
        completionTokens: data['completion_tokens'] as int,
        totalTokens: data['total_tokens'] as int,
      );

  /// Creates [Usage] from a JSON string.
  factory Usage.fromJson(String data) {
    return Usage.fromMap(json.decode(data) as Map<String, dynamic>);
  }

  /// Prompt token count.
  final int promptTokens;

  /// Completion token count.
  final int completionTokens;

  /// Total token count.
  final int totalTokens;

  /// Converts this usage object to map data.
  Map<String, dynamic> toMap() => {
        'prompt_tokens': promptTokens,
        'completion_tokens': completionTokens,
        'total_tokens': totalTokens,
      };

  /// Values used for equality-style comparisons.
  List<Object?> get props {
    return [
      promptTokens,
      completionTokens,
      totalTokens,
    ];
  }
}

/// Render or execution mode for a completion choice.
enum MessageType { message, inlineWidget, action }
