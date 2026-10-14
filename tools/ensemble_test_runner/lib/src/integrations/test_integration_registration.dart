/// Registration hook for optional test-runtime integrations.
///
/// The descriptor contains only callbacks, so the runtime and harness can
/// install selected integrations without importing their SDK-specific bridges.
final class TestIntegrationRegistration {
  final String name;
  final void Function() install;
  final void Function()? afterBootstrap;

  const TestIntegrationRegistration({
    required this.name,
    required this.install,
    this.afterBootstrap,
  });
}

/// Installs each selected integration once and preserves registration order.
final class TestIntegrationRegistry {
  final List<TestIntegrationRegistration> _registrations;
  final Set<String> _installed = <String>{};

  TestIntegrationRegistry(Iterable<TestIntegrationRegistration> registrations)
      : _registrations = List<TestIntegrationRegistration>.unmodifiable(
          registrations,
        ) {
    final names = <String>{};
    for (final registration in _registrations) {
      if (registration.name.isEmpty || !names.add(registration.name)) {
        throw ArgumentError.value(
          registration.name,
          'registrations',
          'Integration names must be non-empty and unique.',
        );
      }
    }
  }

  void installAll() {
    for (final registration in _registrations) {
      if (_installed.add(registration.name)) registration.install();
    }
  }

  void afterBootstrap() {
    for (final registration in _registrations) {
      if (_installed.contains(registration.name)) {
        registration.afterBootstrap?.call();
      }
    }
  }
}
