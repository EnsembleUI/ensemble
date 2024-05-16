import 'package:ensemble_ts_interpreter/view.dart';
import 'package:flutter/widgets.dart' hide View;

class Layout {
  final Map map;
  final View view;
  Layout(this.map,this.view);
  static Layout from(Map map,View view) {
    return Layout(map,view);
  }
  Widget build(BuildContext context) {
    Widget rtn = const Text('hey');
    map.forEach((k,v) {
      if (k == "Form") {
        rtn = buildForm(v as Map, context);
      } else if ( k == 'Expanded' ) {

      }
    });
    return rtn;
  }
  Expanded buildExpanded(Map props,BuildContext context) {
    if ( props['items'] == null ) {
      throw Exception('Expanded must have items property');
    }
    List<Widget> childWidgets = buildChildWidgets(props['items'] as List);
    Widget child;
    if ( childWidgets.isNotEmpty ) {
      child = childWidgets.first;
    } else {
      throw Exception("Expanded must have one child");
    }
    return Expanded(child:child);
  }
  Form buildForm(Map props,BuildContext context) {
    if ( props['items'] == null ) {
      throw Exception('Form must have items property');
    }
    List<Widget> childWidgets = buildChildWidgets(props['items'] as List);
    return Form(child:Column(children:childWidgets));
  }
  List<Widget> buildChildWidgets(List children) {
    List<Widget> childWidgets = [];
    for ( final String id in children) {
      WidgetView? wv = view.get(id);
      if ( wv != null ) {
        childWidgets.add(wv.widget);
      }
    }
    return childWidgets;
  }
}