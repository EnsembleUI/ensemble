import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ensemble_test_runner/reporters/atomic_file.dart';
import 'package:path/path.dart' as p;

const _webPQuality = 82;

String? _cachedCwebpPath;
bool _didResolveCwebpPath = false;

/// Best-effort host-side WebP conversion for PNGs transported from a device.
/// Frame manifests are updated atomically; PNG remains the fallback whenever
/// the bundled encoder is unavailable or does not produce a smaller image.
Future<void> optimizeTransportedScreenshotsForHost(String artifactRoot) async {
  final manifestsDir = Directory(p.join(artifactRoot, 'frames'));
  final legacyManifestsDir = Directory(p.join(artifactRoot, 'screenshots'));
  final imagesDir = Directory(p.join(artifactRoot, 'report', 'screenshots'));
  if (!imagesDir.existsSync()) return;

  final converted = <String, String>{};

  Future<void> optimizeManifests(Directory dir) async {
    if (!dir.existsSync()) return;
    for (final entity in dir.listSync().whereType<File>()) {
      if (!entity.path.endsWith('_frames.json')) continue;
      final dynamic decoded;
      try {
        decoded = json.decode(entity.readAsStringSync());
      } catch (_) {
        continue;
      }
      if (decoded is! Map || decoded['frames'] is! List) continue;
      var changed = false;
      for (final dynamic rawFrame in decoded['frames'] as List) {
        if (rawFrame is! Map) continue;
        final fileName = rawFrame['file']?.toString();
        if (fileName == null || !fileName.endsWith('.png')) continue;
        final existingConversion = converted[fileName];
        if (existingConversion != null) {
          rawFrame['file'] = existingConversion;
          changed = true;
          continue;
        }
        final png = File(p.join(imagesDir.path, fileName));
        if (!png.existsSync()) continue;
        final pngBytes = png.readAsBytesSync();
        final webpBytes = await _encodeWebP(pngBytes);
        if (webpBytes == null || webpBytes.length >= pngBytes.length) continue;
        final webpName = '${p.basenameWithoutExtension(fileName)}.webp';
        AtomicFile.writeBytesSync(
          File(p.join(imagesDir.path, webpName)),
          webpBytes,
        );
        rawFrame['file'] = webpName;
        converted[fileName] = webpName;
        png.deleteSync();
        changed = true;
      }
      if (changed) {
        AtomicFile.writeStringSync(
          entity,
          const JsonEncoder.withIndent('  ').convert(decoded),
        );
      }
    }
  }

  await optimizeManifests(manifestsDir);
  await optimizeManifests(legacyManifestsDir);
}

Future<Uint8List?> _encodeWebP(Uint8List pngBytes) async {
  final cwebpPath = await _resolveCwebpPath();
  if (cwebpPath == null) return null;
  final tempDir = Directory.systemTemp.createTempSync('ensemble_webp_');
  try {
    final input = File(p.join(tempDir.path, 'input.png'));
    final output = File(p.join(tempDir.path, 'output.webp'));
    input.writeAsBytesSync(pngBytes);
    final result = await Process.run(cwebpPath, [
      '-quiet',
      '-q',
      '$_webPQuality',
      '-m',
      '4',
      '-metadata',
      'none',
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
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  }
}

Future<String?> _resolveCwebpPath() async {
  if (_didResolveCwebpPath) return _cachedCwebpPath;
  _didResolveCwebpPath = true;
  final packageConfig = File(
    p.join(Directory.current.path, '.dart_tool', 'package_config.json'),
  );
  if (!packageConfig.existsSync()) return null;
  final config = jsonDecode(packageConfig.readAsStringSync());
  if (config is! Map<String, dynamic> || config['packages'] is! List) {
    return null;
  }
  String? rootUri;
  for (final package in config['packages'] as List) {
    if (package is Map<String, dynamic> && package['name'] == 'webp') {
      rootUri = package['rootUri'] as String?;
      break;
    }
  }
  if (rootUri == null) return null;
  final architecture = _webPArchitecture();
  if (architecture == null) return null;
  final packageRoot = p.normalize(
    p.join(packageConfig.parent.path, p.fromUri(Uri.parse(rootUri))),
  );
  final executable = Platform.isWindows ? 'cwebp.exe' : 'cwebp';
  final cwebp = File(p.join(packageRoot, architecture, executable));
  if (!cwebp.existsSync()) return null;
  return _cachedCwebpPath = cwebp.path;
}

String? _webPArchitecture() => switch (Abi.current()) {
      Abi.macosArm64 => 'mac-arm64',
      Abi.macosX64 => 'mac-x86-64',
      Abi.linuxArm64 => 'linux-aarch64',
      Abi.linuxX64 => 'linux-x86-64',
      Abi.windowsX64 => 'windows-x64',
      _ => null,
    };
