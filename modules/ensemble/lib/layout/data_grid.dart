import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/widget/has_children.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/model/item_template.dart';
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
  void initChildren({List<WidgetModel>? children, Map? itemTemplate}) {
    _controller.children = children;
    this.itemTemplate = ItemTemplate.from(itemTemplate);
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
      'sorting': (val) => controller.sorting = Utils.getMap(val),
      'DataColumns': (List cols) {
        this.cols = cols;
      },
      'horizontalMargin': (val) =>
          controller.horizontalMargin = Utils.optionalDouble(val),
      'dataRowHeight': (val) =>
          controller.dataRowHeight = Utils.optionalDouble(val),
      'headingRowHeight': (val) =>
      controller.headingRowHeight = Utils.optionalDouble(val),
      'staticScrollbar': (val) =>
      controller.staticScrollbar = Utils.optionalBool(val),
      'thumbThickness': (val) =>
      controller.thumbThickness = Utils.optionalDouble(val),
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
      sortOrder: Utils.getString(context.eval(map['sortOrder']),
          fallback: 'ascending'),
      onSort: onSort,
    );
  }
}

class EnsembleDataRow extends StatefulWidget
    with UpdatableContainer, Invokable {
  static const type = 'DataRow';
  List<WidgetModel>? children;
  ItemTemplate? itemTemplate;
  bool visible = true;

  @override
  State<StatefulWidget> createState() => EnsembleDataRowState();

  @override
  void initChildren({List<WidgetModel>? children, Map? itemTemplate}) {
    this.children = children;
    this.itemTemplate = ItemTemplate.from(itemTemplate);
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
  List<WidgetModel>? children;
  Map<String, dynamic>? sorting;
  double? horizontalMargin;
  GenericTextController? headingTextController;
  double? dataRowHeight;
  double? headingRowHeight;
  bool? staticScrollbar;
  double? columnSpacing;
  double? thumbThickness;
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
  int columnIndex;
  String? order;

  DataColumnSort({
    required this.columnIndex,
    this.order,
  });
}

class DataGridState extends EWidgetState<DataGrid>
    with TemplatedWidgetState, HasChildren<DataGrid> {
  List<Widget>? templatedChildren;
  List<EnsembleDataColumn> _columns = [];
  List<dynamic> dataList = [];
  DataColumnSort? dataColumnSort;

  final List<DataRow> _rows = [];
  final List<Widget> _children = [];

  @override
  void initState() {
    widget._controller.addListener(refreshState);
    _setInitialDataColumn();
    super.initState();
  }

  void refreshState() {
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (widget.itemTemplate != null) {
      // initial value
      if (widget.itemTemplate!.initialValue != null) {
        templatedChildren = buildWidgetsFromTemplate(
            context, widget.itemTemplate!.initialValue!, widget.itemTemplate!);
      }
      // listen for changes
      registerItemTemplate(context, widget.itemTemplate!,
          onDataChanged: (List dataList) {
            this.dataList = dataList;
            _sortItems();
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
    final ScrollController _scrollController = ScrollController();
    if (scopeManager == null) {
      throw Exception(
          'scopeManager is null in the DataGrid.buildWidget method. This is unexpected. DataGrid.id=${widget.id}');
    }

    _buildDataColumn(scopeManager);
    _buildChildren();
    _buildDataRow();

    // Setting sort column index and order
    final sortOrder =
        dataColumnSort?.order ?? DataColumnSortType.ascending.name;
    int? sortColIndex;
    if (dataColumnSort?.columnIndex != null) {
      if (dataColumnSort!.columnIndex >= _columns.length) {
        throw LanguageError(
            'Provide a valid data columnIndex. columnIndex is should be less than the data columns length');
      }
      final sortable = _columns[dataColumnSort!.columnIndex].sortable ?? false;
      sortColIndex = sortable ? dataColumnSort?.columnIndex : null;
    }

    DataTable grid = DataTable(
      sortColumnIndex: sortColIndex,
      sortAscending: sortOrder == DataColumnSortType.ascending.name,
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

      child: RawScrollbar(
        thickness: widget.controller.thumbThickness,
        controller: _scrollController,
        thumbVisibility: widget.controller.staticScrollbar, // Ensure the scrollbar thumb is always visible
        trackVisibility: widget.controller.staticScrollbar,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          controller: _scrollController,
          child: RequiresChildWithIntrinsicDimension(child: grid),
        ),
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
    if (_columns.isEmpty) {
      _columns = List<EnsembleDataColumn>.generate(
        widget.cols.length,
        (index) {
          return EnsembleDataColumn.fromYaml(
            map: widget.cols[index] as Map,
            context: scopeManager.dataContext,
            onSort: (index, _) {
              _toggleSortColumn(index);
            },
          );
        },
      );
    }
  }

  void _buildDataRow() {
    _rows.clear();
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
        buildChildren(child.children!,
                // scope comes from the rowScope (item-template) or the widget scope (children)
                preferredScopeManager: rowScope?.scopeManager ?? scopeManager)
            .asMap()
            .forEach((index, Widget c) {
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

  void _setInitialDataColumn() {
    final sorting = widget._controller.sorting;

    if (sorting != null) {
      final colIndex = Utils.optionalInt(sorting['columnIndex']);
      if (colIndex == null) {
        throw LanguageError(
            'Add a columnIndex to the sorting. It is a mandatory property for sorting a data grid');
      } else {
        dataColumnSort = DataColumnSort(
          columnIndex: colIndex,
          order: Utils.getString(sorting['order'], fallback: 'ascending'),
        );
      }
    }
  }

  void _buildChildren() {
    _children.clear();
    if (widget._controller.children != null) {
      _children.addAll(buildChildren(widget._controller.children!));
    }
    if (templatedChildren != null) {
      _children.addAll(templatedChildren!);
    }
  }

  // Sorting the datas array (ascending or descending)
  void _sortItems() {
    if (_columns.isNotEmpty &&
        dataColumnSort != null &&
        dataColumnSort?.columnIndex != null) {
      final sortOrder =
          dataColumnSort?.order ?? DataColumnSortType.ascending.name;
      _columns[dataColumnSort!.columnIndex].sortOrder = sortOrder;
      final EnsembleDataColumn sortItem = _columns[dataColumnSort!.columnIndex];
      final bool? sortable = sortItem.sortable;
      final String? sortKey = sortItem.sortKey;

      if (sortable != null && sortable) {
        bool isAscendingOrder = sortOrder == DataColumnSortType.ascending.name;
        dataList = Utils.sortMapObjectsByKey(dataList, sortKey,
            isAscendingOrder: isAscendingOrder);
      }
    }

    templatedChildren =
        buildWidgetsFromTemplate(context, dataList, widget.itemTemplate!);
    setState(() {});
  }

  // Change ascending to descending and vice versa in dataColumnSort object
  void _toggleSortColumn(int index) {
    final sortOrder =
        _columns[index].sortOrder ?? DataColumnSortType.ascending.name;
    final sortable = _columns[index].sortable;
    final String? sortKey = _columns[index].sortKey;
    if (sortable == true && sortKey != null) {
      _columns[index].sortOrder = sortOrder == DataColumnSortType.ascending.name
          ? DataColumnSortType.descending.name
          : DataColumnSortType.ascending.name;
      dataColumnSort = DataColumnSort(
        columnIndex: index,
        order: _columns[index].sortOrder,
      );

      _sortItems();
    }
  }

  void _onItemTap(int index) {
    if (widget.controller.onItemTap != null) {
      widget._controller.selectedItemIndex = index;
      ScreenController().executeAction(context, widget._controller.onItemTap!);
    }
  }
}
