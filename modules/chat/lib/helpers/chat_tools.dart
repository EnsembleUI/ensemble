import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/util/utils.dart';

enum ChatToolKind { inlineWidget, legacyAction, appTool }

/// A model-callable tool declared by an Ensemble application.
class ChatToolDefinition {
  ChatToolDefinition({
    required this.name,
    required this.description,
    required this.inputs,
    required this.kind,
    this.action,
    this.options = const {},
  });

  final String name;
  final String description;
  final Map<String, dynamic> inputs;
  final ChatToolKind kind;
  final EnsembleAction? action;
  final Map<String, dynamic> options;

  int get timeoutSeconds {
    final value = options['timeout'];
    if (value is num && value > 0) return value.toInt();
    return 15;
  }

  dynamic get confirmation => options['confirmation'];

  Map<String, dynamic> prepareInputs(Map<String, dynamic> supplied) {
    final prepared = Map<String, dynamic>.from(supplied);
    for (final entry in inputs.entries) {
      final schema = entry.value is Map
          ? Map<String, dynamic>.from(entry.value as Map)
          : <String, dynamic>{'type': entry.value};
      if (!prepared.containsKey(entry.key) && schema.containsKey('default')) {
        prepared[entry.key] = schema['default'];
      }
      if (schema['required'] == true && !prepared.containsKey(entry.key)) {
        throw FormatException("Missing required input '${entry.key}'.");
      }
      if (prepared.containsKey(entry.key)) {
        _validateValue(prepared[entry.key], schema, entry.key);
      }
    }
    final unknown = prepared.keys.where((key) => !inputs.containsKey(key));
    if (unknown.isNotEmpty) {
      throw FormatException('Unknown tool input(s): ${unknown.join(', ')}.');
    }
    return prepared;
  }

  void _validateValue(dynamic value, Map<String, dynamic> schema, String path) {
    final allOf = schema['allOf'];
    if (allOf is List) {
      for (final child in allOf.whereType<Map>()) {
        _validateValue(value, Map<String, dynamic>.from(child), path);
      }
    }

    final anyOf = schema['anyOf'];
    if (anyOf is List && !_matchesAnySchema(value, anyOf, path)) {
      throw FormatException("Input '$path' does not match any allowed schema.");
    }

    final oneOf = schema['oneOf'];
    if (oneOf is List && _matchingSchemaCount(value, oneOf, path) != 1) {
      throw FormatException(
          "Input '$path' must match exactly one allowed schema.");
    }

    final type = schema['type'];
    if (!_matchesType(value, type)) {
      throw FormatException("Input '$path' must be ${_describeType(type)}.");
    }

    if (schema.containsKey('const') &&
        !const DeepCollectionEquality().equals(value, schema['const'])) {
      throw FormatException("Input '$path' must equal ${schema['const']}.");
    }
    final allowed = schema['enum'];
    if (allowed is List &&
        !allowed.any(
            (item) => const DeepCollectionEquality().equals(item, value))) {
      throw FormatException(
          "Input '$path' must be one of ${allowed.join(', ')}.");
    }

    if (value is String) {
      final minLength = schema['minLength'];
      final maxLength = schema['maxLength'];
      if (minLength is num && value.length < minLength) {
        throw FormatException(
            "Input '$path' is shorter than $minLength characters.");
      }
      if (maxLength is num && value.length > maxLength) {
        throw FormatException(
            "Input '$path' is longer than $maxLength characters.");
      }
      final pattern = schema['pattern'];
      if (pattern is String && !RegExp(pattern).hasMatch(value)) {
        throw FormatException("Input '$path' has an invalid format.");
      }
    } else if (value is num) {
      _validateNumber(value, schema, path);
    } else if (value is List) {
      _validateArray(value, schema, path);
    } else if (value is Map) {
      _validateObject(value, schema, path);
    }
  }

  void _validateNumber(num value, Map<String, dynamic> schema, String path) {
    final minimum = schema['minimum'];
    final maximum = schema['maximum'];
    final exclusiveMinimum = schema['exclusiveMinimum'];
    final exclusiveMaximum = schema['exclusiveMaximum'];
    if (minimum is num && value < minimum) {
      throw FormatException("Input '$path' must be at least $minimum.");
    }
    if (maximum is num && value > maximum) {
      throw FormatException("Input '$path' must be at most $maximum.");
    }
    if (exclusiveMinimum is num && value <= exclusiveMinimum) {
      throw FormatException(
          "Input '$path' must be greater than $exclusiveMinimum.");
    }
    if (exclusiveMaximum is num && value >= exclusiveMaximum) {
      throw FormatException(
          "Input '$path' must be less than $exclusiveMaximum.");
    }
  }

  void _validateArray(
      List<dynamic> value, Map<String, dynamic> schema, String path) {
    final minItems = schema['minItems'];
    final maxItems = schema['maxItems'];
    if (minItems is num && value.length < minItems) {
      throw FormatException(
          "Input '$path' must contain at least $minItems item(s).");
    }
    if (maxItems is num && value.length > maxItems) {
      throw FormatException(
          "Input '$path' must contain at most $maxItems item(s).");
    }
    if (schema['uniqueItems'] == true) {
      for (var index = 0; index < value.length; index++) {
        if (value.take(index).any((item) =>
            const DeepCollectionEquality().equals(item, value[index]))) {
          throw FormatException("Input '$path' must contain unique items.");
        }
      }
    }
    final items = schema['items'];
    if (items is Map) {
      final itemSchema = Map<String, dynamic>.from(items);
      for (var index = 0; index < value.length; index++) {
        _validateValue(value[index], itemSchema, '$path[$index]');
      }
    }
  }

  void _validateObject(
      Map<dynamic, dynamic> value, Map<String, dynamic> schema, String path) {
    final properties = schema['properties'] is Map
        ? Map<String, dynamic>.from(schema['properties'] as Map)
        : const <String, dynamic>{};
    final required = schema['required'] is List
        ? (schema['required'] as List).map((item) => item.toString()).toSet()
        : const <String>{};
    for (final name in required) {
      if (!value.containsKey(name)) {
        throw FormatException("Missing required input '$path.$name'.");
      }
    }
    if (schema['additionalProperties'] == false) {
      final unknown = value.keys.where((key) => !properties.containsKey(key));
      if (unknown.isNotEmpty) {
        throw FormatException(
            "Unknown input(s) in '$path': ${unknown.join(', ')}.");
      }
    }
    for (final entry in properties.entries) {
      if (!value.containsKey(entry.key)) continue;
      final childSchema = entry.value is Map
          ? Map<String, dynamic>.from(entry.value as Map)
          : <String, dynamic>{'type': entry.value};
      _validateValue(value[entry.key], childSchema, '$path.${entry.key}');
    }
  }

  bool _matchesAnySchema(dynamic value, List<dynamic> schemas, String path) =>
      _matchingSchemaCount(value, schemas, path) > 0;

  int _matchingSchemaCount(dynamic value, List<dynamic> schemas, String path) {
    var matches = 0;
    for (final child in schemas.whereType<Map>()) {
      try {
        _validateValue(value, Map<String, dynamic>.from(child), path);
        matches++;
      } on FormatException {
        // A union member that does not match is expected.
      }
    }
    return matches;
  }

  bool _matchesType(dynamic value, dynamic type) {
    if (type == null) return true;
    if (type is List) {
      return type.any((candidate) => _matchesType(value, candidate));
    }
    return switch (type) {
      'null' => value == null,
      'boolean' => value is bool,
      'string' => value is String,
      'integer' => value is int,
      'number' => value is num,
      'array' => value is List,
      'object' => value is Map,
      _ => true,
    };
  }

  String _describeType(dynamic type) =>
      type is List ? type.join(' or ') : type?.toString() ?? 'valid';

  Map<String, dynamic> toOpenAITool() {
    final properties = <String, dynamic>{};
    final required = <String>[];
    for (final entry in inputs.entries) {
      final rawSchema = entry.value;
      final schema = rawSchema is Map
          ? Map<String, dynamic>.from(rawSchema)
          : <String, dynamic>{'type': rawSchema};
      if (schema.remove('required') == true) required.add(entry.key);
      schema.remove('default');
      properties[entry.key] = schema;
    }

    return {
      'type': 'function',
      'function': {
        'name': name,
        'description': description,
        'parameters': {
          'type': 'object',
          'properties': properties,
          if (required.isNotEmpty) 'required': required,
          'additionalProperties': false,
        },
      },
    };
  }
}

/// A tool invocation returned by a chat-completion model.
class ChatToolCall {
  ChatToolCall({
    required this.id,
    required this.name,
    required this.inputs,
  });

  final String id;
  final String name;
  final Map<String, dynamic> inputs;

  factory ChatToolCall.fromOpenAI(Map call) {
    final function = call['function'];
    final arguments = function is Map ? function['arguments'] : null;
    dynamic decoded = arguments;
    if (arguments is String && arguments.trim().isNotEmpty) {
      decoded = jsonDecode(arguments);
    }
    return ChatToolCall(
      id: call['id']?.toString() ?? Utils.generateRandomId(12),
      name: function is Map ? function['name']?.toString() ?? '' : '',
      inputs: decoded is Map ? Map<String, dynamic>.from(decoded) : {},
    );
  }
}

/// Terminal value returned to the model after an app tool executes.
class ChatToolResult {
  ChatToolResult({
    required this.callId,
    required this.name,
    required this.status,
    this.data,
    this.error,
  });

  final String callId;
  final String name;
  final String status;
  final dynamic data;
  final dynamic error;

  Map<String, dynamic> toModelOutput() => {
        'status': status,
        if (data != null) 'data': data,
        if (error != null) 'error': error,
      };
}
