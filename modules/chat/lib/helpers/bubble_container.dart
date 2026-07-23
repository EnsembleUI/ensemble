/// Chat bubble widgets and alignment helpers.
library bubble_container;

import 'package:flutter/material.dart';

/// Horizontal alignment for a chat bubble tail.
enum BubbleAlignment { left, right }

/// A rounded message bubble used by the Ensemble chat UI.
class BubbleContainer extends StatelessWidget {
  /// Radius applied to the rounded bubble corners.
  final double bubbleRadius;

  /// Background color for the bubble.
  final Color color;

  /// Message text displayed inside the bubble.
  final String text;

  /// Text style for [text].
  final TextStyle textStyle;

  /// Controls whether the bubble is aligned left or right.
  final BubbleAlignment bubbleAlignment;

  /// Optional inner spacing for the bubble content.
  final EdgeInsets? padding;

  /// Optional outer spacing around the bubble.
  final EdgeInsets? margin;

  /// Creates a chat bubble.
  const BubbleContainer({
    Key? key,
    required this.text,
    this.bubbleRadius = 25,
    this.color = Colors.white70,
    this.textStyle = const TextStyle(
      color: Colors.white,
      fontSize: 17,
    ),
    required this.bubbleAlignment,
    this.padding,
    this.margin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Align(
        alignment: bubbleAlignment == BubbleAlignment.left
            ? Alignment.bottomLeft
            : Alignment.bottomRight,
        child: Container(
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(
                  bubbleAlignment == BubbleAlignment.left ? 0 : bubbleRadius),
              topRight: Radius.circular(
                  bubbleAlignment == BubbleAlignment.right ? 0 : bubbleRadius),
              bottomLeft: Radius.circular(bubbleRadius),
              bottomRight: Radius.circular(bubbleRadius),
            ),
          ),
          child: Padding(
            padding: padding ??
                const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Text(
              text,
              style: textStyle,
            ),
          ),
        ),
      ),
    );

    // return Row(
    //   children: [
    //     Container(
    //       color: Colors.transparent,
    //       constraints: BoxConstraints(
    //         minWidth: MediaQuery.of(context).size.width * .2,
    //         maxWidth: MediaQuery.of(context).size.width * .8,
    //       ),
    //       child: Container(
    //         decoration: BoxDecoration(
    //           gradient: const LinearGradient(colors: [
    //             Color.fromRGBO(255, 255, 255, 15),
    //             Color.fromRGBO(255, 255, 255, 100),
    //           ]),
    // borderRadius: BorderRadius.only(
    //   topLeft: const Radius.circular(0),
    //   topRight: Radius.circular(bubbleRadius),
    //   bottomLeft: Radius.circular(bubbleRadius),
    //   bottomRight: Radius.circular(bubbleRadius),
    // ),
    //         ),
    //         child: Padding(
    //           padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
    //           child: Text(
    //             text,
    //             style: textStyle,
    //             textAlign: TextAlign.left,
    //           ),
    //         ),
    //       ),
    //     ),
    //   ],
    // );
  }
}
