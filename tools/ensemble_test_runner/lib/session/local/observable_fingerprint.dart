import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:ensemble_test_runner/session/local/widget_locator_id.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:ensemble_test_runner/session/observation/ui_observation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds an observable-state fingerprint from semantic fields (not ID/count-only).
String fingerprintForObservation({
  required ScreenObservation screen,
  required List<UiElement> elements,
}) {
  final buffer = StringBuffer();
  buffer.write('screen:');
  buffer.write(screen.name ?? '');
  buffer.write('|');
  buffer.write(screen.routeId ?? '');
  buffer.write('|');
  buffer.write(screen.hasModal);
  buffer.write('|');
  buffer.write(screen.navigationStack.join(','));
  buffer.write('|');
  buffer.write(screen.isLoading);
  buffer.write('\n');
  for (final el in elements) {
    _writeElementTreeDigest(buffer, el, 0);
  }
  return sha256.convert(utf8.encode(buffer.toString())).toString();
}

String fingerprintForElement(UiElement element) => _elementDigest(element);

/// Cheap post-mutation digest: route + owned keys + plain widget text.
///
/// Never enables semantics or walks a full observe tree — used by
/// [FlutterUiObserver.syncRevisionAfterMutation] on every `act`.
String lightweightMutationFingerprint({
  required WidgetTester tester,
  String? routeName,
}) {
  final buffer = StringBuffer();
  buffer.write('route:');
  buffer.write(routeName?.trim() ?? '');
  buffer.write('\n');
  for (final element in tester.allElements) {
    final ownedId = readOwnedWidgetLocatorId(element);
    if (ownedId != null && ownedId.isNotEmpty) {
      buffer.write('id:');
      buffer.write(ownedId);
      buffer.write('\n');
    }
    final widget = element.widget;
    if (widget is Text) {
      final data = widget.data?.trim();
      if (data != null && data.isNotEmpty) {
        buffer.write('text:');
        buffer.write(data);
        buffer.write('\n');
      }
    } else if (widget is TextField) {
      final value = widget.controller?.text.trim();
      if (value != null && value.isNotEmpty) {
        buffer.write('field:');
        buffer.write(value);
        buffer.write('\n');
      }
    } else if (widget is EditableText) {
      final value = widget.controller.text.trim();
      if (value.isNotEmpty) {
        buffer.write('edit:');
        buffer.write(value);
        buffer.write('\n');
      }
    }
  }
  return sha256.convert(utf8.encode(buffer.toString())).toString();
}

void _writeElementTreeDigest(StringBuffer buffer, UiElement element, int depth) {
  buffer.write('  ' * depth);
  buffer.write(_elementDigest(element));
  buffer.write('\n');
  for (final child in element.children) {
    _writeElementTreeDigest(buffer, child, depth + 1);
  }
}

String _elementDigest(UiElement element) {
  final b = element.bounds;
  // Bucket bounds to reduce noise from sub-pixel layout jitter.
  String bucket(double? v) => v == null ? '' : (v / 4).round().toString();
  return [
    element.testId ?? '',
    element.type ?? '',
    element.role ?? '',
    element.label ?? '',
    element.text ?? '',
    element.hint ?? '',
    element.options.join(','),
    element.state.visible,
    element.state.enabled,
    element.state.interactable,
    element.state.focused,
    element.state.selected,
    element.state.checked,
    element.state.obscured,
    element.state.offscreen,
    element.state.secure,
    bucket(b?.left),
    bucket(b?.top),
    bucket(b?.width),
    bucket(b?.height),
    element.supportedActions.join(','),
  ].join('|');
}
