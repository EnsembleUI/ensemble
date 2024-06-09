import 'dart:ui';

import 'package:ensemble_ts_interpreter/invokables/invokable.dart';

class MyLocale with Invokable {
  MyLocale(this.languageCode, [this.countryCode]);

  final String languageCode;
  final String? countryCode;

  static MyLocale? from(Locale? locale) {
    return locale != null
        ? MyLocale(locale.languageCode, locale.countryCode)
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

  @override
  String toString() =>
      countryCode == null ? languageCode : "${languageCode}_${countryCode}";
}
