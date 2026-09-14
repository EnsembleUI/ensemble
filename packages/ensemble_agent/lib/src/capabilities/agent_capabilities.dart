/// Standardized reasons an on-device agent may be unavailable.
enum AgentUnavailableReason {
  unsupportedDevice,
  unsupportedOS,
  modelUnavailable,
  modelDownloading,
  featureDisabled,
  permissionRequired,
  providerError,
}

/// Snapshot of what the current device/provider can do.
class AgentCapabilities {
  const AgentCapabilities({
    required this.available,
    this.provider,
    this.textGeneration = false,
    this.streaming = false,
    this.toolCalling = false,
    this.nativeToolCalling = false,
    this.structuredOutput = false,
    this.imageInput = false,
    this.unavailableReason,
  });

  final bool available;
  final String? provider;
  final bool textGeneration;
  final bool streaming;

  /// Effective: runtime can run tools (Path A native and/or Path B protocol).
  final bool toolCalling;

  /// Provider exposes a native tool/function-calling API (e.g. Apple FM).
  /// Android Gemini Nano reports false; Ensemble uses Path B instead.
  final bool nativeToolCalling;

  final bool structuredOutput;
  final bool imageInput;
  final AgentUnavailableReason? unavailableReason;

  static const AgentCapabilities unavailable = AgentCapabilities(
    available: false,
    unavailableReason: AgentUnavailableReason.unsupportedDevice,
  );

  factory AgentCapabilities.fromMap(Map<String, dynamic> map) {
    return AgentCapabilities(
      available: map['available'] == true,
      provider: map['provider'] as String?,
      textGeneration: map['textGeneration'] == true,
      streaming: map['streaming'] == true,
      toolCalling: map['toolCalling'] == true,
      nativeToolCalling: map['nativeToolCalling'] == true,
      structuredOutput: map['structuredOutput'] == true,
      imageInput: map['imageInput'] == true,
      unavailableReason: parseUnavailableReason(
        map['unavailableReason'] as String?,
      ),
    );
  }

  Map<String, dynamic> toMap() => {
        'available': available,
        if (provider != null) 'provider': provider,
        'textGeneration': textGeneration,
        'streaming': streaming,
        'toolCalling': toolCalling,
        'nativeToolCalling': nativeToolCalling,
        'structuredOutput': structuredOutput,
        'imageInput': imageInput,
        if (unavailableReason != null)
          'unavailableReason': unavailableReason!.name,
      };
}

/// Parses a wire-format unavailable reason string.
AgentUnavailableReason? parseUnavailableReason(String? value) {
  if (value == null) return null;
  for (final reason in AgentUnavailableReason.values) {
    if (reason.name == value ||
        reason.name.toLowerCase() == value.toLowerCase()) {
      return reason;
    }
  }
  return AgentUnavailableReason.providerError;
}
