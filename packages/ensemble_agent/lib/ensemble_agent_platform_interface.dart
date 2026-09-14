import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ensemble_agent_method_channel.dart';
import 'src/capabilities/agent_capabilities.dart';
import 'src/providers/model_types.dart';

/// Platform interface for native on-device model adapters.
abstract class EnsembleAgentPlatform extends PlatformInterface {
  EnsembleAgentPlatform() : super(token: _token);

  static final Object _token = Object();

  static EnsembleAgentPlatform _instance = MethodChannelEnsembleAgent();

  /// The default instance of [EnsembleAgentPlatform] to use.
  static EnsembleAgentPlatform get instance => _instance;

  /// Platform-specific implementations should set this when they register.
  static set instance(EnsembleAgentPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Returns current on-device model capabilities for this device.
  Future<AgentCapabilities> getCapabilities() {
    throw UnimplementedError('getCapabilities() has not been implemented.');
  }

  /// Runs a single non-streaming generation request.
  Future<ModelResponse> generate(ModelRequest request) {
    throw UnimplementedError('generate() has not been implemented.');
  }

  /// Streams generation events for [request].
  Stream<ModelEvent> stream(ModelRequest request) {
    throw UnimplementedError('stream() has not been implemented.');
  }

  /// Cancels an in-flight request identified by [requestId].
  Future<void> cancel(String requestId) {
    throw UnimplementedError('cancel() has not been implemented.');
  }
}
