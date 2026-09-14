/// On-device AI agent runtime for Flutter.
///
/// This package owns local model providers, the agent loop, sessions, tool
/// call protocol, streaming, capability detection, and normalized errors.
/// Consumers such as `ensemble_chat` supply tool execution via [ToolHandler]
/// and must not be imported by this package.
library ensemble_agent;

import 'src/providers/provider_factory.dart';

export 'src/agent/agent.dart';
export 'src/agent/agent_event.dart';
export 'src/agent/agent_types.dart';
export 'src/capabilities/agent_capabilities.dart';
export 'src/capabilities/ensemble_agent_capabilities.dart';
export 'src/errors/agent_exception.dart';
export 'src/providers/fake_local_model_provider.dart';
export 'src/providers/local_model_provider.dart';
export 'src/providers/model_types.dart';
export 'src/providers/platform_local_model_provider.dart';
export 'src/session/agent_session.dart';
export 'src/tools/agent_tool.dart';
export 'src/tracing/agent_trace.dart';

/// Side-effect: register the system [LocalModelProvider] factory.
// ignore: unused_element
final bool _ensembleAgentSystemProviderRegistered = () {
  ensureSystemProviderRegistered();
  return true;
}();
