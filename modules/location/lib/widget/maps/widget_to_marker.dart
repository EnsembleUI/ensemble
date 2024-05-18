import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;

import 'package:google_maps_flutter/google_maps_flutter.dart';

// courtesy of https://github.com/Mohamedfaroouk/widget_to_marker
/// extension to convert widget to bitmap descriptor for Google Maps
/// This only works on Native / Canvaskit (not HTML renderer)
extension ToBitmapDescriptor on Widget {
  Future<BitmapDescriptor> toBitmapDescriptor(
      {required int maxWidth, required int maxHeight}) async {
    final (pngBytes, width, height) =
        await _createImageFromWidget(ConstrainedBox(
      constraints: BoxConstraints(
          maxWidth: maxWidth.toDouble(), maxHeight: maxHeight.toDouble()),
      child: this,
    ));
    final view = ui.PlatformDispatcher.instance.views.first;
    return BitmapDescriptor.fromBytes(
      pngBytes,
      size: Size(
        width / view.devicePixelRatio,
        height / view.devicePixelRatio,
      ),
    );
  }
}

Future<(Uint8List, int, int)> _createImageFromWidget(Widget widget) async {
  final repaintBoundary = RenderRepaintBoundary();
  final view = ui.PlatformDispatcher.instance.views.first;
  final renderView = RenderView(
    view: view,
    child: RenderPositionedBox(
      alignment: Alignment.center,
      child: repaintBoundary,
    ),
    configuration: ViewConfiguration(
      size: view.physicalSize,
      devicePixelRatio: view.devicePixelRatio,
    ),
  );
  final pipelineOwner = PipelineOwner();
  final buildOwner = BuildOwner(focusManager: FocusManager());
  pipelineOwner.rootNode = renderView;
  renderView.prepareInitialFrame();

  final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
    container: repaintBoundary,
    child: RepaintBoundary(
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: widget,
        ),
      ),
    ),
  ).attachToRenderTree(buildOwner);

  buildOwner.buildScope(rootElement);
  await Future.delayed(const Duration(milliseconds: 300));
  buildOwner.buildScope(rootElement);
  buildOwner.finalizeTree();
  pipelineOwner.flushLayout();
  pipelineOwner.flushCompositingBits();
  pipelineOwner.flushPaint();
  final ui.Image image = await repaintBoundary.toImage(
    pixelRatio: view.devicePixelRatio,
  );
  final ByteData? byteData = await image.toByteData(
    format: ui.ImageByteFormat.png,
  );
  return (byteData!.buffer.asUint8List(), image.width, image.height);
}
