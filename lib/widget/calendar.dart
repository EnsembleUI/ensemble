import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:ensemble/ensemble_theme.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:ensemble/framework/widget/icon.dart' as framework;
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/input/form_helper.dart';
import 'package:ensemble/widget/widget_registry.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:ensemble/util/extensions.dart';
import 'package:table_calendar/table_calendar.dart';

class Calendar extends StatefulWidget
    with Invokable, HasController<CalendarController, CalendarState> {
  static const type = 'Calendar';
  Calendar({Key? key}) : super(key: key);

  final CalendarController _controller = CalendarController();
  @override
  CalendarController get controller => _controller;

  @override
  State<StatefulWidget> createState() => CalendarState();

  @override
  Map<String, Function> getters() {
    return {

    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {

    };
  }
}

class CalendarController extends WidgetController {

}

class CalendarState extends WidgetState<Calendar> {
  List<DateTime?> _dates = [];

  @override
  Widget buildWidget(BuildContext context) {
    return TableCalendar(
      firstDay: DateTime.utc(2010, 10, 16),
      lastDay: DateTime.utc(2030, 3, 14),
      focusedDay: DateTime.now(),
      rowHeight: 100,
      calendarFormat: CalendarFormat.month,
      calendarStyle: CalendarStyle(
        // markerSize: 100
      ),
      // enabledDayPredicate: (day) {
      //   return day.weekday == 2 ? true : false;
      // },
      selectedDayPredicate: (day) {
        return day.weekday >= 2 && day.weekday <= 4 ? true : false;
      },

      onRangeSelected: (start, end, focusedDay) {
        setState(() {

        });
      },

      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) {
          return Container(
            height: 200,
            decoration: BoxDecoration(color: Colors.green),
            child: Column(
              children: [
                Text(day.toString()),
                Text(day.toString()),
                Text(day.toString()),
              ],
            )

          );
        },
        // disabledBuilder: (context, day, focusedDay) => Container(
        //   decoration: BoxDecoration(color: Colors.grey),
        // ),
        withinRangeBuilder: (context, day, focusedDay) {
          return Container(
            decoration: BoxDecoration(color: Colors.red),
            child: Text(day.toString()),
          );
        },
        rangeStartBuilder: (context, day, focusedDay) => Container(
          child: Text('hi'),
        )

      ),
      // selectedDayPredicate: (day) {
      //   return isSameDay(_selectedDay, day);
      // },
      // onDaySelected: (selectedDay, focusedDay) {
      //   setState(() {
      //     _selectedDay = selectedDay;
      //     _focusedDay = focusedDay; // update `_focusedDay` here as well
      //   });
      // },
    );


    // return CalendarDatePicker2(
    //   config: CalendarDatePicker2Config(
    //     calendarType: CalendarDatePicker2Type.range,
    //     dayTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, decoration: TextDecoration.lineThrough),
    //     disabledDayTextStyle: TextStyle(decoration: TextDecoration.lineThrough),
    //     dayBuilder: ({required date, decoration, isDisabled, isSelected, isToday, textStyle}) {
    //       return Container(
    //         height: 300,
    //         decoration: BoxDecoration(color: Colors.red),
    //         child: Text(date.toString()),
    //       );
    //     }
    //   ),
    //   value: _dates,
    //
    //   onValueChanged: (dates) => _dates = dates,
    //
    //
    // );
  }
}
