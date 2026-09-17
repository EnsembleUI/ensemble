import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a semantic [UiElement] snapshot from a live Flutter [Element].
///
/// Shared by [FlutterUiObserver] and live fingerprint revalidation so observe
/// and act agree on observable state.
UiElement describeElement({
  required Element element,
  required String elementId,
  required String? testId,
  required AssertionEngine assertions,
  required WidgetTester tester,
  required bool includeBounds,
}) {
  final type = inferWidgetType(element);
  final secure = looksSecure(element, testId);
  final bounds = boundsFor(element);
  final visible = assertions.isElementVisuallyActionable(element);
  final offscreen = bounds != null && !inViewport(tester, bounds);
  final enabled = readEnabled(element);
  final text = secure ? null : readText(element);
  final label = secure ? null : readSemanticsLabel(tester, element);
  final checked = readChecked(element);
  final interactable = visible && !offscreen && enabled != false;

  return UiElement(
    elementId: elementId,
    testId: testId,
    type: type,
    label: label,
    text: text,
    state: UiElementState(
      exists: true,
      visible: visible,
      interactable: interactable,
      enabled: enabled,
      secure: secure,
      offscreen: offscreen,
      obscured: false,
      checked: checked,
    ),
    bounds: includeBounds ? bounds : null,
    supportedActions: supportedActionsFor(type, secure: secure),
  );
}

T? _selfOrAncestor<T extends Widget>(Element element) {
  final w = element.widget;
  if (w is T) return w;
  return element.findAncestorWidgetOfExactType<T>();
}

String inferWidgetType(Element element) {
  if (_selfOrAncestor<EditableText>(element) != null ||
      _selfOrAncestor<TextField>(element) != null ||
      _selfOrAncestor<CupertinoTextField>(element) != null) {
    return 'textInput';
  }
  if (_selfOrAncestor<ElevatedButton>(element) != null ||
      _selfOrAncestor<TextButton>(element) != null ||
      _selfOrAncestor<OutlinedButton>(element) != null ||
      _selfOrAncestor<FilledButton>(element) != null ||
      _selfOrAncestor<IconButton>(element) != null ||
      _selfOrAncestor<GestureDetector>(element) != null ||
      _selfOrAncestor<InkWell>(element) != null) {
    return 'button';
  }
  if (_selfOrAncestor<Switch>(element) != null ||
      _selfOrAncestor<CupertinoSwitch>(element) != null ||
      _selfOrAncestor<Checkbox>(element) != null) {
    return 'toggle';
  }
  if (_selfOrAncestor<Slider>(element) != null) {
    return 'slider';
  }
  if (element.widget is Text || element.widget is RichText) {
    return 'text';
  }
  return 'widget';
}

bool looksSecure(Element element, String? testId) {
  final editable = _selfOrAncestor<EditableText>(element);
  if (editable != null && editable.obscureText) return true;
  final field = _selfOrAncestor<TextField>(element);
  if (field != null && field.obscureText) return true;
  final cupertino = _selfOrAncestor<CupertinoTextField>(element);
  if (cupertino != null && cupertino.obscureText) return true;
  return false;
}

bool? readEnabled(Element element) {
  final elevated = _selfOrAncestor<ElevatedButton>(element);
  if (elevated != null) return elevated.onPressed != null;
  final textButton = _selfOrAncestor<TextButton>(element);
  if (textButton != null) return textButton.onPressed != null;
  final outlined = _selfOrAncestor<OutlinedButton>(element);
  if (outlined != null) return outlined.onPressed != null;
  final filled = _selfOrAncestor<FilledButton>(element);
  if (filled != null) return filled.onPressed != null;
  final icon = _selfOrAncestor<IconButton>(element);
  if (icon != null) return icon.onPressed != null;

  final sw = _selfOrAncestor<Switch>(element);
  if (sw != null) return sw.onChanged != null;
  final cupertino = _selfOrAncestor<CupertinoSwitch>(element);
  if (cupertino != null) return cupertino.onChanged != null;
  final cb = _selfOrAncestor<Checkbox>(element);
  if (cb != null) return cb.onChanged != null;
  return null;
}

bool? readChecked(Element element) {
  final sw = _selfOrAncestor<Switch>(element);
  if (sw != null) return sw.value;
  final cupertino = _selfOrAncestor<CupertinoSwitch>(element);
  if (cupertino != null) return cupertino.value;
  final cb = _selfOrAncestor<Checkbox>(element);
  if (cb != null) return cb.value;
  return null;
}

String? readText(Element element) {
  final texts = <String>[];
  void visit(Element e) {
    final w = e.widget;
    if (w is Text && w.data != null && w.data!.isNotEmpty) {
      texts.add(w.data!);
    }
    if (w is EditableText && w.controller.text.isNotEmpty) {
      texts.add(w.controller.text);
    }
    e.visitChildren(visit);
  }

  visit(element);
  if (texts.isEmpty) return null;
  return texts.first;
}

String? readSemanticsLabel(WidgetTester tester, Element element) {
  try {
    final node = tester.getSemantics(
      find.byElementPredicate((e) => identical(e, element)),
    );
    final label = node.label;
    return label.isEmpty ? null : label;
  } catch (_) {
    return null;
  }
}

UiBounds? boundsFor(Element element) {
  final renderObject = element.renderObject;
  if (renderObject is! RenderBox ||
      !renderObject.hasSize ||
      renderObject.size.isEmpty) {
    return null;
  }
  final topLeft = renderObject.localToGlobal(Offset.zero);
  final rect = topLeft & renderObject.size;
  if (!rect.isFinite || rect.isEmpty) return null;
  return UiBounds(
    left: rect.left,
    top: rect.top,
    width: rect.width,
    height: rect.height,
  );
}

bool inViewport(WidgetTester tester, UiBounds bounds) {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  final rect =
      Rect.fromLTWH(bounds.left, bounds.top, bounds.width, bounds.height);
  return (Offset.zero & size).overlaps(rect);
}

List<String> supportedActionsFor(String? type, {required bool secure}) {
  switch (type) {
    case 'textInput':
      return secure
          ? const ['tap', 'enterText', 'clearText', 'focus']
          : const [
              'tap',
              'enterText',
              'clearText',
              'replaceText',
              'submitText',
              'focus',
            ];
    case 'button':
      return const ['tap', 'longPress', 'doubleTap'];
    case 'toggle':
      return const ['tap', 'toggle', 'check', 'uncheck'];
    case 'slider':
      return const ['tap', 'setSlider'];
    case 'text':
      return const ['tap'];
    default:
      return const ['tap'];
  }
}
