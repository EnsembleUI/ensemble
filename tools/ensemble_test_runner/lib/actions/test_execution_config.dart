/// Timing defaults for [TestStepExecutor] (overridable per executor instance).
///
/// These values are tuned for local and CI execution. Individual YAML wait
/// steps can provide their own timeout; action settling is bounded separately.
class TestExecutionConfig {
  final Duration settleStepDuration;
  final Duration settleTimeout;

  /// Maximum time to wait for post-action frames before explicit next-step waits.
  final Duration actionSettleTimeout;
  final Duration waitPollInterval;
  final Duration defaultWaitTimeout;

  const TestExecutionConfig({
    this.settleStepDuration = const Duration(milliseconds: 100),
    this.settleTimeout = const Duration(seconds: 2),
    this.actionSettleTimeout = const Duration(milliseconds: 150),
    this.waitPollInterval = const Duration(milliseconds: 100),
    this.defaultWaitTimeout = const Duration(seconds: 5),
  });
}
