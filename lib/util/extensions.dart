import 'package:intl/intl.dart';

extension DateOnly on DateTime {
  /// return Date as ISO-8601 i.e. YYYY-MM-DD
  String toIso8601DateString() {
    return DateFormat('yyyy-MM-dd').format(this);
  }

  DateTime toDate() {
    return DateTime(year, month, day);
  }
}