
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class EnsembleImage extends StatefulWidget with Invokable, HasController<ImageController, ImageState> {
  static const type = 'Image';
  EnsembleImage({Key? key}) : super(key: key);

  final ImageController _controller = ImageController();
  @override
  get controller => _controller;

  @override
  State<StatefulWidget> createState() => ImageState();

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'source': (value) => _controller.source = Utils.getString(value, fallback: ''),
      'fit': (value) => _controller.fit = Utils.optionalString(value),
      'placeholderColor': (value) => _controller.placeholderColor = Utils.getColor(value),
      'onTap': (funcDefinition) => _controller.onTap = Utils.getAction(funcDefinition, initiator: this)
    };
  }

}

class ImageController extends BoxController {
  String source = '';
  String? fit;
  Color? placeholderColor;
  EnsembleAction? onTap;
}

class ImageState extends WidgetState<EnsembleImage> {
  late Widget placeholder;

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

    BoxFit? fit = WidgetUtils.getBoxFit(widget._controller.fit);
    Widget image;
    if (isSvg()) {
      image = buildSvgImage(source, fit);
    } else {
      image = buildNonSvgImage(source, fit);
    }

    Widget rtn = BoxWrapper(
        widget: image,
        boxController: widget._controller,
        ignoresMargin: true,      // make sure the gesture don't include the margin
        ignoresDimension: true    // we apply width/height in the image already
    );
    if (widget._controller.onTap != null) {
      rtn = GestureDetector(
        child: rtn,
        onTap: () => ScreenController().executeAction(context, widget._controller.onTap!,event: EnsembleEvent(widget))
      );
    }
    if (widget._controller.margin != null) {
      rtn = Padding(
          padding: widget._controller.margin!,
          child: rtn);
    }
    return rtn;
  }

  Widget buildNonSvgImage(String source, BoxFit? fit) {
    if (source.startsWith('https://') || source.startsWith('http://')) {
      return CachedNetworkImage(
        imageUrl: source,
        width: widget._controller.width?.toDouble(),
        height: widget._controller.height?.toDouble(),
        fit: fit,
        errorWidget: (context, error, stacktrace) => errorFallback(),
        placeholder: (context, url) => placeholder);
    }
    // else attempt local asset
    // user might use env variables to switch between remote and local images.
    // Assets might have additional token e.g. my-image.png?x=2343
    // so we need to strip them out
    return Image.asset(
        Utils.getLocalAssetFullPath(source),
        width: widget._controller.width?.toDouble(),
        height: widget._controller.height?.toDouble(),
        fit: fit,
        errorBuilder: (context, error, stacktrace) => errorFallback());
  }

  Widget buildSvgImage(String source, BoxFit? fit) {
    // if is URL
    if (source.startsWith('https://') || source.startsWith('http://')) {
      return SvgPicture.network(
          widget._controller.source,
          width: widget._controller.width?.toDouble(),
          height: widget._controller.height?.toDouble(),
          fit: fit ?? BoxFit.contain,
          placeholderBuilder: (_) => placeholder
      );
    }
    // attempt local assets
    return SvgPicture.asset(
        Utils.getLocalAssetFullPath(widget._controller.source),
        width: widget._controller.width?.toDouble(),
        height: widget._controller.height?.toDouble(),
        fit: fit ?? BoxFit.contain
    );
  }

  bool isSvg() {
    return widget._controller.source.endsWith('svg');
  }

  /// display if the image cannot be loaded
  Widget errorFallback() {
    return Image.asset(
      'assets/images/img_placeholder.png',
      package: 'ensemble',
      fit: BoxFit.cover);
  }

  // use modern colors as background placeholder while images are being loaded
  final placeholderColors = [0xffD9E3E5, 0xffBBCBD2, 0xffA79490, 0xffD7BFA8, 0xffEAD9C9, 0xffEEEAE7];
  Widget getPlaceholder() {
    // TODO: this doesn't show up when Image doesn't have explicit width/height
    return ColoredBox(
        color: widget._controller.placeholderColor ??
            Color(placeholderColors[Random().nextInt(placeholderColors.length)]),
    );
  }




}