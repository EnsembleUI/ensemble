import 'package:ensemble/widget/widget_builder.dart';

abstract class BaseLayout extends WidgetBuilder {
  BaseLayout({
    this.backgroundColor,
    this.padding,
    this.gap,
    this.layout,
    this.alignment,
    this.borderRadius,
    this.boxShadowColor,
    this.boxShadowOffset,

    this.onTap,
    styles
  }): super(styles: styles);

  int? backgroundColor;
  int? padding;
  int? gap;
  String? layout;
  String? alignment;
  int? borderRadius;
  String? boxShadowColor;
  List<int>? boxShadowOffset;

  dynamic onTap;


}
