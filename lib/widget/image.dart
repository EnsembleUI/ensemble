
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/layout_helper.dart';
import 'package:ensemble/util/utils.dart';
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
    Widget image = renderImage();

    BorderRadius? borderRadius = widget._controller.borderRadius == null ? null :
      BorderRadius.all(Radius.circular(widget._controller.borderRadius!.toDouble()));
    return Container(
      margin: Utils.getInsets(widget._controller.margin),
      decoration: BoxDecoration(
        border: !widget._controller.hasBorder() ? null : Border.all(
            color: widget._controller.borderColor ?? Colors.black26,
            width: (widget._controller.borderWidth ?? 1).toDouble()),
        borderRadius: borderRadius
      ),
      padding: Utils.getInsets(widget._controller.padding),
      child: ClipRRect(
        child: image,
        borderRadius: borderRadius ?? const BorderRadius.all(Radius.zero)
      )
    );
  }

  Widget renderImage() {
    if (widget._controller.source.endsWith('svg')) {
      return renderSvg();
    }
    return renderNonSvg();
  }

  Widget renderSvg() {
    final Widget networkSvg = SvgPicture.network(
      widget._controller.source,
      placeholderBuilder: (_) => placeholderImage()
    );
    return networkSvg;
  }

  Widget renderNonSvg() {
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
    // image binding is tricky. When the URL has not been resolved
    // the image will throw exception. We have to use a permanent placeholder
    // until the binding engages
    Image image = Image.network(
        widget._controller.source,
        width: widget._controller.width?.toDouble(),
        height: widget._controller.height?.toDouble(),
        fit: fit,
        errorBuilder: (context, error, stacktrace) => fallbackImage(),
        loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return placeholderImage();
        }
    );
    return image;
  }

  Widget placeholderImage() {
    return SizedBox(
      width: widget._controller.width?.toDouble(),
      height: widget._controller.height?.toDouble(),
      child: const Center(
          child: CircularProgressIndicator()
      )
    );
  }

  Widget fallbackImage() {
    return Container(
      width: widget._controller.width?.toDouble(),
      height: widget._controller.height?.toDouble(),
      color: Colors.white60,
      child: const Center(
        child: Icon(Icons.image, size: 50)
      )
    );
  }





}