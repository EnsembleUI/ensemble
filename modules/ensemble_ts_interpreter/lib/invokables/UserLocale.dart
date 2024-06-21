import 'dart:ui';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';

class UserLocale with Invokable {
  UserLocale(this.languageCode, [this.countryCode]);

  final String languageCode;
  final String? countryCode;

  static UserLocale? from(Locale? locale) {
    return locale != null
        ? UserLocale(locale.languageCode, locale.countryCode)
        : null;
  }

  @override
  Map<String, Function> getters() => {
        'languageCode': () => languageCode,
        'countryCode': () => countryCode,
      };

  @override
  Map<String, Function> methods() => {'toString': () => toString()};

  @override
  Map<String, Function> setters() => {};

  Locale toLocale() => Locale(languageCode, countryCode);

  @override
  String toString() =>
      countryCode == null ? languageCode : "${languageCode}_${countryCode}";
}
