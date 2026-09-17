import 'package:crypto/crypto.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:ensemble_test_runner/session/observation/ui_observation.dart';
import 'dart:convert';

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
    buffer.write(_elementDigest(el));
    buffer.write('\n');
  }
  return sha256.convert(utf8.encode(buffer.toString())).toString();
}

String fingerprintForElement(UiElement element) => _elementDigest(element);

String _elementDigest(UiElement element) {
  final b = element.bounds;
  // Bucket bounds to reduce noise from sub-pixel layout jitter.
  String bucket(double? v) =>
      v == null ? '' : (v / 4).round().toString();
  return [
    element.testId ?? '',
    element.type ?? '',
    element.label ?? '',
    element.text ?? '',
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
