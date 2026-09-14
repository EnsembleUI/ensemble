import '../providers/local_model_provider.dart';
import 'agent_capabilities.dart';

/// Convenience entry point for querying current device capabilities.
class EnsembleAgentCapabilities {
  EnsembleAgentCapabilities._();

  /// Returns capabilities for the active system provider.
  static Future<AgentCapabilities> current() async {
    final provider = await LocalModelProvider.system();
    return provider.getCapabilities();
  }
}
