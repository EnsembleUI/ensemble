
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/widget_builder.dart' as ensemble;
import 'package:ensemble/widget/widget_registry.dart';
import 'package:flutter/cupertino.dart';
import 'package:yaml/yaml.dart';

class ImageBuilder extends ensemble.WidgetBuilder {
  static const type = 'Image';
  ImageBuilder({
    this.source,
    this.width,
    this.height,
    this.fit,
    styles
  }): super(styles: styles);

  final String? source;
  final int? width;
  final int? height;
  final String? fit;

  static ImageBuilder fromDynamic(Map<String, dynamic> props, Map<String, dynamic> styles, {WidgetRegistry? registry}) {
    return ImageBuilder(
      // props
      source: props['source'],

      // styles
      width: Utils.optionalInt(styles['width']),
      height: Utils.optionalInt(styles['height']),
      fit: Utils.optionalString(styles['fit']),
      styles: styles
    );
  }

  @override
  Widget buildWidget({
    List<Widget>? children,
    ItemTemplate? itemTemplate}) {
    return EnsembleImage(
      builder: this
    );
  }

}


class EnsembleImage extends StatefulWidget {
  const EnsembleImage({required this.builder, Key? key})
      : super(key: key);

  final ImageBuilder builder;

  @override
  EnsembleImageState createState() => EnsembleImageState();
}


class EnsembleImageState extends State<EnsembleImage> {

  @override
  Widget build(BuildContext context) {
    BoxFit? fit;
    switch (widget.builder.fit) {
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
    return Image.network(
        widget.builder.source ?? '',
        width: widget.builder.width?.toDouble(),
        height: widget.builder.height?.toDouble(),
        fit: fit
    );
  }



}