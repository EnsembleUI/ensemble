import 'package:ensemble/framework/context.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/layout_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

/// rendering our root page
class View extends StatefulWidget {
  View(
      this.pageData,
      this.bodyWidget,
      {
        this.footer,
        this.navBar,
        this.drawer,
      }) : super(key: ValueKey(pageData.pageName));

  final ViewState currentState = ViewState();
  final PageData pageData;
  final Widget bodyWidget;
  final Widget? footer;
  final BottomNavigationBar? navBar;
  final Drawer? drawer;

  @override
  State<View> createState() => currentState;

  ViewState getState() {
    return currentState;
  }


}

class ViewState extends State<View>{
  @override
  Widget build(BuildContext context) {

    // modal page has certain criteria (no navBar, no header)
    if (widget.pageData.pageType == PageType.modal) {
      // need a close button to go back to non-modal pages
      // also animate up and down (vs left and right)
      return Scaffold(
          body: widget.bodyWidget,
          bottomSheet: widget.footer);
    }
    // regular page
    else {
      return Scaffold(
        // slight optimization, if body background is set, let's paint
        // the entire screen including the Safe Area
        backgroundColor:
            widget.pageData.pageStyles?['backgroundColor'] is int ?
            Color(widget.pageData.pageStyles!['backgroundColor']) :
            null,
        appBar:
          widget.pageData.pageTitle != null ?
          AppBar(title: Text(widget.pageData.pageTitle!)) :
          null,
        body: SafeArea(
          child: widget.bodyWidget
        ),
        bottomNavigationBar: widget.navBar,
        drawer: widget.drawer,
        bottomSheet: widget.footer,
      );
    }
  }



}


/// data for the current page
class PageData {
  PageData({
    required this.pageName,
    required this.datasourceMap,
    required EnsembleContext eContext,
    this.subViewDefinitions,
    this.pageStyles,
    this.pageTitle,
    this.pageType,
    this.apiMap
  }) {
    _eContext = eContext;
  }

  final String? pageTitle;

  final PageType? pageType;

  // unique page name
  final String pageName;

  final Map<String, dynamic>? pageStyles;

  // store the data sources (e.g API result) and their callbacks
  final Map<String, ActionResponse> datasourceMap;

  // store the raw definition of the SubView (to be accessed by itemTemplates)
  final Map<String, YamlMap>? subViewDefinitions;

  // arguments passed into this page
  late final EnsembleContext _eContext;

  // API model mapping
  Map<String, YamlMap>? apiMap;

  /// everytime we call this, we make sure any populated API result will have its updated values here
  EnsembleContext getEnsembleContext() {
    for (var element in datasourceMap.values) {
      if (element._resultData != null) {
        _eContext.addDataContext(element._resultData!);
      }
    }
    return _eContext;
  }

}



class ActionResponse {
  Map<String, dynamic>? _resultData;
  Set<Function> listeners = {};

  void addListener(Function listener) {
    listeners.add(listener);
  }

  set resultData(Map<String, dynamic> data) {
    _resultData = data;

    // notify listeners
    for (var listener in listeners) {
      listener(_resultData);
    }
  }
}
