import 'dart:math';

import 'package:flutter/cupertino.dart';

/// return a colored box (e.g. useful as image placeholder)
/// Color will be randomly chosen unless given a color
/// Its size will be determined by the parent container if the width or height is null
class ColoredBoxPlaceholder extends StatelessWidget {
  const ColoredBoxPlaceholder({super.key, this.color, this.width, this.height});

  final double? width;
  final double? height;
  final Color? color;
  final _boxPlaceholderColors = const [
    0xffD9E3E5,
    0xffBBCBD2,
    0xffA79490,
    0xffD7BFA8,
    0xffEAD9C9,
    0xffEEEAE7
  ];

  // container without child will get the size of its parent if width or height is null
  @override
  Widget build(BuildContext context) => Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
          color: color ??
              Color(_boxPlaceholderColors[
                  Random().nextInt(_boxPlaceholderColors.length)])));
}
