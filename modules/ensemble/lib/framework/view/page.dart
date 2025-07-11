import 'dart:async';
import 'dart:developer';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/ensemble_app.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/devmode.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/menu.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/theme_manager.dart';
import 'package:ensemble/framework/view/bottom_nav_page_view.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/view/footer.dart';
import 'package:ensemble/framework/view/has_selectable_text.dart';
import 'package:ensemble/framework/view/page_group.dart';
import 'package:ensemble/framework/widget/icon.dart' as ensemble;
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/unfocus.dart';
import 'package:flutter/material.dart';

class SinglePageController extends WidgetController {
  TextStyleComposite? _textStyle;
  int? maxLines;

  SinglePageController(SinglePageModel model) {
    setStyles(model.runtimeStyles ?? {});
  }

  void setStyles(Map<String, dynamic> pageStyles) {
    getBaseSetters().forEach((key, value) {
      if (pageStyles.containsKey(key)) {
        value(pageStyles[key]);
      }
    });
  }

  @override
  Map<String, Function> getBaseSetters() {
    Map<String, Function> setters = super.getBaseSetters();
    setters.addAll({
      'maxLines': (value) => maxLines = Utils.optionalInt(value, min: 1),
      'textStyle': (style) =>
          _textStyle = Utils.getTextStyleAsComposite(this, style: style),
    });
    return setters;
  }
}

/// The root View. Every Ensemble page will have at least one at its root
class Page extends StatefulWidget {
  Page({
    super.key,
    required DataContext dataContext,
    required SinglePageModel pageModel,
    required this.onRendered,
  })  : _initialDataContext = dataContext,
        _pageModel = pageModel,
        _controller = SinglePageController(pageModel);

  final DataContext _initialDataContext;
  final SinglePageModel _pageModel;
  final SinglePageController _controller;

  /// The reference to DataContext is needed for API invoked before
  /// the page load. In these cases we do not have the context to travel
  /// to the DataScopeWidget. This should only be used for this purpose.
  ScopeManager? rootScopeManager;

  final Function() onRendered;

  @override
  State<Page> createState() => PageState();
}

class PageState extends State<Page>
    with AutomaticKeepAliveClientMixin, RouteAware, WidgetsBindingObserver {
  late Widget rootWidget;
  PreferredSizeWidget? _cachedHeaderAppBar;
  PreferredSizeWidget? _cachedDrawerAppBar;
  SinglePageModel? _lastCachedPageModel;
  bool? _lastHasDrawer;
  late ScopeManager _scopeManager;
  Widget? footerWidget;
  late ScrollController pageController;

  // a menu can include other pages, keep track of what is selected
  int selectedPage = 0;

  // Auto-hide app bar functionality
  bool _isAppBarVisible = true;
  late ScrollController _autoHideScrollController;
  double _lastScrollOffset = 0.0;
  static const double _scrollThreshold = 10.0;
  static const double _showThreshold = 10.0;
  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 16); // ~60fps

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(covariant Page oldWidget) {
    super.didUpdateWidget(oldWidget);
    // widget can be re-created at any time, we need to keep the Scope intact.
    widget.rootScopeManager = _scopeManager;
  }

  void _reassignScrollController() {
    // Ensure we're in a valid state
    if (!mounted) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_autoHideScrollController.hasClients) {
        print('⚠️ ScrollController not ready, skipping reassignment');
        return;
      }
      
      try {
        // Remove existing listener (if any)
        _autoHideScrollController.removeListener(_handleAutoHideScroll);
      } catch (e) {
        // Listener wasn't there, continue
      }
      
      // Add listener back
      _autoHideScrollController.addListener(_handleAutoHideScroll);
      
      // Update reference only if different
      if (currentPageController != _autoHideScrollController) {
        currentPageController = _autoHideScrollController;
        print('✅ Reassigned scroll controller on page resume');
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // if our widget changes, we need to save the scopeManager to it.
    print('widget changed!!!!!!!!!');
    widget.rootScopeManager = _scopeManager;
        _reassignScrollController();

    // see if we are part of a ViewGroup or not
    BottomNavScreen? bottomNavRootScreen = BottomNavScreen.getScreen(context);
    if (bottomNavRootScreen != null) {
      bottomNavRootScreen.onReVisited(() {
        if (widget._pageModel.viewBehavior.onResume != null) {
          ScreenController().executeActionWithScope(
              context, _scopeManager, widget._pageModel.viewBehavior.onResume!,
              event: EnsembleEvent(null,
                  data: {"inactiveDuration": null, "isAppResume": false}));
        }
      });
    }
    // standalone screen, listen when another screen is popped and we are back here
    else {
      var route = ModalRoute.of(context);
      if (route is PageRoute) {
        Ensemble().routeObserver.unsubscribe(this);
        Ensemble().routeObserver.subscribe(this, route);
      }
    }
  }

  /// the last time the screen went to the background
  DateTime? appLastPaused;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // make a note of when the app was paused
    if (state == AppLifecycleState.paused) {
      appLastPaused = DateTime.now();
      if (widget._pageModel.viewBehavior.onPause != null) {
        ScreenController().executeActionWithScope(
            context, _scopeManager, widget._pageModel.viewBehavior.onPause!,
            event: EnsembleEvent(null, data: {"isAppPause": true}));
      }
    } else if (state == AppLifecycleState.resumed) {
      // the App has to pause (go to background) before we respect resume.
      if (appLastPaused != null &&
          widget._pageModel.viewBehavior.onResume != null) {
        var inactiveDuration =
            DateTime.now().difference(appLastPaused!).inMilliseconds;

        // if we our screen is the currently active route
        var route = ModalRoute.of(context);
        if (route != null && route.isCurrent) {
          // BottomNavBar is the route that contains each Tabs,
          // so we ignore if we are currently not an active Tab
          BottomNavScreen? bottomNavRootScreen =
              BottomNavScreen.getScreen(context);
          if (bottomNavRootScreen != null && !bottomNavRootScreen.isActive()) {
            return;
          }
          ScreenController().executeActionWithScope(
              context, _scopeManager, widget._pageModel.viewBehavior.onResume!,
              event: EnsembleEvent(null, data: {
                "inactiveDuration": inactiveDuration,
                "isAppResume": true
              }));
        }
      }
      // reset inactive time
      appLastPaused = null;
    }
  }

  @override
  void didPush() {
    log("didPush() for ${widget.hashCode}");
  }

  DateTime? screenLastPaused;

  // a new page is pushed and this page is no longer active
  @override
  void didPushNext() {
    super.didPushNext();
    screenLastPaused = DateTime.now();
    if (widget._pageModel.viewBehavior.onPause != null) {
      ScreenController().executeActionWithScope(
          context, _scopeManager, widget._pageModel.viewBehavior.onPause!,
          event: EnsembleEvent(null, data: {"isAppPause": false}));
    }
  }

  /// when a page is popped and we go back to this page
  @override
  void didPopNext() {
    super.didPopNext();
    _reassignScrollController();
    if (widget._pageModel.viewBehavior.onResume != null) {
      ScreenController().executeActionWithScope(
          context, _scopeManager, widget._pageModel.viewBehavior.onResume!,
          event: EnsembleEvent(null, data: {
            "inactiveDuration": screenLastPaused == null
                ? null
                : DateTime.now().difference(screenLastPaused!).inMilliseconds,
            "isAppResume": false
          }));
    }
    // reset the last paused time
    screenLastPaused = null;
  }

  @override
  void initState() {
    pageController = ScrollController();
    _autoHideScrollController = ScrollController();
    currentPageController = _autoHideScrollController;
    _autoHideScrollController.addListener(_handleAutoHideScroll);
    WidgetsBinding.instance.addObserver(this);
    _scopeManager = ScopeManager(
        widget._initialDataContext
            .clone(newBuildContext: context)
            //evaluate imports if any in the context of this page
            .evalImports(widget._pageModel.importedCode),
        PageData(
          customViewDefinitions: widget._pageModel.customViewDefinitions,
          apiMap: widget._pageModel.apiMap,
          socketData: widget._pageModel.socketData,
        ),
        importedCode: widget._pageModel.importedCode);
    widget.rootScopeManager = _scopeManager;
    // if we have a menu, figure out which child page to display initially
    if (widget._pageModel.menu != null &&
        widget._pageModel.menu!.menuItems.length > 1) {
      for (int i = 0; i < widget._pageModel.menu!.menuItems.length; i++) {
        MenuItem item = widget._pageModel.menu!.menuItems[i];
        dynamic selected = _scopeManager.dataContext.eval(item.selected);
        if (selected == true || selected == 'true') {
          selectedPage = i;
        }
      }
    }

    // execute view behavior
    if (widget._pageModel.viewBehavior.onLoad != null) {
      /// we want to wait for the View to first rendered (so all their Invokable IDs are in)
      /// before executing API since its response can reference the IDs
      /// Probably not ideal as we want to fire this off asap. It's the API response that
      /// needs to make sure Invokable IDs are there (through currently our code can't
      /// separate them out yet
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await ScreenController().executeActionWithScope(
            context, _scopeManager, widget._pageModel.viewBehavior.onLoad!);

        // after loading all the script, execute onRendered
        // This is not exactly right but we don't have a way to know when the page
        // has completely rendered. This will be sufficient for most use case
        widget.onRendered();
      });
    }

    // build the root widget
    rootWidget = (widget._pageModel.rootWidgetModel == null)
        ? const SizedBox.shrink()
        : _scopeManager.buildRootWidget(
            widget._pageModel.rootWidgetModel!, executeGlobalCode);

    footerWidget = (widget._pageModel.footer?.footerWidgetModel != null)
        ? _scopeManager
            .buildWidget(widget._pageModel.footer!.footerWidgetModel!)
        : null;

    super.initState();
    // Adding a listener for [viewGroupNotifier] so we can execute
    // onViewGroupUpdate when change in parent ViewGroup occurs
    viewGroupNotifier.addListener(executeOnViewGroupUpdate);
  }

  /// Handle auto-hide scroll logic
void _handleAutoHideScroll() {
  if (!_autoHideScrollController.hasClients) return;
  
  final currentOffset = _autoHideScrollController.offset;
  final scrollDelta = currentOffset - _lastScrollOffset;
  
  bool shouldHideAppBar = false;
  bool shouldShowAppBar = false;
  
    if (!_autoHideScrollController.hasClients) return;
    
    // Cancel previous timer if it exists
    _debounceTimer?.cancel();
    
    // Create new timer with debounce
    _debounceTimer = Timer(_debounceDuration, () {
      _performScrollVisibilityCheck();
    });
}

void _performScrollVisibilityCheck() {
  if (!_autoHideScrollController.hasClients) return;
  
  final currentOffset = _autoHideScrollController.offset;
  final scrollDelta = currentOffset - _lastScrollOffset;
  
  bool shouldHideAppBar = false;
  bool shouldShowAppBar = false;
  
  // Always show header when at the top
  if (currentOffset <= 0 && !_isAppBarVisible) {
    shouldShowAppBar = true;
  } else if (scrollDelta > 0 && currentOffset > _scrollThreshold && _isAppBarVisible) {
    // Scrolling down past threshold - hide app bar
    shouldHideAppBar = true;
  } else if (scrollDelta < -2.0 && !_isAppBarVisible) {
    // Requires at least 2 pixels of upward movement
    shouldShowAppBar = true;
  }
    
    if (shouldHideAppBar || shouldShowAppBar) {
      setState(() {
        _isAppBarVisible = shouldShowAppBar;
      });
    }
    
    _lastScrollOffset = currentOffset;
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

  /// create AppBar that is part of a CustomScrollView
  Widget? buildSliverAppBar(SinglePageModel pageModel, bool hasDrawer) {
    if (!_isAppBarVisible) return null;
    
    if (pageModel.headerModel != null) {
      dynamic appBar = _buildAppBar(pageModel.headerModel!,
          scrollableView: true,
          showNavigationIcon: pageModel.runtimeStyles?['showNavigationIcon']);
      if (appBar is SliverAppBar || appBar is AnimatedAppBar) {
        return appBar;
      }
    }
    if (hasDrawer) {
      return const SliverAppBar();
    }
    return null;
  }
void _buildAppBarCache(SinglePageModel pageModel, bool hasDrawer) {
  // Check if cache needs rebuilding
  bool needsRebuild = _lastCachedPageModel != pageModel || _lastHasDrawer != hasDrawer;

  
  if (!needsRebuild) {
    return; // Cache is still valid, no need to rebuild
  }

  // Clear existing cache
  _cachedHeaderAppBar = null;
  _cachedDrawerAppBar = null;

  // Build and cache header AppBar if header model exists
  if (pageModel.headerModel != null) {
    try {
      dynamic appBar = _buildAppBar(
        pageModel.headerModel!,
        scrollableView: false,
        showNavigationIcon: pageModel.runtimeStyles?['showNavigationIcon']
      );
      
      if (appBar is PreferredSizeWidget) {
        _cachedHeaderAppBar = appBar;
      }
    } catch (e) {
      // Handle any errors in AppBar building
      print('Error building header AppBar: $e');
      _cachedHeaderAppBar = null;
    }
  }

  // Build and cache drawer AppBar if drawer is needed
  if (hasDrawer) {
    try {
      _cachedDrawerAppBar = AppBar();
    } catch (e) {
      // Handle any errors in AppBar building
      print('Error building drawer AppBar: $e');
      _cachedDrawerAppBar = null;
    }
  }

  // Update cache markers to track what we cached
  _lastCachedPageModel = pageModel;
  _lastHasDrawer = hasDrawer;
}
  /// fixed AppBar
PreferredSizeWidget? buildFixedAppBar(SinglePageModel pageModel, bool hasDrawer) {
  // Build cache if needed
  _buildAppBarCache(pageModel, hasDrawer);
  
  PreferredSizeWidget? baseAppBar;
  
  // Get cached AppBar
  if (_cachedHeaderAppBar != null) {
    baseAppBar = _cachedHeaderAppBar;
  } else if (_cachedDrawerAppBar != null) {
    baseAppBar = _cachedDrawerAppBar;
  }

  if (baseAppBar == null) {
    return null;
  }

  // Use Offstage to hide/show without removing from widget tree
  return PreferredSize(
    preferredSize: baseAppBar.preferredSize,
    child: Offstage(
      offstage: !_isAppBarVisible, // Hide when _isAppBarVisible is false
      child: baseAppBar,
    ),
  );
}

Widget _wrapWithSafeAreaIfNeeded(Widget child, bool collapseSafeArea) {
  if (collapseSafeArea != true) {
    return child;
  }
  print('this is value received: ${collapseSafeArea}');

  return Builder(
    builder: (context) {
      final mediaQuery = MediaQuery.of(context);
      double topPadding = _isAppBarVisible ? mediaQuery.padding.top : 55.0;
      
      return Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: child,
      );
    },
  );
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
    // Build custom leading widget if provided
    Widget? leadingWidget;
    if (headerModel.leadingWidget != null) {
      leadingWidget = _scopeManager.buildWidget(headerModel.leadingWidget!);
    }

    final evaluatedHeader = EnsembleThemeManager()
        .getRuntimeStyles(_scopeManager.dataContext, headerModel);

    bool centerTitle =
        Utils.getBool(evaluatedHeader?['centerTitle'], fallback: true);
    Color? backgroundColor =
        Utils.getColor(evaluatedHeader?['backgroundColor']);
    Color? surfaceTintColor =
        Utils.getColor(evaluatedHeader?['surfaceTintColor']);
    Color? color = Utils.getColor(evaluatedHeader?['color']);
    Color? shadowColor = Utils.getColor(evaluatedHeader?['shadowColor']);
    double? elevation =
        Utils.optionalInt(evaluatedHeader?['elevation'], min: 0)?.toDouble();
    ScrollMode scrollMode =
        Utils.getEnum<ScrollMode>(evaluatedHeader?['scrollMode'], ScrollMode.values);
    final titleBarHeight =
        Utils.optionalInt(evaluatedHeader?['titleBarHeight'], min: 0)
                ?.toDouble() ??
            kToolbarHeight;

    // animation
    final animation = evaluatedHeader?['animation'] != null
        ? EnsembleThemeManager.yamlToDart(evaluatedHeader?['animation'])
        : null;
    bool animationEnabled = false;
    int? duration;
    Curve? curve;
    AnimationType? animationType;
    if (animation != null) {
      animationEnabled = Utils.getBool(animation!['enabled'], fallback: false);
      duration = Utils.getInt(animation!['duration'], fallback: 0);
      curve = Utils.getCurve(animation!['curve']);
      animationType = Utils.getEnum<AnimationType>(animation!['animationType'], AnimationType.values);
    }
    // applicable only to Sliver scrolling
    double? flexibleMaxHeight =
        Utils.optionalInt(evaluatedHeader?['flexibleMaxHeight'])?.toDouble();

    double? flexibleMinHeight =
        Utils.optionalInt(evaluatedHeader?['flexibleMinHeight'])?.toDouble();
    // collapsed height if specified needs to be bigger than titleBar height
    if (flexibleMinHeight != null && flexibleMinHeight < titleBarHeight) {
      flexibleMinHeight = null;
    }

    if (scrollableView) {
      return AnimatedAppBar( scrollController: externalScrollController!,
        automaticallyImplyLeading:
           leadingWidget == null && showNavigationIcon != false,
        leadingWidget: leadingWidget,
        titleWidget: titleWidget,
        centerTitle: centerTitle,
        backgroundColor: backgroundColor,
        surfaceTintColor: surfaceTintColor,
        foregroundColor: color,

        // control the drop shadow on the header's bottom edge
        elevation: elevation,
        shadowColor: shadowColor,

        titleBarHeight: titleBarHeight,

        // animation
        animated: animationEnabled,
        curve: curve,
        duration: duration,
        animationType: animationType,

        backgroundWidget: backgroundWidget,
        expandedBarHeight: flexibleMaxHeight?? titleBarHeight,
        collapsedBarHeight: flexibleMinHeight?? titleBarHeight,
        floating: scrollMode == ScrollMode.floating,
        pinned: scrollMode == ScrollMode.pinned,

      );

    } else {
      return AppBar(
        automaticallyImplyLeading:
            leadingWidget == null && showNavigationIcon != false,
        leading: leadingWidget,
        title: titleWidget,
        centerTitle: centerTitle,
        backgroundColor: backgroundColor,
        surfaceTintColor: surfaceTintColor,
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
  Widget build(BuildContext context) {
    super.build(context);
    //log("View build() $hashCode");

    // drawer might be injected from the PageGroup, so check for it first.
    // Note that if the drawer already exists, we will ignore any new drawer
    Widget? _drawer = PageGroupWidget.getNavigationDrawer(context);
    Widget? _endDrawer = PageGroupWidget.getNavigationEndDrawer(context);
    bool hasDrawer = _drawer != null || _endDrawer != null;

    Widget? _bottomNavBar;
    if (widget._pageModel.menu != null) {
      EnsembleThemeManager().configureStyles(_scopeManager.dataContext,
          widget._pageModel.menu!, widget._pageModel.menu!);
    }
    // build the navigation menu (bottom nav bar or drawer). Note that menu is not applicable on modal pages
    if (widget._pageModel.menu != null &&
        widget._pageModel.screenOptions?.pageType != PageType.modal) {
      if (widget._pageModel.menu is BottomNavBarMenu) {
        _bottomNavBar = _buildBottomNavBar(
            context, widget._pageModel.menu as BottomNavBarMenu);
      } else if (widget._pageModel.menu is DrawerMenu) {
        if (!(widget._pageModel.menu as DrawerMenu).atStart) {
          _endDrawer ??=
              _buildDrawer(context, widget._pageModel.menu as DrawerMenu);
        } else {
          _drawer ??=
              _buildDrawer(context, widget._pageModel.menu as DrawerMenu);
        }
      }
      // sidebar navBar will be rendered as part of the body
    }

    LinearGradient? backgroundGradient = Utils.getBackgroundGradient(
        widget._pageModel.runtimeStyles?['backgroundGradient']);
    Color? backgroundColor = Utils.getColor(_scopeManager.dataContext
        .eval(widget._pageModel.runtimeStyles?['backgroundColor']));
    // if we have a background image, set the background color to transparent
    // since our image is outside the Scaffold
    dynamic evaluatedBackgroundImg = _scopeManager.dataContext
        .eval(widget._pageModel.runtimeStyles?['backgroundImage']);
    BackgroundImage? backgroundImage =
        Utils.getBackgroundImage(evaluatedBackgroundImg);
    if (backgroundImage != null || backgroundGradient != null) {
      backgroundColor = Colors.transparent;
    }

    // whether to usse CustomScrollView for the entire page
    bool isScrollableView =
        widget._pageModel.runtimeStyles?['scrollableView'] == true;
    bool collapsableHeader = widget._pageModel.runtimeStyles?['collapsableHeader'] == true;
    bool collapseSafeArea = widget._pageModel.runtimeStyles?['collapseSafeArea'] == true;

    PreferredSizeWidget? fixedAppBar;
    if (!isScrollableView) {
      fixedAppBar = buildFixedAppBar(widget._pageModel, hasDrawer);
    }

    // whether we have a header and if the close button is already there-
    bool hasHeader = (widget._pageModel.headerModel != null && _isAppBarVisible) || hasDrawer;
    bool? showNavigationIcon =
        widget._pageModel.runtimeStyles?['showNavigationIcon'];

    // add close button for modal page
    Widget? closeModalButton;
    if (widget._pageModel.screenOptions?.pageType == PageType.modal &&
        !hasHeader &&
        showNavigationIcon != false) {
      closeModalButton = FloatingActionButton(
        elevation: 3,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        mini: true,
        onPressed: () {
          Navigator.maybePop(context);
        },
        child: const Icon(Icons.close_rounded),
      );
    }
    Widget rtn = DataScopeWidget(
      scopeManager: _scopeManager,
      child: Unfocus(
        isUnfocus: Utils.getBool(widget._pageModel.runtimeStyles?['unfocus'],
            fallback: false),
        child: Scaffold(
            resizeToAvoidBottomInset: true,
            // slight optimization, if body background is set, let's paint
            // the entire screen including the Safe Area
            backgroundColor: backgroundColor,

            // appBar is inside CustomScrollView if defined
            appBar: fixedAppBar,
body: FooterLayout(
  body: isScrollableView
    ? (collapsableHeader == true 
        ? _wrapWithSafeAreaIfNeeded(
            buildNestedScrollablePageContent(hasDrawer),
            collapseSafeArea
          )
        : buildScrollablePageContent(hasDrawer))
    : _wrapWithSafeAreaIfNeeded(
        buildFixedPageContent(fixedAppBar != null),
        collapseSafeArea
      ),
  footer: footerWidget,
),
            bottomNavigationBar: _bottomNavBar,
            drawer: _drawer,
            endDrawer: _endDrawer,
            floatingActionButton: closeModalButton,
            floatingActionButtonLocation:
                widget._pageModel.runtimeStyles?['navigationIconPosition'] ==
                        'start'
                    ? FloatingActionButtonLocation.startTop
                    : FloatingActionButtonLocation.endTop),
      ),
    );
    DevMode.pageDataContext = _scopeManager.dataContext;
    // selectableText at the root
    if (Utils.optionalBool(widget._pageModel.runtimeStyles?['selectable']) ==
        true) {
      rtn = HasSelectableText(child: rtn);
    }

    // if backgroundImage is set, put it outside of the Scaffold so
    // keyboard sliding up (when entering value) won't resize the background
    if (backgroundImage != null) {
      return Stack(
        children: [
          Positioned.fill(
            child: backgroundImage.getImageAsWidget(_scopeManager),
          ),
          rtn,
        ],
      );
    } else if (backgroundGradient != null) {
      return Scaffold(
          resizeToAvoidBottomInset: false,
          body: Container(
              decoration: BoxDecoration(gradient: backgroundGradient),
              child: rtn));
    }
    return rtn;
  }

  /// determine if we should wraps the body in a SafeArea or not
  bool useSafeArea() {
    bool? useSafeArea =
        Utils.optionalBool(widget._pageModel.runtimeStyles?['useSafeArea']);

    // backward compatible with legacy attribute
    if (useSafeArea == null) {
      bool? ignoreSafeArea = Utils.optionalBool(
          widget._pageModel.runtimeStyles?['ignoreSafeArea']);
      if (ignoreSafeArea != null) {
        useSafeArea = !ignoreSafeArea;
      }
    }

    // by default don't use Safe Area
    return useSafeArea ?? false;
  }

  Widget buildFixedPageContent(bool hasAppBar) {
    return getBody(hasAppBar && _isAppBarVisible);
  }

  Widget buildScrollablePageContent(bool hasDrawer) {
    List<Widget> slivers = [];
    externalScrollController = ScrollController();
    // appBar
    Widget? appBar = buildSliverAppBar(widget._pageModel, hasDrawer);

    if (appBar != null) {
      slivers.add(appBar);
    }

    // body
    slivers.add(SliverToBoxAdapter(
      child: getBody(appBar != null),
    ));

    return CustomScrollView(
      controller: externalScrollController,
      slivers: slivers,
    );
  }

  Widget buildNestedScrollablePageContent(bool hasDrawer) {
    return NestedScrollView(
        controller: _autoHideScrollController,
        physics: ClampingScrollPhysics(),
        floatHeaderSlivers: true,
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          List<Widget> slivers = [];
          Widget? appBar = buildSliverAppBar(widget._pageModel, hasDrawer);
          if (appBar != null) {
            slivers.add(appBar);
          }
          return slivers;
        },
        body: getBody(_isAppBarVisible));
  }
  Widget getBody(bool hasAppBar) {
    // ignore safe area is only applicable if we don't have an AppBar
    bool _useSafeArea = !hasAppBar && useSafeArea();
    if (widget._pageModel.menu is SidebarMenu) {
      SidebarMenu sidebarMenu = widget._pageModel.menu as SidebarMenu;

      List<MenuItem> menuItems = sidebarMenu.menuItems;
      List<NavigationRailDestination> navItems = [];
      for (int i = 0; i < menuItems.length; i++) {
        MenuItem item = menuItems[i];
        navItems.add(NavigationRailDestination(
            padding: Utils.getInsets(sidebarMenu.runtimeStyles?['itemPadding']),
            icon: item.icon != null
                ? ensemble.Icon.fromModel(item.icon!)
                : const SizedBox.shrink(),
            label: Text(Utils.translate(item.label ?? '', context))));
      }

      // TODO: consolidate buildWidget into 1 place
      double paddingFromSafeSpace = 15;
      Widget? headerWidget;
      if (sidebarMenu.headerModel != null) {
        headerWidget = _scopeManager.buildWidget(sidebarMenu.headerModel!);
      }
      Widget menuHeader = Column(children: [
        SizedBox(height: paddingFromSafeSpace),
        Container(
          child: headerWidget,
        )
      ]);

      Widget? menuFooter;
      if (sidebarMenu.footerModel != null) {
        // push footer to the bottom of the rail
        menuFooter = Expanded(
          child: Align(
              alignment: Alignment.bottomCenter,
              child: _scopeManager.buildWidget(sidebarMenu.footerModel!)),
        );
      }

      MenuItemDisplay itemDisplay = MenuItemDisplay.values
              .from(sidebarMenu.runtimeStyles?['itemDisplay']) ??
          MenuItemDisplay.stacked;

      // stacked's min gap seems to be 72 regardless of what we set. For side by side optimal min gap is around 40
      // we set this minGap and let user controls with itemPadding
      int minGap = itemDisplay == MenuItemDisplay.sideBySide ? 40 : 72;

      // minExtendedWidth is applicable only for side by side, and should never be below minWidth (or exception)
      int minWidth = Utils.optionalInt(sidebarMenu.runtimeStyles?['minWidth'],
              min: minGap) ??
          200;

      List<Widget> content = [];
      // process menu styles
      Color? menuBackground =
          Utils.getColor(sidebarMenu.runtimeStyles?['backgroundColor']);
      content.add(NavigationRail(
        extended: itemDisplay == MenuItemDisplay.sideBySide ? true : false,
        minExtendedWidth: minWidth.toDouble(),
        minWidth: minGap.toDouble(),
        // this is important for optimal default item spacing
        labelType: itemDisplay != MenuItemDisplay.sideBySide
            ? NavigationRailLabelType.all
            : null,
        backgroundColor: menuBackground,
        leading: menuHeader,
        destinations: navItems,
        trailing: menuFooter,
        selectedIndex: selectedPage,
        onDestinationSelected: (index) =>
            selectNavigationIndex(context, menuItems[index]),
      ));

      // show a divider between the NavigationRail and the content
      Color? borderColor =
          Utils.getColor(widget._pageModel.menu!.runtimeStyles?['borderColor']);
      int? borderWidth = Utils.optionalInt(
          widget._pageModel.menu!.runtimeStyles?['borderWidth']);
      if (borderColor != null || borderWidth != null) {
        content.add(VerticalDivider(
            thickness: (borderWidth ?? 1).toDouble(),
            width: (borderWidth ?? 1).toDouble(),
            color: borderColor));
      }

      // add the bodyWidget
      content.add(Expanded(
          child: SafeArea(
              top: _useSafeArea, bottom: _useSafeArea, child: rootWidget)));
      return DefaultTextStyle.merge(
          style: widget._controller._textStyle?.getTextStyle(),
          maxLines: widget._controller.maxLines,
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.start, children: content));
    }

    return DefaultTextStyle.merge(
        style: widget._controller._textStyle?.getTextStyle(),
        maxLines: widget._controller.maxLines,
        child: SafeArea(
            top: _useSafeArea, bottom: _useSafeArea, child: rootWidget));
  }

  Drawer? _buildDrawer(BuildContext context, DrawerMenu menu) {
    List<MenuItem> visibleItems =
        Menu.getVisibleMenuItems(_scopeManager.dataContext, menu.menuItems);
    List<Widget> menuItems = [];

    for (int i = 0; i < visibleItems.length; i++) {
      MenuItem item = visibleItems[i];

      final customWidget = _buildCustomIcon(item);
      final label = customWidget != null
          ? ''
          : Utils.translate(item.label ?? '', context);

      Widget menuItem;
      void handleTap() {
        if (!item.isClickable) return;

        if (item.onTap != null) {
          ScreenController().executeActionWithScope(
              context, _scopeManager, EnsembleAction.from(item.onTap)!);
        }
        if (item.switchScreen) {
          selectNavigationIndex(context, item);
        }
      }

      if (customWidget != null) {
        menuItem = item.isClickable
            ? InkWell(onTap: handleTap, child: customWidget)
            : customWidget;
      } else {
        menuItem = ListTile(
          enabled: item.isClickable,
          selected: i == selectedPage,
          title: Text(label),
          leading: ensemble.Icon(item.icon ?? '', library: item.iconLibrary),
          horizontalTitleGap: 0,
          onTap: item.isClickable ? handleTap : null,
        );
      }

      menuItems.add(menuItem);
    }

    return Drawer(
      backgroundColor: Utils.getColor(menu.runtimeStyles?['backgroundColor']),
      child: Column(
        children: [
          // Header
          if (menu.headerModel != null)
            _scopeManager.buildWidget(menu.headerModel!),

          // Menu Items in scrollable area
          Expanded(
            child: ListView(
              children: menuItems,
            ),
          ),

          // Footer at bottom
          if (menu.footerModel != null)
            _scopeManager.buildWidget(menu.footerModel!),
        ],
      ),
    );
  }

  /// Build a Bottom Navigation Bar (default if display is not specified)
  BottomNavigationBar? _buildBottomNavBar(
      BuildContext context, BottomNavBarMenu menu) {
    List<BottomNavigationBarItem> navItems = [];
    for (int i = 0; i < menu.menuItems.length; i++) {
      MenuItem item = menu.menuItems[i];

      final dynamic customIcon = _buildCustomIcon(item);
      final dynamic customActiveIcon = _buildCustomIcon(item, isActive: true);

      final isCustom = customIcon != null || customActiveIcon != null;
      final label = isCustom ? '' : Utils.translate(item.label ?? '', context);
      ScopeManager? scopeManager = DataScopeWidget.getScope(context) ??
          PageGroupWidget.getScope(context);
      if (scopeManager != null) {
        menu.resolveStyles(scopeManager, menu, context);
      }
      navItems.add(
        BottomNavigationBarItem(
          activeIcon: customActiveIcon ??
              ensemble.Icon(item.activeIcon ?? item.icon,
                  library: item.iconLibrary),
          icon: customIcon ??
              ensemble.Icon(item.icon ?? '', library: item.iconLibrary),
          label: label,
        ),
      );
    }
    return BottomNavigationBar(
        items: navItems,
        backgroundColor: Utils.getColor(menu.runtimeStyles?['backgroundColor']),
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index != selectedPage) {
            selectNavigationIndex(context, menu.menuItems[index]);
          }
        },
        currentIndex: selectedPage);
  }

  Widget? _buildCustomIcon(MenuItem item, {bool isActive = false}) {
    Widget? iconWidget;
    dynamic customWidgetModel =
        isActive ? item.customActiveWidget : item.customWidget;
    if (customWidgetModel != null) {
      iconWidget = _scopeManager.buildWidget(customWidgetModel);
    }
    return iconWidget;
  }

  void selectNavigationIndex(BuildContext context, MenuItem menuItem) {
    ScreenController().navigateToScreen(context,
        screenName: menuItem.page, isExternal: menuItem.isExternal);
  }
  /// this method executes if this screen is part of ViewGroup
  /// and onViewGroupUpdate is defined in View
  void executeOnViewGroupUpdate() {
    if (widget._pageModel.viewBehavior.onViewGroupUpdate != null) {
      ScreenController().executeActionWithScope(
          context,
          _scopeManager,
          widget._pageModel.viewBehavior.onViewGroupUpdate!);
    }
  }
  @override
  void dispose() {
    pageController.dispose();
    _autoHideScrollController.removeListener(_handleAutoHideScroll);
    _autoHideScrollController.dispose();
    viewGroupNotifier.removeListener(executeOnViewGroupUpdate);
    Ensemble().routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);

    //log('Disposing View ${widget.hashCode}');
    _scopeManager.dispose();
    //_scopeManager.debugListenerMap();
    super.dispose();
  }
}

class AnimatedAppBar extends StatefulWidget {
  final ScrollController scrollController;
  final collapsedBarHeight;
  final expandedBarHeight;
  final automaticallyImplyLeading;
  final leadingWidget;
  final titleWidget;
  final centerTitle;
  final backgroundColor;
  final surfaceTintColor;
  final foregroundColor;
  final elevation;
  final shadowColor;
  final titleBarHeight;
  final backgroundWidget;
  final floating;
  final pinned;
  final animated;
  final curve;
  final animationType;
  final duration;
  AnimatedAppBar(
      {Key? key,
        this.automaticallyImplyLeading,
        this.leadingWidget,
        this.titleWidget,
        this.centerTitle,
        this.backgroundColor,
        this.surfaceTintColor,
        this.foregroundColor,
        this.elevation,
        this.shadowColor,
        this.titleBarHeight,
        this.backgroundWidget,
        this.animated,
        this.floating,
        this.pinned,
        this.collapsedBarHeight,
        this.expandedBarHeight,
        required this.scrollController,
        this.curve,
        this.animationType,
        this.duration})
      : super(key: key);

  @override
  _AnimatedAppBarState createState() => _AnimatedAppBarState();
}

class _AnimatedAppBarState extends State<AnimatedAppBar> with WidgetsBindingObserver{
  bool isCollapsed = false;
  
  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_updateCollapseState);
  }

  void _updateCollapseState() {

    if (!widget.scrollController.hasClients) return;

    double expandedHeight = (widget.expandedBarHeight ?? 0.0).toDouble();
    double collapsedHeight = (widget.collapsedBarHeight ?? 0.0).toDouble();
    double threshold = (expandedHeight - collapsedHeight).clamp(10.0, double.infinity);
    bool newState = widget.scrollController.offset > threshold;


    if (newState != isCollapsed) {
      setState(() {
        isCollapsed = newState;
      });
    }
  }

  @override
  void didUpdateWidget(AnimatedAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_updateCollapseState);
      widget.scrollController.addListener(_updateCollapseState);
    }

    if (oldWidget.expandedBarHeight != widget.expandedBarHeight ||
        oldWidget.collapsedBarHeight != widget.collapsedBarHeight) {
      _updateCollapseState();
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_updateCollapseState);
    super.dispose();
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
  Widget build(BuildContext context) {
    return SliverAppBar(
      collapsedHeight: widget.collapsedBarHeight,
      expandedHeight: widget.expandedBarHeight,
      pinned: widget.pinned,
      floating: widget.floating,
      centerTitle: widget.centerTitle,
      title: widget.animated
          ? switch (widget.animationType) {
        AnimationType.fade => AnimatedOpacity(
          opacity: isCollapsed ? 1.0 : 0.0,
          duration: Duration(milliseconds: widget.duration ?? 300),
          curve: widget.curve ?? Curves.easeIn,
          child: widget.titleWidget,
        ),
        AnimationType.drop => AnimatedSlide(
          offset: isCollapsed ? Offset(0, 0) : Offset(0, -2),
          duration: Duration(milliseconds: widget.duration ?? 300),
          curve: widget.curve ?? Curves.easeIn,
          child: widget.titleWidget,
        ),
        _ => widget.titleWidget,
      }
      : widget.titleWidget,
      elevation: widget.elevation,
      backgroundColor: widget.backgroundColor,
      flexibleSpace: wrapsInFlexible(widget.backgroundWidget),
      automaticallyImplyLeading: widget.automaticallyImplyLeading,
      leading: widget.leadingWidget,
      surfaceTintColor: widget.surfaceTintColor,
      foregroundColor: widget.foregroundColor,
      shadowColor: widget.shadowColor,
      toolbarHeight: widget.titleBarHeight,
    );
  }
}

enum ScrollMode {
  pinned,
  floating,
}

enum AnimationType{
  drop,
  fade,
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