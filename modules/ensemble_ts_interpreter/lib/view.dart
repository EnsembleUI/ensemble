
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:ensemble_ts_interpreter/invokables/invokabletext.dart';
import 'package:ensemble_ts_interpreter/invokables/invokabletextformfield.dart';
import 'package:yaml/yaml.dart';

class View {
  static const String PROPERTIES = "properties";
  String title;
  List<WidgetView> items;
  Map<String,WidgetView> idWidgetMap;
  View(this.title,this.items,this.idWidgetMap);
  static View from(YamlMap map) {
    String title = map['title'];
    var list = map['items'];
    List<WidgetView> items = [];
    Map<String,WidgetView> idWidgetMap = HashMap<String,WidgetView>();
    if ( list != null ) {
      for ( final YamlMap item in list ) {
        //a. *Where are you going : Auto-complete
        item.forEach((k,v) {
          var arr = k.split('.');
          String id = arr[0];
          String label = arr[1];
          WidgetView? wv = WidgetViewFactory.getWidgetView(v, id, label, null);
          if ( wv != null ) {
            items.add(wv);
            idWidgetMap[id] = wv;
          }
        });
      }
    }
    return View(title,items,idWidgetMap);
  }
  WidgetView? get(String id) {
    if ( idWidgetMap.containsKey(id) ) {
      return idWidgetMap[id];
    }
    return null;
  }
  WidgetView requireValue(String id) {
    if ( idWidgetMap.containsKey(id) ) {
      return idWidgetMap[id]!;
    }
    throw Exception(id+' is not present in the map');
  }
}
class WidgetViewFactory {
  static WidgetView? getWidgetView(String name,String key,String label, Map? properties) {
    WidgetView? rtn;
    if ( name == 'TextInput' ) {
      /*TextFormField widget = TextFormField(
        key: Key(key),
        controller: TextEditingController(),
        decoration: InputDecoration(labelText:label,hintText:label),
      );
      */
      TextFormField widget = InvokableTextFormField(
        key: Key(key),
        controller: TextEditingController(),
        decoration: InputDecoration(labelText:label,hintText:label),
      );
      rtn = WidgetView(widget, properties);
    } else if ( name == 'Button' ) {
      rtn = WidgetView(
          TextButton(
            key: Key(key),
            onPressed: () { },
            child: Text(label)
          ),properties
      );
    } else if ( name == 'Text' ) {
      rtn = WidgetView(
          InvokableText(
            TextController(label),
            key: Key(key)
          ),properties
       );
    }
    return rtn;
  }
}
class WidgetView {
  Widget widget;
  final Map? properties;
  WidgetView(this.widget,this.properties);
}