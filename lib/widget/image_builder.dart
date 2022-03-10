
import 'package:ensemble/page_model.dart';
import 'package:ensemble/widget/widget_builder.dart' as ensemble;
import 'package:ensemble/widget/widget_registry.dart';
import 'package:flutter/cupertino.dart';
import 'package:yaml/yaml.dart';

class ImageBuilder extends ensemble.WidgetBuilder {
  static const type = 'Image';
  ImageBuilder({
    this.source,
    this.width,
    this.height
  });

  final String? source;
  final int? width;
  final int? height;

  static ImageBuilder fromDynamic(Map<String, dynamic> props, Map<String, dynamic> styles, {WidgetRegistry? registry}) {
    return ImageBuilder(
      source: props['source'],
      width: styles['width'],
      height: styles['height']
    );
  }

  @override
  Widget buildWidget({
    required BuildContext context,
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
    bool hasWidthAndHeight = widget.builder.width != null
        && widget.builder.height != null;

    AspectRatio aspectRatio = AspectRatio(
        aspectRatio: 2,
        child: Image.network(
            widget.builder.source ?? '',
            fit: hasWidthAndHeight ? BoxFit.fill : null
        )
    );

    // wraps around SizedBox if width/height is specified
    if (hasWidthAndHeight) {
      return SizedBox(
          width: widget.builder.width!.toDouble(),
          height: widget.builder.height!.toDouble(),
          child: aspectRatio
      );
    } else {
      return aspectRatio;
    }
  }



}