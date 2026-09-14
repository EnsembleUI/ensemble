import '../capabilities/agent_capabilities.dart';
import '../errors/agent_exception.dart';
import 'local_model_provider.dart';
import 'model_types.dart';

/// Provider used when the current OS cannot host an on-device model.
class UnsupportedLocalModelProvider implements LocalModelProvider {
  const UnsupportedLocalModelProvider({
    required this.id,
    required this.reason,
    required this.message,
  });

  @override
  final String id;
  final AgentUnavailableReason reason;
  final String message;

  @override
  Future<AgentCapabilities> getCapabilities() async => AgentCapabilities(
        available: false,
        provider: id,
        unavailableReason: reason,
      );

  @override
  Future<ModelResponse> generate(ModelRequest request) async {
    throw AgentUnavailableException(message: message, reason: reason);
  }

  @override
  Stream<ModelEvent> stream(ModelRequest request) async* {
    throw AgentUnavailableException(message: message, reason: reason);
  }

  @override
  Future<void> cancel(String requestId) async {}
}
