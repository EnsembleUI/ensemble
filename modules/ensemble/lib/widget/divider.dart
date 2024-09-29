import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/studio/studio_debugger.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';

class EnsembleDivider extends StatefulWidget
    with Invokable, HasController<DividerController, DividerState> {
  static const type = 'Divider';

  EnsembleDivider({Key? key}) : super(key: key);

  final DividerController _controller = DividerController();

  @override
  DividerController get controller => _controller;

  @override
  State<StatefulWidget> createState() => DividerState();

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
      'direction': (value) =>
          _controller.direction = DirectionType.values.from(value) ?? DirectionType.horizontal,
      'margin': (value) => _controller.margin = Utils.getInsets(value),
      'thickness': (value) => _controller.thickness = Utils.optionalInt(value),
      'color': (value) => _controller.color = Utils.getColor(value),
      'indent': (value) => _controller.indent = Utils.optionalInt(value),
      'endIndent': (value) => _controller.endIndent = Utils.optionalInt(value),
      'type': (value) => _controller.type = DividerType.values.from(value) ?? DividerType.solid,
      'dashLength': (value) =>
          _controller.dashLength = Utils.optionalDouble(value),
      'gap': (value) => _controller.gap = Utils.optionalDouble(
          value), 
      'opacity': (value) => _controller.opacity = Utils.optionalDouble(value),
    };
  }
}

class DividerController extends WidgetController {
  DirectionType direction = DirectionType.horizontal;
  EdgeInsets? margin;
  int? thickness;
  Color? color;
  int? indent;
  int? endIndent;
  DividerType type = DividerType.solid; 
  double? dashLength; 
  double? gap; 
  double? opacity; 
}

class DividerState extends EWidgetState<EnsembleDivider> {
  @override
  Widget buildWidget(BuildContext context) {
    Widget rtn;
    // Check for custom border styles
    if (widget._controller.type == DividerType.dotted || widget._controller.type == DividerType.dashed) {
      // Use a custom painted widget for dotted or dashed lines
      rtn = CustomPaint(
        size: Size(
          widget._controller.direction == DirectionType.vertical
              ? (widget._controller.thickness ?? 1).toDouble()
              : double.infinity,
          widget._controller.direction == DirectionType.vertical
              ? double.infinity
              : (widget._controller.thickness ?? 1).toDouble(),
        ),
        painter: DashedLinePainter(
          color: (widget._controller.color ?? const Color(0xFFD3D3D3))
              .withOpacity(widget._controller.opacity ?? 1.0),
          thickness: (widget._controller.thickness ?? 1).toDouble(),
          isVertical: widget._controller.direction == DirectionType.vertical,
          dashLength: widget._controller.dashLength ?? 5,
          gap: widget._controller.gap ?? 3,
          type: widget._controller.type,
          indent: (widget._controller.indent ?? 0).toDouble(),
          endIndent: (widget._controller.endIndent ?? 0).toDouble(),
        ),
      );
    } else {
      if (widget._controller.direction == DirectionType.vertical) {
        rtn = VerticalDivider(
            width: (widget._controller.thickness ?? 1).toDouble(),
            thickness: (widget._controller.thickness ?? 1).toDouble(),
            indent: (widget._controller.indent ?? 0).toDouble(),
            endIndent: (widget._controller.endIndent ?? 0).toDouble(),
            color: (widget._controller.color ?? const Color(0xFFD3D3D3))
                .withOpacity(widget._controller.opacity ?? 1.0));
        rtn = StudioDebugger()
            .assertHasBoundedHeight(rtn, "${EnsembleDivider.type} (vertical)");
      } else {
        rtn = Divider(
            height: (widget._controller.thickness ?? 1).toDouble(),
            thickness: (widget._controller.thickness ?? 1).toDouble(),
            indent: (widget._controller.indent ?? 0).toDouble(),
            endIndent: (widget._controller.endIndent ?? 0).toDouble(),
            color: (widget._controller.color ?? const Color(0xFFD3D3D3))
                .withOpacity(widget._controller.opacity ?? 1.0));
        rtn = StudioDebugger().assertHasBoundedWidth(rtn, EnsembleDivider.type);
      }
    }

    if (widget._controller.margin != null) {
      rtn = Padding(padding: widget._controller.margin!, child: rtn);
    }
    return rtn;
  }
}

enum DividerType {
  solid,
  dashed,
  dotted,
}

enum DirectionType {
  vertical,
  horizontal,
}

class DashedLinePainter extends CustomPainter {
  final Color color;
  final double thickness;
  final bool isVertical;
  final double dashLength;
  final double gap;
  final DividerType type;
  final double indent;
  final double endIndent;

  DashedLinePainter({
    required this.color,
    required this.thickness,
    required this.isVertical,
    required this.dashLength,
    required this.gap,
    required this.type,
    required this.indent,
    required this.endIndent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap =
          type == DividerType.dotted ? StrokeCap.round : StrokeCap.butt;

    if (type == DividerType.dotted) {
      _drawDottedLine(canvas, size, paint);
    } else if (type == DividerType.dashed) {
      _drawDashedLine(canvas, size, paint);
    }
  }

  void _drawDottedLine(Canvas canvas, Size size, Paint paint) {
    // Calculate the total available space and the required total space for each dot
    final double availableSpace = isVertical
        ? size.height - indent - endIndent
        : size.width - indent - endIndent;

    final double dotDiameter = thickness;
    final double effectiveGap = gap < dotDiameter ? dotDiameter : gap;
    final double totalDotSpace =
        dotDiameter + effectiveGap; // Adjust gap if needed
    final int numDots = (availableSpace / totalDotSpace).floor();

    double currentPosition = isVertical ? indent : indent; // Start with indent

    for (int i = 0; i < numDots; i++) {
      if (isVertical) {
        // Draw vertical dots
        canvas.drawCircle(
          Offset(size.width / 2, currentPosition + dotDiameter / 2),
          dotDiameter / 2,
          paint,
        );
      } else {
        // Draw horizontal dots
        canvas.drawCircle(
          Offset(currentPosition + dotDiameter / 2, size.height / 2),
          dotDiameter / 2,
          paint,
        );
      }
      // Move to the next position for the dot
      currentPosition += totalDotSpace;
    }
  }

  void _drawDashedLine(Canvas canvas, Size size, Paint paint) {
    // Draw dashed line with proper indentation
    double currentPosition = isVertical ? indent : indent; // Start with indent

    while (
        currentPosition < (isVertical ? size.height : size.width) - endIndent) {
      if (isVertical) {
        // Draw vertical dashes
        canvas.drawLine(
          Offset(size.width / 2, currentPosition),
          Offset(size.width / 2, currentPosition + dashLength),
          paint,
        );
      } else {
        // Draw horizontal dashes
        canvas.drawLine(
          Offset(currentPosition, size.height / 2),
          Offset(currentPosition + dashLength, size.height / 2),
          paint,
        );
      }
      currentPosition += dashLength + gap;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}