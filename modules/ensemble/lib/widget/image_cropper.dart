import 'dart:math';
import 'dart:io' as io;
import 'package:custom_image_crop/custom_image_crop.dart';
import 'package:ensemble/action/haptic_action.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/widget/helpers/box_wrapper.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg_provider/flutter_svg_provider.dart';
import 'package:path_provider/path_provider.dart';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

import 'widget_util.dart';

// ignore: must_be_immutable
class EnsembleImageCropper extends StatefulWidget
    with
        Invokable,
        HasController<EnsembleImageCropperController,
            EnsembleImageCropperState> {
  static const type = 'ImageCropper';
  EnsembleImageCropper({Key? key}) : super(key: key);

  final EnsembleImageCropperController _controller =
      EnsembleImageCropperController();
  @override
  get controller => _controller;

  @override
  State<StatefulWidget> createState() => EnsembleImageCropperState();

  @override
  Map<String, Function> getters() {
    return {
      'source': () => _controller.source,
      'fit': () => _controller.fit,
      'width': () => _controller.imageWidth,
      'height': () => _controller.imageHeight,
      'placeholderColor': () => _controller.placeholderColor,
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'crop': () => _controller.cropAction?.cropImage(),
      'reset': () => _controller.reset(),
      'rotateLeft': () => _controller.rotateLeft(),
      'rotateRight': () => _controller.rotateRight(),
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'id': (value) => _controller.id = Utils.getString(value, fallback: ''),
      'source': (value) =>
          _controller.source = Utils.getString(value, fallback: ''),
      'shape': (value) =>
          _controller.shape = Utils.getString(value, fallback: 'Circle'),
      'fit': (value) => _controller.fit = Utils.optionalString(value),
      'width': (width) => _controller.imageWidth = Utils.optionalDouble(width),
      'height': (height) =>
          _controller.imageHeight = Utils.optionalDouble(height),
      'borderRadius': (borderRadius) =>
          _controller.shapeBorderRadius = Utils.optionalDouble(borderRadius),
      'strokeColor': (value) => _controller.strokeColor = Utils.getColor(value),
      'strokeWidth': (width) =>
          _controller.strokeWidth = Utils.optionalDouble(width),
      'cropPercentage': (cropPercentage) => _controller.cropPercentage =
          Utils.optionalDouble(cropPercentage, max: 1.0),
      'placeholderColor': (value) =>
          _controller.placeholderColor = Utils.getColor(value),
      'onTap': (funcDefinition) => _controller.onTap =
          EnsembleAction.from(funcDefinition, initiator: this),
      'onTapHaptic': (value) =>
          _controller.onTapHaptic = Utils.optionalString(value),
      'isRotate': (value) =>
          _controller.isRotate = Utils.getBool(value, fallback: true),
      'isMove': (value) =>
          _controller.isMove = Utils.getBool(value, fallback: true),
      'isScale': (value) =>
          _controller.isScale = Utils.getBool(value, fallback: true),
      'onCropped': (funcDefinition) => _controller.onCropped =
          EnsembleAction.from(funcDefinition, initiator: this)
    };
  }
}

mixin CropAction on EWidgetState<EnsembleImageCropper> {
  Future<void> cropImage();
}

class EnsembleImageCropperController extends BoxController {
  CropAction? cropAction;
  String source = '';
  String? fit;
  Color? placeholderColor;
  EnsembleAction? onTap;
  double? imageHeight;
  double? imageWidth;

  double? strokeWidth;
  double? shapeBorderRadius;
  double? cropPercentage;
  String shape = '';
  String? onTapHaptic;
  Color? strokeColor;
  bool isRotate = true;
  bool isMove = true;
  bool isScale = true;
  EnsembleAction? onCropped;
  CustomImageCropController cropController = CustomImageCropController();

  Future<String?> cropImage() async {
    final image = await cropController.onCropImage();
    if (image != null) {
      io.Directory tempDir = await getTemporaryDirectory();
      String tempPath = tempDir.path;
      final filePath =
          '$tempPath/${DateTime.now().toIso8601String()}-cropped-image.png';
      final file = io.File(filePath);
      final byteData = image.bytes.buffer.asUint8List();
      file.createSync();
      await file.writeAsBytes(byteData.toList());
      return file.path;
    }
    return null;
  }

  void reset() {
    cropController.reset();
  }

  void rotateLeft() {
    cropController.addTransition(CropImageData(angle: -pi / 4));
  }

  void rotateRight() {
    cropController.addTransition(CropImageData(angle: pi / 4));
  }
}

class EnsembleImageCropperState extends EWidgetState<EnsembleImageCropper>
    with CropAction {
  late Widget placeholder;
  final currentShape = CustomCropShape.Circle;

  @override
  void initState() {
    super.initState();
    placeholder = getPlaceholder();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.controller.cropAction = this;
  }

  @override
  void didUpdateWidget(covariant EnsembleImageCropper oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller.cropAction = this;
  }

  @override
  Future<void> cropImage() async {
    final imagePath = await widget.controller.cropImage();
    if (imagePath != null) {
      ScreenController().executeAction(
        context,
        widget._controller.onCropped!,
        event: EnsembleEvent(
          widget,
          data: {'file': imagePath},
        ),
      );
    }
  }

  @override
  Widget buildWidget(BuildContext context) {
    String source = widget._controller.source.trim();
    // use the placeholder for the initial state before binding kicks in
    if (source.isEmpty) {
      return placeholder;
    }

    BoxFit? fit = Utils.getBoxFit(widget._controller.fit);
    final cropShape = _getCropShape();

    Widget rtn;
    rtn = SizedBox(
      height: widget.controller.imageHeight,
      width: widget.controller.imageWidth,
      child: BoxWrapper(
          widget: CustomImageCrop(
            backgroundColor: widget.controller.backgroundColor ?? Colors.white,
            cropController: widget.controller.cropController,
            image: buildImageProvider(source,
                fit), // Any Imageprovider will work, try with a NetworkImage for example...
            shape: cropShape,
            imageFit: CustomImageFit.fillVisibleSpace,
            ratio: _getRatio(cropShape),
            canRotate: widget.controller.isRotate,
            canMove: widget.controller.isMove,
            canScale: widget.controller.isScale,
            borderRadius: widget.controller.shapeBorderRadius ?? 0,
            customProgressIndicator: const CupertinoActivityIndicator(),
            cropPercentage: widget.controller.cropPercentage ?? 0.8,
            // use custom paint if needed
            pathPaint: Paint()
              ..color = widget.controller.strokeColor ?? Colors.white
              ..strokeWidth = widget.controller.strokeWidth ?? 4.0
              ..style = PaintingStyle.stroke
              ..strokeJoin = StrokeJoin.round,
          ),
          boxController: widget._controller,
          ignoresMargin: true, // make sure the gesture don't include the margin
          ignoresDimension: true // we apply width/height in the image already
          ),
    );
    if (widget._controller.onTap != null) {
      rtn = GestureDetector(
        child: rtn,
        onTap: () {
          if (widget._controller.onTapHaptic != null) {
            ScreenController().executeAction(
              context,
              HapticAction(
                type: widget._controller.onTapHaptic!,
                onComplete: null,
              ),
            );
          }

          ScreenController().executeAction(context, widget._controller.onTap!,
              event: EnsembleEvent(widget));
        },
      );
    }
    if (widget._controller.margin != null) {
      rtn = Padding(padding: widget._controller.margin!, child: rtn);
    }
    return rtn;
  }

  CustomCropShape _getCropShape() {
    String? shape =
        capitalizeFirstLetter(widget.controller.shape.toLowerCase());
    shape = shape == 'Rectangle' ? CustomCropShape.Ratio.name : shape;
    return CustomCropShape.values.from(shape) ?? CustomCropShape.Circle;
  }

  String? capitalizeFirstLetter(String? value) {
    if (value == null || value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
  }

  Ratio? _getRatio(CustomCropShape cropShape) {
    switch (cropShape) {
      case CustomCropShape.Ratio:
        return Ratio(width: 19, height: 9);
      case CustomCropShape.Square:
        return Ratio(width: 1, height: 1);
      case CustomCropShape.Circle:
        return null;
    }
  }

  bool isSvg() {
    return widget._controller.source.endsWith('svg');
  }

  ImageProvider buildImageProvider(String source, BoxFit? fit) {
    if (isSvg()) {
      return buildSvgImageProvider(source, fit);
    }
    return buildNonSvgImageProvider(source, fit);
  }

  ImageProvider buildNonSvgImageProvider(String source, BoxFit? fit) {
    if (source.startsWith('https://') || source.startsWith('http://')) {
      return Image.network(
        source,
        width: widget._controller.width?.toDouble(),
        height: widget._controller.height?.toDouble(),
      ).image;
    } else if (Utils.isMemoryPath(widget._controller.source)) {
      return Image.file(
        io.File(widget._controller.source),
        width: widget._controller.width?.toDouble(),
        height: widget._controller.height?.toDouble(),
        fit: fit,
      ).image;
    } else {
      return Image.asset(
        Utils.getLocalAssetFullPath(widget._controller.source),
        width: widget._controller.width?.toDouble(),
        height: widget._controller.height?.toDouble(),
        fit: fit,
      ).image;
    }
  }

  Svg buildSvgImageProvider(String source, BoxFit? fit) {
    // if is URL
    if (source.startsWith('https://') || source.startsWith('http://')) {
      return Svg(widget._controller.source, source: SvgSource.network);
    }
    // attempt local assets
    return Svg(
      Utils.getLocalAssetFullPath(widget._controller.source),
      source: SvgSource.asset,
    );
  }

  // use modern colors as background placeholder while images are being loaded
  final placeholderColors = [
    0xffD9E3E5,
    0xffBBCBD2,
    0xffA79490,
    0xffD7BFA8,
    0xffEAD9C9,
    0xffEEEAE7
  ];
  Widget getPlaceholder() {
    // container without child will get the size of its parent
    return Container(
      decoration: BoxDecoration(
        color: widget._controller.placeholderColor ??
            Color(
              placeholderColors[Random().nextInt(placeholderColors.length)],
            ),
      ),
    );
  }
}
