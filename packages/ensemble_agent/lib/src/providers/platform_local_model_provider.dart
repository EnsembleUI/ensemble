import '../../ensemble_agent_platform_interface.dart';
import '../capabilities/agent_capabilities.dart';
import 'local_model_provider.dart';
import 'model_types.dart';

/// [LocalModelProvider] backed by the Flutter plugin platform interface.
class PlatformLocalModelProvider implements LocalModelProvider {
  PlatformLocalModelProvider({
    required this.id,
    EnsembleAgentPlatform? platform,
  }) : _platform = platform ?? EnsembleAgentPlatform.instance;

  @override
  final String id;

  final EnsembleAgentPlatform _platform;

  @override
  Future<AgentCapabilities> getCapabilities() => _platform.getCapabilities();

  @override
  Future<ModelResponse> generate(ModelRequest request) =>
      _platform.generate(request);

  @override
  Stream<ModelEvent> stream(ModelRequest request) =>
      _platform.stream(request);

  @override
  Future<void> cancel(String requestId) => _platform.cancel(requestId);
}
