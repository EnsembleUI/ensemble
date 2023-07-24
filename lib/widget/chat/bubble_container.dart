import 'package:flutter/material.dart';

class BubbleContainer extends StatelessWidget {
  final double bubbleRadius;
  final Color color;
  final String text;
  final TextStyle textStyle;

  const BubbleContainer({
    Key? key,
    required this.text,
    this.bubbleRadius = 16,
    this.color = Colors.white70,
    this.textStyle = const TextStyle(
      color: Colors.black87,
      fontSize: 16,
    ),
  }) : super(key: key);

  ///chat bubble builder method
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          color: Colors.transparent,
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(0),
                  topRight: Radius.circular(bubbleRadius),
                  bottomLeft: Radius.circular(bubbleRadius),
                  bottomRight: Radius.circular(bubbleRadius),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: Text(
                  text,
                  style: textStyle,
                  textAlign: TextAlign.left,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
