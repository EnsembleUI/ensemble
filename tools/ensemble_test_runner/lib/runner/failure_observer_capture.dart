import 'dart:ui' as ui;

import 'package:ensemble_test_runner/actions/extended_step_handlers.dart';
import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/observation/observe_screenshot.dart';
import 'package:ensemble_test_runner/session/observation/observation_options.dart';
import 'package:ensemble_test_runner/session/observation/suggested_locator.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:ensemble_test_runner/session/observation/ui_observation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bound observe used on failure — prefer a quick snapshot over long settle.
const failureObserverOptions = ObservationOptions(
  synchronization: ObservationSynchronization.immediate,
  includeBounds: true,
);

/// Live UI dump + highlighted screenshot for a failed step's Observer tab.
Future<void> captureFailureObserverBestEffort({
  required LocalTestExecutionSession session,
  required TestStepExecutor executor,
  required int stepIndex,
}) async {
  final ctx = executor.context;
  if (!ctx.config.screenshots.enabled) return;
  try {
    await testerPumpForObserver(executor.tester);
    var observation = await session.observe(options: failureObserverOptions);
    observation = enrichSuggestedLocators(
      observation: observation,
      resolver: session.resolver,
      registry: session.registry,
    );
    final raw = ExtendedStepHandlers.captureScreenshotImage(
      executor.tester,
      secureContent: ctx.config.screenshots.secureContent,
    );
    late final ui.Image highlighted;
    try {
      highlighted = await paintObservationHighlights(
        source: raw,
        observation: observation,
        tester: executor.tester,
      );
    } catch (_) {
      raw.dispose();
      rethrow;
    }
    if (!identical(raw, highlighted)) {
      raw.dispose();
    }
    final device = ctx.testCase.deviceTarget;
    ctx.runtime.failureObserver?.dispose();
    ctx.runtime.failureObserver = FailureObserverArtifact(
      stepIndex: stepIndex,
      screen: _screenLabel(observation),
      image: highlighted,
      elements: flattenObservationElementsForReport(observation),
      deviceId: device?.id,
      deviceLabel: device?.displayLabel,
      platform: device?.platform,
      model: device?.model,
    );
  } catch (_) {
    // Observer capture must never replace the real test failure.
  }
}

Future<void> testerPumpForObserver(WidgetTester tester) async {
  try {
    await tester.pump();
  } catch (_) {}
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
