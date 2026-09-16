import 'package:ensemble_test_runner/models/ensemble_test_models.dart';

/// Widget `devices` filtering that is safe to import from the Dart CLI.
///
/// Keep Flutter / `dart:ui` out of this library. `ensemble test` compiles as a
/// VM executable; pulling in [EnsembleTestDiscovery] would fail with
/// "dart:ui is not available on this platform".

/// Keeps only suite `devices` whose ids are in [selectedIds].
///
/// Empty [selectedIds] means all devices (CLI default). Unknown ids throw.
EnsembleTestConfig applyDeviceFilter(
  EnsembleTestConfig config,
  Set<String> selectedIds,
) {
  if (selectedIds.isEmpty) return config;
  if (config.devices.isEmpty) {
    throw EnsembleTestFailure(
      '`--device` was set but tests/config.yaml has no devices.',
    );
  }
  final known = {for (final device in config.devices) device.id};
  final unknown = selectedIds.difference(known);
  if (unknown.isNotEmpty) {
    final knownList = config.devices.map((d) => d.id).join(', ');
    throw EnsembleTestFailure(
      'Unknown device id(s): ${unknown.join(', ')}. Known: $knownList',
    );
  }
  return config.copyWith(
    devices: [
      for (final device in config.devices)
        if (selectedIds.contains(device.id)) device,
    ],
  );
}

/// Widget `devices` entries that still apply on a real integration target.
///
/// Viewport/model are ignored by the harness. Matching [platform] rows keep
/// locale/theme. Other platforms are skipped. If `--device` was set and none
/// of those ids match the connected platform, this throws.
IntegrationDeviceMatrix resolveIntegrationDeviceMatrix(
  EnsembleTestConfig config, {
  required String platform,
  Set<String> selectedIds = const {},
}) {
  final filtered = applyDeviceFilter(config, selectedIds);
  if (filtered.devices.isEmpty) {
    return IntegrationDeviceMatrix(
      config: filtered,
      skipped: const [],
      platform: TestDeviceTarget.normalizePlatform(platform),
    );
  }
  final normalized = TestDeviceTarget.normalizePlatform(platform);
  if (normalized.isEmpty) {
    return IntegrationDeviceMatrix(
      config: filtered,
      skipped: const [],
      platform: normalized,
    );
  }
  final matched = <TestDeviceTarget>[];
  final skipped = <TestDeviceTarget>[];
  for (final device in filtered.devices) {
    if (device.matchesPlatform(normalized)) {
      matched.add(device);
    } else {
      skipped.add(device);
    }
  }
  if (matched.isEmpty && selectedIds.isNotEmpty) {
    throw EnsembleTestFailure(
      '--device did not match the connected $normalized target. '
      'Selected: ${selectedIds.join(', ')}. Use --device-id to pick a '
      'matching emulator/simulator, or choose a devices entry for '
      '$normalized.',
    );
  }
  return IntegrationDeviceMatrix(
    config: filtered.copyWith(devices: matched),
    skipped: skipped,
    platform: normalized,
  );
}

/// Result of narrowing a widget `devices` matrix to one integration target.
class IntegrationDeviceMatrix {
  final EnsembleTestConfig config;
  final List<TestDeviceTarget> skipped;
  final String platform;

  const IntegrationDeviceMatrix({
    required this.config,
    required this.skipped,
    required this.platform,
  });

  List<String> get warnings {
    if (skipped.isEmpty) return const [];
    final skippedIds = skipped.map((device) => device.id).join(', ');
    if (config.devices.isEmpty) {
      return [
        'No suite devices match the connected $platform target '
            '(skipped: $skippedIds). Running once on the real display.',
      ];
    }
    final keptIds = config.devices.map((device) => device.id).join(', ');
    return [
      'Skipping suite device(s) that do not match the connected $platform '
          'target: $skippedIds. Using $keptIds (locale/theme still apply; '
          'viewport/model are ignored in integration mode).',
    ];
  }
}
