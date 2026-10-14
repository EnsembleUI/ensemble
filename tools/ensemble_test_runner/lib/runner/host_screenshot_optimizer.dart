import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/reporters/atomic_file.dart';
import 'package:ensemble_test_runner/runner/webp_encoder.dart';
import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:path/path.dart' as p;

/// Converts PNGs transported from a device to WebP before report creation.
/// Frame manifests are updated atomically and source PNGs are removed.
Future<void> optimizeTransportedScreenshotsForHost(String artifactRoot) async {
  return await RunnerBenchmark.async(
      'screenshot', 'optimizeTransportedScreenshotsForHost', () async {
    final manifestsDir = Directory(p.join(artifactRoot, 'frames'));
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
          final webpBytes = await encodePngAsWebp(
            pngBytes,
            benchmarkOperation: 'encodeHostWebP',
          );
          if (webpBytes == null) {
            throw StateError(
                'Could not encode transported screenshot as WebP.');
          }
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
  });
}
