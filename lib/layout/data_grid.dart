import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/context.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/layout_utils.dart';
import 'package:ensemble/widget/widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:yaml/yaml.dart';
import 'package:flutter/material.dart';
//8e26249e-c08c-4b3e-8584-cc83a5c9bc29
class DataGrid extends StatefulWidget with UpdatableContainer, Invokable, HasController<DataGridController,DataGridState> {
  static const type = 'DataGrid';
  DataGrid({Key? key}) : super(key: key);

  late final List<Widget>? children;
  late final ItemTemplate? itemTemplate;
  late List<EnsembleDataColumn> cols;
  late List<EnsembleDataRow> rows;

  final DataGridController _controller = DataGridController();
  @override
  DataGridController get controller => _controller;
  @override
  State<StatefulWidget> createState() => DataGridState();

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  void initChildren({List<Widget>? children, ItemTemplate? itemTemplate}) {
    this.children = children;
    this.itemTemplate = itemTemplate;
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'DataColumns': (List cols) {
        this.cols = List<EnsembleDataColumn>.generate(cols.length,
                (index) => EnsembleDataColumn.fromYaml(map:cols[index] as YamlMap)
        );
      },
      'DataRows': (List rows) {
        this.rows = List<EnsembleDataRow>.generate(rows.length,
                (index) => EnsembleDataRow.fromYaml(map: rows[index] as YamlMap)
        );
      }
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
class EnsembleDataRow {
  final YamlMap map;
  const EnsembleDataRow(this.map);
  static EnsembleDataRow fromYaml({required YamlMap map}) {
    return EnsembleDataRow(map);
  }
}

class DataGridController extends Controller {

}

class DataGridState extends WidgetState<DataGrid> {
  @override
  Widget build(BuildContext context) {

    /*List<DataCell> cells = List<DataCell>.generate(widget.rows.length,
            (index) =>
    );

     */
    return DataTable(columns:widget.cols,rows:const []);
  }

}

