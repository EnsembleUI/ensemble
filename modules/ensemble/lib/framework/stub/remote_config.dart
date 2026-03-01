/// Abstract provider for Remote Config values.
///
/// The real implementation is provided by the [ensemble_remote_config] module
/// when enabled via [EnsembleModules] in the starter; otherwise a stub is used.
abstract class RemoteConfig {
  dynamic getValue(String key, dynamic defaultValue);

  /// Return all currently known values, using the same typing rules as
  /// [getValue] with a `null` default (i.e. minimal inference).
  Map<String, dynamic> getAllValues();

  /// Metadata about the current Remote Config state (debugging only).
  Map<String, dynamic> getInfo();

  /// Manually trigger a refresh/fetch of Remote Config values.
  ///
  /// This is intended for developer tools or long‑lived sessions, and is
  /// typically called from expressions as `ensemble.remoteConfig.refresh()`.
  Future<void> refresh();

  /// Optionally register a map of default values.
  ///
  /// This is primarily intended for use from Dart (e.g. starter wiring), but
  /// is also exposed in expressions as `ensemble.remoteConfig.setDefaults({...})`
  /// for advanced scenarios.
  Future<void> setDefaults(Map<String, dynamic> defaults);
}

/// Stub used when the ensemble_remote_config module is not enabled.
/// Always returns [defaultValue] so expressions like ensemble.remoteConfig.my_key or ensemble.remoteConfig.get('key', 'default')
/// work without throwing.
class RemoteConfigStub implements RemoteConfig {
  @override
  dynamic getValue(String key, dynamic defaultValue) => defaultValue;

  @override
  Map<String, dynamic> getAllValues() => const {};

  @override
  Map<String, dynamic> getInfo() =>
      const {'initialized': false, 'source': 'stub'};

  @override
  Future<void> refresh() async {
    // no-op in stub
  }

  @override
  Future<void> setDefaults(Map<String, dynamic> defaults) async {
    // no-op in stub
  }
}
