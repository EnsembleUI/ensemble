/// Execution path classification for YAML steps on the session API.
enum YamlStepPath {
  /// UI gesture → session.act
  act,

  /// Wait/sync → session.waitFor
  wait,

  /// Assertion → session.assertCondition
  assert_,

  /// Privileged environment mutation (mocks, storage writes, …)
  privileged,

  /// App/screen lifecycle via harness/executor
  lifecycle,

  /// Control-flow; does NOT acquire the leaf session lock
  control,

  /// Diagnostic / quality
  diagnostic,
}
