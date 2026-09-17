import 'dart:io';

import 'package:ensemble_test_runner/execution/device_discovery.dart';

/// Selects an Android/iOS emulator, simulator, or physical device for
/// integration mode.
Future<FlutterDevice> selectIntegrationDevice(
  List<String> arguments, {
  Future<List<FlutterDevice>> Function()? discover,
}) async {
  final devices = await (discover ?? discoverFlutterDevices)();
  final supported =
      devices.where((device) => device.isSupportedIntegrationTarget).toList();
  final requested = _optionValues(arguments, '--device-id');
  if (requested.isNotEmpty) {
    final matches = devices.where((device) => device.id == requested.single);
    if (matches.isEmpty) {
      throw StateError(
        'Flutter device "${requested.single}" was not found.\n'
        '${formatDeviceList(devices)}',
      );
    }
    final selected = matches.single;
    if (!selected.isSupportedIntegrationTarget) {
      throw StateError(
        'Device "${selected.display}" is not supported. Select an Android or '
        'iOS emulator, simulator, or physical device.\n'
        '${formatDeviceList(devices)}',
      );
    }
    return selected;
  }
  if (supported.isEmpty) {
    throw StateError(
      'No supported integration target is connected. Start an Android '
      'emulator/iOS simulator or connect a physical Android/iOS device.\n'
      '${formatDeviceList(devices)}',
    );
  }
  if (supported.length == 1) return supported.single;
  if (!stdin.hasTerminal) {
    throw StateError(
      'Multiple integration targets are connected. Select one with '
      '--device-id=<id>:\n${formatDeviceList(supported)}',
    );
  }
  stderr.writeln('Select an integration target:');
  for (var i = 0; i < supported.length; i++) {
    stderr.writeln('  ${i + 1}) ${supported[i].display}');
  }
  stderr.write('Device: ');
  final selection = int.tryParse(stdin.readLineSync()?.trim() ?? '');
  if (selection == null || selection < 1 || selection > supported.length) {
    throw StateError('No valid integration target was selected.');
  }
  return supported[selection - 1];
}

/// Deterministic selection for unit tests (no stdin).
String selectIntegrationDeviceId({
  required String machineJson,
  String? requestedId,
}) {
  final devices = parseFlutterDevices(machineJson);
  final supported =
      devices.where((device) => device.isSupportedIntegrationTarget).toList();
  if (requestedId != null) {
    final matches = devices.where((device) => device.id == requestedId);
    if (matches.isEmpty) throw StateError('Device not found: $requestedId');
    if (!matches.single.isSupportedIntegrationTarget) {
      throw StateError('Unsupported integration device: $requestedId');
    }
    return matches.single.id;
  }
  if (supported.isEmpty) throw StateError('No supported integration target');
  if (supported.length > 1) {
    throw StateError('Multiple integration targets require --device-id');
  }
  return supported.single.id;
}

List<String> _optionValues(List<String> arguments, String name) {
  final prefix = '$name=';
  final values = <String>[];
  for (final argument in arguments) {
    if (argument.startsWith(prefix)) {
      values.add(argument.substring(prefix.length));
    }
  }
  return values;
}
