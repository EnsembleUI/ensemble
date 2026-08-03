/// Minimal module bootstrap for the example application.
///
/// Applications with custom Ensemble modules can replace this with their
/// generated module initialization. The example does not need any modules,
/// but the YAML test bootstrap expects the entry point to exist.
class EnsembleModules {
  /// Initializes the modules used by the application.
  Future<void> init() async {}
}
