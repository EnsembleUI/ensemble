import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/framework/widget/has_children.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

class Card extends StatefulWidget
    with
        UpdatableContainer,
        Invokable,
        HasController<CardController, _CardState> {
  Card({super.key});

  static const String type = "Card";

  @override
  State<Card> createState() => _CardState();

  @override
  CardController get controller => _controller;

  final CardController _controller = CardController();

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
      "width": (value) => _controller.width = Utils.optionalString(value),
      "height": (value) => _controller.height = Utils.optionalString(value),
      "backgroundColor": (value) => _controller.backgroundColor = Utils.getColor(value),
      "border": (value) => _controller.border = Utils.optionalString(value),
      "borderRadius": (value) => _controller.borderRadius = Utils.optionalDouble(value),
      "shadowColor": (value) => _controller.shadowColor = Utils.getColor(value),
      "shadowOffset": (value) => _controller.shadowOffset = Utils.optionalDouble(value),
      "shadowBlur": (value) => _controller.shadowBlur = Utils.optionalDouble(value),
      "shadowSpread": (value) => _controller.shadowSpread = Utils.optionalDouble(value),
      "padding": (value) => _controller.padding = Utils.optionalInsets(value),
      "maxWidth": (value) => _controller.maxWidth = Utils.optionalDouble(value),
      "minWidth": (value) => _controller.minWidth = Utils.optionalDouble(value),
      "gap": (value) => _controller.gap = Utils.optionalDouble(value),
    };
  }

  @override
  void initChildren({List<WidgetModel>? children, Map? itemTemplate}) {
    _controller.children = children;
  }
}

class CardController extends WidgetController {
  String? width;
  String? height;
  Color? backgroundColor;
  String? border;
  double? borderRadius;
  Color? shadowColor;
  double? shadowOffset;
  double? shadowBlur;
  double? shadowSpread;
  EdgeInsets? padding;
  double? maxWidth;
  double? minWidth;
  double? gap;
  List<WidgetModel>? children;

  CardController() {
    backgroundColor = Colors.transparent;
    borderRadius = 10.0;
    shadowColor = Colors.grey.shade300;
    shadowOffset = 0.0;
    shadowBlur = 0.0;
    shadowSpread = 0.0;
    padding = const EdgeInsets.all(20.0);
    maxWidth = 250.0;
    minWidth = 250.0;
    gap = 0.0;
  }
}

class _CardState extends EWidgetState<Card> with HasChildren<Card> {
  @override
  Widget buildWidget(BuildContext context) {
    List<Widget> childrenWidgets = [];
    
    if (widget.controller.children != null) {
      childrenWidgets = buildChildren(widget.controller.children!);
    }

    // Parse border if provided
    BoxBorder? cardBorder;
    if (widget.controller.border != null) {
      cardBorder = _parseBorder(widget.controller.border!);
    } else {
      // Default border
      cardBorder = Border.all(color: Colors.grey.shade300, width: 1.0);
    }

    // Create box shadow
    List<BoxShadow> shadows = [];
    if (widget.controller.shadowBlur != null && 
        widget.controller.shadowBlur! > 0) {
      shadows.add(BoxShadow(
        color: widget.controller.shadowColor ?? Colors.grey.shade300,
        offset: Offset(
          widget.controller.shadowOffset ?? 0.0,
          widget.controller.shadowOffset ?? 0.0,
        ),
        blurRadius: widget.controller.shadowBlur ?? 0.0,
        spreadRadius: widget.controller.shadowSpread ?? 0.0,
      ));
    }

    // Parse width and height
    double? cardWidth = _parseSize(widget.controller.width);
    double? cardHeight = _parseSize(widget.controller.height);

    Widget cardContent = Container(
      width: cardWidth,
      height: cardHeight,
      constraints: BoxConstraints(
        maxWidth: widget.controller.maxWidth ?? double.infinity,
        minWidth: widget.controller.minWidth ?? 0.0,
      ),
      padding: widget.controller.padding ?? const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: widget.controller.backgroundColor ?? Colors.transparent,
        border: cardBorder,
        borderRadius: BorderRadius.circular(
          widget.controller.borderRadius ?? 10.0,
        ),
        boxShadow: shadows,
      ),
      child: widget.controller.gap != null && widget.controller.gap! > 0
          ? _buildChildrenWithGap(childrenWidgets)
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: childrenWidgets,
            ),
    );

    return cardContent;
  }

  Widget _buildChildrenWithGap(List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    
    List<Widget> childrenWithGaps = [];
    for (int i = 0; i < children.length; i++) {
      childrenWithGaps.add(children[i]);
      if (i < children.length - 1) {
        childrenWithGaps.add(SizedBox(height: widget.controller.gap!));
      }
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: childrenWithGaps,
    );
  }

  BoxBorder _parseBorder(String borderString) {
    // Simple border parsing - can be extended for more complex cases
    // Format: "width style color" e.g., "1px solid red"
    List<String> parts = borderString.split(' ');
    
    double width = 1.0;
    Color color = Colors.grey.shade300;
    
    if (parts.isNotEmpty) {
      // Try to parse width
      String widthStr = parts[0].replaceAll('px', '');
      width = double.tryParse(widthStr) ?? 1.0;
    }
    
    if (parts.length > 2) {
      // Try to parse color
      color = Utils.getColor(parts[2]) ?? Colors.grey.shade300;
    }
    
    return Border.all(color: color, width: width);
  }

  double? _parseSize(String? sizeString) {
    if (sizeString == null) return null;
    
    // Handle percentage (relative to parent)
    if (sizeString.endsWith('%')) {
      // For now, return null to let parent handle sizing
      return null;
    }
    
    // Handle pixel values
    if (sizeString.endsWith('px')) {
      return double.tryParse(sizeString.replaceAll('px', ''));
    }
    
    // Handle plain numbers
    return double.tryParse(sizeString);
  }
}