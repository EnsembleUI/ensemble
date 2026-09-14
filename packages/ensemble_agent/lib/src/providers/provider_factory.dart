import 'package:flutter/foundation.dart';

import '../../ensemble_agent_platform_interface.dart';
import '../capabilities/agent_capabilities.dart';
import 'local_model_provider.dart';
import 'platform_local_model_provider.dart';
import 'unsupported_local_model_provider.dart';

/// Builds the default on-device provider for the current platform.
Future<LocalModelProvider> createSystemLocalModelProvider() async {
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return PlatformLocalModelProvider(
        id: 'apple_foundation_models',
        platform: EnsembleAgentPlatform.instance,
      );
    case TargetPlatform.android:
      return PlatformLocalModelProvider(
        id: 'gemini_nano',
        platform: EnsembleAgentPlatform.instance,
      );
    default:
      return const UnsupportedLocalModelProvider(
        id: 'unsupported',
        reason: AgentUnavailableReason.unsupportedOS,
        message: 'On-device agents are only supported on iOS and Android.',
      );
  }
}

/// Ensures [LocalModelProviderFactory] can resolve the system provider.
void ensureSystemProviderRegistered() {
  LocalModelProviderFactory.registerSystemImpl(createSystemLocalModelProvider);
}
