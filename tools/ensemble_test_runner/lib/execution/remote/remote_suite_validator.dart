import 'package:ensemble_test_runner/execution/remote/remote_models.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';

/// Fail-fast checks for remote-incompatible suite fixtures.
abstract final class RemoteSuiteValidator {
  RemoteSuiteValidator._();

  /// Throws [EnsembleTestFailure] when [config] cannot run with [target].
  static void validate({
    required EnsembleTestConfig config,
    required ExecutionTarget target,
  }) {
    if (target == ExecutionTarget.local) return;

    if (config.mode != ExecutionMode.integration) {
      throw EnsembleTestFailure(
        'target: remote requires mode: integration '
        '(got mode: ${config.mode.name}).',
      );
    }

    final remote = config.remote;
    if (remote == null) {
      throw EnsembleTestFailure(
        'target: remote requires a "remote:" block in tests/config.yaml '
        '(provider and devices).',
      );
    }
    if (remote.provider.trim().isEmpty) {
      throw EnsembleTestFailure('"remote.provider" is required.');
    }
    if (remote.devices.isEmpty) {
      throw EnsembleTestFailure(
        '"remote.devices" must list at least one Firebase Test Lab device.',
      );
    }
    for (final device in remote.devices) {
      if (device.model.trim().isEmpty) {
        throw EnsembleTestFailure(
          'Each remote.devices entry requires a non-empty "model".',
        );
      }
    }

    for (final endpoint in remote.endpoints) {
      _requireRemotelyReachableUrl(
        endpoint.url,
        field: 'remote.endpoints[${endpoint.name}].url',
      );
    }

    for (final service in config.services) {
      _rejectHostLocalService(service, remoteEndpoints: remote.endpoints);
    }
  }

  static void _rejectHostLocalService(
    TestServiceConfig service, {
    required List<RemoteEndpointConfig> remoteEndpoints,
  }) {
    final namedEndpoint = remoteEndpoints.where((e) => e.name == service.name);
    if (namedEndpoint.isNotEmpty) {
      // Explicit remote.endpoints entry replaces host process launch.
      return;
    }

    final url = service.url?.trim() ?? '';
    final ready = service.resolvedReadyUrl?.trim() ?? '';
    final hasCommand = service.command.trim().isNotEmpty;

    if (hasCommand && url.isEmpty && ready.isEmpty) {
      throw EnsembleTestFailure(
        'Remote target cannot start host-local service "${service.name}" '
        '(command: ${service.command}). Provide remote.endpoints with a '
        'reachable HTTPS URL for this name, or remove the service and use mocks.',
      );
    }

    if (url.isNotEmpty) {
      _requireRemotelyReachableUrl(url, field: 'services[${service.name}].url');
    }
    if (ready.isNotEmpty) {
      _requireRemotelyReachableUrl(
        ready,
        field: 'services[${service.name}].readyUrl',
      );
    }

    // Even with a remote URL, a local command implies host process + adb reverse.
    if (hasCommand) {
      throw EnsembleTestFailure(
        'Remote target rejects host-launched service "${service.name}". '
        'Remove "command" and declare the URL under remote.endpoints, '
        'or use in-app mocks only.',
      );
    }
  }

  static void _requireRemotelyReachableUrl(
    String raw, {
    required String field,
  }) {
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw EnsembleTestFailure(
        '$field must be an absolute URL with a host (got "$raw").',
      );
    }
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      throw EnsembleTestFailure(
        '$field must use http or https (got ${uri.scheme}).',
      );
    }
    final host = uri.host.toLowerCase();
    if (host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host == '0.0.0.0' ||
        host.endsWith('.local') ||
        host.startsWith('10.') ||
        host.startsWith('192.168.') ||
        RegExp(r'^172\.(1[6-9]|2\d|3[0-1])\.').hasMatch(host)) {
      throw EnsembleTestFailure(
        '$field "$raw" is not reachable from Firebase Test Lab '
        '(loopback/private LAN). Use a public HTTPS test endpoint or mocks.',
      );
    }
  }
}
