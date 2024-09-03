import 'package:ensemble/util/utils.dart';
import 'package:flutter/cupertino.dart';

/// covert a transform model into a Matrix4
class TransformMatrix {

  static Matrix4? from(dynamic input) {
    Matrix4? result;
    if (input is List) {
      input.forEach((element) {
        if (element is Map && element.isNotEmpty) {
          // only process the first pair for each entry
          final key = element.entries.first.key.toString();
          final value = element.entries.first.value;

          switch (key) {
            case 'translate':
              final xy = _XY.from(value, 'translate', min: -1000, max: 1000);
              if (xy != null) {
                (result ??= Matrix4.identity())..translate(xy.x ?? 0.0, xy.y ?? 0.0);
              }
              break;
            case 'scale':
              final xy = _XY.from(value, 'scale', min: -10, max: 10);
              if (xy != null) {
                (result ??= Matrix4.identity())..scale(xy.x, xy.y);
              }
              break;
            case 'skew':
              final xy = _XY.from(value, 'skew', min: -10, max: 10);
              if (xy?.x != null) {
                (result ??= Matrix4.identity()).setEntry(0, 1, xy!.x!);
              }
              if (xy?.y != null) {
                (result ??= Matrix4.identity()).setEntry(1, 0, xy!.y!);
              }
              break;
            case 'rotate':
              final xy = _XY.from(value, 'rotate', min: 0, max: 360);
              if (xy?.x != null) {
                (result ??= Matrix4.identity()).rotateX(xy!.x!);
              }
              if (xy?.y != null) {
                (result ??= Matrix4.identity()).rotateY(xy!.y!);
              }
              break;
          }
        }
      });
    }
    return result;
  }
}

class _XY {
  double? x;
  double? y;

  _XY._(this.x, this.y);

  static _XY? from(dynamic input, String prefix, {double? min, double? max}) {
    if (input is Map) {
      final x = Utils.optionalDouble(input['${prefix}X'], min: min, max: max);
      final y = Utils.optionalDouble(input['${prefix}Y'], min: min, max: max);
      if (x != null || y != null) {
        return _XY._(x, y);
      }
    }
    return null;
  }
}
