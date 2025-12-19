import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/page_model.dart';
import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

class CustomWidgetModel extends WidgetModel {
  CustomWidgetModel(this.widgetModel, String type, Map<String, dynamic> props,
      Map<String, dynamic> styles,
      {this.importedCode,
      this.parameters,
      this.inputs,
      this.actions,
      this.events,
      this.globalCode,
      this.globalCodeSpan,
      this.apiMap})
      : super(widgetModel.definition, type, {}, {}, styles, [], props);

  List<ParsedCode>? importedCode;
  WidgetModel widgetModel;
  List<String>? parameters;
  Map<String, dynamic>? inputs;
  Map<String, EnsembleEvent>? events;
  Map<String, EnsembleAction?>? actions;
  String? globalCode;
  SourceSpan? globalCodeSpan;
  Map<String, YamlMap>? apiMap;

  WidgetModel getModel() {
    return widgetModel;
  }

  CustomWidgetLifecycle getLifecycleActions() {
    return CustomWidgetLifecycle(onLoad: EnsembleAction.from(props['onLoad']));
  }
}

// custom widget's lifecycle
class CustomWidgetLifecycle {
  CustomWidgetLifecycle({this.onLoad});

  EnsembleAction? onLoad;
}
