import 'dart:math';
import 'dart:io' as io;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:custom_image_crop/custom_image_crop.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble/widget/image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';

// import 'package:crop_your_image/crop_your_image.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      'reset': () => _controller.cropAction?.reset(),
      'rotateLeft': () => _controller.cropAction?.rotateLeft(),
      'rotateRight': () => _controller.cropAction?.rotateRight(),
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'id': (value) => _controller.id = Utils.getString(value, fallback: ''),
      'source': (value) =>
          _controller.source = Utils.getString(value, fallback: ''),
      'fit': (value) => _controller.fit = Utils.optionalString(value),
      'width': (width) => _controller.imageWidth = Utils.optionalDouble(width),
      'height': (height) =>
          _controller.imageHeight = Utils.optionalDouble(height),
      'placeholderColor': (value) =>
          _controller.placeholderColor = Utils.getColor(value),
      'onTap': (funcDefinition) => _controller.onTap =
          EnsembleAction.fromYaml(funcDefinition, initiator: this),
      'isRotate': (value) =>
          _controller.isRotate = Utils.getBool(value, fallback: true),
      'isMove': (value) =>
          _controller.isMove = Utils.getBool(value, fallback: true),
      'isScale': (value) =>
          _controller.isScale = Utils.getBool(value, fallback: true),
      'cropOnTap': (value) =>
          _controller.cropOnTap = Utils.getBool(value, fallback: true),
      'onCropped': (funcDefinition) => _controller.onCropped =
          EnsembleAction.fromYaml(funcDefinition, initiator: this)
    };
  }
}

mixin CropAction on WidgetState<EnsembleImageCropper> {
  Future<void> cropImage();
  void reset();
  void rotateLeft();
  void rotateRight();
}

class EnsembleImageCropperController extends BoxController {
  CropAction? cropAction;
  String source = '';
  String? fit;
  Color? placeholderColor;
  EnsembleAction? onTap;
  double? imageHeight;
  double? imageWidth;

  Color? cornerDotColor;
  Color? maskColor;
  double? cornerRadius;
  bool? cropOnTap;
  bool isRotate = true;
  bool isMove = true;
  bool isScale = true;
  EnsembleAction? onCropped;
  EnsembleAction? onStatusChanged;
  CustomImageCropController cropController = CustomImageCropController();
}

class EnsembleImageCropperState extends WidgetState<EnsembleImageCropper>
    with CropAction {
  late Widget placeholder;
  Uint8List? _croppedImage;
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
    final image = await widget.controller.cropController.onCropImage();
    if (image != null) {
      _croppedImage = image.bytes;
      final filePath =
          File('croppedImage', null, image.bytes.length, null, image.bytes)
                  .path ??
              '';
      ScreenController().executeAction(
        context,
        widget._controller.onCropped!,
        event: EnsembleEvent(
          widget,
          data: {'file': filePath},
        ),
      );
      setState(() {});
    }
  }

  @override
  void reset() {
    widget.controller.cropController.reset();
  }

  @override
  void rotateLeft() {
    widget.controller.cropController
        .addTransition(CropImageData(angle: -pi / 4));
  }

  @override
  void rotateRight() {
    widget.controller.cropController
        .addTransition(CropImageData(angle: pi / 4));
  }

  @override
  Widget buildWidget(BuildContext context) {
    String source = widget._controller.source.trim();
    // use the placeholder for the initial state before binding kicks in
    if (source.isEmpty) {
      return placeholder;
    }

    BoxFit? fit = WidgetUtils.getBoxFit(widget._controller.fit);

    Widget rtn;
    rtn = _croppedImage != null
        ? Image.memory(
            _croppedImage!,
            height: widget.controller.imageHeight,
            width: widget.controller.imageWidth,
          )
        : SizedBox(
            height: widget.controller.imageHeight,
            width: widget.controller.imageWidth,
            child: BoxWrapper(
                widget: CustomImageCrop(
                  backgroundColor:
                      widget.controller.backgroundColor ?? Colors.white,
                  cropController: widget.controller.cropController,
                  image: buildImageProvider(source,
                      fit), // Any Imageprovider will work, try with a NetworkImage for example...
                  shape: currentShape,
                  // ratio: currentShape == CustomCropShape.Ratio
                  //     ? Ratio(width: width, height: height)
                  //     : null,
                  canRotate: widget.controller.isRotate,
                  canMove: widget.controller.isMove,
                  canScale: widget.controller.isScale,
                  // borderRadius:
                  //     currentShape == CustomCropShape.Ratio ? radius : 0,
                  customProgressIndicator: const CupertinoActivityIndicator(),
                  // use custom paint if needed
                  // pathPaint: Paint()
                  //   ..color = Colors.red
                  //   ..strokeWidth = 4.0
                  //   ..style = PaintingStyle.stroke
                  //   ..strokeJoin = StrokeJoin.round,
                ),
                boxController: widget._controller,
                ignoresMargin:
                    true, // make sure the gesture don't include the margin
                ignoresDimension:
                    true // we apply width/height in the image already
                ),
          );
    if (widget._controller.onTap != null) {
      rtn = GestureDetector(
          child: rtn,
          onTap: () => ScreenController().executeAction(
              context, widget._controller.onTap!,
              event: EnsembleEvent(widget)));
    }
    if (widget._controller.margin != null) {
      rtn = Padding(padding: widget._controller.margin!, child: rtn);
    }
    return rtn;
  }

  ImageProvider buildImageProvider(String source, BoxFit? fit) {
    if (source.startsWith('https://') || source.startsWith('http://')) {
      return CachedNetworkImageProvider(
        source,
        maxWidth: widget._controller.width,
        maxHeight: widget._controller.height,
      );
    } else if (Utils.isMemoryPath(widget._controller.source)) {
      return Image.file(io.File(widget._controller.source),
          width: widget._controller.width?.toDouble(),
          height: widget._controller.height?.toDouble(),
          fit: fit,
          errorBuilder: (context, error, stacktrace) => errorFallback()).image;
    } else {
      return Image.asset(Utils.getLocalAssetFullPath(widget._controller.source),
          width: widget._controller.width?.toDouble(),
          height: widget._controller.height?.toDouble(),
          fit: fit,
          errorBuilder: (context, error, stacktrace) => errorFallback()).image;
    }
  }

  /// display if the image cannot be loaded
  Widget errorFallback() {
    return Image.asset(
      'assets/images/img_placeholder.png',
      package: 'ensemble',
      fit: BoxFit.cover,
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
