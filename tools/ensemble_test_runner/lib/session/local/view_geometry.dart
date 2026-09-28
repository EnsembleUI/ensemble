import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Logical screen viewport shared by observer visibility and bounds checks.
///
/// `RenderView.paintBounds` can include platform-specific extra paint area in
/// integration runs. Observer coordinates and the serialized viewport are in
/// logical view pixels, so visibility must use the same view dimensions.
Rect logicalViewportRect(WidgetTester tester) {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  return Offset.zero & size;
}

bool rectIntersectsLogicalViewport(Rect rect, WidgetTester tester) =>
    rect.isFinite &&
    !rect.isEmpty &&
    logicalViewportRect(tester).overlaps(rect);
