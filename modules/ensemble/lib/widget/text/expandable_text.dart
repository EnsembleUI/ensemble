import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class ExpandableText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final int maxLines;
  final TextAlign? textAlign;
  final bool selectable;
  final TextScaler? textScaler;
  final TextOverflow? textOverflow;
  final String readMoreText;
  final String readLessText;
  final TextStyle? expandTextStyle;

  ExpandableText({
    required this.text,
    required this.style,
    this.maxLines = 3,
    this.textAlign,
    this.selectable = false,
    this.textScaler,
    this.textOverflow,
    this.readMoreText = '...Read more',
    this.readLessText = ' Read less',
    this.expandTextStyle,
  });

  @override
  _ExpandableTextState createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _isExpanded = false;

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final textAlign = widget.textAlign ?? TextAlign.start;
    final style = widget.style;
    final textScaler = widget.textScaler;
    final textOverflow = widget.textOverflow;
    final expandTextStyle = widget.expandTextStyle ?? widget.style.copyWith(color: Colors.blue);

    TextSpan link = TextSpan(
      text: _isExpanded ? widget.readLessText : widget.readMoreText,
      style: expandTextStyle,
      recognizer: TapGestureRecognizer()..onTap = _toggleExpand,
    );

    return LayoutBuilder(
      builder: (context, size) {
        final span = TextSpan(text: text, style: style);
        final tp = TextPainter(
          text: span,
          maxLines: widget.maxLines,
          textAlign: textAlign,
          textDirection: Directionality.of(context),
          textScaler: textScaler ?? TextScaler.noScaling
        );
        tp.layout(maxWidth: size.maxWidth);

        final exceedsMaxLines = tp.didExceedMaxLines;

        return
              widget.selectable
                ? SelectableText.rich(
              TextSpan(
                text: _isExpanded || !exceedsMaxLines
                    ? text
                    : text.substring(
                    0,
                    tp.getPositionForOffset(Offset(
                        size.maxWidth,
                        tp.preferredLineHeight * widget.maxLines))
                        .offset),
                style: style,
                children: [if (exceedsMaxLines || _isExpanded) link],
              ),
              textAlign: textAlign,
              textScaler: textScaler,
            )
                : Text.rich(
              TextSpan(
                text: _isExpanded || !exceedsMaxLines
                    ? text
                    : text.substring(
                    0,
                    tp.getPositionForOffset(Offset(
                        size.maxWidth,
                        tp.preferredLineHeight * widget.maxLines))
                        .offset),
                style: style,
                children: [if (exceedsMaxLines || _isExpanded) link],
              ),
              textAlign: textAlign,
              textScaler: textScaler,
            );
      },
    );
  }
}
