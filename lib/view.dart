import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/layout_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

/// rendering our root page
class View extends StatefulWidget {
  View(
      this.pageData,
      this.children,
      {
        this.footer,
        this.navBar
      }) : super(key: ValueKey(pageData.pageName));

  final ViewState currentState = ViewState();
  final PageData pageData;
  final List<Widget> children;
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
    // apply page-wide styles
    TextStyle? textStyle;
    int? bgColor;
    bool scrollable = false;
    MainAxisAlignment mainAxis = MainAxisAlignment.start;
    CrossAxisAlignment crossAxis = CrossAxisAlignment.start;

    Map<String, dynamic>? pageStyles = widget.pageData.pageStyles;
    if (pageStyles != null) {
      String? fontFamily = pageStyles['fontFamily'];
      double? fontSize = pageStyles['fontSize'];
      textStyle = TextStyle(fontFamily: fontFamily, fontSize: fontSize);

      // Note: color can be hex or string
      bgColor = pageStyles['backgroundColor'];

      scrollable = pageStyles['scrollable'] is bool && pageStyles['scrollable'];

      if (pageStyles['layout'] != null) {
        mainAxis = LayoutUtils.getMainAxisAlignment(pageStyles['layout']);
      }
      if (pageStyles['alignment'] != null) {
        crossAxis = LayoutUtils.getCrossAxisAlignment(pageStyles['alignment']);
      }
    }



    Widget body =
      DefaultTextStyle.merge(
        // page-wide styling
        style: textStyle,
        // for background color
        child: Ink(
          color: bgColor != null ? Color(bgColor) : null,
          child: Column(
            mainAxisAlignment: mainAxis,
            crossAxisAlignment: crossAxis,
            children: widget.children)
        )
      );

    Widget bodyWrapper =
        scrollable ?
        SingleChildScrollView(child: body) :
        body;

    // modal page has certain criteria (no navBar, no header)
    if (widget.pageData.pageType == PageType.modal) {
      // need a close button to go back to non-modal pages
      // also animate up and down (vs left and right)
      return Scaffold(
          body: bodyWrapper,
          bottomSheet: widget.footer);
    }
    // regular page
    else {
      return Scaffold(
        appBar:
          widget.pageData.pageTitle != null ?
          AppBar(title: Text(widget.pageData.pageTitle!)) :
          null,
        body: SafeArea(
          child: bodyWrapper
        ),
        bottomNavigationBar: widget.navBar,
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
