class Utils {

  /// return an Integer if it is, or null if not
  static int? optionalInt(dynamic value) {
    return value is int ? value : null;
  }
  static bool? optionalBool(dynamic value) {
    return value is bool ? value : null;
  }
  /// return anything as a string if exists, or null if not
  static String? optionalString(dynamic value) {
    return value?.toString();
  }
  static double? optionalDouble(dynamic value) {
    return
      value is double ? value :
      value is int ? value.toDouble() :
      value is String ? double.tryParse(value) :
      null;
  }

  static String getString(dynamic value, {required String fallback}) {
    return value?.toString() ?? fallback;
  }

  static bool getBool(dynamic value, {required bool fallback}) {
    return value is bool ? value : fallback;
  }

  static double getDouble(dynamic value, {required double fallback}) {
    return
      value is double ? value :
          value is int ? value.toDouble() :
              value is String ? double.tryParse(value) ?? fallback :
                fallback;
  }


}