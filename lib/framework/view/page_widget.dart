import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

import '../data_context.dart';

class PageWidget extends StatefulWidget
    with Invokable, HasController<PageWidgetController, PageWidgetState> {
  static const type = 'Page';
  PageWidget({
    Key? key,
    required DataContext dataContext,
    required SinglePageModel pageModel,
  })  : _initialDataContext = dataContext,
        _pageModel = pageModel,
        super(key: key);

  final DataContext _initialDataContext;
  final SinglePageModel _pageModel;

  final PageWidgetController _controller = PageWidgetController();
  @override
  get controller => _controller;

  @override
  State<StatefulWidget> createState() => PageWidgetState();

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

class PageWidgetController extends BoxController {
  bool? isLoading = false;
}

class PageWidgetState extends WidgetState<PageWidget> {
  late ScopeManager _scopeManager;

  @override
  void initState() {
    _scopeManager = ScopeManager(
        widget._initialDataContext.clone(newBuildContext: context),
        PageData(
            customViewDefinitions: widget._pageModel.customViewDefinitions,
            apiMap: widget._pageModel.apiMap));
    super.initState();
  }

  /// create AppBar that is part of a CustomScrollView
  Widget? buildSliverAppBar(SinglePageModel pageModel, bool hasDrawer) {
    if (pageModel.headerModel != null) {
      dynamic appBar = _buildAppBar(pageModel.headerModel!,
          scrollableView: true,
          showNavigationIcon: pageModel.pageStyles?['showNavigationIcon']);
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
  PreferredSizeWidget? buildFixedAppBar(
      SinglePageModel pageModel, bool hasDrawer) {
    if (pageModel.headerModel != null) {
      dynamic appBar = _buildAppBar(pageModel.headerModel!,
          scrollableView: false,
          showNavigationIcon: pageModel.pageStyles?['showNavigationIcon']);
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
    // whether to usse CustomScrollView for the entire page
    bool isScrollableView =
        widget._pageModel.pageStyles?['scrollableView'] == true;

    PreferredSizeWidget? fixedAppBar;
    if (!isScrollableView) {
      fixedAppBar = buildFixedAppBar(widget._pageModel, false);
    }

    Widget rtn = DataScopeWidget(
      scopeManager: _scopeManager,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        // slight optimization, if body background is set, let's paint
        // the entire screen including the Safe Area
        backgroundColor: widget.controller.backgroundColor,

        // appBar is inside CustomScrollView if defined
        appBar: AppBar(
          title: const Text('PageWidget'),
        ),
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
