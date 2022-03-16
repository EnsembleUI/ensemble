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
        this.navBar
      }) : super(key: ValueKey(pageData.pageName));

  final ViewState currentState = ViewState();
  final PageData pageData;
  final Widget bodyWidget;
  final Widget? footer;
  final BottomNavigationBar? navBar;

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
    this.subViewDefinitions,
    this.pageStyles,
    this.pageTitle,
    this.pageType,
    this.args,
    this.apiMap
  });

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
  Map<String, dynamic>? args;

  // API model mapping
  Map<String, YamlMap>? apiMap;

  Map<String, dynamic> getPageData() {
    Map<String, dynamic> dataMap = args ?? {};
    datasourceMap.values.forEach((element) {
      if (element._resultData != null) {
        dataMap.addAll(element._resultData!);
      }

    });
    return dataMap;
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
