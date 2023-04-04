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
    return null == ValidationBuilder().phone().test(value);
  }
}
