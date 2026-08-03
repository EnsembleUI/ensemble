/// Timing defaults for [TestStepExecutor] (overridable per executor instance).
///
/// These values are intentionally conservative defaults for local and CI
/// execution. Individual YAML wait steps can provide their own timeout.
class TestExecutionConfig {
  final Duration settleStepDuration;
  final Duration settleTimeout;
  final Duration actionSettleTimeout;
  final Duration waitPollInterval;
  final Duration defaultWaitTimeout;

  const TestExecutionConfig({
    this.settleStepDuration = const Duration(milliseconds: 100),
    this.settleTimeout = const Duration(seconds: 2),
    this.actionSettleTimeout = const Duration(seconds: 1),
    this.waitPollInterval = const Duration(milliseconds: 100),
    this.defaultWaitTimeout = const Duration(seconds: 5),
  });
}
