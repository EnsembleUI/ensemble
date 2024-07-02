import 'package:flutter/material.dart';

enum BubbleAlignment { left, right }

class BubbleContainer extends StatelessWidget {
  final double bubbleRadius;
  final Color color;
  final String text;
  final TextStyle textStyle;
  final BubbleAlignment bubbleAlignment;

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
  }) : super(key: key);

  ///chat bubble builder method
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: bubbleAlignment == BubbleAlignment.left
          ? Alignment.bottomLeft
          : Alignment.bottomRight,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
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
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: Text(
            text,
            style: textStyle,
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
