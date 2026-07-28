import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ensemble_device_preview/ensemble_device_preview.dart';
import 'package:ensemble_test_runner/actions/extended_step_handlers.dart';
import 'package:ensemble_test_runner/actions/screenshot_device.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/live_async_call.dart';
import 'package:ensemble_test_runner/runner/test_artifacts.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

const _maxReportScreenshotWidth = 360;
const _reportScreenshotJpegQuality = 82;
const _reportScreenshotWebPQuality = 82;

String? _cachedCwebpPath;
bool _didResolveCwebpPath = false;

/// Encodes each frame to a compressed device-framed image and writes a
/// [frames.json] manifest.
///
/// Returns the display path of the frames manifest.
/// The HTML report builds the contact-sheet gallery from these per-step files.
Future<String?> writeScreenshotFrames({
  required String testId,
  required ScreenshotConfig config,
  required List<ScreenshotSheetFrame> frames,
  required TestStatus status,
  int? failedStepIndex,
  String? failedStepLabel,
  String? failureMessage,
  String? failedDeviceId,
}) async {
  if (frames.isEmpty) return null;

  final defaultDevice = resolveScreenshotDevice(const {});
  final directory = ensembleTestArtifactDirectory('screenshots');
  directory.createSync(recursive: true);
  final safeTestId = _safeFileName(testId);
  final frameEntries = <Map<String, dynamic>>[];

  try {
    for (final frame in frames) {
      final failedFrame = status == TestStatus.failed &&
          frame.stepIndex == failedStepIndex &&
          (failedDeviceId == null || frame.deviceId == failedDeviceId);
      final frameDevice = _deviceForFrame(frame, defaultDevice);
      final encoded = frame.encodedReportImage ??
          await _encodeFrameImage(frame, frameDevice);
      frame.encodedReportImage ??= encoded;

      final frameFileName = _dedupedImageFileName(encoded);
      final frameFile = ensembleTestArtifactFile('screenshots', frameFileName);
      if (!frameFile.existsSync()) {
        frameFile.writeAsBytesSync(encoded.bytes);
      }
      frameEntries.add({
        'stepIndex': frame.stepIndex,
        'label': frame.label,
        'file': frameFileName,
        if (failedFrame) 'failed': true,
        if (frame.deviceId != null) 'deviceId': frame.deviceId,
        if (frame.deviceLabel != null) 'deviceLabel': frame.deviceLabel,
        if (frame.highlight != null) 'highlight': frame.highlight!.toJson(),
      });
    }
  } finally {
    if (status != TestStatus.pending) {
      for (final frame in frames) {
        try {
          frame.image.dispose();
        } catch (_) {}
      }
    }
  }

  if (frameEntries.isEmpty) return null;

  // Drop legacy composite sheet artifacts from older runner versions.
  for (final legacyName in [
    '$safeTestId.png',
    '${safeTestId}_sheet.png',
  ]) {
    final legacy = ensembleTestArtifactFile('screenshots', legacyName);
    if (legacy.existsSync()) {
      legacy.deleteSync();
    }
  }

  final framesFileName = '${safeTestId}_frames.json';
  final framesFile = ensembleTestArtifactFile('screenshots', framesFileName);
  framesFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'status': status.name,
      if (failedStepIndex != null) 'failedStepIndex': failedStepIndex,
      if (failedStepLabel != null) 'failedStepLabel': failedStepLabel,
      if (failureMessage != null) 'failureMessage': failureMessage,
      'frames': frameEntries,
    }),
  );

  return ensembleTestArtifactDisplayPath('screenshots', framesFileName);
}

/// @Deprecated Use [writeScreenshotFrames]. Kept as a thin alias for call sites.
Future<String?> writeScreenshotContactSheet({
  required String testId,
  required ScreenshotConfig config,
  required List<ScreenshotSheetFrame> frames,
  required TestStatus status,
  required int durationMs,
  int? failedStepIndex,
  String? failedStepLabel,
  String? failureMessage,
  String? failedDeviceId,
}) {
  return writeScreenshotFrames(
    testId: testId,
    config: config,
    frames: frames,
    status: status,
    failedStepIndex: failedStepIndex,
    failedStepLabel: failedStepLabel,
    failureMessage: failureMessage,
    failedDeviceId: failedDeviceId,
  );
}

DeviceInfo _deviceForFrame(
  ScreenshotSheetFrame frame,
  DeviceInfo fallback,
) {
  final platform = frame.platform;
  final model = frame.model;
  if ((platform == null || platform.isEmpty) &&
      (model == null || model.isEmpty)) {
    return fallback;
  }
  return resolveScreenshotDevice({
    if (platform != null && platform.isNotEmpty) 'platform': platform,
    if (model != null && model.isNotEmpty) 'model': model,
  });
}

Future<EncodedScreenshotImage> _encodeFrameImage(
  ScreenshotSheetFrame frame,
  DeviceInfo device,
) async {
  final bytes = await LiveAsyncCallSupport.runUntracked(
    () => ExtendedStepHandlers.encodeScreenshotImage(frame.image, device),
  );
  if (bytes == null) {
    throw EnsembleTestFailure('Failed to encode screenshot.');
  }
  return _compressedReportImage(bytes);
}

Future<EncodedScreenshotImage> _compressedReportImage(
    Uint8List pngBytes) async {
  try {
    final decoded = img.decodePng(pngBytes);
    if (decoded == null) {
      return EncodedScreenshotImage(bytes: pngBytes, extension: 'png');
    }

    final resized = decoded.width > _maxReportScreenshotWidth
        ? img.copyResize(
            decoded,
            width: _maxReportScreenshotWidth,
            interpolation: img.Interpolation.average,
          )
        : decoded;

    final background =
        img.Image(width: resized.width, height: resized.height, numChannels: 3);
    img.fill(background, color: img.ColorRgb8(10, 17, 31));
    img.compositeImage(background, resized);

    final jpgBytes = Uint8List.fromList(
      img.encodeJpg(
        background,
        quality: _reportScreenshotJpegQuality,
        chroma: img.JpegChroma.yuv420,
      ),
    );
    final optimizedPngBytes = Uint8List.fromList(
      img.encodePng(background, level: 9),
    );
    final candidates = <EncodedScreenshotImage>[
      EncodedScreenshotImage(bytes: jpgBytes, extension: 'jpg'),
      EncodedScreenshotImage(bytes: optimizedPngBytes, extension: 'png'),
    ];

    final webPBytes = await _encodeWebP(optimizedPngBytes);
    if (webPBytes != null) {
      candidates
          .add(EncodedScreenshotImage(bytes: webPBytes, extension: 'webp'));
    }

    candidates.sort((a, b) => a.bytes.length.compareTo(b.bytes.length));
    return candidates.first;
  } catch (_) {
    return EncodedScreenshotImage(bytes: pngBytes, extension: 'png');
  }
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
      '$_reportScreenshotWebPQuality',
      '-m',
      '4',
      input.path,
      '-o',
      output.path,
    ]);
    if (result.exitCode != 0 || !output.existsSync()) {
      return null;
    }
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

  final packageConfigJson =
      jsonDecode(packageConfig.readAsStringSync()) as Map<String, dynamic>;
  final packages = packageConfigJson['packages'];
  if (packages is! List) return null;

  String? webpRootUri;
  for (final package in packages) {
    if (package is Map<String, dynamic> && package['name'] == 'webp') {
      webpRootUri = package['rootUri'] as String?;
      break;
    }
  }
  if (webpRootUri == null) return null;

  final packageRoot = p.normalize(
    p.join(
      packageConfig.parent.path,
      p.fromUri(Uri.parse(webpRootUri)),
    ),
  );
  final architecture = _webPArchitecture();
  if (architecture == null) return null;

  final executable = Platform.isWindows ? 'cwebp.exe' : 'cwebp';
  final cwebp = File(p.join(packageRoot, architecture, executable));
  if (!cwebp.existsSync()) return null;
  _cachedCwebpPath = cwebp.path;
  return _cachedCwebpPath;
}

String? _webPArchitecture() {
  switch (Abi.current()) {
    case Abi.macosArm64:
      return 'mac-arm64';
    case Abi.macosX64:
      return 'mac-x86-64';
    case Abi.linuxArm64:
      return 'linux-aarch64';
    case Abi.linuxX64:
      return 'linux-x86-64';
    case Abi.windowsX64:
      return 'windows-x64';
    default:
      return null;
  }
}

String _safeFileName(String value) =>
    value.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');

String _dedupedImageFileName(EncodedScreenshotImage image) {
  final digest = sha256.convert(image.bytes).toString();
  return 'shot_${image.bytes.length}_$digest.${image.extension}';
}
