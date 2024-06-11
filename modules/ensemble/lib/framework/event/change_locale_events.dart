import 'dart:ui';

// force a locale change while the App is running
class SetLocaleEvent {
  SetLocaleEvent(this.locale);
  final Locale locale;
}

// clear the runtime forced locale if specified
class ClearLocaleEvent {}
