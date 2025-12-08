import 'dart:collection';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/model/item_template.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/extensions.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ensemble_table_calendar/ensemble_table_calendar.dart';
import 'package:yaml/yaml.dart';
import 'package:collection/collection.dart';

final kToday = DateTime.now();
final kFirstDay = DateTime(kToday.year, kToday.month - 12, kToday.day);
final kLastDay = DateTime(kToday.year, kToday.month + 12, kToday.day);

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
  List<String> passthroughSetters() => ['rowSpans'];

  @override
  Map<String, Function> getters() {
    return {
      'selectedCell': () => _controller.selectedDays.value
          .map((e) => e.toIso8601DateString())
          .toList(),
      'markedCell': () => _controller.markedDays.value
          .map((e) => e.toIso8601DateString())
          .toList(),
      'disabledCell': () => _controller.disableDays.value
          .map((e) => e.toIso8601DateString())
          .toList(),
      'rangeStart': () => _controller.rangeStart?.toIso8601DateString(),
      'rangeEnd': () => _controller.rangeEnd?.toIso8601DateString(),
      'range': () => _controller.range,
      'focusDate': () => _controller.focusedDay.value,
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'selectCell': (value) => _selectCell(value),
      'selectStartEndCell': (start, end) => _selectCell(start, end),
      'toggleSelectCell': (value) => _toggleSelectedCell(value),
      'unSelectCell': (value) => _unSelectCell(value),
      'unSelectStartEndCell': (start, end) => _unSelectCell(start, end),
      'markCell': (singleDate) => _markCell(singleDate),
      'markStartEndCell': (start, end) => _markCell(start, end),
      'unMarkCell': (singleDate) => _unMarkCell(singleDate),
      'unMarkStartEndCell': (start, end) => _unMarkCell(start, end),
      'toggleMarkCell': (singleDate) => _toggleMarkCell(singleDate),
      'disableCell': (value) => _disableCell(value),
      'enableCell': (value) => _enableCell(value),
      'toggleDisableCell': (value) => _toggleDisableCell(value),
      'previous': (value) => _controller.pageController?.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
      'next': (value) => _controller.pageController?.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
      'addRowSpan': (value) => setRowSpan(value),
      'update': () => _controller.update(),
      'clearRange': () => clearRange(),
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
      'headerVisible': (value) =>
          _controller.headerVisible = Utils.getBool(value, fallback: true),
      'firstDay': (value) => _controller.firstDay = Utils.getDate(value),
      'lastDay': (value) => _controller.lastDay = Utils.getDate(value),
      'rowSpans': (value) {
        _controller.rowSpanLimit = value['spanPerRow'];
        _controller.overlapOverflowBuilder = value['overflowWidget'];
        _controller.topMargin = Utils.getInt(value['topMargin'], fallback: 0);

        if (value['span-template'] is YamlMap ||
            value['span-template'] is Map) {
          setRowSpanItemTemplate(value['span-template']);
        }

        if (value['children'] is List) {
          for (var span in value['children']) {
            setRowSpan(span['span']);
          }
        }
      },
      'headerTextStyle': (value) =>
          _controller.headerTextStyle = Utils.getTextStyle(value),
      'header': (value) => _controller.header = value,
      'tooltip': (value) => setTooltip(value),
      'showTooltip': (value) =>
          _controller.showTooltip = Utils.getBool(value, fallback: false),
      'showOutsideDate': (value) =>
          _controller.showOutsideDate = Utils.getBool(value, fallback: false),
    };
  }

  void clearRange() {
    _controller.rangeStart = null;
    _controller.rangeEnd = null;
    _controller.range = null;
  }

  void setRowSpanItemTemplate(dynamic rowSpanData) {
    try {
      if (rowSpanData is! Map ||
          rowSpanData is! YamlMap ||
          rowSpanData['span'] is! Map ||
          rowSpanData['span'] is! YamlMap) {
        return;
      }

      final rowSpanTemplate = RowSpanTemplate(
        data: rowSpanData['data'],
        name: rowSpanData['name'],
        spanTemplate: SpanTemplate(
          rowId: rowSpanData['span']['rowId'],
          start: rowSpanData['span']['start'],
          end: rowSpanData['span']['end'],
          widget: rowSpanData['span']['widget'],
        ),
      );
      _controller.rowSpanTemplate = rowSpanTemplate;
    } on Exception catch (_) {
      //noop
    }
  }

  setTooltip(value) {
    _controller.tooltip = Utils.optionalString(value?['text']);
    _controller.tooltipBackgroundColor =
        Utils.getColor(value?['backgroundColor']);
    DateTime? date;
    if (value?['date'] is DateTime) {
      date = value?['date'];
    } else {
      date = Utils.getDate(value?['date']);
    }
    if (date != null) {
      _controller.tooltipDate =
          DateTime.utc(date.year, date.month, date.day, 0, 0, 0);
    }
    _controller.tooltipTextStyle = Utils.getTextStyle(value?['textStyle']);
  }

  List<DateTime>? _getDates(DateTime? start, DateTime? end) {
    List<DateTime> dates = [];

    if (start == null || end == null || start.isAfter(end)) return null;

    for (int i = 0; i <= end.difference(start).inDays; i++) {
      dates.add(start.add(Duration(days: i)));
    }

    return dates;
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
        rangeDates.add(value.start.add(Duration(days: days)).toDate());
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
      updatedDisabledDays.add(date);
    }

    _controller.rangeStart = null;
    _controller.rangeEnd = null;
    _controller.range = null;
    _controller.disableDays.value = updatedDisabledDays;
  }

  void _enableCell(dynamic value) {
    final rawDate = _getDate(value);
    if (rawDate == null) return;

    HashSet<DateTime> updatedDisabledDays =
        HashSet<DateTime>.from(_controller.disableDays.value);

    for (var date in rawDate) {
      updatedDisabledDays.remove(date);
    }

    _controller.rangeStart = null;
    _controller.rangeEnd = null;
    _controller.range = null;
    _controller.disableDays.value = updatedDisabledDays;
  }

  void _toggleDisableCell(dynamic value) {
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

    _controller.rangeStart = null;
    _controller.rangeEnd = null;
    _controller.range = null;
    _controller.disableDays.value = updatedDisabledDays;
  }

  void _selectCell(dynamic value, [dynamic end]) {
    List<DateTime>? rawDate;
    if (end != null) {
      final startDate = _getDate(value)?.firstOrNull;
      final endDate = _getDate(end)?.firstOrNull;

      rawDate = _getDates(startDate, endDate);

      // If both start and end dates are valid, set up range selection
      if (startDate != null && endDate != null && rawDate != null) {
        final normalizedStart = startDate.toDate();
        final normalizedEnd = endDate.toDate();

        if (_controller.rangeSelectionMode != RangeSelectionMode.disabled) {
          _controller.rangeSelectionMode = RangeSelectionMode.toggledOn;
        }

        _controller.rangeStart = normalizedStart;
        _controller.rangeEnd = normalizedEnd;
        _controller.range =
            DateTimeRange(start: normalizedStart, end: normalizedEnd);

        _controller.selectedDays.value.clear();

        _controller.update();
        return;
      }
    } else {
      rawDate = _getDate(value);
    }
    if (rawDate == null) return;

    // For single date selection, clear range and use selectedDays
    HashSet<DateTime> updatedDisabledDays =
        HashSet<DateTime>.from(_controller.selectedDays.value);

    for (var date in rawDate) {
      updatedDisabledDays.add(date);
    }

    _controller.rangeStart = null;
    _controller.rangeEnd = null;
    _controller.range = null;
    _controller.selectedDays.value = updatedDisabledDays;
  }

  void _unSelectCell(dynamic value, [dynamic end]) {
    List<DateTime>? rawDate;
    if (end != null) {
      final startDate = _getDate(value)?.firstOrNull;
      final endDate = _getDate(end)?.firstOrNull;

      rawDate = _getDates(startDate, endDate);
    } else {
      rawDate = _getDate(value);
    }
    if (rawDate == null) return;

    HashSet<DateTime> updatedDisabledDays =
        HashSet<DateTime>.from(_controller.selectedDays.value);

    for (var date in rawDate) {
      updatedDisabledDays.remove(date);
    }

    _controller.selectedDays.value = updatedDisabledDays;
  }

  void _toggleSelectedCell(dynamic value) {
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

    _controller.rangeStart = null;
    _controller.rangeEnd = null;
    _controller.range = null;
    _controller.selectedDays.value = updatedDisabledDays;
  }

  void _unMarkCell(dynamic value, [dynamic end]) {
    List<DateTime>? rawDate;
    if (end != null) {
      final startDate = _getDate(value)?.firstOrNull;
      final endDate = _getDate(end)?.firstOrNull;

      rawDate = _getDates(startDate, endDate);
    } else {
      rawDate = _getDate(value);
    }
    if (rawDate == null) return;

    HashSet<DateTime> updatedMarkDays =
        HashSet<DateTime>.from(_controller.markedDays.value);
    HashSet<DateTime> updatedSelectedDays =
        HashSet<DateTime>.from(_controller.selectedDays.value);

    for (var date in rawDate) {
      updatedMarkDays.remove(date);
      updatedSelectedDays.remove(date);
    }

    _controller.rangeStart = null;
    _controller.rangeEnd = null;
    _controller.range = null;
    _controller.markedDays.value = updatedMarkDays;
    _controller.selectedDays.value = updatedSelectedDays;
  }

  void _markCell(dynamic value, [dynamic end]) {
    List<DateTime>? rawDate;
    if (end != null) {
      final startDate = _getDate(value)?.firstOrNull;
      final endDate = _getDate(end)?.firstOrNull;

      rawDate = _getDates(startDate, endDate);
    } else {
      rawDate = _getDate(value);
    }
    if (rawDate == null) return;

    HashSet<DateTime> updatedMarkDays =
        HashSet<DateTime>.from(_controller.markedDays.value);
    HashSet<DateTime> updatedSelectedDays =
        HashSet<DateTime>.from(_controller.selectedDays.value);

    for (var date in rawDate) {
      updatedMarkDays.add(date);
      updatedSelectedDays.remove(date);
    }

    _controller.rangeStart = null;
    _controller.rangeEnd = null;
    _controller.range = null;
    _controller.markedDays.value = updatedMarkDays;
    _controller.selectedDays.value = updatedSelectedDays;
  }

  void _toggleMarkCell(dynamic value) {
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

    _controller.rangeStart = null;
    _controller.rangeEnd = null;
    _controller.range = null;
    _controller.markedDays.value = updatedMarkDays;
    _controller.selectedDays.value = updatedSelectedDays;
  }

  void setRowSpan(dynamic data) {
    final List<RowSpanConfig> spans = List.from(_controller.rowSpans.value);
    if (data is YamlMap || data is Map) {
      final rowSpan = RowSpanConfig(
        startDay: Utils.getDate(data['start']),
        endDay: Utils.getDate(data['end']),
        widget: data['widget'],
        inputs: data['inputs'],
        id: Utils.generateRandomId(6),
      );
      spans.add(rowSpan);
    }
    _controller.rowSpans.value = spans;
  }

  void setRangeData(dynamic data) {
    if (data is YamlMap) {
      _controller.highlightColor = Utils.getColor(data['highlightColor']);
      _controller.rangeSelectionMode = RangeSelectionMode.toggledOn;
      _controller.onRangeStart =
          EnsembleAction.from(data['onStart'], initiator: this);
      _controller.onRangeComplete =
          EnsembleAction.from(data['onComplete'], initiator: this);
      setCellData(data['startCell'], _controller.rangeStartCell);
      setCellData(data['endCell'], _controller.rangeEndCell);
      setCellData(data['betweenCell'], _controller.rangeBetweenCell);
    }
  }

  void setCellData(dynamic data, Cell cell) {
    if (data is YamlMap) {
      cell.widget = data['widget'];
      cell.onTap = EnsembleAction.from(data['onTap'], initiator: this);
      if (data.containsKey('config')) {
        cell.config = CellConfig(
            backgroundColor: Utils.getColor(data['config']?['backgroundColor']),
            padding: Utils.getInsets(data['config']?['padding']),
            margin: Utils.getInsets(data['config']?['margin']),
            textStyle: Utils.getTextStyle(data['config']?['textStyle']),
            alignment: Utils.getAlignment(data['config']?['alignment']),
            shape: Utils.getBoxShape(data['config']?['shape']),
            borderRadius:
                Utils.getBorderRadius(data['config']?['borderRadius']));
      }
    }
  }
}

class RowSpanConfig {
  ScopeManager? scope;
  DateTime? startDay;
  DateTime? endDay;
  dynamic widget;
  Map? inputs;
  String id;
  int? rowId;

  RowSpanConfig({
    this.startDay,
    this.endDay,
    this.widget,
    this.inputs,
    required this.id,
    this.scope,
    this.rowId,
  });

  bool get isValid => startDay != null && endDay != null;

  Map<String, dynamic> toJson() {
    return {
      'start': startDay,
      'end': endDay,
      'widget': widget,
      'inputs': inputs,
      'rowId': rowId,
    };
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

  dynamic rowSpanLimit;
  int topMargin = 0;
  dynamic overlapOverflowBuilder;

  RowSpanTemplate? rowSpanTemplate;
  DateTime? selectedDate;
  DateTime? disabledDate;

  PageController? pageController;
  DateTime? rangeStart;
  DateTime? rangeEnd;
  DateTimeRange? range;
  RangeSelectionMode rangeSelectionMode = RangeSelectionMode.toggledOff;
  EnsembleAction? onRangeComplete;
  EnsembleAction? onRangeStart;
  Color? highlightColor;
  bool headerVisible = true;
  dynamic header;
  DateTime? firstDay;
  DateTime? lastDay;
  final ValueNotifier<DateTime> focusedDay = ValueNotifier(DateTime.now());
  ValueNotifier<List<RowSpanConfig>> rowSpans = ValueNotifier([]);
  TextStyle? headerTextStyle;

  String? tooltip;
  DateTime? tooltipDate;
  TextStyle? tooltipTextStyle;
  Color? tooltipBackgroundColor;
  bool showTooltip = false;

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
  CalendarState? widgetState;

  bool showOutsideDate = false;

  void _bind(CalendarState state) {
    widgetState = state;
  }

  void update() {
    widgetState?.listener();
  }
}

int getHashCode(DateTime key) {
  return key.day * 1000000 + key.month * 10000 + key.year;
}

class CalendarState extends EWidgetState<EnsembleCalendar>
    with TemplatedWidgetState {
  final CalendarFormat _calendarFormat = CalendarFormat.month;
  ItemTemplate? itemTemplate;

  @override
  void initState() {
    widget._controller.selectedDays.addListener(listener);
    widget._controller.markedDays.addListener(listener);
    widget._controller.disableDays.addListener(listener);
    widget._controller.rowSpans.addListener(listener);
    super.initState();
  }

  void listener() {
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    _registerRowSpanListener(context);
    super.didChangeDependencies();
  }

  void _registerRowSpanListener(BuildContext context) {
    if (widget.controller.rowSpanTemplate != null) {
      registerItemTemplate(context, widget.controller.rowSpanTemplate!,
          onDataChanged: (dataList) {
        if (dataList is List) {
          final configs = _builRowSpanConfigs(context, dataList);
          widget._controller.rowSpans.value = configs;
          setState(() {});
        }
      });
    }
  }

  _builRowSpanConfigs(BuildContext context, List dataList) {
    List<RowSpanConfig> rowSpanConfigs = [];

    RowSpanTemplate? itemTemplate = widget.controller.rowSpanTemplate;
    ScopeManager? myScope = DataScopeWidget.getScope(context);
    if (myScope != null && itemTemplate != null) {
      for (dynamic dataItem in dataList) {
        ScopeManager dataScope = myScope.createChildScope();
        dataScope.dataContext.addDataContextById(itemTemplate.name, dataItem);

        rowSpanConfigs.add(
          RowSpanConfig(
              id: Utils.generateRandomId(6),
              rowId: Utils.optionalInt(
                  dataScope.dataContext.eval(itemTemplate.spanTemplate.rowId)),
              startDay: Utils.getDate(
                  dataScope.dataContext.eval(itemTemplate.spanTemplate.start)),
              endDay: Utils.getDate(
                  dataScope.dataContext.eval(itemTemplate.spanTemplate.end)),
              scope: dataScope,
              widget:
                  dataScope.dataContext.eval(itemTemplate.spanTemplate.widget)),
        );
      }
    }
    return rowSpanConfigs;
  }

  @override
  void dispose() {
    widget._controller.selectedDays.removeListener(listener);
    widget._controller.markedDays.removeListener(listener);
    widget._controller.disableDays.removeListener(listener);
    widget._controller.rowSpans.removeListener(listener);
    super.dispose();
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

  void _onDisableSelected(DateTime selectedDay) {
    final data = {
      'day': selectedDay.day,
      'month': selectedDay.month,
      'year': selectedDay.year,
      'date': selectedDay,
    };
    ScopeManager? parentScope = DataScopeWidget.getScope(context);
    parentScope?.dataContext.addDataContext(data);

    widget._controller.disabledDate = selectedDay;

    if (widget._controller.disableCell.onTap != null) {
      ScreenController().executeAction(
        context,
        widget._controller.disableCell.onTap!,
      );
    }
  }

  void _onRangeSelected(DateTime? start, DateTime? end, DateTime focusedDay) {
    setState(() {
      widget._controller.focusedDay.value = focusedDay;
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
    widget.controller._bind(this);

    return Column(
      children: [
        if (widget._controller.headerVisible)
          ValueListenableBuilder<DateTime>(
            valueListenable: widget._controller.focusedDay,
            builder: (context, value, _) {
              Widget? header;

              if (widget._controller.header != null) {
                header = widgetBuilder(context, widget._controller.header, {});
              }

              return header ??
                  _CalendarHeader(
                    focusedDay: value,
                    headerStyle: widget._controller.headerTextStyle,
                    onLeftArrowTap: () {
                      widget._controller.pageController?.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    },
                    onRightArrowTap: () {
                      widget._controller.pageController?.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    },
                  );
            },
          ),
        TableCalendar(
          firstDay: widget._controller.firstDay ?? kFirstDay,
          lastDay: widget._controller.lastDay ?? kLastDay,
          focusedDay: widget._controller.focusedDay.value,
          headerVisible: false,
          selectedDayPredicate: (day) =>
              widget._controller.selectedDays.value.contains(day.toDate()),
          markedDayPredicate: (day) =>
              widget._controller.markedDays.value.contains(day.toDate()),
          enabledDayPredicate: (day) =>
              !(widget._controller.disableDays.value.contains(day.toDate())),
          rowSpanLimit:
              scopeManager?.dataContext.eval(widget._controller.rowSpanLimit) ??
                  -1,
          rangeStartDay: widget._controller.rangeStart,
          rangeEndDay: widget._controller.rangeEnd,
          calendarFormat: _calendarFormat,
          rangeSelectionMode: widget._controller.rangeSelectionMode,
          onDaySelected: _onDaySelected,
          onRangeSelected: _onRangeSelected,
          onDisabledDayTapped: _onDisableSelected,
          onCalendarCreated: (controller) =>
              widget._controller.pageController = controller,
          onPageChanged: (focusedDay) =>
              widget._controller.focusedDay.value = focusedDay,
          rowHeight: widget._controller.rowHeight,
          daysOfWeekVisible: true,
          overlayRanges: getOverlayRange(),
          toolTipDate: widget._controller.tooltipDate,
          toolTip: widget._controller.tooltip,
          toolTipBackgroundColor: widget._controller.tooltipBackgroundColor,
          toolTipStyle: widget._controller.tooltipTextStyle,
          showTooltip: widget._controller.showTooltip,
          topMargin: widget._controller.topMargin,
          calendarBuilders: CalendarBuilders(
            outsideBuilder: widget._controller.showOutsideDate
                ? null
                : (context, day, focusedDay) {
                    return const SizedBox.shrink();
                  },
            overlayDefaultBuilder: (context, collapsedLength, children) {
              final collapsedSpans = widget._controller.rowSpans.value
                  .where((object) => children.contains(object.id))
                  .toList();

              if (widget._controller.overlapOverflowBuilder == null) {
                return null;
              }

              ScopeManager? myScope = DataScopeWidget.getScope(context);
              ScopeManager? dataScope = myScope?.createChildScope();

              if (collapsedLength != null) {
                dataScope?.dataContext.addDataContextById(
                    'collapsedLength', collapsedSpans.length);
                dataScope?.dataContext.addDataContextById('collapsedSpans',
                    collapsedSpans.map((e) => e.toJson()).toList());
              }

              final child = dataScope?.buildWidgetWithScopeFromDefinition(
                  widget._controller.overlapOverflowBuilder);
              return child;
            },
            overlayBuilder: widget._controller.rowSpans.value.isEmpty
                ? null
                : (context, range) {
                    final spans = widget._controller.rowSpans;

                    final span = spans.value
                        .firstWhereOrNull((element) => element.id == range.id);
                    if (span != null) {
                      if (span.scope != null) {
                        final child = span.scope?.buildWidgetFromDefinition(
                            YamlMap.wrap(span.widget));
                        return child;
                      }
                      return widgetBuilder(
                        context,
                        span.widget,
                        span.inputs?.cast<String, dynamic>() ?? {},
                      );
                    }

                    return const SizedBox.shrink();
                  },
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
                            Theme.of(context).primaryColor.withValues(alpha: 0.4),
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
                  'date': day,
                  'year': day.year,
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
              if (widget._controller.rangeSelectionMode ==
                  RangeSelectionMode.toggledOn) {
                final isWithinRange = widget._controller.rangeStart != null &&
                    widget._controller.rangeEnd != null &&
                    _isWithinRange(day, widget._controller.rangeStart!,
                        widget._controller.rangeEnd!);
                if (isWithinRange) {
                  return cellBuilder(context, day, focusedDay,
                      widget._controller.rangeBetweenCell);
                }
              }
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

  List<CustomRange> getOverlayRange() {
    final overlayRange = <CustomRange>[];
    for (var span in widget._controller.rowSpans.value) {
      if (span.endDay != null && span.startDay != null) {
        overlayRange.add(CustomRange(
          start: span.startDay!,
          end: span.endDay!,
          id: span.id,
          rowId: span.rowId,
        ));
      }
    }
    return overlayRange;
  }

  bool _isWithinRange(DateTime day, DateTime start, DateTime end) {
    if (isSameDay(day, start) || isSameDay(day, end)) {
      return true;
    }

    if (day.isAfter(start) && day.isBefore(end)) {
      return true;
    }

    return false;
  }

  Widget? widgetBuilder(
      BuildContext context, dynamic item, Map<String, dynamic> data) {
    ScopeManager? parentScope = DataScopeWidget.getScope(context);
    final childScope = parentScope?.createChildScope();
    childScope?.dataContext.addDataContext(data);
    return childScope?.buildWidgetWithScopeFromDefinition(item);
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
    if (cell.widget != null) {
      customWidget = widgetBuilder(context, cell.widget, data);
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

class _CalendarHeader extends StatelessWidget {
  final TextStyle? headerStyle;
  final DateTime focusedDay;
  final VoidCallback onLeftArrowTap;
  final VoidCallback onRightArrowTap;

  const _CalendarHeader({
    Key? key,
    required this.focusedDay,
    required this.onLeftArrowTap,
    required this.onRightArrowTap,
    this.headerStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final headerText = DateFormat.yMMM().format(focusedDay);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          const SizedBox(width: 16.0),
          Text(
            headerText,
            style: headerStyle ?? const TextStyle(fontSize: 26.0),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onLeftArrowTap,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onRightArrowTap,
          ),
        ],
      ),
    );
  }
}

class RowSpanTemplate extends ItemTemplate {
  RowSpanTemplate({
    required String data,
    required String name,
    dynamic template,
    required this.spanTemplate,
  }) : super(data, name, template);

  final SpanTemplate spanTemplate;
}

class SpanTemplate {
  final String start;
  final String end;
  final dynamic widget;
  final dynamic rowId;

  SpanTemplate(
      {required this.start, required this.end, this.widget, this.rowId});
}
