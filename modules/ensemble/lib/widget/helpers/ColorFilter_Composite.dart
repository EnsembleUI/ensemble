import 'package:flutter/material.dart';
import 'package:ensemble/util/utils.dart';

class ColorFilterComposite {
  Color? color;
  BlendMode blendMode;

  ColorFilterComposite({
    this.color,
    this.blendMode = BlendMode.modulate,
  });

  factory ColorFilterComposite.from(dynamic payload) {
    if (payload is Map && payload['color'] != null) {
      return ColorFilterComposite(
        color: Utils.getColor(payload['color']),
        blendMode: Utils.getBlendMode(payload['blendMode']),
      );
    }
    return ColorFilterComposite();
  }

  // Returns a ColorFilter if color is not null
  ColorFilter? getColorFilter() { 
    if (color == null) return null;
    // Special case for black color with modulate blend mode - use grayscale
    bool isBlack = color!.value == 0xFF000000 || color!.value == 0x00000000;
    if (isBlack && blendMode == BlendMode.modulate) {
      return Utils.getGreyScale();
    }
    
    return ColorFilter.mode(color!, blendMode);
  }
}