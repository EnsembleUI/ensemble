import 'dart:async';

import 'package:ensemble_ts_interpreter/invokables/invokable.dart';

/// Result sent by an Ensemble action in response to a model tool call.
class EnsembleToolResponse {
  const EnsembleToolResponse({
    required this.callId,
    required this.status,
    this.data,
    this.error,
  });

  final String callId;
  final String status;
  final dynamic data;
  final dynamic error;

  Map<String, dynamic> toMap() => {
        'callId': callId,
        'status': status,
        if (data != null) 'data': data,
        if (error != null) 'error': error,
      };
}

typedef EnsembleToolResponseHandler = FutureOr<void> Function(
    EnsembleToolResponse response);

/// Routes [respondToTool] actions back to the widget that owns the tool call.
class EnsembleToolResponseDispatcher {
  EnsembleToolResponseDispatcher._();

  static final EnsembleToolResponseDispatcher instance =
      EnsembleToolResponseDispatcher._();

  final Map<String, EnsembleToolResponseHandler> _handlers = {};

  void register(String callId, EnsembleToolResponseHandler handler) {
    _handlers[callId] = handler;
  }

  void unregister(String callId) {
    _handlers.remove(callId);
  }

  bool hasHandler(String callId) => _handlers.containsKey(callId);

  Future<void> respond(EnsembleToolResponse response) async {
    final handler = _handlers[response.callId];
    if (handler == null) {
      throw StateError('No active tool call found for ${response.callId}.');
    }
    await handler(response);
  }

  /// Attempts to deliver a response, returning false when the owning chat turn
  /// has already ended or been disposed.
  Future<bool> tryRespond(EnsembleToolResponse response) async {
    final handler = _handlers[response.callId];
    if (handler == null) return false;
    await handler(response);
    return true;
  }
}

/// Scope exposed to tool actions as `tool`.
class EnsembleToolCallContext with Invokable {
  EnsembleToolCallContext({
    required this.callId,
    required this.name,
    required this.inputs,
  });

  final String callId;
  final String name;
  final Map<String, dynamic> inputs;

  Map<String, dynamic> toMap() => {
        'callId': callId,
        'name': name,
        'inputs': inputs,
      };

  @override
  Map<String, Function> getters() => {
        'callId': () => callId,
        'name': () => name,
        'inputs': () => inputs,
      };

  @override
  Map<String, Function> methods() => {};

  @override
  Map<String, Function> setters() => {};
}
