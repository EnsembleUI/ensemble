import 'dart:io';
import 'dart:math';
import 'dart:io' as io;
import 'package:path_provider/path_provider.dart';

import 'package:crop_your_image/crop_your_image.dart';
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
      'cornerDotColor': () => _controller.cornerDotColor,
      'maskColor': () => _controller.maskColor,
      'cornerRadius': () => _controller.cornerRadius,
    };
  }

  @override
  Map<String, Function> methods() {
    return {'crop': () => _controller.cropController.crop()};
  }

  @override
  Map<String, Function> setters() {
    return {
      'id': (value) => _controller.id = Utils.getString(value, fallback: ''),
      'source': (value) =>
          _controller.source = Utils.getString(value, fallback: ''),
      'cornerDotColor': (value) =>
          _controller.cornerDotColor = Utils.getColor(value),
      'maskColor': (value) => _controller.maskColor = Utils.getColor(value),
      'cornerRadius': (value) =>
          _controller.cornerRadius = Utils.getDouble(value, fallback: 20),
      'cropOnTap': (value) =>
          _controller.cropOnTap = Utils.getBool(value, fallback: true),
      'onCropped': (funcDefinition) => _controller.onCropped =
          EnsembleAction.fromYaml(funcDefinition, initiator: this)
    };
  }
}

class EnsembleImageCropperController extends BoxController {
  String source = '';
  Color? cornerDotColor;
  Color? placeholderColor;
  Color? maskColor;
  double? cornerRadius;
  bool? cropOnTap;
  EnsembleAction? onCropped;
  EnsembleAction? onStatusChanged;
  CropController cropController = CropController();
}

class EnsembleImageCropperState extends WidgetState<EnsembleImageCropper> {
  late Widget placeholder;
  Uint8List? _croppedImage;

  @override
  void initState() {
    super.initState();
    placeholder = getPlaceholder();
  }

  @override
  Widget buildWidget(BuildContext context) {
    String source = widget._controller.source.trim();
    // use the placeholder for the initial state before binding kicks in
    if (source.isEmpty) {
      return placeholder;
    }

    Widget rtn;

    if (_croppedImage == null) {
      rtn = FutureBuilder(
        future: getImage(widget._controller.source),
        builder: (BuildContext context, AsyncSnapshot<Uint8List> snapshot) {
          if (snapshot.hasData) {
            return _buildCropImage(image: snapshot.data!);
          } else if (snapshot.hasError) {
            return const CircularProgressIndicator();
          }
          return getPlaceholder();
        },
      );
    } else {
      rtn = _buildCropImage();
    }

    if (widget._controller.margin != null) {
      rtn = Padding(padding: widget._controller.margin!, child: rtn);
    }
    return rtn;
  }

  Widget _buildCropImage({Uint8List? image}) {
    final imageData = image ?? _croppedImage;
    if (imageData == null) return const SizedBox();

    return SizedBox(
      height: 350,
      width: 350,
      child: Crop(
        image: imageData,
        controller: widget._controller.cropController,
        initialAreaBuilder: (rect) => Rect.fromLTRB(
          rect.left + 24,
          rect.top + 32,
          rect.right - 24,
          rect.bottom - 32,
        ),
        maskColor:
            widget._controller.maskColor ?? Colors.white.withOpacity(0.2),
        cornerDotBuilder: (size, edgeAlignment) => DotControl(
          color: widget._controller.cornerDotColor ?? Colors.white,
        ),
        radius: widget._controller.cornerRadius ?? 20,
        aspectRatio: 1,
        interactive: true,
        onMoved: (newRect) {},
        onStatusChanged: onStatusChanged,
        onCropped: onImageCropped,
      ),
    );
  }

  void onStatusChanged(CropStatus status) {
    if (widget._controller.onStatusChanged != null) {
      ScreenController().executeAction(
        context,
        widget._controller.onStatusChanged!,
        event: EnsembleEvent(widget, data: {'cropStatus': status.name}),
      );
    }
  }

  void onImageCropped(Uint8List image) async {
    _croppedImage = image;
    setState(() {});
    // final widgetId = widget._controller.id;
    // if (widget._controller.onCropped != null && widgetId != null) {
    //   // final file = io.File('croppedImage');
    //   Directory tempDir = await getTemporaryDirectory();
    //   String tempPath = tempDir.path;
    //   final filePath = '$tempPath/cropped-image.png';
    //   final file = io.File(filePath);
    //   file.createSync();
    //   file.writeAsBytes(image);

    //   final myPath = file.path;
    //   print('File Path: $myPath');

    //   ScreenController().executeAction(
    //     context,
    //     widget._controller.onCropped!,
    //     event: EnsembleEvent(
    //       widget,
    //       data: {'file': file.path},
    //     ),
    //   );
    // }
  }

  Future<Uint8List> getImage(String path) async {
    final imagePath = Utils.getLocalAssetFullPath(path);
    final ByteData bytes = await rootBundle.load(imagePath);
    final Uint8List list = bytes.buffer.asUint8List();
    return list;
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

class CroppedFileData with Invokable {
  CroppedFileData({io.File? file}) : _file = file;

  final io.File? _file;

  @override
  Map<String, Function> getters() {
    return {
      'file': () => _file?.path,
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {};
  }
}
