import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/widget_util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble/framework/widget/view.dart';
//8e26249e-c08c-4b3e-8584-cc83a5c9bc29
class DataGrid extends StatefulWidget with UpdatableContainer, Invokable, HasController<DataGridController,DataGridState> {
  static const type = 'DataGrid';
  DataGrid({Key? key}) : super(key: key);
  late final ItemTemplate? itemTemplate;
  late List<EnsembleDataColumn> cols;

  final DataGridController _controller = DataGridController();
  @override
  DataGridController get controller => _controller;
  @override
  State<StatefulWidget> createState() => DataGridState(controller);

  @override
  Map<String, Function> getters() {
    return {};
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
        if ( _controller.children == null || index >= _controller.children!.length ) {
          throw Exception("children array is null or has smalller length and removeRow is being called");
        }
        _controller.children!.removeAt(index);
        _controller.dispatchChanges(KeyValue('children',_controller.children!));
      }
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'DataColumns': (List cols) {
        this.cols = List<EnsembleDataColumn>.generate(cols.length,
                (index) => EnsembleDataColumn.fromYaml(map:cols[index] as Map)
        );
      },
      'headingTextStyle': (Map styles) {
        controller.headingTextController = TextController();
        TextUtils.setStyles(styles, controller.headingTextController!);
      },
      'dataTextStyle': (Map styles) {
        controller.dataTextController = TextController();
        TextUtils.setStyles(styles, controller.dataTextController!);
      },
      'horizontalMargin': (val)=> controller.horizontalMargin = Utils.optionalDouble(val),
      'dataRowHeight': (val) => controller.dataRowHeight = Utils.optionalDouble(val),
      'headingRowHeight': (val) => controller.headingRowHeight = Utils.optionalDouble(val),
      'columnSpacing': (val) => controller.columnSpacing = Utils.optionalDouble(val),
      'dividerThickness': (val) => controller.dividerThickness = Utils.optionalDouble(val),
      'border': (Map val) {
        Map<String,dynamic> map = {};
        val.forEach((key, value) {
          if ( value is Map ) {
            Color color = Utils.getColor(value['color'])??Colors.black;
            double width = Utils.getDouble(value['width'],fallback: 1.0);
            map[key] = BorderSide(
                color: color,
                width: width
            );
          } else if ( key == 'borderRadius' ) {
            double? radius = Utils.optionalDouble(value);
            map[key] = (radius == null)?BorderRadius.zero:BorderRadius.circular(radius);
          }
        });
        controller.border = TableBorder(
          top: map['top']??BorderSide.none,
          right: map['right']??BorderSide.none,
          bottom: map['bottom']??BorderSide.none,
          left: map['left']??BorderSide.none,
          horizontalInside: map['horizontalInside']??BorderSide.none,
          verticalInside: map['verticalInside']??BorderSide.none,
          borderRadius: map['borderRadius']??BorderRadius.zero
        );
      },
    };
  }
}
class EnsembleDataColumn extends DataColumn {
  final String type;
  EnsembleDataColumn({required String label,required this.type,String? tooltip,Function? onSort}) :
        super(label:Text(label),tooltip:tooltip,numeric:type == 'numeric');

  static EnsembleDataColumn fromYaml({required Map map,Function? onSort}) {
    String type = Utils.getString(map['type'], fallback: '');
    if ( type == '' ) {
      throw Exception('DataGrid column must have a type.');
    }
    return EnsembleDataColumn(
      label: Utils.getString(map['label'], fallback: ''),
      type: type,
      tooltip: Utils.optionalString(map['tooltip']),
      onSort:onSort
    );

  }
}
class EnsembleDataRow extends StatefulWidget with UpdatableContainer{
  static const type = 'DataRow';
  List<Widget>? children;
  ItemTemplate? itemTemplate;

  @override
  State<StatefulWidget> createState() => EnsembleDataRowState();

  @override
  void initChildren({List<Widget>? children, ItemTemplate? itemTemplate}) {
    this.children = children;
    this.itemTemplate = itemTemplate;
  }
}
class EnsembleDataRowState extends State<EnsembleDataRow> {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    throw UnimplementedError();
  }
  
}

class DataGridController extends WidgetController {
  List<Widget>? children;
  double? horizontalMargin;
  TextController? headingTextController;
  double? dataRowHeight;
  double? headingRowHeight;
  double? columnSpacing;
  TextController? dataTextController;
  double? dividerThickness;
  TableBorder border = const TableBorder();
}

class DataGridState extends WidgetState<DataGrid> with TemplatedWidgetState {
  DataGridController controller;
  DataGridState(this.controller);
  List<Widget>? templatedChildren;
  @override
  void initState() {
    controller.addListener(refreshState);
    super.initState();
  }
  void refreshState() {
    setState(() {

    });
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (widget.itemTemplate != null) {
      // initial value
      if (widget.itemTemplate!.initialValue != null) {
        templatedChildren = buildWidgetsFromTemplate(context, widget.itemTemplate!.initialValue!, widget.itemTemplate!);
      }
      // listen for changes
      registerItemTemplate(context, widget.itemTemplate!, onDataChanged: (List dataList) {
        setState(() {
          templatedChildren = buildWidgetsFromTemplate(context, dataList, widget.itemTemplate!);
        });
      });
    }
  }
  @override
  void dispose() {
    templatedChildren = null;
    controller.removeListener(refreshState);
    super.dispose();

  }
  @override
  Widget build(BuildContext context) {
    if (!widget._controller.visible) {
      return const SizedBox.shrink();
    }

    List<Widget> children = [];
    if (controller.children != null) {
      children.addAll(controller.children!);
    }
    if (templatedChildren != null) {
      children.addAll(templatedChildren!);
    }
    List<DataRow> rows = [];
    for ( Widget w in children ) {
      DataScopeWidget? rowScope;

      if ( w is DataScopeWidget ) {
        rowScope = w;
        w = w.child;
      }
      if ( w is! EnsembleDataRow ) {
        throw Exception("Direct children of DataGrid must be of type DataRow");
      }
      EnsembleDataRow child = w;
      List<DataCell> cells = [];
      if ( child.children != null ) {
        for ( Widget c in child.children! ) {
          // for templated row only, wrap each cell widget in a DataScopeWidget, and simply use the row's datascope
          if (rowScope != null) {
            Widget scopeWidget = DataScopeWidget(
                scopeManager: rowScope.scopeManager,
                child: c);

            cells.add(DataCell(scopeWidget));
          } else {
            cells.add(DataCell(c));
          }
        }
      }
      if ( widget.cols.length != cells.length ) {
        if (kDebugMode) {
          print('Number of DataGrid columns must be equal to the number of cells in each row. Number of DataGrid columns is ${widget.cols.length} '
              'while number of cells in the row is ${cells.length}. We will try to match them to be the same');
        }
        if ( widget.cols.length > cells.length ) {
          int diff = widget.cols.length - cells.length;
          //more cols than cells, need to fill up cells with empty text
          for ( int i=0;i<diff;i++ ) {
            cells.add(const DataCell(Text('')));
          }
        } else {
          int diff = cells.length - widget.cols.length;
          for ( int i=0;i<diff;i++ ) {
            cells.removeLast();
          }
        }
      }
      rows.add(DataRow(cells:cells));
    }
    TextStyle? headingTextStyle;
    if ( widget.controller.headingTextController != null ) {
      Text headingText = TextUtils.buildText(
          widget.controller.headingTextController!);
      headingTextStyle = headingText.style;
    }
    TextStyle? dataTextStyle;
    if ( widget.controller.dataTextController != null ) {
      Text dataText = TextUtils.buildText(
          widget.controller.dataTextController!);
      dataTextStyle = dataText.style;
    }

    DataTable grid = DataTable(columns: widget.cols,
      rows: rows,
      horizontalMargin: widget.controller.horizontalMargin,
      headingTextStyle: headingTextStyle,
      dataRowHeight: widget.controller.dataRowHeight,
      headingRowHeight: widget.controller.headingRowHeight,
      dataTextStyle: dataTextStyle,
      columnSpacing: widget.controller.columnSpacing,
      dividerThickness: widget.controller.dividerThickness,
      border: widget.controller.border,
    );
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: grid
      )
    );
  }

}



