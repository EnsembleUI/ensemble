import 'dart:convert';

import '../tools/agent_tool.dart';

/// Ensemble-owned Path B tool protocol for providers without native tool calling
/// (e.g. Android Gemini Nano / ML Kit Prompt API).
abstract final class ToolCallProtocol {
  static const toolCallType = 'tool_call';
  static const finalType = 'final';

  /// Instructions appended so the model emits only protocol JSON.
  static String instructionsFor(List<AgentTool> tools) {
    final catalog = tools
        .map((t) => {
              'name': t.name,
              'description': t.description,
              'inputSchema': t.inputSchema,
            })
        .toList();
    return '''
You must respond with a single JSON object only (no markdown, no prose).

When you need a tool:
{"type":"$toolCallType","id":"<unique_id>","name":"<tool_name>","arguments":{...}}

When you can answer the user:
{"type":"$finalType","text":"<answer>"}

Available tools:
${jsonEncode(catalog)}
''';
  }

  /// Parses a model text response into a protocol message.
  static ProtocolMessage parse(
    String text, {
    required Set<String> allowedToolNames,
  }) {
    final decoded = _extractJsonObject(text);
    if (decoded == null) {
      throw const ProtocolParseException(
        'Model response was not a valid JSON protocol object.',
      );
    }

    final type = decoded['type'] as String?;
    if (type == finalType) {
      return ProtocolFinal(text: decoded['text']?.toString() ?? '');
    }
    if (type == toolCallType) {
      final name = decoded['name'] as String?;
      if (name == null || name.isEmpty) {
        throw const ProtocolParseException('tool_call is missing name.');
      }
      if (!allowedToolNames.contains(name)) {
        throw ProtocolParseException('Unknown tool "$name".');
      }
      final id = decoded['id']?.toString().isNotEmpty == true
          ? decoded['id'].toString()
          : 'call_${name}_${DateTime.now().millisecondsSinceEpoch}';
      final argsRaw = decoded['arguments'];
      final arguments = argsRaw is Map
          ? Map<String, dynamic>.from(argsRaw)
          : <String, dynamic>{};
      return ProtocolToolCall(
        call: ToolCall(id: id, name: name, arguments: arguments),
      );
    }
    throw ProtocolParseException('Unknown protocol type: $type');
  }

  static Map<String, dynamic>? _extractJsonObject(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```', multiLine: true);
    final fenceMatch = fence.firstMatch(trimmed);
    final candidate =
        fenceMatch != null ? fenceMatch.group(1)!.trim() : trimmed;

    try {
      final decoded = jsonDecode(candidate);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      // Fall through.
    }

    final start = candidate.indexOf('{');
    final end = candidate.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        final decoded = jsonDecode(candidate.substring(start, end + 1));
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } on FormatException {
        return null;
      }
    }
    return null;
  }
}

sealed class ProtocolMessage {
  const ProtocolMessage();
}

class ProtocolToolCall extends ProtocolMessage {
  const ProtocolToolCall({required this.call});

  final ToolCall call;
}

class ProtocolFinal extends ProtocolMessage {
  const ProtocolFinal({required this.text});

  final String text;
}

class ProtocolParseException implements Exception {
  const ProtocolParseException(this.message);

  final String message;

  @override
  String toString() => 'ProtocolParseException: $message';
}
