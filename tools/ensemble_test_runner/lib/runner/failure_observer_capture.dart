import 'dart:ui' as ui;

import 'package:ensemble_device_preview/ensemble_device_preview.dart';
import 'package:ensemble_test_runner/actions/screenshot_device.dart';
import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/screenshot_capture.dart';
import 'package:ensemble_test_runner/runner/test_artifacts.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/observation/observation_options.dart';
import 'package:ensemble_test_runner/session/observation/suggested_locator.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:ensemble_test_runner/session/observation/ui_observation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bound observe used on failure — prefer a quick snapshot over long settle.
const failureObserverOptions = ObservationOptions(
  synchronization: ObservationSynchronization.immediate,
  includeBounds: true,
);

/// Live UI dump for a failed step's Observer tab.
///
/// Does **not** capture a second screenshot and does **not** pump the tester —
/// that would advance the tree past the failure frame. Overlays are percent
/// rects mapped onto the existing failure [ScreenshotSheetFrame] for HTML.
Future<void> captureFailureObserverBestEffort({
  required LocalTestExecutionSession session,
  required TestStepExecutor executor,
  required int stepIndex,
}) async {
  final ctx = executor.context;
  if (!ctx.config.screenshots.enabled) return;
  try {
    // No pump: must match the pixels already in screenshotSheetFrames.
    var observation = await session.observe(options: failureObserverOptions);
    observation = enrichSuggestedLocators(
      observation: observation,
      resolver: session.resolver,
      registry: session.registry,
    );
    final device = ctx.testCase.deviceTarget;
    final frame = _latestScreenshotFrame(ctx, stepIndex);
    final overlays = frame == null
        ? const <Map<String, dynamic>>[]
        : observerOverlaysForReport(
            observation: observation,
            tester: executor.tester,
            image: frame.image,
            device: device,
          );
    ctx.runtime.failureObserver?.dispose();
    ctx.runtime.failureObserver = FailureObserverArtifact(
      stepIndex: stepIndex,
      screen: _screenLabel(observation),
      elements: flattenObservationElementsForReport(observation),
      overlays: overlays,
      deviceId: device?.id,
      deviceLabel: device?.displayLabel,
      platform: device?.platform,
      model: device?.model,
    );
  } catch (_) {
    // Observer capture must never replace the real test failure.
  }
}

ScreenshotSheetFrame? _latestScreenshotFrame(
  EnsembleTestContext ctx,
  int stepIndex,
) {
  ScreenshotSheetFrame? latest;
  for (final frame in ctx.runtime.screenshotSheetFrames) {
    if (frame.stepIndex == stepIndex) latest = frame;
  }
  return latest;
}

String _screenLabel(UiObservation observation) {
  final screen = observation.screen;
  if (screen.unknown) return 'Unknown';
  final name = screen.name?.trim();
  if (name != null && name.isNotEmpty) return name;
  final route = screen.routeId?.trim();
  if (route != null && route.isNotEmpty) return route;
  return 'Unknown';
}

/// Percent-of-framed-image overlays for HTML (aligned with failure highlights).
List<Map<String, dynamic>> observerOverlaysForReport({
  required UiObservation observation,
  required WidgetTester tester,
  required ui.Image image,
  TestDeviceTarget? device,
}) {
  final renderView = tester.binding.renderViews.first;
  final logicalSize = renderView.size;
  final imageSize = Size(image.width.toDouble(), image.height.toDouble());
  final frameDevice = !framesScreenshotsWithDeviceBezel || device == null
      ? null
      : resolveScreenshotDevice({
          'platform': device.platform,
          'model': device.model,
        });

  final overlays = <Map<String, dynamic>>[];
  void walk(UiElement element) {
    if (_shouldOverlay(element)) {
      final overlay = _overlayPercent(
        element: element,
        logicalSize: logicalSize,
        imageSize: imageSize,
        frameDevice: frameDevice,
      );
      if (overlay != null) overlays.add(overlay);
    }
    for (final child in element.children) {
      walk(child);
    }
  }

  for (final root in observation.elements) {
    walk(root);
  }
  return overlays;
}

bool _shouldOverlay(UiElement element) {
  if (element.state.visible == false) return false;
  final bounds = element.bounds;
  if (bounds == null) return false;
  if (bounds.width < 4 || bounds.height < 4) return false;
  final type = (element.type ?? '').toLowerCase();
  if (type == 'widget') return false;
  return true;
}

Map<String, dynamic>? _overlayPercent({
  required UiElement element,
  required Size logicalSize,
  required Size imageSize,
  DeviceInfo? frameDevice,
}) {
  final bounds = element.bounds!;
  final logical = Rect.fromLTWH(
    bounds.left,
    bounds.top,
    bounds.width,
    bounds.height,
  );
  if (logical.isEmpty) return null;
  final scaled = screenshotLogicalRectToImagePixels(
    logicalRect: logical,
    logicalSize: logicalSize,
    imageSize: imageSize,
  );
  if (scaled.isEmpty) return null;
  final clipped = scaled.intersect(Offset.zero & imageSize);
  if (clipped.width < 8 || clipped.height < 8) return null;
  if (scaled.height > 0 && clipped.height / scaled.height < 0.45) return null;
  if (scaled.width > 0 && clipped.width / scaled.width < 0.45) return null;

  final framed = screenshotHighlightPercentRect(
    rectInImagePixels: clipped,
    imageSize: imageSize,
    frameDevice: frameDevice,
  );
  // [screenshotHighlightPercentRect] returns LTRB percents; [Rect.width] is
  // already right-left (same as failure ScreenshotHighlight).
  if (framed.width <= 0 || framed.height <= 0) return null;

  // Chip id only when it is a usable selector id. After enrichSuggestedLocators,
  // a missing suggestedLocator.id means the raw testId was rejected (e.g. page
  // shell) — do not fall back and re-label every highlight with the screen name.
  final suggested = element.suggestedLocator;
  String? id;
  if (suggested != null) {
    final sid = suggested.id?.trim();
    if (sid != null && sid.isNotEmpty) id = sid;
  } else {
    final tid = element.testId?.trim();
    if (tid != null && tid.isNotEmpty) id = tid;
  }
  final type = (element.type ?? element.role)?.trim();
  return {
    'left': framed.left,
    'top': framed.top,
    'width': framed.width,
    'height': framed.height,
    if (id != null) 'id': id,
    if (type != null && type.isNotEmpty && type.toLowerCase() != 'widget')
      'type': type,
  };
}

/// Flat element rows for the HTML Observer table (no nested children).
List<Map<String, dynamic>> flattenObservationElementsForReport(
  UiObservation observation,
) {
  final out = <Map<String, dynamic>>[];
  var index = 1;
  void walk(UiElement element) {
    final visible = element.state.visible != false;
    if (visible) {
      out.add(_elementRow(index++, element));
    }
    for (final child in element.children) {
      walk(child);
    }
  }

  for (final root in observation.elements) {
    walk(root);
  }
  return out;
}

Map<String, dynamic> _elementRow(int index, UiElement element) {
  final type = (element.type ?? element.role ?? 'widget').trim();
  final title = _titleFor(element);
  final locator = element.suggestedLocator;
  final selector = locator == null
      ? null
      : formatSuggestedSelector(locator);
  final value = _valueFor(element, type: type, title: title);
  return {
    'index': index,
    'type': type,
    if (title != null && title.isNotEmpty) 'title': title,
    if (element.testId != null && element.testId!.trim().isNotEmpty)
      'id': element.testId!.trim(),
    if (selector != null && selector.isNotEmpty) 'selector': selector,
    if (element.locatorWarning != null &&
        element.locatorWarning!.trim().isNotEmpty)
      'warning': element.locatorWarning!.trim(),
    if (element.state.enabled != null) 'enabled': element.state.enabled,
    if (element.state.checked != null) 'checked': element.state.checked,
    if (value != null) 'value': value,
    if (element.options.isNotEmpty) 'options': element.options,
  };
}

/// Editable / selected content only — never repeat a button/icon label as value.
String? _valueFor(
  UiElement element, {
  required String type,
  required String? title,
}) {
  switch (type.toLowerCase()) {
    case 'textinput':
    case 'textfield':
    case 'dropdown':
      break;
    default:
      return null;
  }
  final text = element.text?.trim();
  if (text == null || text.isEmpty) return null;
  if (title != null && title.trim() == text) return null;
  return text;
}

String? _titleFor(UiElement element) {
  final type = (element.type ?? '').toLowerCase();
  switch (type) {
    case 'text':
      return _firstNonEmpty([element.text, element.label]);
    case 'icon':
      return _firstNonEmpty([element.text, element.label]);
    case 'image':
    case 'svg':
    case 'gif':
    case 'lottie':
      return _firstNonEmpty([element.text, element.label, element.testId]);
    case 'dropdown':
    case 'switch':
    case 'toggle':
    case 'textinput':
    case 'textfield':
      return _firstNonEmpty([element.label, element.testId]);
    case 'button':
    case 'card':
      return _firstNonEmpty([element.text, element.label, element.testId]);
    default:
      return _firstNonEmpty([element.label, element.text, element.testId]);
  }
}

String? _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  }
  return null;
}
