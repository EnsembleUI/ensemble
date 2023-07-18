import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble/widget/widget_util.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svg/svg.dart';

class CroppableImage extends StatefulWidget
    with
        Invokable,
        HasController<CroppableImageController, CroppableImageState> {
  static const type = 'CroppableImage';
  CroppableImage({Key? key}) : super(key: key);

  final CroppableImageController _controller = CroppableImageController();
  @override
  get controller => _controller;

  @override
  State<StatefulWidget> createState() => CroppableImageState();

  @override
  Map<String, Function> getters() {
    return {
      'source': () => _controller.source,
      'fit': () => _controller.fit,
      'resizedWidth': () => _controller.resizedWidth,
      'resizedHeight': () => _controller.resizedHeight,
      'placeholderColor': () => _controller.placeholderColor,
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'source': (value) =>
          _controller.source = Utils.getString(value, fallback: ''),
      'fit': (value) => _controller.fit = Utils.optionalString(value),
      'resizedWidth': (width) => _controller.resizedWidth =
          Utils.optionalInt(width, min: 0, max: 2000),
      'resizedHeight': (height) => _controller.resizedHeight =
          Utils.optionalInt(height, min: 0, max: 2000),
      'placeholderColor': (value) =>
          _controller.placeholderColor = Utils.getColor(value),
      'onTap': (funcDefinition) => _controller.onTap =
          EnsembleAction.fromYaml(funcDefinition, initiator: this)
    };
  }
}

class CroppableImageController extends BoxController {
  String source = '';
  String? fit;
  Color? placeholderColor;
  EnsembleAction? onTap;

  // whether we should resize the image to this. Note that we should set either
  // resizedWidth or resizedHeight but not both so the aspect ratio is maintained
  int? resizedWidth;
  int? resizedHeight;
}

class CroppableImageState extends WidgetState<CroppableImage> {
  late Widget placeholder;
  final _controller = CropController();

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

    Widget rtn = FutureBuilder(
      future: getImage(widget._controller.source),
      builder: (BuildContext context, AsyncSnapshot<Uint8List> snapshot) {
        if (snapshot.hasData) {
          return SizedBox(
            height: 350,
            width: 350,
            child: Crop(
              image: snapshot.data!,
              controller: _controller,
              initialAreaBuilder: (rect) => Rect.fromLTRB(
                rect.left + 24,
                rect.top + 32,
                rect.right - 24,
                rect.bottom - 32,
              ),
              baseColor: Colors.blue.shade900,
              maskColor: Colors.white.withAlpha(100),
              radius: 20,
              onCropped: (image) {},
            ),
          );
        } else if (snapshot.hasError) {
          return const CircularProgressIndicator();
        }
        return getPlaceholder();
      },
    );

    if (widget._controller.onTap != null) {
      rtn = GestureDetector(
        child: rtn,
        onTap: () => ScreenController().executeAction(
          context,
          widget._controller.onTap!,
          event: EnsembleEvent(widget),
        ),
      );
    }
    if (widget._controller.margin != null) {
      rtn = Padding(padding: widget._controller.margin!, child: rtn);
    }
    return rtn;
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
