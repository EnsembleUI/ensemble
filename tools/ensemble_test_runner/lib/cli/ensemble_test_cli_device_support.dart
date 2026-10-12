part of 'ensemble_test_cli.dart';

void _validatePlatformProject(String appDir, String platform) {
  final requiredPath = platform == 'android'
      ? p.join(appDir, 'android', 'app')
      : p.join(appDir, 'ios', 'Runner.xcodeproj', 'project.pbxproj');
  final exists = platform == 'android'
      ? Directory(requiredPath).existsSync()
      : File(requiredPath).existsSync();
  if (exists) return;
  throw StateError(
    'The $platform application project is incomplete. From the app root run:\n'
    '  flutter create --platforms=$platform .',
  );
}

List<TestServiceConfig> _resolvedHostServices(
  List<TestServiceConfig> services,
  Map<String, dynamic> overrides, {
  required String appDir,
}) {
  return [
    for (final service in services)
      (() {
        final raw = overrides[service.name];
        final override = raw is Map
            ? Map<String, dynamic>.from(raw)
            : const <String, dynamic>{};
        final rawEnvironment = override['environment'];
        final overrideEnvironment = rawEnvironment is Map
            ? rawEnvironment.map(
                (key, value) => MapEntry(key.toString(), value.toString()),
              )
            : const <String, String>{};
        final workingDirectory = service.workingDirectory;
        return TestServiceConfig(
          name: service.name,
          command: service.command,
          url: override['url']?.toString() ?? service.url,
          arguments: service.arguments,
          workingDirectory: workingDirectory == null
              ? appDir
              : (p.isAbsolute(workingDirectory)
                  ? workingDirectory
                  : p.join(appDir, workingDirectory)),
          environment: {...service.environment, ...overrideEnvironment},
          readyUrl: override['readyUrl']?.toString() ?? service.readyUrl,
          readyTimeoutMs: service.readyTimeoutMs,
        );
      })(),
  ];
}

Future<void> _addAdbReverse(String deviceId, int port) async {
  final result = await Process.run(
    'adb',
    ['-s', deviceId, 'reverse', 'tcp:$port', 'tcp:$port'],
  );
  if (result.exitCode != 0) {
    throw StateError(
      'Failed to route host service port $port to Android device $deviceId: '
      '${result.stderr.toString().trim()}',
    );
  }
}

Future<void> _removeAdbReverse(String deviceId, int port) async {
  try {
    await Process.run(
      'adb',
      ['-s', deviceId, 'reverse', '--remove', 'tcp:$port'],
    );
  } catch (_) {
    // Best-effort cleanup must not hide the suite result.
  }
}

Future<void> _clearAdbLogcat(String deviceId) async {
  try {
    await Process.run('adb', ['-s', deviceId, 'logcat', '-c']);
  } catch (_) {
    // Clearing is best-effort; transport can still scrape a noisy buffer.
  }
}

Future<String> _readAdbLogcat(String deviceId) async {
  try {
    final result = await Process.run(
      'adb',
      ['-s', deviceId, 'logcat', '-d', '-v', 'brief'],
    );
    return '${result.stdout ?? ''}\n${result.stderr ?? ''}';
  } catch (_) {
    return '';
  }
}
