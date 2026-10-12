import 'package:ensemble_test_runner/session/local/modal_route_lookup.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:ensemble_test_runner/session/local/view_geometry.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Geometry and visibility queries shared by observation and assertions.
///
/// These checks intentionally use render-tree state and the logical viewport.
/// They do not register inherited-widget dependencies while inspecting a
/// target, which keeps hot-path checks safe during route transitions.
bool isElementGeometricallyVisible(Element element, WidgetTester tester) {
  if (!isUnderCurrentModalRoute(element)) return false;
  if (isUnderOffstageAncestor(element)) return false;
  final renderObject = element.renderObject;
  if (renderObject is! RenderBox ||
      !renderObject.hasSize ||
      renderObject.size.isEmpty) {
    return false;
  }
  if (effectiveElementOpacity(element) <= 0.01) return false;
  final topLeft = renderObject.localToGlobal(Offset.zero);
  final rect = topLeft & renderObject.size;
  if (!rect.isFinite || rect.isEmpty) return false;
  return rectIntersectsLogicalViewport(rect, tester);
}

/// Whether [element] is retained by an [Offstage] subtree rather than part of
/// the current rendered screen.
bool isUnderOffstageAncestor(Element element) {
  var isOffstage = false;
  element.visitAncestorElements((ancestor) {
    final renderObject = ancestor.renderObject;
    if (renderObject is RenderOffstage && renderObject.offstage) {
      isOffstage = true;
      return false;
    }
    return true;
  });
  return isOffstage;
}

/// Returns the effective opacity contributed by the element's ancestors.
double effectiveElementOpacity(Element element) {
  var opacity = 1.0;
  element.visitAncestorElements((ancestor) {
    final renderObject = ancestor.renderObject;
    if (renderObject is RenderOpacity) {
      opacity *= renderObject.opacity;
    } else if (renderObject != null &&
        renderObject.runtimeType.toString() == 'RenderAnimatedOpacity') {
      try {
        final animatedOpacity = (renderObject as dynamic).opacity;
        if (animatedOpacity is Animation<double>) {
          opacity *= animatedOpacity.value;
        } else if (animatedOpacity is double) {
          opacity *= animatedOpacity;
        }
      } catch (_) {
        // Keep the opacity already collected from other ancestors.
      }
    }
    return opacity > 0.01;
  });
  return opacity;
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
  final rect =
      Rect.fromLTWH(bounds.left, bounds.top, bounds.width, bounds.height);
  return rectIntersectsLogicalViewport(rect, tester);
}
