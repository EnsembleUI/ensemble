/// LLM-facing tool definition. Provider adapters convert this to native forms.
class AgentTool {
  const AgentTool({
    required this.name,
    required this.description,
    this.inputSchema = const {},
    this.metadata,
  });

  final String name;
  final String description;

  /// JSON-schema-like map of parameter name → schema object.
  final Map<String, dynamic> inputSchema;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'inputSchema': inputSchema,
        if (metadata != null) 'metadata': metadata,
      };

  factory AgentTool.fromMap(Map<String, dynamic> map) {
    return AgentTool(
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      inputSchema: Map<String, dynamic>.from(
        (map['inputSchema'] as Map?) ?? const {},
      ),
      metadata: map['metadata'] is Map
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : null,
    );
  }
}

/// A model-requested tool invocation.
class ToolCall {
  const ToolCall({
    required this.id,
    required this.name,
    this.arguments = const {},
  });

  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'arguments': arguments,
      };

  factory ToolCall.fromMap(Map<String, dynamic> map) {
    return ToolCall(
      id: map['id'] as String? ?? map['callId'] as String? ?? '',
      name: map['name'] as String,
      arguments: Map<String, dynamic>.from(
        (map['arguments'] as Map?) ?? const {},
      ),
    );
  }
}

/// Callback used by the runtime to execute a tool outside this package.
typedef ToolHandler = Future<ToolResult> Function(ToolCall call);

/// Provider-neutral tool execution result.
sealed class ToolResult {
  const ToolResult();

  factory ToolResult.success({dynamic data, Map<String, dynamic>? metadata}) {
    return ToolSuccess(data: data, metadata: metadata);
  }

  factory ToolResult.error({
    required String code,
    required String message,
    bool retryable = false,
    Map<String, dynamic>? metadata,
  }) {
    return ToolFailure(
      code: code,
      message: message,
      retryable: retryable,
      metadata: metadata,
    );
  }

  Map<String, dynamic> toMap();
}

class ToolSuccess extends ToolResult {
  const ToolSuccess({this.data, this.metadata});

  final dynamic data;
  final Map<String, dynamic>? metadata;

  @override
  Map<String, dynamic> toMap() => {
        'status': 'success',
        'data': data,
        if (metadata != null) 'metadata': metadata,
      };
}

class ToolFailure extends ToolResult {
  const ToolFailure({
    required this.code,
    required this.message,
    this.retryable = false,
    this.metadata,
  });

  final String code;
  final String message;
  final bool retryable;
  final Map<String, dynamic>? metadata;

  @override
  Map<String, dynamic> toMap() => {
        'status': 'error',
        'error': {
          'code': code,
          'message': message,
          'retryable': retryable,
        },
        if (metadata != null) 'metadata': metadata,
      };
}
