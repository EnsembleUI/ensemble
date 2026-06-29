/// Timing defaults for [TestStepExecutor] (overridable per executor instance).
class TestExecutionConfig {
  final Duration settleStepDuration;
  final Duration settleTimeout;
  final Duration waitPollInterval;
  final Duration defaultWaitTimeout;

  const TestExecutionConfig({
    this.settleStepDuration = const Duration(milliseconds: 100),
    this.settleTimeout = const Duration(seconds: 10),
    this.waitPollInterval = const Duration(milliseconds: 100),
    this.defaultWaitTimeout = const Duration(seconds: 5),
  });
}
