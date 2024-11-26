// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:ensemble_chat/ensemble_chat.dart';
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:collection/collection.dart';

abstract class AIClient {
  final String systemPrompt;
  final String model;
  final double? temperature;
  final List<Map<String, dynamic>>? tools;
  final String? apiKey;

  AIClient({
    required this.model,
    required this.temperature,
    this.tools,
    required this.systemPrompt,
    this.apiKey,
  });

  Future<Completion?> complete(String prompt);
}

class OpenAIClient extends AIClient {
  List<InternalMessage> Function() getMessages;

  OpenAIClient({
    required super.model,
    required super.temperature,
    super.tools,
    required super.systemPrompt,
    super.apiKey,
    required this.getMessages,
  });

  List<Map> _getMessages(String prompt) {
    final messages = <Map>[];
    messages.add({"role": "system", "content": systemPrompt});
    final internalMessage = getMessages();
    for (var message in internalMessage) {
      final role =
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

  updateTool(Completion response) {
    if (response.choices.firstOrNull?.finishReason == 'tool_calls') {
      final toolName =
          response.choices.firstOrNull?.inlineWidget?.keys.firstOrNull;
      if (toolName == null) return;

      final tool = tools?.firstWhereOrNull(
          (element) => element['function']['name'] == toolName);

      if (tool == null) return;

      response.choices.first.tool = tool;
      final newMessageType = MessageType.values.firstWhereOrNull(
          (element) => element.name.toString() == tool['function']['toolType']);
      if (newMessageType == null) return;
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

class Completion {
  Completion({
    required this.id,
    required this.object,
    required this.created,
    required this.model,
    required this.choices,
    required this.usage,
  });

  factory Completion.fromJson(String data) {
    return Completion.fromMap(json.decode(data) as Map<String, dynamic>);
  }

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

  final String id;
  final String object;
  final int created;
  final String model;
  final List<Choice> choices;
  final Usage usage;

  Map<String, dynamic> toMap() => {
        'id': id,
        'object': object,
        'created': created,
        'model': model,
        'choices': choices.map((e) => e.toMap()).toList(),
        'usage': usage.toMap(),
      };

  String toJson() => json.encode(toMap());

  List<Object?> get props => [id, object, created, model, choices, usage];
}

class Choice {
  Choice({
    this.text,
    this.message,
    required this.index,
    this.logprobs,
    this.finishReason,
    this.messageType = MessageType.message,
  });
  factory Choice.fromJson(String data) {
    return Choice.fromMap(json.decode(data) as Map<String, dynamic>);
  }

  factory Choice.fromMap(Map<String, dynamic> data) => Choice(
        text: data['text'],
        message: data['message'],
        index: data['index'] as int,
        logprobs: data['logprobs'] as dynamic,
        finishReason: data['finish_reason'] as String?,
      );
  final String? text;
  final Map? message;
  final int index;
  final dynamic logprobs;
  final String? finishReason;
  MessageType messageType;
  dynamic tool;

  Map<String, dynamic> toMap() => {
        'text': text,
        'index': index,
        'logprobs': logprobs,
        'finish_reason': finishReason,
        'message': message,
        'messageType': messageType.name,
      };

  List<Object?> get props => [text, index, logprobs, finishReason];

  String? get getMessage => text ?? message?['content'];
  Map? get inlineWidget {
    final function =
        (message?['tool_calls'] as List?)?.firstOrNull?['function'];
    if (function == null) return null;

    return {function['name']: function['arguments']};
  }
}

class Usage {
  const Usage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });
  factory Usage.fromMap(Map<String, dynamic> data) => Usage(
        promptTokens: data['prompt_tokens'] as int,
        completionTokens: data['completion_tokens'] as int,
        totalTokens: data['total_tokens'] as int,
      );
  factory Usage.fromJson(String data) {
    return Usage.fromMap(json.decode(data) as Map<String, dynamic>);
  }

  final int promptTokens;

  final int completionTokens;
  final int totalTokens;

  Map<String, dynamic> toMap() => {
        'prompt_tokens': promptTokens,
        'completion_tokens': completionTokens,
        'total_tokens': totalTokens,
      };

  List<Object?> get props {
    return [
      promptTokens,
      completionTokens,
      totalTokens,
    ];
  }
}

enum MessageType { message, inlineWidget, action }
