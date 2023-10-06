import 'dart:developer';

import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/view/page.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

class AppScroller extends StatefulWidget
    with Invokable, HasController<AppScrollerController, _AppScrollerState> {
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
    return {
      'stretchExpandedHeight': (offset) =>
          _controller.stretchExpandedHeight(offset),
    };
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

      // others
      'headerBackgroundColor': (color) =>
          _controller.headerBackgroundColor = Utils.getColor(color),
      'onHeaderStretch': (action) => _controller.onHeaderStretch =
          EnsembleAction.fromYaml(action, initiator: this),

      // temp
      'onExpandedHeightReset': (action) => _controller.onExpandedHeightReset =
          EnsembleAction.fromYaml(action, initiator: this),
    };
  }
}

class AppScrollerController extends WidgetController {
  // styles
  int? fixedHeaderHeight;
  int? expandedHeight; // includes the fixedHeaderHeight
  int? collapsedHeight; // includes the fixedHeaderHeight

  // widgets
  dynamic fixedHeader;
  dynamic flexibleHeader;
  dynamic flexibleBackground;
  dynamic body;

  // others
  ScrollController? scrollController;
  Color? headerBackgroundColor;
  EnsembleAction? onHeaderStretch;
  EnsembleAction? onExpandedHeightReset;

  int? _maxExpandedHeight;
  void stretchExpandedHeight(int offset) {
    int newMaxExpandedHeight = Device().screenHeight - offset;
    if (_maxExpandedHeight == null ||
        _maxExpandedHeight != newMaxExpandedHeight) {
      // scroll to the top
      if (scrollController != null) {
        scrollController?.jumpTo(0);
      }

      // set expanded height
      _maxExpandedHeight = newMaxExpandedHeight;
      //log("stretch expanded height to $_maxExpandedHeight");
      notifyListeners();
    }
  }
}

class _AppScrollerState extends WidgetState<AppScroller> {
  @override
  void initState() {
    super.initState();
    widget._controller.scrollController = ScrollController();
    widget._controller.scrollController!.addListener(() {
      // if we are at the max expanded height and we scroll backward, reset to the normal expanded height
      if (widget._controller._maxExpandedHeight != null &&
          widget._controller.scrollController!.offset > 50 &&
          widget._controller.scrollController!.position.userScrollDirection ==
              ScrollDirection.reverse) {
        setState(() {
          widget._controller._maxExpandedHeight = null;
        });
        if (widget._controller.onExpandedHeightReset != null) {
          ScreenController().executeAction(
              context, widget._controller.onExpandedHeightReset!);
        }
      }
    });
  }

  @override
  Widget buildWidget(BuildContext context) {
    ScopeManager? scopeManager = DataScopeWidget.getScope(context);
    List<Widget> slivers = [];

    Widget? header = buildHeader(scopeManager!);
    if (header != null) {
      slivers.add(header);
    }
    Widget? body = buildBody(scopeManager);
    if (body != null) {
      slivers.add(body);
    }

    return CustomScrollView(
      slivers: slivers,
      controller: widget._controller.scrollController,
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
      toolbarHeight:
          widget._controller.fixedHeaderHeight?.toDouble() ?? kToolbarHeight,

      // flexible header widget
      flexibleSpace: buildFlexibleHeader(scopeManager),
      expandedHeight: widget._controller._maxExpandedHeight?.toDouble() ??
          widget._controller.expandedHeight?.toDouble(),
      collapsedHeight: widget._controller.collapsedHeight
          ?.toDouble(), // toolbar height + the flexible title height
      elevation: 0,

      // others
      backgroundColor: widget._controller.headerBackgroundColor,
      automaticallyImplyLeading: false,

      stretch: widget._controller.onHeaderStretch != null,
      //stretchTriggerOffset: 50,
      onStretchTrigger: widget._controller.onHeaderStretch == null
          ? null
          : () async {
              // async function so make sure we wait for screen to render
              SchedulerBinding.instance.addPostFrameCallback((_) {
                ScreenController().executeAction(
                    context, widget._controller.onHeaderStretch!);
              });
            },

      //bottom: buildBottomHeader(scopeManager),
    );
  }

  Widget? buildFixedHeader(ScopeManager scopeManager) {
    if (widget._controller.fixedHeader != null) {
      return scopeManager
          .buildWidgetFromDefinition(widget._controller.fixedHeader);
    }
    return null;
  }

  /// TODO: background widget are re-rendered on changging expandedHeight, and that
  /// messes up the data. Fix this problem. For now just render it once and re-use
  Widget? backgroundWidget;

  Widget? buildFlexibleHeader(ScopeManager scopeManager) {
    if (widget._controller.flexibleBackground != null) {
      backgroundWidget ??= scopeManager
          .buildWidgetFromDefinition(widget._controller.flexibleBackground);
    }
    Widget? flexibleHeader;
    if (widget._controller.flexibleHeader != null) {
      flexibleHeader = scopeManager
          .buildWidgetFromDefinition(widget._controller.flexibleHeader);
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
        preferredSize: Size.fromHeight(50), child: Text("blah blah here"));
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
