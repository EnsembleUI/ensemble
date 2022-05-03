

import 'package:ensemble/error_handling.dart';
import 'package:ensemble/page_model.dart';
import 'package:yaml/yaml.dart';

class ViewUtil {

  ///convert a YAML representing a widget to a WidgetModel
  static WidgetModel buildModel(dynamic item, Map<String, YamlMap>? customWidgetMap) {
    String? widgetType;
    YamlMap? payload;

    bool isCustomWidget = false;
    Map<String, dynamic>? customWidgetInputs;
    List<String>? customWidgetParameters;

    // name only e.g Spacer
    if (item is String) {
      widgetType = item;
    } else if (item is YamlMap) {
      widgetType = item.keys.first.toString();
      if (item[widgetType] is YamlMap) {
        payload = item[widgetType];
      }
    }

    // if this is a custom widget
    if (customWidgetMap != null && customWidgetMap[widgetType] != null) {
      isCustomWidget = true;
      // payload if exists here is a key/value pairs
      if (payload != null) {
        customWidgetInputs = {};
        payload.forEach((key, value) {
          customWidgetInputs![key] = value;
        });
      }

      // overwrite the payload & widgetType since custom widget defines their definition separately
      payload = customWidgetMap[widgetType];
      widgetType = payload!['type'];

      // see if the definition declare any parameters
      if (payload['parameters'] is YamlList) {
        customWidgetParameters = [];
        for (dynamic param in payload['parameters']) {
          customWidgetParameters.add(param.toString());
        }
      }

    }

    if (widgetType == null) {
      throw LanguageError('Invalid widget definition.', recovery: 'Widget type is required');
    }

    // Let's build the model now
    // no payload, simple widget e.g Spacer or Spacer:
    if (payload == null) {
      return WidgetModel(widgetType, {}, {});
    }

    List<WidgetModel>? children;
    ItemTemplate? itemTemplate;
    Map<String, dynamic> props = {};
    Map<String, dynamic> styles = {};

    payload.forEach((key, value) {
      if (value != null) {
        if (key == 'styles' && value is YamlMap) {
          value.forEach((styleKey, styleValue) {
            styles[styleKey] = styleValue;
          });
        } else if (key == 'children' && value is YamlList) {
          children = ViewUtil.buildModels(value, customWidgetMap);
        } else if (key == "item-template" && value is YamlMap) {
          itemTemplate = ItemTemplate(
              value['data'],
              value['name'],
              value['template']);
        } else {
          props[key] = value;
        }
      }
    });

    if (isCustomWidget) {
      return CustomWidgetModel(
          widgetType,
          styles,
          props,
          children: children,
          itemTemplate: itemTemplate,
          parameters: customWidgetParameters,
          inputs: customWidgetInputs);

    } else {
      return WidgetModel(
          widgetType,
          styles,
          props,
          children: children,
          itemTemplate: itemTemplate);
    }
  }

  static List<WidgetModel> buildModels(YamlList items, Map<String, YamlMap>? customWidgetMap) {
    List<WidgetModel> rtn = [];
    for (dynamic item in items) {
      rtn.add(buildModel(item, customWidgetMap));
    }
    return rtn;
  }


}