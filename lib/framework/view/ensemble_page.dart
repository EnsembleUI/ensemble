import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

import '../data_context.dart';

class PageWidget extends StatefulWidget {
  const PageWidget({
    Key? key,
    required DataContext dataContext,
    required SinglePageModel pageModel,
  })  : _initialDataContext = dataContext,
        _pageModel = pageModel,
        super(key: key);

  final DataContext _initialDataContext;
  final SinglePageModel _pageModel;

  @override
  State<PageWidget> createState() => _PageWidgetState();
}

class _PageWidgetState extends State<PageWidget> {
  late Widget rootWidget;
  late ScopeManager _scopeManager;

  @override
  void initState() {
    _scopeManager = ScopeManager(
        widget._initialDataContext.clone(newBuildContext: context),
        PageData(
            customViewDefinitions: widget._pageModel.customViewDefinitions,
            apiMap: widget._pageModel.apiMap));

    // build the root widget
    rootWidget = _scopeManager.buildRootWidget(
        widget._pageModel.rootWidgetModel, executeGlobalCode);
    super.initState();
  }

  /// This is a callback because we need the widget to be first instantiate
  /// since the global code block may reference them. Once the global code
  /// block runs, only then we can continue the next steps for the widget
  /// creation process (propagate data scopes and execute bindings)
  void executeGlobalCode() {
    if (widget._pageModel.globalCode != null) {
      _scopeManager.dataContext.evalCode(
          widget._pageModel.globalCode!, widget._pageModel.globalCodeSpan!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DataScopeWidget(
      scopeManager: _scopeManager,
      child: rootWidget,
    );
  }
}

class EnsemblePage extends StatefulWidget
    with Invokable, HasController<EnsemblePageController, EnsemblePageState> {
  static const type = 'View';

  EnsemblePage({Key? key}) : super(key: key);

  final EnsemblePageController _controller = EnsemblePageController();
  @override
  get controller => _controller;

  @override
  State<StatefulWidget> createState() => EnsemblePageState();

  @override
  Map<String, Function> getters() {
    return {
      'isLoading': () => _controller.isLoading,
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'isLoading': (value) => _controller.isLoading = Utils.optionalBool(value),
    };
  }
}

class EnsemblePageController extends BoxController {
  bool? isLoading = false;
  HeaderModel? headerModel;

  Map<String, dynamic>? pageStyles;
}

class EnsemblePageState extends WidgetState<EnsemblePage> {
  late ScopeManager _scopeManager;

  @override
  void initState() {
    super.initState();
    // _scopeManager = DataScopeWidget.getScope(context)!;
  }

  /// create AppBar that is part of a CustomScrollView
  Widget? buildSliverAppBar(SinglePageModel pageModel, bool hasDrawer) {
    if (widget.controller.headerModel != null) {
      dynamic appBar = _buildAppBar(widget.controller.headerModel!,
          scrollableView: true,
          showNavigationIcon:
              widget.controller.pageStyles?['showNavigationIcon']);
      if (appBar is SliverAppBar) {
        return appBar;
      }
    }
    if (hasDrawer) {
      return const SliverAppBar();
    }
    return null;
  }

  /// fixed AppBar
  PreferredSizeWidget? buildFixedAppBar(bool hasDrawer) {
    final pageStyles = widget.controller.pageStyles;
    final headerModel = widget.controller.headerModel;

    if (headerModel != null) {
      dynamic appBar = _buildAppBar(headerModel,
          scrollableView: false,
          showNavigationIcon: pageStyles?['showNavigationIcon']);
      if (appBar is PreferredSizeWidget) {
        return appBar;
      }
    }

    /// we need the Appbar to show our menu drawer icon
    if (hasDrawer) {
      return AppBar();
    }
    return null;
  }

  /// fixed AppBar
  dynamic _buildAppBar(HeaderModel headerModel,
      {required bool scrollableView, bool? showNavigationIcon}) {
    Widget? titleWidget;
    if (headerModel.titleWidget != null) {
      titleWidget = _scopeManager.buildWidget(headerModel.titleWidget!);
    }
    if (titleWidget == null && headerModel.titleText != null) {
      final title = _scopeManager.dataContext.eval(headerModel.titleText);
      titleWidget = Text(Utils.translate(title.toString(), context));
    }

    Widget? backgroundWidget;
    if (headerModel.flexibleBackground != null) {
      backgroundWidget =
          _scopeManager.buildWidget(headerModel.flexibleBackground!);
    }

    bool centerTitle =
        Utils.getBool(headerModel.styles?['centerTitle'], fallback: true);
    Color? backgroundColor =
        Utils.getColor(headerModel.styles?['backgroundColor']);
    Color? surfaceTintColor =
        Utils.getColor(headerModel.styles?['surfaceTintColor']);
    Color? color = Utils.getColor(headerModel.styles?['color']);
    Color? shadowColor = Utils.getColor(headerModel.styles?['shadowColor']);
    double? elevation =
        Utils.optionalInt(headerModel.styles?['elevation'], min: 0)?.toDouble();

    final titleBarHeight =
        Utils.optionalInt(headerModel.styles?['titleBarHeight'], min: 0)
                ?.toDouble() ??
            kToolbarHeight;

    // applicable only to Sliver scrolling
    double? flexibleMaxHeight =
        Utils.optionalInt(headerModel.styles?['flexibleMaxHeight'])?.toDouble();
    double? flexibleMinHeight =
        Utils.optionalInt(headerModel.styles?['flexibleMinHeight'])?.toDouble();
    // collapsed height if specified needs to be bigger than titleBar height
    if (flexibleMinHeight != null && flexibleMinHeight < titleBarHeight) {
      flexibleMinHeight = null;
    }

    if (scrollableView) {
      return SliverAppBar(
        automaticallyImplyLeading: showNavigationIcon != false,
        title: titleWidget,
        centerTitle: centerTitle,
        backgroundColor: backgroundColor,
        surfaceTintColor: surfaceTintColor,
        foregroundColor: color,

        // control the drop shadow on the header's bottom edge
        elevation: elevation,
        shadowColor: shadowColor,

        toolbarHeight: titleBarHeight,

        flexibleSpace: wrapsInFlexible(backgroundWidget),
        expandedHeight: flexibleMaxHeight,
        collapsedHeight: flexibleMinHeight,

        pinned: true,
      );
    } else {
      return AppBar(
        automaticallyImplyLeading: showNavigationIcon != false,
        title: titleWidget,
        centerTitle: centerTitle,
        backgroundColor: backgroundColor,
        foregroundColor: color,

        // control the drop shadow on the header's bottom edge
        elevation: elevation,
        shadowColor: shadowColor,

        toolbarHeight: titleBarHeight,
        flexibleSpace: backgroundWidget,
      );
    }
  }

  /// wraps the background in a FlexibleSpaceBar for automatic stretching and parallax effect.
  Widget? wrapsInFlexible(Widget? backgroundWidget) {
    if (backgroundWidget != null) {
      return FlexibleSpaceBar(
        background: backgroundWidget,
        collapseMode: CollapseMode.parallax,
      );
    }
    return null;
  }

  @override
  Widget buildWidget(BuildContext context) {
    _scopeManager = DataScopeWidget.getScope(context)!;
    if (_scopeManager == null) {
      throw Exception(
          'scopeManager is null in the EnsemblePage.buildWidget method. This is unexpected. EnsemblePage.id=${widget.id}');
    }

    print('IsLoading Widget: ${widget.controller.isLoading}');
    // whether to usse CustomScrollView for the entire page
    bool isScrollableView =
        widget.controller.pageStyles?['scrollableView'] == true;

    PreferredSizeWidget? fixedAppBar;
    if (!isScrollableView) {
      fixedAppBar = buildFixedAppBar(false);
    }

    Widget rtn = DataScopeWidget(
      scopeManager: _scopeManager,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        // slight optimization, if body background is set, let's paint
        // the entire screen including the Safe Area
        backgroundColor: widget.controller.backgroundColor,

        // appBar is inside CustomScrollView if defined
        appBar: fixedAppBar,
        body: const Center(child: Text('Rendered Page View')),
      ),
    );

    // if backgroundImage is set, put it outside of the Scaffold so
    // keyboard sliding up (when entering value) won't resize the background
    if (widget.controller.backgroundImage != null) {
      return Stack(
        children: [
          Positioned.fill(
              child: widget.controller.backgroundImage!.asImageWidget),
          rtn
        ],
      );
    } else if (widget.controller.backgroundGradient != null) {
      return Scaffold(
          resizeToAvoidBottomInset: false,
          body: Container(
              decoration:
                  BoxDecoration(gradient: widget.controller.backgroundGradient),
              child: rtn));
    }
    return rtn;
  }
}

/// a wrapper InheritedWidget to expose the ScopeManager
/// to every widgets in our tree
class DataScopeWidget extends InheritedWidget {
  const DataScopeWidget(
      {super.key, required this.scopeManager, required super.child});

  final ScopeManager scopeManager;

  @override
  bool updateShouldNotify(DataScopeWidget oldWidget) {
    return oldWidget.scopeManager != scopeManager;
  }

  /// return the ScopeManager which includes the dataContext
  static ScopeManager? getScope(BuildContext context) {
    DataScopeWidget? viewWidget =
        context.dependOnInheritedWidgetOfExactType<DataScopeWidget>();
    if (viewWidget != null) {
      return viewWidget.scopeManager;
    }
    return null;
  }
}
