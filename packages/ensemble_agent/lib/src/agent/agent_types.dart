/// How a finished agent turn ended.
enum AgentFinishReason {
  completed,
  cancelled,
  timeout,
  maxIterations,
  modelError,
  toolError,
  unsupported,
}

/// Optional usage metrics from a provider.
class AgentUsage {
  const AgentUsage({
    this.inputTokens,
    this.outputTokens,
    this.duration,
    this.provider,
  });

  final int? inputTokens;
  final int? outputTokens;
  final Duration? duration;
  final String? provider;

  Map<String, dynamic> toMap() => {
        if (inputTokens != null) 'inputTokens': inputTokens,
        if (outputTokens != null) 'outputTokens': outputTokens,
        if (duration != null) 'durationMs': duration!.inMilliseconds,
        if (provider != null) 'provider': provider,
      };

  factory AgentUsage.fromMap(Map<String, dynamic> map) {
    final durationMs = map['durationMs'];
    return AgentUsage(
      inputTokens: map['inputTokens'] as int?,
      outputTokens: map['outputTokens'] as int?,
      duration: durationMs is num
          ? Duration(milliseconds: durationMs.toInt())
          : null,
      provider: map['provider'] as String?,
    );
  }
}

/// Final result of an agent run / session turn.
class AgentResult {
  const AgentResult({
    this.text,
    this.structuredOutput,
    this.usage,
    this.finishReason = AgentFinishReason.completed,
  });

  final String? text;
  final dynamic structuredOutput;
  final AgentUsage? usage;
  final AgentFinishReason finishReason;

  Map<String, dynamic> toMap() => {
        if (text != null) 'text': text,
        if (structuredOutput != null) 'structuredOutput': structuredOutput,
        if (usage != null) 'usage': usage!.toMap(),
        'finishReason': finishReason.name,
      };
}

/// Input to an agent turn. Extensible for future modalities.
sealed class AgentInput {
  const AgentInput();

  factory AgentInput.text(String text) = AgentTextInput;
}

class AgentTextInput extends AgentInput {
  const AgentTextInput(this.text);

  final String text;
}

/// Concurrency behavior when a second turn is submitted on a busy session.
enum AgentConcurrencyPolicy {
  queue,
  cancelPrevious,
  reject,
}

/// Tunables for the agent loop.
class AgentOptions {
  const AgentOptions({
    this.timeout = const Duration(seconds: 30),
    this.maxIterations = 10,
    this.maxToolCalls = 8,
    this.concurrency = AgentConcurrencyPolicy.reject,
  });

  final Duration timeout;
  final int maxIterations;
  final int maxToolCalls;
  final AgentConcurrencyPolicy concurrency;
}
