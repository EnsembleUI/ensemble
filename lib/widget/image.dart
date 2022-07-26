
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/layout_helper.dart';
import 'package:ensemble/util/utils.dart';
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
      'width': (value) => _controller.width = Utils.optionalInt(value),
      'height': (value) => _controller.height = Utils.optionalInt(value),
      'fit': (value) => _controller.fit = Utils.optionalString(value),
    };
  }

}

class ImageController extends BoxController {
  String source = '';
  int? width;
  int? height;
  String? fit;
}

class ImageState extends WidgetState<EnsembleImage> {

  @override
  Widget build(BuildContext context) {
    if (!widget._controller.visible) {
      return const SizedBox.shrink();
    }

    BoxFit? fit;
    switch (widget._controller.fit) {
      case 'fill':
        fit = BoxFit.fill;
        break;
      case 'contain':
        fit = BoxFit.contain;
        break;
      case 'cover':
        fit = BoxFit.cover;
        break;
      case 'fitWidth':
        fit = BoxFit.fitWidth;
        break;
      case 'fitHeight':
        fit = BoxFit.fitHeight;
        break;
      case 'none':
        fit = BoxFit.none;
        break;
      case 'scaleDown':
        fit = BoxFit.scaleDown;
        break;
    }

    Widget image;
    if (isSvg()) {
      image = buildSvgImage(fit);
    } else {
      image = buildNonSvgImage(fit);
    }

    return WidgetUtils.wrapInBox(image, widget._controller);
  }

  Widget buildNonSvgImage(BoxFit? fit) {
    String source = widget._controller.source.trim();
    if (source.isNotEmpty) {
      // if is URL
      if (source.startsWith('https://') || source.startsWith('http://')) {
        // image binding is tricky. When the URL has not been resolved
        // the image will throw exception. We have to use a permanent placeholder
        // until the binding engages
        return Image.network(
            widget._controller.source,
            width: widget._controller.width?.toDouble(),
            height: widget._controller.height?.toDouble(),
            fit: fit,
            errorBuilder: (context, error, stacktrace) => placeholderImage(),
            loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }
              return placeholderImage();
            }
        );
      }
      // else attempt local asset
      else {
        return Image.asset(
          'assets/images/${widget._controller.source}',
          width: widget._controller.width?.toDouble(),
          height: widget._controller.height?.toDouble(),
          fit: fit,
          errorBuilder: (context, error, stacktrace) => placeholderImage()
        );
      }
    }
    return placeholderImage();
  }

  Widget buildSvgImage(BoxFit? fit) {
    // if is URL
    if (widget._controller.source.startsWith('https://') || widget._controller.source.startsWith('http://')) {
      return SvgPicture.network(
          widget._controller.source,
          width: widget._controller.width?.toDouble(),
          height: widget._controller.height?.toDouble(),
          fit: fit ?? BoxFit.contain,
          placeholderBuilder: (_) => placeholderImage()
      );
    }
    // attempt local assets
    return SvgPicture.asset(
        'assets/images/${widget._controller.source}',
        width: widget._controller.width?.toDouble(),
        height: widget._controller.height?.toDouble(),
        fit: fit ?? BoxFit.contain,
        placeholderBuilder: (_) => placeholderImage()
    );
  }

  bool isSvg() {
    return widget._controller.source.endsWith('svg');
  }

  Widget placeholderImage() {
    return SizedBox(
      width: widget._controller.width?.toDouble(),
      height: widget._controller.height?.toDouble(),
      child: Image.asset('assets/images/img_placeholder.png')
    );
  }




}