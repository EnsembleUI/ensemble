import 'package:ensemble/widget/widget_builder.dart';

/// base class for VStack/HStack
abstract class BoxLayout extends WidgetBuilder {
  BoxLayout({
    this.mainAxis,
    this.crossAxis,
    this.width,
    this.maxWidth,
    this.height,
    this.maxHeight,
    this.margin,
    this.padding,
    this.gap,

    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.fontFamily,
    this.fontSize,

    this.shadowColor,
    this.shadowOffset,
    this.shadowRadius,

    this.scrollable = false,
    this.onTap,
    expanded,
    this.autoFit = false,

  }) : super (expanded: expanded);

  final bool autoFit;

  final String? mainAxis;
  final String? crossAxis;

  final int? width;
  final int? maxWidth;
  final int? height;
  final int? maxHeight;
  final int? margin;
  final int? padding;
  final int? gap;

  final int? backgroundColor;
  final int? borderColor;
  final int? borderRadius;
  final String? fontFamily;
  final int? fontSize;

  final int? shadowColor;
  final List<int>? shadowOffset;
  final int? shadowRadius;

  final bool scrollable;
  final dynamic onTap;


}
