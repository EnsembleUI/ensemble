import 'package:form_validator/form_validator.dart';

class InputValidator {
  /// check if value is a valid IPv4 or IPv6
  static bool ipAddress(String value) {
    String? error = ValidationBuilder()
        .or((builder) => builder.ip(), (builder) => builder.ipv6())
        .test(value);
    return error == null;
  }

  /// check if value is a valid phone number
  static bool phone(String value) {
    // https://github.com/EnsembleUI/ensemble/issues/1518 Clean the string by removing `(`, `)`, `-`, and spaces
    // we don't need to taks the country specific masks into account as they all have just these characters - https://gist.github.com/mikemunsie/d58d88cad0281e4b187b0effced769b2
    String cleanedValue = value.replaceAll(RegExp(r'[()\-\s]'), '');
    final RegExp PhoneRegExp = RegExp(r'^\+?\d{7,15}$');
    return null ==
        ValidationBuilder()
            .regExp(PhoneRegExp, "Please enter a valid Phone Number")
            .test(cleanedValue);
  }
}
