import 'package:ensemble_date/ensemble_date.dart';

main(List<String> args) {
  const pattern = '\'Heute ist\' dd-MMMM-yyyy';
  final n = DateTime.now();
  final de_String = DateTime.now().format(pattern, 'de_DE');
  final de_Date = Date.parse(de_String, pattern: pattern, locale: 'de_DE');
  print(
    'DE (String): $de_String',
  );
  print(
    'DE (Date): $de_Date',
  );

  final es_Timeago = DateTime.now().subDays(100).timeago(locale: 'es');
  print("ES (Timeago): $es_Timeago");

  final en_Format = DateTime.now().format('MMMM dd y, h:mm:ss a');
  print("EN (Format): $en_Format");

  final utc = DateTime(2006, 6, 6, 6, 6, 6, 6, 6).utc;
  print(".UTC: $utc");

  var now = DateTime.now();
  var closest = now.closestTo(
    [
      n.nextWeek,
      n.previousDay.previousDay,
      n.previousWeek.nextDay,
      n.nextMonth,
      n.nextYear,
    ],
  )!;
  print('Closest to now ($now): $closest (${closest.timeago()})');

  print(Date.today is DateTime);

  print("Human String: " +
      DateTime.parse('2014-11-20T16:51:30.000Z').toHumanString());

  print("Yesterday: " + (Date.today - Duration(days: 1)).toString());
  print("Tomorrow: " + (Date.today + Duration(days: 1)).toString());

  print(Duration(days: 1) + Duration(hours: 12, minutes: 5));
  print(Duration(days: 1) - Duration(hours: 12, minutes: 5));
  print(Duration(hours: 1) * 2.5);
  print(Duration(hours: 1) / 70);
}
