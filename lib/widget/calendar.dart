import 'dart:collection';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/extensions.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:yaml/yaml.dart';

final kToday = DateTime.now();
final kFirstDay = DateTime(kToday.year, kToday.month - 3, kToday.day);
final kLastDay = DateTime(kToday.year, kToday.month + 3, kToday.day);

class EnsembleCalendar extends StatefulWidget
    with Invokable, HasController<CalendarController, CalendarState> {
  static const type = 'Calendar';
  EnsembleCalendar({Key? key}) : super(key: key);

  final CalendarController _controller = CalendarController();
  @override
  CalendarController get controller => _controller;

  @override
  State<StatefulWidget> createState() => CalendarState();

  @override
  Map<String, Function> getters() {
    return {
      'selectedCell': () => _controller.selectedDays.value.toList(),
      'markedCell': () => _controller.markedDays.value.toList(),
      'disableCell': () => _controller.disableDays.value.toList(),
      'rangeStart': () => _controller.rangeStart,
      'rangeEnd': () => _controller.rangeEnd,
      'range': () => _controller.range,
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'selectCell': (value) => _selectCell(value),
      'markCell': (singleDate) => _markCell(singleDate),
      'disableCell': (value) => _disableCell(value),
      'previous': (value) => _controller.pageController?.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
      'next': (value) => _controller.pageController?.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut)
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'rowHeight': (value) =>
          _controller.rowHeight = Utils.getDouble(value, fallback: 52.0),
      'cell': (value) => setCellData(value, _controller.cell),
      'selectCell': (value) => setCellData(value, _controller.selectCell),
      'todayCell': (value) => setCellData(value, _controller.todayCell),
      'markCell': (value) => setCellData(value, _controller.markCell),
      'disableCell': (value) => setCellData(value, _controller.disableCell),
      'range': (value) => setRangeData(value),
    };
  }

  List<DateTime>? _getDate(dynamic value) {
    if (value is DateTime) {
      return [value.toDate()];
    } else if (value is List<DateTime>) {
      return value.map((e) => e.toDate()).toList();
    } else if (value is String) {
      DateTime? parsedData = Utils.getDate(value);
      if (parsedData != null) {
        return [parsedData.toDate()];
      } else {
        return null;
      }
    } else if (value is List) {
      List<DateTime> dateTimes = [];

      for (var date in value) {
        DateTime? parsedDate = Utils.getDate(date);
        if (parsedDate != null) {
          dateTimes.add(parsedDate.toDate());
        } else {
          return null;
        }
      }
      return dateTimes;
    } else if (value is DateTimeRange) {
      List<DateTime> rangeDates = [];
      for (int days = 0;
          days <= value.start.difference(value.end).inDays.abs();
          days++) {
        rangeDates.add(value.start.add(Duration(days: days)));
      }
      return rangeDates;
    }

    return null;
  }

  void _disableCell(dynamic value) {
    final rawDate = _getDate(value);
    if (rawDate == null) return;

    HashSet<DateTime> updatedDisabledDays =
        HashSet<DateTime>.from(_controller.disableDays.value);

    for (var date in rawDate) {
      if (updatedDisabledDays.contains(date)) {
        updatedDisabledDays.remove(date);
      } else {
        updatedDisabledDays.add(date);
      }
    }

    _controller.disableDays.value = updatedDisabledDays;
  }

  void _selectCell(dynamic value) {
    final rawDate = _getDate(value);
    if (rawDate == null) return;

    HashSet<DateTime> updatedDisabledDays =
        HashSet<DateTime>.from(_controller.selectedDays.value);

    for (var date in rawDate) {
      if (updatedDisabledDays.contains(date)) {
        updatedDisabledDays.remove(date);
      } else {
        updatedDisabledDays.add(date);
      }
    }

    _controller.selectedDays.value = updatedDisabledDays;
    // _controller.rangeStart = null;
    // _controller.rangeEnd = null;
  }

  void _markCell(dynamic value) {
    final rawDate = _getDate(value);
    if (rawDate == null) return;

    HashSet<DateTime> updatedMarkDays =
        HashSet<DateTime>.from(_controller.markedDays.value);
    HashSet<DateTime> updatedSelectedDays =
        HashSet<DateTime>.from(_controller.selectedDays.value);

    for (var date in rawDate) {
      if (updatedMarkDays.contains(date)) {
        updatedMarkDays.remove(date);
      } else {
        updatedMarkDays.add(date);
      }
      updatedSelectedDays.remove(date);
    }

    _controller.markedDays.value = updatedMarkDays;
    _controller.selectedDays.value = updatedSelectedDays;
  }

  void setRangeData(dynamic data) {
    if (data is YamlMap) {
      _controller.highlightColor = Utils.getColor(data['highlightColor']);
      _controller.rangeSelectionMode = RangeSelectionMode.toggledOn;
      _controller.onRangeStart =
          EnsembleAction.fromYaml(data['onStart'], initiator: this);
      _controller.onRangeComplete =
          EnsembleAction.fromYaml(data['onComplete'], initiator: this);
      setCellData(data['startCell'], _controller.rangeStartCell);
      setCellData(data['endCell'], _controller.rangeEndCell);
      setCellData(data['betweenCell'], _controller.rangeBetweenCell);
    }
  }

  void setCellData(dynamic data, Cell cell) {
    if (data is YamlMap) {
      cell.widget = data['widget'];
      cell.onTap = EnsembleAction.fromYaml(data['onTap'], initiator: this);
      if (data.containsKey('config')) {
        cell.config = CellConfig(
            backgroundColor: Utils.getColor(data['config']?['backgroundColor']),
            padding: Utils.getInsets(data['config']?['padding']),
            margin: Utils.getInsets(data['config']?['margin']),
            textStyle: Utils.getTextStyle(data['config']?['textStylek']),
            alignment: Utils.getAlignment(data['config']?['alignment']),
            shape: Utils.getBoxShape(data['config']?['shape']),
            borderRadius:
                Utils.getBorderRadius(data['config']?['borderRadius']));
      }
    }
  }
}

class CellConfig {
  Color? backgroundColor;
  EdgeInsets? margin;
  EdgeInsets? padding;
  TextStyle? textStyle;
  Alignment? alignment;
  EBorderRadius? borderRadius;
  BoxShape? shape;

  CellConfig({
    this.backgroundColor,
    this.margin,
    this.padding,
    this.textStyle,
    this.alignment,
    this.borderRadius,
    this.shape,
  });
}

class Cell {
  dynamic widget;
  CellConfig? config;
  EnsembleAction? onTap;

  Cell({this.widget, this.config, this.onTap});

  bool get isDefault => !((widget != null) || (config != null));
}

class CalendarController extends WidgetController {
  double rowHeight = 52.0;
  Cell cell = Cell();
  Cell selectCell = Cell();
  Cell todayCell = Cell();
  Cell markCell = Cell();
  Cell disableCell = Cell();
  Cell rangeStartCell = Cell();
  Cell rangeEndCell = Cell();
  Cell rangeBetweenCell = Cell();

  DateTime? selectedDate;

  PageController? pageController;
  DateTime? rangeStart;
  DateTime? rangeEnd;
  DateTimeRange? range;
  RangeSelectionMode rangeSelectionMode = RangeSelectionMode.toggledOff;
  EnsembleAction? onRangeComplete;
  EnsembleAction? onRangeStart;
  Color? highlightColor;

  final ValueNotifier<Set<DateTime>> markedDays = ValueNotifier(
    LinkedHashSet<DateTime>(
      equals: isSameDay,
      hashCode: getHashCode,
    ),
  );
  final ValueNotifier<Set<DateTime>> selectedDays = ValueNotifier(
    LinkedHashSet<DateTime>(
      equals: isSameDay,
      hashCode: getHashCode,
    ),
  );
  final ValueNotifier<Set<DateTime>> disableDays = ValueNotifier(
    LinkedHashSet<DateTime>(
      equals: isSameDay,
      hashCode: getHashCode,
    ),
  );
}

int getHashCode(DateTime key) {
  return key.day * 1000000 + key.month * 10000 + key.year;
}

class CalendarState extends WidgetState<EnsembleCalendar> {
  final CalendarFormat _calendarFormat = CalendarFormat.month;
  final ValueNotifier<DateTime> _focusedDay = ValueNotifier(DateTime.now());

  @override
  void initState() {
    widget._controller.selectedDays.addListener(() {
      setState(() {});
    });

    widget._controller.markedDays.addListener(() {
      setState(() {});
    });

    widget._controller.disableDays.addListener(() {
      setState(() {});
    });

    super.initState();
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    final data = {
      'day': selectedDay.day,
      'month': selectedDay.month,
      'year': selectedDay.year,
      'date': selectedDay,
      'focusedDay': focusedDay.day,
    };
    ScopeManager? parentScope = DataScopeWidget.getScope(context);
    parentScope?.dataContext.addDataContext(data);

    widget._controller.selectedDate = selectedDay;

    if (widget._controller.cell.onTap != null) {
      ScreenController().executeAction(
        context,
        widget._controller.cell.onTap!,
      );
    }
  }

  void _onRangeSelected(DateTime? start, DateTime? end, DateTime focusedDay) {
    setState(() {
      _focusedDay.value = focusedDay;
      widget._controller.rangeStart = start;
      widget._controller.rangeEnd = end;
    });
    if (end != null && widget._controller.onRangeComplete != null) {
      widget._controller.range = DateTimeRange(start: start!, end: end);
      ScreenController().executeAction(
        context,
        widget._controller.onRangeComplete!,
      );
    } else if (start != null && widget._controller.onRangeStart != null) {
      ScreenController().executeAction(
        context,
        widget._controller.onRangeStart!,
      );
    }
  }

  @override
  Widget buildWidget(BuildContext context) {
    return Column(
      children: [
        TableCalendar(
          firstDay: kFirstDay,
          lastDay: kLastDay,
          focusedDay: _focusedDay.value,
          headerVisible: false,
          selectedDayPredicate: (day) =>
              widget._controller.selectedDays.value.contains(day.toDate()),
          enabledDayPredicate: (day) =>
              !(widget._controller.disableDays.value.contains(day.toDate())),
          rangeStartDay: widget._controller.rangeStart,
          rangeEndDay: widget._controller.rangeEnd,
          calendarFormat: _calendarFormat,
          rangeSelectionMode: widget._controller.rangeSelectionMode,
          onDaySelected: _onDaySelected,
          onRangeSelected: _onRangeSelected,
          onCalendarCreated: (controller) =>
              widget._controller.pageController = controller,
          onPageChanged: (focusedDay) => _focusedDay.value = focusedDay,
          rowHeight: widget._controller.rowHeight,
          calendarBuilders: CalendarBuilders(
            disabledBuilder: (context, day, focusedDay) {
              return cellBuilder(
                  context, day, focusedDay, widget._controller.disableCell);
            },
            rangeStartBuilder: (context, day, focusedDay) {
              return cellBuilder(
                  context, day, focusedDay, widget._controller.rangeStartCell);
            },
            rangeEndBuilder: (context, day, focusedDay) {
              return cellBuilder(
                  context, day, focusedDay, widget._controller.rangeEndCell);
            },
            withinRangeBuilder: (context, day, focusedDay) {
              return cellBuilder(context, day, focusedDay,
                  widget._controller.rangeBetweenCell);
            },
            rangeHighlightBuilder: (context, day, isWithinRange) {
              if (isWithinRange) {
                return LayoutBuilder(builder: (context, constraints) {
                  final shorterSide =
                      constraints.maxHeight > constraints.maxWidth
                          ? constraints.maxWidth
                          : constraints.maxHeight;

                  final isRangeStart =
                      isSameDay(day, widget._controller.rangeStart);
                  final isRangeEnd =
                      isSameDay(day, widget._controller.rangeEnd);

                  return Center(
                    child: Container(
                      height: (shorterSide - 12),
                      margin: EdgeInsetsDirectional.only(
                        start: isRangeStart ? constraints.maxWidth * 0.5 : 0.0,
                        end: isRangeEnd ? constraints.maxWidth * 0.5 : 0.0,
                      ),
                      decoration: BoxDecoration(
                        color: widget._controller.highlightColor ??
                            Theme.of(context).primaryColor.withOpacity(0.4),
                        shape: widget._controller.markCell.config?.shape ??
                            BoxShape.rectangle,
                      ),
                    ),
                  );
                });
              }
              return null;
            },
            markerBuilder: (context, rawDate, events) {
              final day = rawDate.toDate();
              if (widget._controller.markedDays.value.contains(day)) {
                final data = {
                  'day': day.day,
                  'month': day.month,
                };

                Widget? cell;
                if (widget._controller.markCell.widget != null) {
                  cell = widgetBuilder(
                      context, widget._controller.markCell.widget, data);
                }

                return cell ??
                    AnimatedContainer(
                      width: double.maxFinite,
                      height: double.maxFinite,
                      duration: const Duration(milliseconds: 250),
                      margin: widget._controller.markCell.config?.margin,
                      padding: widget._controller.markCell.config?.padding,
                      decoration: BoxDecoration(
                        color:
                            widget._controller.markCell.config?.backgroundColor,
                        borderRadius: widget
                            ._controller.markCell.config?.borderRadius
                            ?.getValue(),
                      ),
                    );
              }
              return null;
            },
            todayBuilder: (context, day, focusedDay) {
              return cellBuilder(
                  context, day, focusedDay, widget._controller.todayCell);
            },
            defaultBuilder: (context, day, focusedDay) {
              return cellBuilder(
                  context, day, focusedDay, widget._controller.cell);
            },
            selectedBuilder: (context, day, focusedDay) {
              return cellBuilder(
                  context, day, focusedDay, widget._controller.selectCell);
            },
          ),
        ),
      ],
    );
  }

  Widget? widgetBuilder(
      BuildContext context, dynamic item, Map<String, dynamic> data) {
    ScopeManager? parentScope = DataScopeWidget.getScope(context);
    parentScope?.dataContext.addDataContext(data);
    return parentScope?.buildWidgetFromDefinition(item);
  }

  Widget? cellBuilder(
    BuildContext context,
    DateTime day,
    DateTime focusedDay,
    Cell cell,
  ) {
    final text = "${day.day}";
    if (cell.isDefault) {
      return null;
    }

    final data = {
      'day': day.day,
      'month': day.month,
      'year': day.year,
      'date': day,
      'focusedDay': focusedDay.day,
    };

    Widget? customWidget;
    if (widget._controller.markCell.widget != null) {
      customWidget =
          widgetBuilder(context, widget._controller.markCell.widget, data);
    }

    return customWidget ??
        AnimatedContainer(
          width: double.maxFinite,
          height: double.maxFinite,
          duration: const Duration(milliseconds: 250),
          margin: cell.config?.margin,
          padding: cell.config?.padding,
          decoration: BoxDecoration(
            color: cell.config?.backgroundColor,
            borderRadius: cell.config?.borderRadius?.getValue(),
            shape: cell.config?.shape ?? BoxShape.rectangle,
          ),
          alignment: cell.config?.alignment ?? Alignment.center,
          child: Text(
            text,
            style: cell.config?.textStyle,
          ),
        );
  }
}
