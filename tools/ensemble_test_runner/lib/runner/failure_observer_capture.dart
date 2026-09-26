import 'dart:ui' as ui;

import 'package:ensemble_device_preview/ensemble_device_preview.dart';
import 'package:ensemble_test_runner/actions/screenshot_device.dart';
import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/diagnostic_ui_snapshot.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/screenshot_capture.dart';
import 'package:ensemble_test_runner/runner/test_artifacts.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:ensemble_test_runner/session/observation/observer_json.dart';
import 'package:ensemble_test_runner/session/observation/ui_observation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Live UI dump for a step's Observer tab (success or failure).
///
/// Uses [captureDiagnosticUiSnapshot] — no SemanticsHandle, no pump, no leaf
/// queue. Does **not** capture a second screenshot; call after the step frame
/// exists so overlays match that PNG.
///
/// Prefer [captureStepReportArtifacts] so shot + Observer stay paired. Mid-wait
/// hooks hold the leaf queue — pass [allowWhileQueueBusy] so report overlays
/// match the mid-wait PNG instead of drifting to the next screen.
Future<void> captureStepObserverBestEffort({
  required LocalTestExecutionSession session,
  required TestStepExecutor executor,
  required int stepIndex,
  bool allowWhileQueueBusy = false,
}) async {
  final ctx = executor.context;
  if (!ctx.config.screenshots.enabled) return;
  if (session.queue.isBusy && !allowWhileQueueBusy) return;
  final frame = _latestScreenshotFrame(ctx, stepIndex);
  if (frame == null) return;
  try {
    final snap = captureDiagnosticUiSnapshot(
      tester: executor.tester,
      assertions: session.assertions,
      navigation: session.services.navigation,
    );
    final device = ctx.testCase.deviceTarget;
    final elements = observationElementsTreeForReport(snap.observation);
    final viewport = snap.observation.viewport?.toJson();
    final observationJson = observerPayloadToJson(
      stepIndex: stepIndex,
      screen: snap.screenLabel,
      viewport: viewport,
      elements: elements,
    );
    final overlays = observerOverlaysForReport(
      observation: snap.observation,
      tester: executor.tester,
      image: frame.image,
      device: device,
    );
    ctx.runtime.upsertStepObserver(
      StepObserverArtifact(
        stepIndex: stepIndex,
        screen: snap.screenLabel,
        elements: elements,
        viewport: viewport,
        observationJson: observationJson,
        overlays: overlays,
        deviceId: device?.id,
        deviceLabel: device?.displayLabel,
        platform: device?.platform,
        model: device?.model,
      ),
    );
  } catch (_) {
    // Observer capture must never replace the real test result.
  }
}

/// True when [stepIndex] already has Observer metadata (e.g. before-step shot).
bool hasStepObserver(EnsembleTestContext ctx, int stepIndex) =>
    ctx.runtime.stepObservers.any((o) => o.stepIndex == stepIndex);

/// Write report Observer from a previously taken [snap] onto the latest frame.
///
/// Used when the tree may advance after the PNG was frozen (transient
/// `waitForNavigation` screens) — re-walking now would label the next route.
void upsertStepObserverFromSnapshot({
  required EnsembleTestContext ctx,
  required WidgetTester tester,
  required int stepIndex,
  required DiagnosticUiSnapshot snap,
}) {
  if (!ctx.config.screenshots.enabled) return;
  final frame = _latestScreenshotFrame(ctx, stepIndex);
  if (frame == null) return;
  try {
    final device = ctx.testCase.deviceTarget;
    final elements = observationElementsTreeForReport(snap.observation);
    final viewport = snap.observation.viewport?.toJson();
    final observationJson = observerPayloadToJson(
      stepIndex: stepIndex,
      screen: snap.screenLabel,
      viewport: viewport,
      elements: elements,
    );
    final overlays = observerOverlaysForReport(
      observation: snap.observation,
      tester: tester,
      image: frame.image,
      device: device,
    );
    ctx.runtime.upsertStepObserver(
      StepObserverArtifact(
        stepIndex: stepIndex,
        screen: snap.screenLabel,
        elements: elements,
        viewport: viewport,
        observationJson: observationJson,
        overlays: overlays,
        deviceId: device?.id,
        deviceLabel: device?.displayLabel,
        platform: device?.platform,
        model: device?.model,
      ),
    );
  } catch (_) {
    // Observer capture must never replace the real test result.
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
  // Same pre-order indices as [observationElementsTreeForReport] so HTML can
  // link tree rows ↔ screenshot highlights on hover.
  var index = 1;
  void walk(UiElement element) {
    // Keep indices aligned with observationElementsTreeForReport, which
    // retains offscreen nodes even when visible=false.
    if (element.state.visible == false && element.state.offscreen != true) {
      return;
    }
    final myIndex = index++;
    if (element.state.visible != false && _shouldOverlay(element)) {
      final overlay = _overlayPercent(
        element: element,
        logicalSize: logicalSize,
        imageSize: imageSize,
        frameDevice: frameDevice,
      );
      if (overlay != null) {
        overlays.add({
          ...overlay,
          'index': myIndex,
        });
      }
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
  // A keyed widget wrapper is still a meaningful target (for example a
  // scroll section). Show its bounds so the report can link that target to
  // the screenshot; only omit unkeyed structural wrappers.
  if (type == 'widget' && !_elementHasIdSelector(element)) return false;
  // Skip type-only parents when a *keyed card/toast* descendant is the real
  // target (wrapper chrome beside `id=gateway_card`). Keyed CTA buttons inside
  // NotificationCard must not suppress the banner chrome overlay.
  if (!_elementHasIdSelector(element) &&
      _subtreeHasKeyedCardOrToast(element.children)) {
    return false;
  }
  return true;
}

bool _elementHasIdSelector(UiElement element) {
  final suggested = element.suggestedLocator;
  final sid = suggested?.id?.trim();
  if (sid != null && sid.isNotEmpty) return true;
  final tid = element.testId?.trim();
  return tid != null && tid.isNotEmpty;
}

bool _subtreeHasKeyedCardOrToast(List<UiElement> elements) {
  for (final element in elements) {
    if (_elementHasIdSelector(element)) {
      final type = (element.type ?? '').toLowerCase();
      if (type == 'card' || type == 'toast') return true;
    }
    if (_subtreeHasKeyedCardOrToast(element.children)) return true;
  }
  return false;
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

/// @nodoc Legacy report name retained for callers. Serialization now lives in
/// the Observer layer so report consumers receive the already-built payload.
List<Map<String, dynamic>> observationElementsTreeForReport(
  UiObservation observation,
) =>
    observerElementsToJson(observation);

/// @nodoc Legacy alias.
List<Map<String, dynamic>> flattenObservationElementsForReport(
  UiObservation observation,
) =>
    observerElementsToJson(observation);
