import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/util/gesture_detector.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/widget_util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble/framework/view/page.dart';

enum DataColumnSortType { ascending, descending }

//8e26249e-c08c-4b3e-8584-cc83a5c9bc29
class DataGrid extends StatefulWidget
    with
        UpdatableContainer,
        Invokable,
        HasController<DataGridController, DataGridState> {
  static const type = 'DataGrid';
  DataGrid({Key? key}) : super(key: key);
  late final ItemTemplate? itemTemplate;
  late List cols;

  final DataGridController _controller = DataGridController();
  @override
  DataGridController get controller => _controller;
  @override
  State<StatefulWidget> createState() => DataGridState();

  @override
  Map<String, Function> getters() {
    return {
      'selectedItemIndex': () => _controller.selectedItemIndex,
    };
  }

  @override
  void initChildren({List<Widget>? children, ItemTemplate? itemTemplate}) {
    _controller.children = children;
    this.itemTemplate = itemTemplate;
  }

  @override
  Map<String, Function> methods() {
    return {
      'removeRow': (int index) {
        if (_controller.children == null ||
            index >= _controller.children!.length) {
          throw Exception(
              "children array is null or has smalller length and removeRow is being called");
        }
        _controller.children!.removeAt(index);
        _controller
            .dispatchChanges(KeyValue('children', _controller.children!));
      }
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'DataColumns': (List cols) {
        this.cols = cols;
      },
      'horizontalMargin': (val) =>
          controller.horizontalMargin = Utils.optionalDouble(val),
      'dataRowHeight': (val) =>
          controller.dataRowHeight = Utils.optionalDouble(val),
      'headingRowHeight': (val) =>
          controller.headingRowHeight = Utils.optionalDouble(val),
      'columnSpacing': (val) =>
          controller.columnSpacing = Utils.optionalDouble(val),
      'dividerThickness': (val) =>
          controller.dividerThickness = Utils.optionalDouble(val),
    };
  }
}

class EnsembleDataColumn extends DataColumn {
  final String type;
  EnsembleDataColumn({
    required String label,
    required this.type,
    this.sortable,
    this.sortKey,
    this.sortOrder,
    String? tooltip,
    dynamic onSort,
  }) : super(
          label: Text(label),
          tooltip: tooltip,
          numeric: type == 'numeric',
          onSort: onSort,
        );

  bool? sortable;
  String? sortKey;
  String? sortOrder;

  static EnsembleDataColumn fromYaml({
    required Map map,
    required DataContext context,
    Function(int, bool)? onSort,
  }) {
    String type = Utils.getString(map['type'], fallback: '');
    if (type == '') {
      throw Exception('DataGrid column must have a type.');
    }

    return EnsembleDataColumn(
      label: Utils.getString(context.eval(map['label']), fallback: ''),
      type: type,
      tooltip: Utils.optionalString(context.eval(map['tooltip'])),
      sortable: Utils.optionalBool(context.eval(map['sortable'])),
      sortKey: Utils.optionalString(context.eval(map['sortKey'])),
      sortOrder: Utils.optionalString(context.eval(map['sortOrder'])),
      onSort: onSort,
    );
  }
}

class EnsembleDataRow extends StatefulWidget
    with UpdatableContainer, Invokable {
  static const type = 'DataRow';
  List<Widget>? children;
  ItemTemplate? itemTemplate;
  bool visible = true;

  @override
  State<StatefulWidget> createState() => EnsembleDataRowState();

  @override
  void initChildren({List<Widget>? children, ItemTemplate? itemTemplate}) {
    this.children = children;
    this.itemTemplate = itemTemplate;
  }

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'visible': (dynamic v) => visible = Utils.getBool(v, fallback: visible)
    };
  }
}

class EnsembleDataRowState extends State<EnsembleDataRow> {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    throw UnimplementedError();
  }
}

class DataGridController extends BoxController {
  List<Widget>? children;
  double? horizontalMargin;
  GenericTextController? headingTextController;
  double? dataRowHeight;
  double? headingRowHeight;
  double? columnSpacing;
  GenericTextController? dataTextController;
  double? dividerThickness;
  TableBorder border = const TableBorder();
  EnsembleAction? onItemTap;
  int selectedItemIndex = -1;

  @override
  Map<String, Function> getBaseSetters() {
    Map<String, Function> setters = super.getBaseSetters();
    setters.addAll({
      'headingText': (Map styles) {
        headingTextController = GenericTextController();
        TextUtils.setStyles(styles, headingTextController!);
      },
      'dataText': (Map styles) {
        dataTextController = GenericTextController();
        TextUtils.setStyles(styles, dataTextController!);
      },
    });
    return setters;
  }
}

class DataColumnSort {
  int? columnIndex;
  String? order;

  DataColumnSort({
    required this.columnIndex,
    required this.order,
  });

  static DataColumnSort fromYaml(
      {required Map<String, dynamic>? map, required DataContext context}) {
    return DataColumnSort(
      columnIndex: Utils.optionalInt(context.eval(map?['columnIndex'])),
      order: Utils.getString(context.eval(map?['sortOrder']),
          fallback: 'ascending'),
    );
  }
}

class DataGridState extends WidgetState<DataGrid> with TemplatedWidgetState {
  List<Widget>? templatedChildren;
  List<EnsembleDataColumn> _columns = [];
  List<dynamic> dataList = [];
  DataColumnSort? dataColumnSort;

  final List<DataRow> _rows = [];
  final List<Widget> _children = [];

  @override
  void initState() {
    widget._controller.addListener(refreshState);
    super.initState();
  }

  void refreshState() {
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (widget.itemTemplate != null) {
      final initValue = widget.itemTemplate!.initialValue;
      print('Initial Value: $initValue');
      // initial value
      if (widget.itemTemplate!.initialValue != null) {
        templatedChildren = buildWidgetsFromTemplate(
            context, widget.itemTemplate!.initialValue!, widget.itemTemplate!);
      }
      // listen for changes
      registerItemTemplate(context, widget.itemTemplate!,
          onDataChanged: (List dataList) {
        this.dataList = dataList;
        _arrangeItems();
        templatedChildren =
            buildWidgetsFromTemplate(context, dataList, widget.itemTemplate!);
      });
    }
  }

  @override
  void dispose() {
    templatedChildren = null;
    widget._controller.removeListener(refreshState);
    super.dispose();
  }

  @override
  Widget buildWidget(BuildContext context) {
    ScopeManager? scopeManager = DataScopeWidget.getScope(context);
    if (scopeManager == null) {
      throw Exception(
          'scopeManager is null in the DataGrid.buildWidget method. This is unexpected. DataGrid.id=${widget.id}');
    }
    _buildDataColumn(scopeManager);
    _buildChildren();
    _buildDataRow();

    DataTable grid = DataTable(
      sortColumnIndex: dataColumnSort?.columnIndex,
      sortAscending: dataColumnSort?.order == DataColumnSortType.ascending.name,
      columns: _columns,
      rows: _rows,
      horizontalMargin: widget.controller.horizontalMargin,
      headingTextStyle: _buildHeadingStyle(),
      dataRowHeight: widget.controller.dataRowHeight,
      headingRowHeight: widget.controller.headingRowHeight,
      dataTextStyle: _buildDataStyle(),
      columnSpacing: widget.controller.columnSpacing,
      dividerThickness: widget.controller.dividerThickness,
      border: TableBorder.all(
        color: widget.controller.borderColor ?? Colors.black,
        width: widget.controller.borderWidth?.toDouble() ?? 1.0,
        borderRadius:
            widget.controller.borderRadius?.getValue() ?? BorderRadius.zero,
      ),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,

        // DataTable requires all children to report their intrinsic height.
        // Some widgets don't like that so we expose this so the widgets
        // can react accordingly
        child: RequiresChildWithIntrinsicDimension(child: grid),
      ),
    );
  }

  TextStyle? _buildHeadingStyle() {
    TextStyle? headingTextStyle;
    if (widget.controller.headingTextController != null) {
      Text headingText =
          TextUtils.buildText(widget.controller.headingTextController!);
      headingTextStyle = headingText.style;
    }
    return headingTextStyle;
  }

  TextStyle? _buildDataStyle() {
    TextStyle? dataTextStyle;
    if (widget.controller.dataTextController != null) {
      Text dataText =
          TextUtils.buildText(widget.controller.dataTextController!);
      dataTextStyle = dataText.style;
    }
    return dataTextStyle;
  }

  void _buildDataColumn(ScopeManager scopeManager) {
    _columns = List<EnsembleDataColumn>.generate(widget.cols.length, (index) {
      // final mapData = widget.cols[index] as Map;
      // final sortAction =
      //     EnsembleAction.fromYaml(mapData['onSort'], initiator: widget);

      // final validSort = sortAction != null && itemExists;

      return EnsembleDataColumn.fromYaml(
        map: widget.cols[index] as Map,
        context: scopeManager.dataContext,
        onSort: (index, _) {
          _sortColumn(index);
        },
      );
    }
        // (index) => EnsembleDataColumn.fromYaml(
        //     map: widget.cols[index] as Map, context: scopeManager.dataContext),
        );
  }

  void _buildDataRow() {
    for (Widget w in _children) {
      DataScopeWidget? rowScope;

      if (w is DataScopeWidget) {
        rowScope = w;
        w = w.child;
      }
      if (w is! EnsembleDataRow) {
        throw Exception("Direct children of DataGrid must be of type DataRow");
      }
      EnsembleDataRow child = w;
      if (!child.visible) {
        continue;
      }
      List<DataCell> cells = [];
      if (child.children != null) {
        child.children!.asMap().forEach((index, Widget c) {
          // for templated row only, wrap each cell widget in a DataScopeWidget, and simply use the row's datascope
          if (rowScope != null) {
            Widget scopeWidget =
                DataScopeWidget(scopeManager: rowScope.scopeManager, child: c);

            cells.add(
              DataCell(EnsembleGestureDetector(
                child: scopeWidget,
                onTap: () => _onItemTap(index),
              )),
            );
          } else {
            cells.add(
              DataCell(EnsembleGestureDetector(
                child: c,
                onTap: () => _onItemTap(index),
              )),
            );
          }
        });
      }
      if (_columns.length != cells.length) {
        if (kDebugMode) {
          print(
              'Number of DataGrid columns must be equal to the number of cells in each row. Number of DataGrid columns is ${_columns.length} '
              'while number of cells in the row is ${cells.length}. We will try to match them to be the same');
        }
        if (_columns.length > cells.length) {
          int diff = _columns.length - cells.length;
          //more cols than cells, need to fill up cells with empty text
          for (int i = 0; i < diff; i++) {
            cells.add(const DataCell(Text('')));
          }
        } else {
          int diff = cells.length - _columns.length;
          for (int i = 0; i < diff; i++) {
            cells.removeLast();
          }
        }
      }
      _rows.add(DataRow(cells: cells));
    }
  }

  void _buildChildren() {
    if (widget._controller.children != null) {
      _children.addAll(widget._controller.children!);
    }
    if (templatedChildren != null) {
      _children.addAll(templatedChildren!);
    }
  }

  void _arrangeItems() {
    print('ArrangeItems Called');
    List<List<Map<dynamic, dynamic>>> datas = [];
    _columns.asMap().forEach((index, col) {
      List<Map<String, dynamic>> dataToSaveMap = [];
      final isSortable = col.sortable != null && col.sortable!;
      if (isSortable && col.sortKey != null) {
        for (final map in dataList) {
          if (map.containsKey(col.sortKey)) {
            dataToSaveMap.add({col.sortKey!: map[col.sortKey]});
          }
        }
      }
      datas.add(dataToSaveMap);
    });
    _sortItems(dataList, datas);
  }

  void _sortItems(List dataList, List<List<Map<dynamic, dynamic>>> datas) {
    _columns.asMap().forEach((index, col) {
      if (col.sortKey != null) {
        final String sortKey = col.sortKey!;
        bool isAscendingOrder =
            col.sortOrder != null && col.sortOrder == 'ascending';

        dataColumnSort = DataColumnSort(
          columnIndex: index,
          order: col.sortOrder,
        );

        if (isAscendingOrder) {
          datas[index].sort((a, b) => (a[sortKey]).compareTo(b[sortKey]));
        } else {
          datas[index].sort((a, b) => (b[sortKey]).compareTo(a[sortKey]));
        }
      }
    });

    datas.asMap().forEach((dataIndex, value) {
      value.asMap().forEach((valueIndex, element) {
        final sortKey = _columns[dataIndex].sortKey;
        if (sortKey != null) {
          dataList[valueIndex][sortKey] = element[sortKey];
        }
      });
    });

    setState(() {});
  }

  void _sortColumn(int index) {
    final sortOrder = _columns[index].sortOrder;
    if (sortOrder != null) {
      _columns[index].sortOrder = sortOrder == DataColumnSortType.ascending.name
          ? DataColumnSortType.descending.name
          : DataColumnSortType.ascending.name;
      _arrangeItems();
    }
  }

  void _onItemTap(int index) {
    if (widget.controller.onItemTap != null) {
      widget._controller.selectedItemIndex = index;
      ScreenController().executeAction(context, widget._controller.onItemTap!);
    }
  }
}
