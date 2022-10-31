import 'dart:developer';

import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/widget/view.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class AppScroller extends StatefulWidget with Invokable, HasController<AppScrollerController, _AppScrollerState>{
  static const type = 'AppScroller';
  AppScroller({super.key});

  @override
  State<AppScroller> createState() => _AppScrollerState();

  final AppScrollerController _controller = AppScrollerController();
  @override
  AppScrollerController get controller => _controller;

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      // styles
      'expandedHeight': (value) => _controller.expandedHeight = value,
      'collapsedHeight': (value) => _controller.collapsedHeight = value,
      'fixedHeaderHeight': (value) => _controller.fixedHeaderHeight = value,

      // widgets
      'fixedHeader': (widget) => _controller.fixedHeader = widget,
      'flexibleHeader': (widget) => _controller.flexibleHeader = widget,
      'flexibleBackground': (widget) => _controller.flexibleBackground = widget,
      'body': (widget) => _controller.body = widget,
    };
  }
}

class AppScrollerController extends WidgetController {
  // styles
  int? fixedHeaderHeight;
  int? expandedHeight;  // includes the fixedHeaderHeight
  int? collapsedHeight; // includes the fixedHeaderHeight

  // widgets
  dynamic fixedHeader;
  dynamic flexibleHeader;
  dynamic flexibleBackground;
  dynamic body;
}

class _AppScrollerState extends WidgetState<AppScroller> {

  @override
  Widget buildWidget(BuildContext context) {
    ScopeManager? scopeManager = DataScopeWidget.getScope(context);
    List<Widget> slivers = [];

    Widget? header = buildHeader(scopeManager!);
    if (header != null) {
      slivers.add(header);
    }
    Widget? body = buildBody(scopeManager!);
    if (body != null) {
      slivers.add(body);
    }

    return CustomScrollView(
      slivers: slivers
    );
  }

  Widget? buildHeader(ScopeManager scopeManager) {
    return SliverAppBar(
      //floating: true,
      //snap: true,
      pinned: true,

      // fixed header widget
      title: buildFixedHeader(scopeManager),
      titleSpacing: 0,
      toolbarHeight: widget._controller.fixedHeaderHeight?.toDouble() ?? kToolbarHeight,

      // flexible header widget
      flexibleSpace: buildFlexibleHeader(scopeManager),
      expandedHeight: widget._controller.expandedHeight?.toDouble(),
      collapsedHeight: widget._controller.collapsedHeight?.toDouble(), // toolbar height + the flexible title height
      elevation: 0,

      // others
      backgroundColor: Colors.white,
      automaticallyImplyLeading: false,

      stretch: true,
      //stretchTriggerOffset: 50,
      // onStretchTrigger: () async {
      //   log("onstretch");
      //   SchedulerBinding.instance?.addPostFrameCallback((_) {
      //     setState(() {
      //       _expandedHeight = 900;
      //     });
      //   });
      //
      // },

      //bottom: buildBottomHeader(scopeManager),
    );
  }

  Widget? buildFixedHeader(ScopeManager scopeManager) {
    if (widget._controller.fixedHeader != null) {
      return scopeManager.buildWidgetFromDefinition(widget._controller.fixedHeader);
    }
    return null;
  }

  Widget? buildFlexibleHeader(ScopeManager scopeManager) {
    Widget? backgroundWidget;
    if (widget._controller.flexibleBackground != null) {
      backgroundWidget = scopeManager.buildWidgetFromDefinition(widget._controller.flexibleBackground);
    }
    Widget? flexibleHeader;
    if (widget._controller.flexibleHeader != null) {
      flexibleHeader = scopeManager.buildWidgetFromDefinition(widget._controller.flexibleHeader);
    }

    return FlexibleSpaceBar(
      // flexible widget
      expandedTitleScale: 1,
      title: flexibleHeader,
      titlePadding: EdgeInsets.zero,

      background: backgroundWidget,
      collapseMode: CollapseMode.parallax,
    );
  }

  PreferredSizeWidget? buildBottomHeader(ScopeManager scopeManager) {
    return PreferredSize(
      preferredSize: Size.fromHeight(50),
      child: Text("blah blah here")
    );
  }

  Widget? buildBody(ScopeManager scopeManager) {
    if (widget._controller.body != null) {
      return SliverToBoxAdapter(
        child: scopeManager.buildWidgetFromDefinition(widget._controller.body),
      );
    }
    return null;
  }








}