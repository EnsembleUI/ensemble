import 'dart:convert';
import 'dart:io';

/// A Flutter device from `flutter devices --machine`.
class FlutterDevice {
  final String id;
  final String name;
  final String targetPlatform;
  final bool emulator;

  const FlutterDevice({
    required this.id,
    required this.name,
    required this.targetPlatform,
    required this.emulator,
  });

  /// `android` or `ios`. Throws for unsupported platforms.
  String get platform {
    if (targetPlatform.startsWith('android')) return 'android';
    if (targetPlatform == 'ios') return 'ios';
    throw StateError(
      'Unsupported Flutter target platform "$targetPlatform" for device $id.',
    );
  }

  bool get isAndroid => targetPlatform.startsWith('android');
  bool get isIos => targetPlatform == 'ios';

  /// Phase 1 supports Android and iOS emulators, simulators, and physical devices.
  bool get isSupportedIntegrationTarget => isAndroid || isIos;

  bool get isVirtual => emulator;

  factory FlutterDevice.fromJson(Map<String, dynamic> json) => FlutterDevice(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? json['id']?.toString() ?? 'Unknown',
        targetPlatform: json['targetPlatform']?.toString() ?? '',
        emulator: json['emulator'] == true,
      );

  String get display {
    final kind = isVirtual ? 'virtual' : 'physical';
    return '$name ($id, $targetPlatform, $kind)';
  }
}

Future<List<FlutterDevice>> discoverFlutterDevices() async {
  final result = await Process.run('flutter', ['devices', '--machine']);
  if (result.exitCode != 0) {
    throw StateError(
      'Could not discover Flutter devices:\n${result.stderr.toString().trim()}',
    );
  }
  return parseFlutterDevices(result.stdout.toString());
}

List<FlutterDevice> parseFlutterDevices(String machineJson) {
  final dynamic decoded = json.decode(machineJson);
  if (decoded is! List) {
    throw StateError('flutter devices --machine returned invalid JSON.');
  }
  return decoded
      .whereType<Map>()
      .map((item) => FlutterDevice.fromJson(Map<String, dynamic>.from(item)))
      .where((device) => device.id.isNotEmpty)
      .toList();
}

String formatDeviceList(List<FlutterDevice> devices) {
  if (devices.isEmpty) return 'Connected devices: none';
  return [
    'Connected devices:',
    for (final device in devices)
      '  - ${device.display}${device.isSupportedIntegrationTarget ? '' : ' [unsupported]'}',
  ].join('\n');
}
