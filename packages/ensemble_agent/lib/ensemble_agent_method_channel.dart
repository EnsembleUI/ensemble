import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ensemble_agent_platform_interface.dart';
import 'src/capabilities/agent_capabilities.dart';
import 'src/errors/agent_exception.dart';
import 'src/providers/model_types.dart';

/// Method-channel implementation of [EnsembleAgentPlatform].
class MethodChannelEnsembleAgent extends EnsembleAgentPlatform {
  /// Visible for tests.
  @visibleForTesting
  final methodChannel = const MethodChannel('ensemble_agent');

  /// Event channel used for streaming model events.
  @visibleForTesting
  final eventChannel = const EventChannel('ensemble_agent/events');

  @override
  Future<AgentCapabilities> getCapabilities() async {
    try {
      final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
        'getCapabilities',
      );
      return AgentCapabilities.fromMap(
        Map<String, dynamic>.from(result ?? const {}),
      );
    } on PlatformException catch (e) {
      throw AgentUnavailableException(
        message: e.message ?? 'Failed to query agent capabilities.',
        reason: AgentUnavailableReason.providerError,
        providerCode: e.code,
        cause: e,
      );
    }
  }

  @override
  Future<ModelResponse> generate(ModelRequest request) async {
    try {
      final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
        'generate',
        request.toMap(),
      );
      return ModelResponse.fromMap(
        Map<String, dynamic>.from(result ?? const {}),
      );
    } on PlatformException catch (e) {
      throw _mapPlatformException(e);
    }
  }

  @override
  Stream<ModelEvent> stream(ModelRequest request) {
    final controller = StreamController<ModelEvent>();
    late StreamSubscription<dynamic> subscription;

    Future<void> start() async {
      try {
        await methodChannel.invokeMethod<void>('stream', request.toMap());
      } on PlatformException catch (e) {
        if (!controller.isClosed) {
          controller.addError(_mapPlatformException(e));
          await controller.close();
        }
        return;
      }

      subscription = eventChannel.receiveBroadcastStream(request.requestId).listen(
        (event) {
          if (event is! Map) return;
          final modelEvent = ModelEvent.fromMap(
            Map<String, dynamic>.from(event),
          );
          controller.add(modelEvent);
          if (modelEvent is ModelCompletedEvent ||
              modelEvent is ModelFailedEvent ||
              modelEvent is ModelCancelledEvent) {
            unawaited(controller.close());
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (error is PlatformException) {
            controller.addError(_mapPlatformException(error), stackTrace);
          } else {
            controller.addError(error, stackTrace);
          }
          unawaited(controller.close());
        },
        onDone: () {
          unawaited(controller.close());
        },
        cancelOnError: true,
      );
    }

    controller.onCancel = () async {
      await methodChannel.invokeMethod<void>('cancel', {
        'requestId': request.requestId,
      });
      await subscription.cancel();
    };

    unawaited(start());
    return controller.stream;
  }

  @override
  Future<void> cancel(String requestId) async {
    try {
      await methodChannel.invokeMethod<void>('cancel', {
        'requestId': requestId,
      });
    } on PlatformException catch (e) {
      throw _mapPlatformException(e);
    }
  }

  AgentException _mapPlatformException(PlatformException e) {
    switch (e.code) {
      case 'unsupported_device':
        return UnsupportedDeviceException(
          message: e.message ?? 'On-device model is not supported.',
          providerCode: e.code,
          cause: e,
        );
      case 'unsupported_capability':
        return UnsupportedCapabilityException(
          message: e.message ?? 'Requested capability is not supported.',
          providerCode: e.code,
          cause: e,
        );
      case 'cancelled':
        return AgentCancelledException(
          message: e.message ?? 'Request was cancelled.',
          providerCode: e.code,
          cause: e,
        );
      case 'timeout':
        return AgentTimeoutException(
          message: e.message ?? 'Request timed out.',
          providerCode: e.code,
          cause: e,
        );
      case 'unavailable':
        return AgentUnavailableException(
          message: e.message ?? 'On-device agent is unavailable.',
          reason: AgentUnavailableReason.modelUnavailable,
          providerCode: e.code,
          cause: e,
        );
      default:
        return ModelExecutionException(
          message: e.message ?? 'Model execution failed.',
          providerCode: e.code,
          cause: e,
          metadata: e.details is Map
              ? Map<String, dynamic>.from(e.details as Map)
              : null,
        );
    }
  }
}
