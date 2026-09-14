import '../capabilities/agent_capabilities.dart';
import 'model_types.dart';

/// Abstraction over Apple Foundation Models, Gemini Nano, fakes, etc.
abstract class LocalModelProvider {
  String get id;

  Future<AgentCapabilities> getCapabilities();

  Future<ModelResponse> generate(ModelRequest request);

  Stream<ModelEvent> stream(ModelRequest request);

  Future<void> cancel(String requestId);

  /// Returns the platform-appropriate system on-device provider.
  static Future<LocalModelProvider> system() =>
      LocalModelProviderFactory.system();
}

/// Factory for constructing system / explicit providers.
class LocalModelProviderFactory {
  LocalModelProviderFactory._();

  static Future<LocalModelProvider> Function()? _systemOverride;
  static Future<LocalModelProvider> Function()? _systemImpl;

  /// Called by the package barrel to register the real system factory.
  static void registerSystemImpl(
    Future<LocalModelProvider> Function() impl,
  ) {
    _systemImpl = impl;
  }

  /// Override used by tests.
  static void debugSetSystemProvider(
    Future<LocalModelProvider> Function()? loader,
  ) {
    _systemOverride = loader;
  }

  static Future<LocalModelProvider> system() async {
    final override = _systemOverride;
    if (override != null) return override();
    final impl = _systemImpl;
    if (impl == null) {
      throw StateError(
        'System provider is not registered. '
        'Import package:ensemble_agent/ensemble_agent.dart first.',
      );
    }
    return impl();
  }
}
