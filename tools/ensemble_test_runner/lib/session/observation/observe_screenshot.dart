import 'dart:io';
import 'dart:ui' as ui;

import 'package:ensemble_test_runner/actions/extended_step_handlers.dart';
import 'package:ensemble_test_runner/actions/screenshot_device.dart';
import 'package:ensemble_test_runner/discovery/ensemble_test_discovery.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/runner/screenshot_capture.dart';
import 'package:ensemble_test_runner/session/observation/observation_options.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:ensemble_test_runner/session/observation/ui_observation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Directory for `--inspect-ui --screenshots` PNGs
/// (`…/build/ensemble_test_runner/inspect-ui`).
String? inspectUiScreenshotDirFromEnvironment() {
  const raw = String.fromEnvironment('ensembleTestObserveScreenshotDir');
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// True when the CLI passed `--screenshots` (screenshot output directory set).
bool get inspectUiScreenshotEnabled =>
    inspectUiScreenshotDirFromEnvironment() != null;

/// Loads suite `tests/config.yaml` for inspect-ui devices + secureContent.
///
/// Uses the same asset path and `--device` dart-define filtering as the YAML
/// suite (`ensembleTestDevice`).
Future<EnsembleTestConfig> loadInspectUiSuiteConfig({
  String? testsAssetPrefix,
}) async {
  final prefix = testsAssetPrefix ??
      (await EnsembleTestDiscovery.loadAppTarget()).testsAssetPrefix;
  return EnsembleTestDiscovery.loadTestConfig(prefix);
}

/// Devices for inspect-ui.
///
/// Without screenshots only the first device is used — the CLI prints a single
/// observation, so re-launching the app for every theme/locale matrix entry is
/// pure overhead. With `--screenshots`, the full matrix is kept so each device
/// can write its own framed PNG.
List<TestDeviceTarget> resolveInspectUiDevices(
  List<TestDeviceTarget> configured, {
  bool forScreenshots = false,
}) {
  final devices = configured.isNotEmpty
      ? configured
      : const [
          TestDeviceTarget(
            id: 'default',
            platform: 'ios',
            model: 'iPhone 15 Pro',
          ),
        ];
  if (forScreenshots || devices.length <= 1) return devices;
  return [devices.first];
}

/// Bound settle for inspect-ui — avoid the default 5s pumpAndSettle wait when
/// the host app keeps scheduling frames (spinners, repeating animations).
const inspectUiObservationOptions = ObservationOptions(
  synchronization: ObservationSynchronization.untilStable,
  stableTimeout: Duration(seconds: 1),
);

/// `{screen}_{theme}_{language}` plus optional device id on collision.
String inspectUiScreenshotBasename({
  required String screen,
  String? theme,
  String? locale,
  String? deviceId,
  bool includeDeviceId = false,
}) {
  final parts = [
    _slug(screen, 'screen'),
    _slug(theme, 'default'),
    _slug(locale, 'default'),
    if (includeDeviceId) _slug(deviceId, 'device'),
  ];
  return parts.join('_');
}

String _slug(String? value, String fallback) {
  final trimmed = (value ?? '').trim();
  if (trimmed.isEmpty) return fallback;
  final slug = trimmed
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return slug.isEmpty ? fallback : slug;
}

/// Applies suite device screen size / safe areas like test-case screenshots.
Future<void> applyInspectUiScreenshotViewport(
  WidgetTester tester,
  TestDeviceTarget device,
) async {
  final info = resolveScreenshotDevice(device.toScreenshotArgs());
  await tester.binding.setSurfaceSize(info.screenSize);
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = info.screenSize;
  final padding = FakeViewPadding(
    left: info.safeAreas.left,
    top: info.safeAreas.top,
    right: info.safeAreas.right,
    bottom: info.safeAreas.bottom,
  );
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
  await tester.pump();
}

/// Captures, highlights observed elements, frames with the device bezel, writes PNG.
Future<String?> writeInspectUiScreenshotForDevice({
  required WidgetTester tester,
  required UiObservation observation,
  required TestDeviceTarget device,
  required String outputPath,
  SecureScreenshotPolicy secureContent = SecureScreenshotPolicy.mask,
}) async {
  final trimmed = outputPath.trim();
  if (trimmed.isEmpty) return null;

  // Labels use Roboto; without this, Flutter tests fall back to Ahem (solid
  // rectangles per glyph), which reads as blank white pills.
  await tester.runAsync(EnsembleTestHarness.ensureAppFontsLoaded);

  final deviceInfo = resolveScreenshotDevice(device.toScreenshotArgs());
  final image = ExtendedStepHandlers.captureScreenshotImage(
    tester,
    secureContent: secureContent,
  );
  try {
    final highlighted = await _paintObservationHighlights(
      source: image,
      observation: observation,
      tester: tester,
    );
    try {
      final bytes = await tester.runAsync(
        () => ExtendedStepHandlers.encodeScreenshotImage(
          highlighted,
          deviceInfo,
        ),
      );
      if (bytes == null) return null;
      final file = File(trimmed);
      file.parent.createSync(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      return file.absolute.path;
    } finally {
      if (!identical(highlighted, image)) {
        highlighted.dispose();
      }
    }
  } finally {
    image.dispose();
  }
}

Future<ui.Image> _paintObservationHighlights({
  required ui.Image source,
  required UiObservation observation,
  required WidgetTester tester,
}) async {
  final targets = <UiElement>[
    for (final root in observation.elements) ..._walkHighlightTargets(root),
  ];
  if (targets.isEmpty) return source;

  final logicalSize = tester.view.physicalSize / tester.view.devicePixelRatio;
  final imageSize = Size(source.width.toDouble(), source.height.toDouble());
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImage(source, Offset.zero, Paint());

  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = const Color(0xFF00B4D8);
  final fill = Paint()
    ..style = PaintingStyle.fill
    ..color = const Color(0x1400B4D8);

  for (final element in targets) {
    final bounds = element.bounds;
    if (bounds == null) continue;
    final logical = Rect.fromLTWH(
      bounds.left,
      bounds.top,
      bounds.width,
      bounds.height,
    );
    if (logical.isEmpty) continue;
    final mapped = screenshotLogicalRectToImagePixels(
      logicalRect: logical,
      logicalSize: logicalSize,
      imageSize: imageSize,
    );
    if (mapped.isEmpty) continue;
    // Only annotate what is actually on the captured frame — scrolled-off
    // controls otherwise leave orphaned chips clamped to the bottom/edge.
    final rect = mapped.intersect(Offset.zero & imageSize);
    if (!_isHighlightableOnFrame(rect, mapped)) continue;
    canvas.drawRect(rect, fill);
    canvas.drawRect(rect, stroke);
    _paintHighlightChips(
      canvas: canvas,
      rect: rect,
      imageSize: imageSize,
      element: element,
    );
  }

  final picture = recorder.endRecording();
  final painted = picture.toImageSync(source.width, source.height);
  picture.dispose();
  return painted;
}

/// Enough of the box must sit on the PNG to be worth outlining / labeling.
bool _isHighlightableOnFrame(Rect clipped, Rect full) {
  if (clipped.isEmpty) return false;
  if (clipped.width < 8 || clipped.height < 8) return false;
  if (full.height <= 0 || full.width <= 0) return false;
  // Drop mostly scrolled-off targets (e.g. a few pixels of a button peeking
  // under the fold) that would only produce floating chips at the edge.
  final heightRatio = clipped.height / full.height;
  final widthRatio = clipped.width / full.width;
  return heightRatio >= 0.45 && widthRatio >= 0.45;
}

Iterable<UiElement> _walkHighlightTargets(UiElement element) sync* {
  if (_shouldHighlight(element)) yield element;
  for (final child in element.children) {
    yield* _walkHighlightTargets(child);
  }
}

String? _highlightId(UiElement element) {
  final id = element.testId?.trim();
  if (id == null || id.isEmpty) return null;
  return id;
}

String? _highlightType(UiElement element) {
  final type = element.type?.trim();
  if (type != null && type.isNotEmpty && type.toLowerCase() != 'widget') {
    return type;
  }
  final role = element.role?.trim();
  if (role != null && role.isNotEmpty && role.toLowerCase() != 'widget') {
    return role;
  }
  return null;
}

void _paintHighlightChips({
  required Canvas canvas,
  required Rect rect,
  required Size imageSize,
  required UiElement element,
}) {
  final id = _highlightId(element);
  final type = _highlightType(element);
  if (id == null && type == null) return;

  const padX = 4.0;
  const padY = 2.0;
  const radius = 3.0;
  // Distinct colors so id vs type read as separate chips, not one token.
  const idColor = Color(0xE6005F87);
  const typeColor = Color(0xE8A16207);
  const textStyle = TextStyle(
    color: Color(0xFFFFFFFF),
    fontSize: 10,
    fontWeight: FontWeight.w600,
    fontFamily: 'Roboto',
    height: 1.15,
  );

  TextPainter? paintChip(String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: (imageSize.width * 0.45).clamp(40.0, 220.0));
    if (painter.width <= 0 || painter.height <= 0) {
      painter.dispose();
      return null;
    }
    return painter;
  }

  final idPainter = id != null ? paintChip(id) : null;
  final typePainter = type != null ? paintChip(type) : null;
  if (idPainter == null && typePainter == null) return;

  final idWidth = idPainter == null ? 0.0 : idPainter.width + padX * 2;
  final typeWidth =
      typePainter == null ? 0.0 : typePainter.width + padX * 2;
  final chipHeight = [
    if (idPainter != null) idPainter.height,
    if (typePainter != null) typePainter.height,
  ].reduce((a, b) => a > b ? a : b) +
      padY * 2;
  final totalWidth = idWidth + typeWidth;

  var left = rect.left;
  var top = rect.top - chipHeight - 2;
  if (top < 0) top = rect.top + 2;
  if (left + totalWidth > imageSize.width) {
    left = (imageSize.width - totalWidth).clamp(0.0, imageSize.width);
  }
  if (left < 0) left = 0;
  if (top + chipHeight > imageSize.height) {
    top = (imageSize.height - chipHeight).clamp(0.0, imageSize.height);
  }

  var x = left;
  if (idPainter != null) {
    final only = typePainter == null;
    final rrect = RRect.fromRectAndCorners(
      Rect.fromLTWH(x, top, idWidth, chipHeight),
      topLeft: const Radius.circular(radius),
      bottomLeft: const Radius.circular(radius),
      topRight: Radius.circular(only ? radius : 0),
      bottomRight: Radius.circular(only ? radius : 0),
    );
    canvas.drawRRect(rrect, Paint()..color = idColor);
    idPainter.paint(
      canvas,
      Offset(x + padX, top + (chipHeight - idPainter.height) / 2),
    );
    idPainter.dispose();
    x += idWidth;
  }
  if (typePainter != null) {
    final only = idPainter == null;
    final rrect = RRect.fromRectAndCorners(
      Rect.fromLTWH(x, top, typeWidth, chipHeight),
      topLeft: Radius.circular(only ? radius : 0),
      bottomLeft: Radius.circular(only ? radius : 0),
      topRight: const Radius.circular(radius),
      bottomRight: const Radius.circular(radius),
    );
    canvas.drawRRect(rrect, Paint()..color = typeColor);
    typePainter.paint(
      canvas,
      Offset(x + padX, top + (chipHeight - typePainter.height) / 2),
    );
    typePainter.dispose();
  }
}

bool _shouldHighlight(UiElement element) {
  if (element.bounds == null) return false;
  // Keep chips on the painted frame only — off-screen / invisible targets
  // were ending up as orphaned labels clamped to the bottom of the PNG.
  if (element.state.visible == false || element.state.offscreen == true) {
    return false;
  }
  if (element.testId != null && element.testId!.trim().isNotEmpty) return true;
  final type = (element.type ?? element.role ?? '').trim().toLowerCase();
  if (type.isEmpty || type == 'widget') return false;
  return true;
}

/// `file://` URI for terminal links when possible.
String inspectUiScreenshotConsoleLink(String absolutePath) {
  final uri = Uri.file(absolutePath);
  return uri.toString();
}
