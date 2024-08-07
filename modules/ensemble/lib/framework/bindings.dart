import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/data_utils.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble_ts_interpreter/parser/newjs_interpreter.dart';
import 'package:event_bus/event_bus.dart';

/// Binding source represents the binding expression
/// ${myText.text}
/// ${myAPI.body.result.status}
/// ${ensemble.storage.cart}
abstract class BindingSource {
  BindingSource(this.modelId, {this.property, this.type});

  String modelId;
  String? property; // property can be empty for custom widget inputs
  String? type; // an additional type to match regardless of modelId

  /// from a single expression e.g. ${callMe(var1, var2.text, ensemble.storage.var3)},
  /// return back the list of bindable sources i.e. va1, var2.text, ensemble.storage.var3
  static List<BindingSource> getBindingSources(
      String expression, DataContext dataContext) {
    List<BindingSource> sources = [];

    if (DataUtils.isExpression(expression)) {
      String? variable =
          DataUtils.onlyExpression.firstMatch(expression)?.group(1)?.trim();
      if (variable != null && variable.isNotEmpty) {
        List<String> bindings =
            Bindings().resolve(JSInterpreter.parseCode(variable));
        for (String binding in bindings) {
          BindingSource? source = _getBindingSource(binding, dataContext);
          if (source != null) {
            sources.add(source);
          }
        }
      }
    }
    return sources;
  }

  static BindingSource? _getBindingSource(
      String binding, DataContext dataContext) {
    RegExp variableNameRegex = RegExp('^[0-9a-z_]+', caseSensitive: false);

    // bindable storage
    String storageExpr = 'ensemble.storage.';
    String userExpr = 'ensemble.user.';
    if (binding.startsWith(storageExpr)) {
      RegExpMatch? match =
          variableNameRegex.firstMatch(binding.substring(storageExpr.length));
      if (match != null) {
        return StorageBindingSource(match.group(0)!);
      }
    } else if (binding.startsWith(userExpr)) {
      RegExpMatch? match =
          variableNameRegex.firstMatch(binding.substring(userExpr.length));
      if (match != null) {
        return SystemStorageBindingSource(match.group(0)!,
            storagePrefix: 'user');
      }
    } else {
      // store the suspected model id as we find it
      String modelId;
      int dotIndex = binding.indexOf('.');

      // no dot notation, so simple 'myVar' (e.g. custom widget's inputs)
      if (dotIndex == -1) {
        // modelId can be of syntax val[1], so strip out the array
        modelId = binding;
        modelId = Utils.stripEndingArrays(modelId);

        if (dataContext.getContextById(modelId) is Invokable) {
          return SimpleBindingSource(modelId);
        }
      }
      // syntax is ${model.property.*}
      else {
        // modelId can be of syntax val[1].myProperty, so also strip out the array if exists
        modelId = binding.substring(0, dotIndex);
        modelId = Utils.stripEndingArrays(modelId);

        dynamic model = dataContext.getContextById(modelId);
        if (model is APIResponse) {
          return APIBindingSource(modelId);
        } else if (model is Invokable) {
          // for now we only know how to bind to widget's direct property (e.g. myText.text)
          if (model is HasController) {
            // get the first property only
            String property = binding.substring(dotIndex + 1);
            int dotIndexInProperty = property.indexOf('.');
            if (dotIndexInProperty != -1) {
              property = property.substring(0, dotIndexInProperty);
            }
            return WidgetBindingSource(modelId, property: property);
          }
          // if not a widget, we are binding to a simple data (e.g. myInput.hotel).
          // That is we can bind to a Map or List. In this case, property doesn't
          // matter as we'll dispatch changes the moment the object changes
          else {
            return SimpleBindingSource(modelId);
          }
        }
      }

      /// we have a potential modelId but couldn't find a valid model. This can
      /// happen when Invokable are created after bindings.
      return DeferredBindingSource(modelId);
    }
    return null;
  }

  /// convert an expression ${..} into a BindingSource
  /// TODO: LEGACY - to be removed and use getBindableSources instead
  static BindingSource? from(String expression, DataContext dataContext) {
    if (DataUtils.isExpression(expression)) {
      // save the model id as we go along so we can resolve unknown model afterward
      String? unknownModelId;

      String variable = expression.substring(2, expression.length - 1).trim();
      RegExp variableNameRegex = RegExp('^[0-9a-z_]+', caseSensitive: false);

      // storage bindable
      String storageExpr = 'ensemble.storage.';
      String userExpr = 'ensemble.user.';
      if (variable.startsWith(storageExpr)) {
        RegExpMatch? match = variableNameRegex
            .firstMatch(variable.substring(storageExpr.length));
        if (match != null) {
          String storageKey = match.group(0)!;
          return StorageBindingSource(storageKey);
        }
      } else if (variable.startsWith(userExpr)) {
        RegExpMatch? match =
            variableNameRegex.firstMatch(variable.substring(userExpr.length));
        if (match != null) {
          return SystemStorageBindingSource(match.group(0)!,
              storagePrefix: 'user');
        }
      } else {
        // if syntax is ${model.property}
        int dotIndex = variable.indexOf('.');
        if (dotIndex != -1) {
          String modelId = variable.substring(0, dotIndex);

          // modelId can be of syntax val[1], so strip out the array
          modelId = Utils.stripEndingArrays(modelId);

          unknownModelId = modelId;
          String property = variable.substring(dotIndex + 1);

          // we don't know how to handle complex binding (e.g. myWidget.length > 0 ? "hi" : there"),
          // so for now just grab the property (i.e. .length > 0 ? "hi" : there) until we reach a space
          int spaceIndex = property.indexOf(" ");
          if (spaceIndex != -1) {
            property = property.substring(0, spaceIndex);
          }

          dynamic model = dataContext.getContextById(modelId);
          if (model is APIResponse) {
            return APIBindingSource(modelId);
          } else if (model is Invokable) {
            // for now we only know how to bind to widget's direct property (e.g. myText.text)
            if (model is HasController) {
              return WidgetBindingSource(modelId, property: property);
            }
            // if not a widget, we are binding to a simple data (e.g. myInput.hotel).
            // That is we can bind to a Map or List. In this case, property doesn't
            // matter as we'll dispatch changes the moment the object changes
            else {
              return SimpleBindingSource(modelId);
            }
          }
        }
        // else try to see if it's simply ${model} or ${model == 4....} e.g. custom widget's inputs
        else {
          // just try to find the first variable
          RegExpMatch? match = variableNameRegex.firstMatch(variable);
          if (match != null) {
            String firstVariable = match.group(0)!;
            unknownModelId = firstVariable;
            dynamic model = dataContext.getContextById(firstVariable);
            if (model is Invokable) {
              return SimpleBindingSource(firstVariable);
            }
          }
        }
      }
      // we have a binding expression but not able to look up the model
      // create a deferred binding source. This is when the Invokable are created after the binding.
      if (unknownModelId != null) {
        return DeferredBindingSource(unknownModelId);
      }
    }
    return null;
  }
}

/// a bindable source backed by Storage
class StorageBindingSource extends BindingSource {
  StorageBindingSource(super.modelId);
}

/// TODO: consolidate this with StorageBindingSource
class SystemStorageBindingSource extends BindingSource {
  SystemStorageBindingSource(super.modelId, {required this.storagePrefix});

  String storagePrefix;
}

/// bindable source backed by API
class APIBindingSource extends BindingSource {
  APIBindingSource(super.modelId);
}

/// simple binding (e.g. custom widget's input variable ${myVar} )
class SimpleBindingSource extends BindingSource {
  SimpleBindingSource(super.modelId);
}

// for source that are widgets (e.g. myText.value )
class WidgetBindingSource extends BindingSource {
  WidgetBindingSource(super.modelId, {super.property});
}

class DeferredBindingSource extends BindingSource {
  DeferredBindingSource(super.modelId);
}

/// Binding Destination represents the left predicate of a binding expression
/// myText.text: $(myTextInput.value)
/// myText.text: $(myAPI.body.result.status)
class BindingDestination {
  BindingDestination(this.widget, this.setterProperty);

  Invokable widget;
  String setterProperty;
}

/// dispatching changes for a BindingSource
class ModelChangeEvent {
  ModelChangeEvent(this.source, this.payload, {this.bindingScope});

  BindingSource source;
  dynamic payload;
  ScopeManager? bindingScope;

  @override
  String toString() {
    return "ModelChangeEvent(${source.modelId}, ${source.property}, scope: $bindingScope)";
  }
}

class AppEventBus {
  static final AppEventBus _instance = AppEventBus._internal();

  factory AppEventBus() {
    return _instance;
  }

  final EventBus? _eventBus;

  EventBus get eventBus => _eventBus!;

  AppEventBus._internal() : _eventBus = EventBus();
}

/// dispatching a theme change event
class ThemeChangeEvent {
  ThemeChangeEvent(this.theme);

  String theme;
}
