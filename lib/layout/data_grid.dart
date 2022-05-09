import 'package:ensemble/framework/templated.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:yaml/yaml.dart';
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
                (index) => EnsembleDataColumn.fromYaml(map:cols[index] as YamlMap)
        );
      },
    };
  }
}
class EnsembleDataColumn extends DataColumn {
  final String type;
  EnsembleDataColumn({required String label,required this.type,String? tooltip,Function? onSort}) :
        super(label:Text(label),tooltip:tooltip,numeric:type == 'numeric');

  static EnsembleDataColumn fromYaml({required YamlMap map,Function? onSort}) {
    return EnsembleDataColumn(
      label:map['label'],
      type:map['type'],
      tooltip:map['tooltip'],
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

class DataGridController extends Controller {
  List<Widget>? children;

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
        templatedChildren = buildItemsFromTemplate(context, widget.itemTemplate!.initialValue!, widget.itemTemplate!);
      }
      // listen for changes
      registerItemTemplate(context, widget.itemTemplate!, onDataChanged: (List dataList) {
        setState(() {
          templatedChildren = buildItemsFromTemplate(context, dataList, widget.itemTemplate!);
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
    List<Widget> children = [];
    if (controller.children != null) {
      children.addAll(controller.children!);
    }
    if (templatedChildren != null) {
      children.addAll(templatedChildren!);
    }
    List<DataRow> rows = [];
    for ( Widget w in children ) {
      if ( w is DataScopeWidget ) {
        w = w.child;
      }
      if ( w is! EnsembleDataRow ) {
        throw Exception("Direct children of DataGrid must be of type DataRow");
      }
      EnsembleDataRow child = w;
      List<DataCell> cells = [];
      if ( child.children != null ) {
        for ( Widget c in child.children! ) {
          cells.add(DataCell(c));
        }
      }
      rows.add(DataRow(cells:cells));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(columns:widget.cols,rows:rows)
      ),
    );
  }

}



