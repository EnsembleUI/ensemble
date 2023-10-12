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
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'selectCell': (value) => _selectCell(value),
      'markCell': (value) => _markCell(value),
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
      'selectedCell': (value) => setCellData(value, _controller.selectedCell),
      'todayCell': (value) => setCellData(value, _controller.todayCell),
      'markCell': (value) => setCellData(value, _controller.markCell),
      'disableCell': (value) => setCellData(value, _controller.disableCell),
      'range': (value) => setRangeData(value),
    };
  }

  DateTime? _getDate(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    return Utils.getDate(value);
  }

  void _disableCell(dynamic value) {
    final rawDate = _getDate(value);
    if (rawDate == null) return;
    final date = rawDate.toDate();

    if (_controller.disableDays.value.contains(date)) {
      _controller.disableDays.value = {..._controller.disableDays.value}
        ..remove(date);
    } else {
      _controller.disableDays.value = {..._controller.disableDays.value}
        ..add(date);
    }
  }

  void _selectCell(dynamic value) {
    final rawDate = _getDate(value);
    if (rawDate == null) return;
    final date = rawDate.toDate();

    if (_controller.selectedDays.value.contains(date)) {
      _controller.selectedDays.value = {..._controller.selectedDays.value}
        ..remove(date);
    } else {
      _controller.selectedDays.value = {..._controller.selectedDays.value}
        ..add(date);
    }

    // _focusedDay.value = focusedDay;
    _controller.rangeStart = null;
    _controller.rangeEnd = null;
  }

  void _markCell(dynamic value) {
    final rawDate = _getDate(value);
    if (rawDate == null) return;
    final date = rawDate.toDate();
    _controller.markedDays.value = {..._controller.markedDays.value}..add(date);
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

  CellConfig({
    this.backgroundColor,
    this.margin,
    this.padding,
    this.textStyle,
    this.alignment,
    this.borderRadius,
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
  Cell selectedCell = Cell();
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
      widget._controller.selectedDays.value.clear();
    });
    if (end != null && widget._controller.onRangeComplete != null) {
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
                return Center(
                  child: Container(
                    height: widget._controller.rowHeight,
                    color: widget._controller.highlightColor ??
                        const Color(0x5D7FC2F8),
                  ),
                );
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
                      alignment: widget._controller.markCell.config?.alignment,
                      child: Text("${day.day}",
                          style: widget._controller.markCell.config?.textStyle),
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
                  context, day, focusedDay, widget._controller.selectedCell);
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
          ),
          alignment: cell.config?.alignment,
          child: Text(
            text,
            style: cell.config?.textStyle,
          ),
        );
  }
}
