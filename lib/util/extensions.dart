import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

extension ByteConversion on int {
  int get kb => this * 1000;
  int get mb => this * 1000 * 1000;
  int get gb => this * 1000 * 1000 * 1000;
}

extension EnhanceDouble on double {
  double clampToRange(double min, double max) {
    if (this < min) {
      return min;
    } else if (this > 2.0) {
      return 2.0;
    } else {
      return this;
    }
  }
}

extension DateOnly on DateTime {
  /// return Date as ISO-8601 i.e. YYYY-MM-DD
  String toIso8601DateString() {
    return DateFormat('yyyy-MM-dd').format(this);
  }

  DateTime toDate() {
    return DateTime(year, month, day);
  }
}

extension EnsembleTimeOfDay on TimeOfDay {
  /// return TimeOfDay as ISO i.e HH:MM:SS
  String toIso8601TimeString() {
    return '${_addLeadingZeroIfNeeded(hour)}:${_addLeadingZeroIfNeeded(minute)}:00';
  }

  /// -1 if before input, 0 if the same, 1 if after input
  int compareTo(TimeOfDay input) {
    if (hour < input.hour) {
      return -1;
    } else if (hour > input.hour) {
      return 1;
    }
    if (minute < input.minute) {
      return -1;
    } else if (minute > input.minute) {
      return 1;
    }
    return 0;
  }

  String _addLeadingZeroIfNeeded(int value) {
    if (value < 10) {
      return '0$value';
    }
    return value.toString();
  }
}
