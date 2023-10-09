import 'dart:collection';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
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
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'markCall': (value) => _markCell(value),
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
      'range': (value) => setRangeData(value),
    };
  }

  void _markCell(dynamic value) {
    final date = Utils.getDate(value);
    if (date == null) return;
    _controller.markedDays.value.add(date);
  }

  void setRangeData(dynamic data) {
    if (data is YamlMap) {
      _controller.rangeSelectionMode = RangeSelectionMode.toggledOn;
      _controller.onRangeStart =
          EnsembleAction.fromYaml(data['onStart'], initiator: this);
      _controller.onRangeComplete =
          EnsembleAction.fromYaml(data['onComplete'], initiator: this);
      setCellData(data['startCell'], _controller.rangeStartCell);
      setCellData(data['endCell'], _controller.rangeEndCell);
    }
  }

  void setCellData(dynamic data, Cell cell) {
    if (data is YamlMap) {
      cell.widget = data['widget'];
      cell.onTap = EnsembleAction.fromYaml(data['onTap'], initiator: this);
      if (data.containsKey('config')) {
        cell.config = CellConfig(
            color: Utils.getColor(data['config']['color']),
            padding: Utils.getInsets(data['config']['padding']),
            margin: Utils.getInsets(data['config']['margin']),
            labelStyle: Utils.getTextStyle(data['config']['labelStyle']),
            alignment: Utils.getAlignment(data['config']['alignment']),
            borderRadius:
                Utils.getBorderRadius(data['config']['borderRadius']));
      }
    }
  }
}

class CellConfig {
  Color? color;
  EdgeInsets? margin;
  EdgeInsets? padding;
  TextStyle? labelStyle;
  Alignment? alignment;
  EBorderRadius? borderRadius;

  CellConfig({
    this.color,
    this.margin,
    this.padding,
    this.labelStyle,
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
  Cell rangeStartCell = Cell();
  Cell rangeEndCell = Cell();

  PageController? pageController;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  RangeSelectionMode rangeSelectionMode = RangeSelectionMode.toggledOff;
  EnsembleAction? onRangeComplete;
  EnsembleAction? onRangeStart;

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
}

int getHashCode(DateTime key) {
  return key.day * 1000000 + key.month * 10000 + key.year;
}

class CalendarState extends WidgetState<EnsembleCalendar> {
  final CalendarFormat _calendarFormat = CalendarFormat.month;
  final ValueNotifier<DateTime> _focusedDay = ValueNotifier(DateTime.now());

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    final data = {
      'day': selectedDay.day,
      'focusedDay': focusedDay.day,
    };
    ScopeManager? parentScope = DataScopeWidget.getScope(context);
    parentScope?.dataContext.addDataContext(data);

    if (widget._controller.cell.onTap != null) {
      ScreenController().executeAction(
        context,
        widget._controller.cell.onTap!,
      );
    }
    setState(() {
      if (widget._controller.selectedDays.value.contains(selectedDay)) {
        widget._controller.selectedDays.value.remove(selectedDay);
        if (widget._controller.selectedCell.onTap != null) {
          ScreenController().executeAction(
            context,
            widget._controller.selectedCell.onTap!,
          );
        }
      } else {
        widget._controller.selectedDays.value.add(selectedDay);
      }

      _focusedDay.value = focusedDay;
      widget._controller._rangeStart = null;
      widget._controller._rangeEnd = null;
    });
  }

  void _onRangeSelected(DateTime? start, DateTime? end, DateTime focusedDay) {
    setState(() {
      _focusedDay.value = focusedDay;
      widget._controller._rangeStart = start;
      widget._controller._rangeEnd = end;
      widget._controller.selectedDays.value.clear();
    });
  }

  @override
  Widget buildWidget(BuildContext context) {
    return ValueListenableBuilder(
        valueListenable: widget._controller.markedDays,
        builder: (context, markedDay, child) {
          return Column(children: [
            // ValueListenableBuilder<DateTime>(
            //   valueListenable: _focusedDay,
            //   builder: (context, value, _) {
            //     return _CalendarHeader(
            //       focusedDay: value,
            //       clearButtonVisible: canClearSelection,
            //       onTodayButtonTap: () {
            //         setState(() => _focusedDay.value = DateTime.now());
            //       },
            //       onClearButtonTap: () {
            //         setState(() {
            //           _rangeStart = null;
            //           _rangeEnd = null;
            //           _selectedDays.clear();
            //         });
            //       },
            //       onLeftArrowTap: () {
            //         _pageController.previousPage(
            //           duration: const Duration(milliseconds: 300),
            //           curve: Curves.easeOut,
            //         );
            //       },
            //       onRightArrowTap: () {
            //         _pageController.nextPage(
            //           duration: const Duration(milliseconds: 300),
            //           curve: Curves.easeOut,
            //         );
            //       },
            //     );
            //   },
            // ),
            TableCalendar(
              firstDay: kFirstDay,
              lastDay: kLastDay,
              focusedDay: _focusedDay.value,
              headerVisible: false,
              selectedDayPredicate: (day) =>
                  widget._controller.selectedDays.value.contains(day),
              rangeStartDay: widget._controller._rangeStart,
              rangeEndDay: widget._controller._rangeEnd,
              calendarFormat: _calendarFormat,
              rangeSelectionMode: widget._controller.rangeSelectionMode,
              onDaySelected: _onDaySelected,
              onRangeSelected: _onRangeSelected,
              onCalendarCreated: (controller) =>
                  widget._controller.pageController = controller,
              onPageChanged: (focusedDay) => _focusedDay.value = focusedDay,
              rowHeight: widget._controller.rowHeight,
              calendarBuilders: CalendarBuilders(
                rangeStartBuilder: widget._controller.rangeStartCell.isDefault
                    ? null
                    : (context, day, focusedDay) {
                        final text = "${day.day}";
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin:
                              widget._controller.rangeStartCell.config?.margin,
                          padding:
                              widget._controller.rangeStartCell.config?.padding,
                          decoration: BoxDecoration(
                            color:
                                widget._controller.rangeStartCell.config?.color,
                            borderRadius: widget
                                ._controller.rangeStartCell.config?.borderRadius
                                ?.getValue(),
                            shape: BoxShape.circle,
                          ),
                          alignment: widget
                              ._controller.rangeStartCell.config?.alignment,
                          child: Text(
                            text,
                            style: widget
                                ._controller.rangeStartCell.config?.labelStyle,
                          ),
                        );
                      },
                rangeEndBuilder: widget._controller.rangeEndCell.isDefault
                    ? null
                    : (context, day, focusedDay) {
                        final text = "${day.day}";
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin:
                              widget._controller.rangeEndCell.config?.margin,
                          padding:
                              widget._controller.rangeEndCell.config?.padding,
                          decoration: BoxDecoration(
                            color:
                                widget._controller.rangeEndCell.config?.color,
                            borderRadius: widget
                                ._controller.rangeEndCell.config?.borderRadius
                                ?.getValue(),
                            shape: BoxShape.circle,
                          ),
                          alignment:
                              widget._controller.rangeEndCell.config?.alignment,
                          child: Text(
                            text,
                            style: widget
                                ._controller.rangeEndCell.config?.labelStyle,
                          ),
                        );
                      },
                rangeHighlightBuilder: (context, day, isWithinRange) {
                  if (isWithinRange) {
                    return Center(
                      child: Container(
                        height: 80,
                        color: const Color(0xFFBBDDFF),
                      ),
                    );
                  }
                  return null;
                },
                markerBuilder: (context, day, events) {
                  if (widget._controller.markedDays.value.contains(day)) {
                    final data = {
                      'day': day.day,
                    };

                    Widget? cell;
                    if (widget._controller.todayCell.widget != null) {
                      cell = widgetBuilder(
                          context, widget._controller.todayCell.widget, data);
                    }

                    return cell ??
                        AnimatedContainer(
                          width: double.maxFinite,
                          height: double.maxFinite,
                          duration: const Duration(milliseconds: 250),
                          margin: widget._controller.todayCell.config?.margin,
                          padding: widget._controller.todayCell.config?.padding,
                          decoration: BoxDecoration(
                            color: widget._controller.todayCell.config?.color,
                            borderRadius: widget
                                ._controller.todayCell.config?.borderRadius
                                ?.getValue(),
                          ),
                          alignment:
                              widget._controller.todayCell.config?.alignment,
                          child: Text("${day.day}",
                              style: widget
                                  ._controller.todayCell.config?.labelStyle),
                        );
                  }
                  return null;
                },
                todayBuilder: widget._controller.todayCell.isDefault
                    ? null
                    : (context, day, focusedDay) {
                        final data = {
                          'day': day.day,
                          'focusedDay': focusedDay,
                        };
                        Widget? cell;
                        if (widget._controller.todayCell.widget != null) {
                          cell = widgetBuilder(context,
                              widget._controller.todayCell.widget, data);
                        }

                        return cell ??
                            AnimatedContainer(
                              width: double.maxFinite,
                              height: double.maxFinite,
                              duration: const Duration(milliseconds: 250),
                              margin:
                                  widget._controller.todayCell.config?.margin,
                              padding:
                                  widget._controller.todayCell.config?.padding,
                              decoration: BoxDecoration(
                                color:
                                    widget._controller.todayCell.config?.color,
                                borderRadius: widget
                                    ._controller.todayCell.config?.borderRadius
                                    ?.getValue(),
                              ),
                              alignment: widget
                                  ._controller.todayCell.config?.alignment,
                              child: Text("${day.day}",
                                  style: widget._controller.todayCell.config
                                      ?.labelStyle),
                            );
                      },
                defaultBuilder: widget._controller.cell.isDefault
                    ? null
                    : (context, day, focusedDay) {
                        final data = {
                          'day': day.day,
                          'focusedDay': focusedDay.day,
                        };
                        Widget? cell;
                        if (widget._controller.cell.widget != null) {
                          cell = widgetBuilder(
                              context, widget._controller.cell.widget, data);
                        }

                        return cell ??
                            AnimatedContainer(
                              width: double.maxFinite,
                              height: double.maxFinite,
                              duration: const Duration(milliseconds: 250),
                              margin: widget._controller.cell.config?.margin,
                              padding: widget._controller.cell.config?.padding,
                              decoration: BoxDecoration(
                                color: widget._controller.cell.config?.color,
                                borderRadius: widget
                                    ._controller.cell.config?.borderRadius
                                    ?.getValue(),
                              ),
                              alignment:
                                  widget._controller.cell.config?.alignment,
                              child: Text("${day.day}",
                                  style: widget
                                      ._controller.cell.config?.labelStyle),
                            );
                      },
                selectedBuilder: widget._controller.selectedCell.isDefault
                    ? null
                    : (context, day, focusedDay) {
                        final data = {
                          'day': day.day,
                          'focusedDay': focusedDay,
                        };
                        Widget? cell;
                        if (widget._controller.selectedCell.widget != null) {
                          cell = widgetBuilder(context,
                              widget._controller.selectedCell.widget, data);
                        }

                        return cell ??
                            AnimatedContainer(
                              width: double.maxFinite,
                              height: double.maxFinite,
                              duration: const Duration(milliseconds: 250),
                              margin: widget
                                  ._controller.selectedCell.config?.margin,
                              padding: widget
                                  ._controller.selectedCell.config?.padding,
                              decoration: BoxDecoration(
                                color: widget
                                    ._controller.selectedCell.config?.color,
                                borderRadius: widget._controller.selectedCell
                                    .config?.borderRadius
                                    ?.getValue(),
                              ),
                              alignment: widget
                                  ._controller.selectedCell.config?.alignment,
                              child: Text("${day.day}",
                                  style: widget._controller.selectedCell.config
                                      ?.labelStyle),
                            );
                      },
              ),
            ),
          ]);
        });
  }

  Widget? widgetBuilder(
      BuildContext context, dynamic item, Map<String, dynamic> data) {
    ScopeManager? parentScope = DataScopeWidget.getScope(context);
    parentScope?.dataContext.addDataContext(data);
    return parentScope?.buildWidgetFromDefinition(item);
  }
}

