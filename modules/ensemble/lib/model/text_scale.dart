import 'package:ensemble/util/utils.dart';

/**
 * Scale the text between the minFactor and maxFactor.
 * Used by App theme and Text widget.
 */
class TextScale {
  TextScale({this.enabled, this.minFactor, this.maxFactor});

  bool? enabled;
  double? minFactor;
  double? maxFactor;

  static TextScale? from(dynamic value) => value is Map
      ? TextScale(
          enabled: Utils.optionalBool(value['enabled']),
          minFactor: Utils.optionalDouble(value['minFactor'], min: 0),
          maxFactor: Utils.optionalDouble(value['maxFactor'], min: 0))
      : null;
}
