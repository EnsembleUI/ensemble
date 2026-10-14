import 'dart:io';

import 'package:ensemble_test_runner/cli/app_patcher.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/parser/ensemble_test_parser.dart';
import 'package:ensemble_test_runner/execution/host_address.dart';
import 'package:path/path.dart' as p;

/// Resolves configured service endpoints for an individual CLI worker.
///
/// Port selection is kept here so serial and sharded execution share the same
/// collision rules and the CLI remains responsible only for orchestration.
Future<Map<String, dynamic>> resolveServiceOverrides({
  required TestAppPatcher patcher,
  required Set<int> usedPorts,
  int preferredOffset = 0,
}) async {
  final testsDir = patcher.testsDirPath;
  if (testsDir == null) return const {};
  final configFile = File(p.join(testsDir, 'config.yaml'));
  if (!configFile.existsSync()) return const {};

  final config = EnsembleTestParser.parseConfigString(
    configFile.readAsStringSync(),
    sourcePath: configFile.path,
  );
  if (config.services.isEmpty) return const {};

  final overrides = <String, dynamic>{};
  for (final service in config.services) {
    final resolvedUrl = await _allocateServiceUrl(
      service.url,
      usedPorts: usedPorts,
      preferredOffset: preferredOffset,
    );
    if (resolvedUrl == null) continue;
    final uri = Uri.parse(resolvedUrl);
    overrides[service.name] = {
      'url': resolvedUrl,
      'environment': {'PORT': '${uri.port}'},
    };
  }
  return overrides;
}

/// Rewrites loopback service endpoints for a device or simulator host.
Map<String, dynamic> rewriteServiceOverridesForHost(
  Map<String, dynamic> overrides,
  List<TestServiceConfig> services,
  String hostAddress,
) {
  final rewritten = Map<String, dynamic>.from(overrides);
  for (final service in services) {
    final existing = rewritten[service.name];
    final map = existing is Map
        ? Map<String, dynamic>.from(existing)
        : <String, dynamic>{};
    final url = map['url']?.toString() ?? service.url;
    final ready = service.readyUrl;
    final newUrl = rewriteServiceUrlForDevice(url, hostAddress);
    if (newUrl != null) map['url'] = newUrl;
    rewritten[service.name] = map;
    if (ready != null) {
      final rewrittenReady = rewriteServiceUrlForDevice(ready, hostAddress);
      if (rewrittenReady != null && rewrittenReady != ready) {
        map['readyUrl'] = rewrittenReady;
      }
    }
  }
  return rewritten;
}

Future<String?> _allocateServiceUrl(
  String? configuredUrl, {
  required Set<int> usedPorts,
  required int preferredOffset,
}) async {
  final baseUri = _serviceBaseUri(configuredUrl);
  if (baseUri == null) return null;
  final configuredPort = baseUri.hasPort ? baseUri.port : null;
  final preferredPort =
      configuredPort == null ? null : configuredPort + preferredOffset;
  final port = await _allocateTcpPort(
    preferredPort: preferredPort,
    usedPorts: usedPorts,
  );
  return baseUri.replace(port: port).toString();
}

Uri? _serviceBaseUri(String? configuredUrl) {
  if (configuredUrl == null || configuredUrl.trim().isEmpty) {
    return Uri.parse('http://127.0.0.1');
  }
  final uri = Uri.tryParse(configuredUrl.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  return uri;
}

Future<int> _allocateTcpPort({
  required int? preferredPort,
  required Set<int> usedPorts,
}) async {
  if (preferredPort != null &&
      preferredPort > 0 &&
      !usedPorts.contains(preferredPort) &&
      await _isTcpPortAvailable(preferredPort)) {
    usedPorts.add(preferredPort);
    return preferredPort;
  }

  while (true) {
    final socket = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    final port = socket.port;
    await socket.close();
    if (usedPorts.add(port)) return port;
  }
}

Future<bool> _isTcpPortAvailable(int port) async {
  try {
    final socket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    await socket.close();
    return true;
  } on SocketException {
    return false;
  }
}
