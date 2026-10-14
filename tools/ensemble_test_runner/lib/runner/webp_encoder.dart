import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:path/path.dart' as p;

const _quality = 82;

Future<String?>? _encoderPath;

/// Encodes PNG bytes as WebP using the platform encoder shipped by `webp`.
///
/// The temporary input/output files are owned by this call and are removed
/// whether encoding succeeds, fails, or throws.
Future<Uint8List?> encodePngAsWebp(
  Uint8List pngBytes, {
  required String benchmarkOperation,
  int? resizeWidth,
  String? blendAlpha,
}) {
  return RunnerBenchmark.async('screenshot', benchmarkOperation, () async {
    if (RunnerBenchmark.collector?.disabledExecutables.contains('cwebp') ==
        true) {
      RunnerBenchmark.dimension('codecFallback', 'controlled-unavailable-webp');
      return null;
    }

    final encoder = await (_encoderPath ??= _resolveEncoderPath());
    if (encoder == null) return null;

    final temporaryDirectory =
        Directory.systemTemp.createTempSync('ensemble_webp_');
    try {
      final input = File(p.join(temporaryDirectory.path, 'input.png'));
      final output = File(p.join(temporaryDirectory.path, 'output.webp'));
      input.writeAsBytesSync(pngBytes);
      final result = await Process.run(encoder, [
        '-quiet',
        '-q',
        '$_quality',
        '-m',
        '4',
        '-metadata',
        'none',
        if (resizeWidth != null) ...['-resize', '$resizeWidth', '0'],
        if (blendAlpha != null) ...['-blend_alpha', blendAlpha],
        input.path,
        '-o',
        output.path,
      ]);
      if (result.exitCode != 0 || !output.existsSync()) return null;
      return output.readAsBytesSync();
    } catch (_) {
      return null;
    } finally {
      try {
        temporaryDirectory.deleteSync(recursive: true);
      } catch (_) {}
    }
  });
}

Future<String?> _resolveEncoderPath() async {
  final packageConfig = File(
    p.join(Directory.current.path, '.dart_tool', 'package_config.json'),
  );
  if (!packageConfig.existsSync()) return null;

  final decoded = jsonDecode(packageConfig.readAsStringSync());
  if (decoded is! Map<String, dynamic> || decoded['packages'] is! List) {
    return null;
  }

  String? rootUri;
  for (final package in decoded['packages'] as List) {
    if (package is Map<String, dynamic> && package['name'] == 'webp') {
      rootUri = package['rootUri'] as String?;
      break;
    }
  }
  if (rootUri == null) return null;

  final architecture = switch (Abi.current()) {
    Abi.macosArm64 => 'mac-arm64',
    Abi.macosX64 => 'mac-x86-64',
    Abi.linuxArm64 => 'linux-aarch64',
    Abi.linuxX64 => 'linux-x86-64',
    Abi.windowsX64 => 'windows-x64',
    _ => null,
  };
  if (architecture == null) return null;

  final packageRoot = p.normalize(
    p.join(packageConfig.parent.path, p.fromUri(Uri.parse(rootUri))),
  );
  final executable = Platform.isWindows ? 'cwebp.exe' : 'cwebp';
  final path = File(p.join(packageRoot, architecture, executable));
  return path.existsSync() ? path.path : null;
}
