import 'dart:developer';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/devmode.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/menu.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/bottom_nav_page_view.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/view/footer.dart';
import 'package:ensemble/framework/view/has_selectable_text.dart';
import 'package:ensemble/framework/view/page_group.dart';
import 'package:ensemble/framework/widget/icon.dart' as ensemble;
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/unfocus.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import '../widget/custom_view.dart';

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

  //final Widget bodyWidget;
  //final Menu? menu;
  //final Widget? footer;

  @override
  State<Page> createState() => PageState();
}

class PageState extends State<Page>
    with AutomaticKeepAliveClientMixin, RouteAware, WidgetsBindingObserver {
  late Widget rootWidget;
  late ScopeManager _scopeManager;
  Widget? footerWidget;

  /// the last time the screen went to the background
  DateTime? appLastPaused;

  // a menu can include other pages, keep track of what is selected
  int selectedPage = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(covariant Page oldWidget) {
    super.didUpdateWidget(oldWidget);
    // widget can be re-created at any time, we need to keep the Scope intact.
    widget.rootScopeManager = _scopeManager;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // if our widget changes, we need to save the scopeManager to it.
    widget.rootScopeManager = _scopeManager;

    // see if we are part of a ViewGroup or not
    BottomNavScreen? bottomNavRootScreen = BottomNavScreen.getScreen(context);
    if (bottomNavRootScreen != null) {
      bottomNavRootScreen.onReVisited(() {
        if (widget._pageModel.viewBehavior.onResume != null) {
          ScreenController().executeActionWithScope(
              context, _scopeManager, widget._pageModel.viewBehavior.onResume!);
        }
      });
    }
    // standalone screen, listen when another screen is popped and we are back here
    else {
      var route = ModalRoute.of(context);
      if (route is PageRoute) {
        Ensemble.routeObserver.subscribe(this, route);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    log(state.toString());
    // make a note of when the app was paused
    if (state == AppLifecycleState.paused) {
      appLastPaused = DateTime.now();
    }
    // the App has to pause (go to background) before we respect resume.
    if (state == AppLifecycleState.resumed &&
        widget._pageModel.viewBehavior.onResume != null &&
        (appLastPaused != null &&
            DateTime.now().difference(appLastPaused!).inMinutes > 5)) {
      // reset inactive time
      appLastPaused = null;

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
            context, _scopeManager, widget._pageModel.viewBehavior.onResume!);
      }
    }
  }

  @override
  void didPush() {
    log("didPush() for ${widget.hashCode}");
  }

  /// when a page is popped and we go back to this page
  @override
  void didPopNext() {
    if (widget._pageModel.viewBehavior.onResume != null) {
      ScreenController().executeActionWithScope(
          context, _scopeManager, widget._pageModel.viewBehavior.onResume!);
    }
  }

  @override
  void initState() {
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
    if (pageModel.headerModel != null) {
      dynamic appBar = _buildAppBar(pageModel.headerModel!,
          scrollableView: true,
          showNavigationIcon: pageModel.runtimeStyles?['showNavigationIcon']);
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
          showNavigationIcon: pageModel.runtimeStyles?['showNavigationIcon']);
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

    final evaluatedHeader = _scopeManager.dataContext.eval(headerModel.styles);

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

    final titleBarHeight =
        Utils.optionalInt(evaluatedHeader?['titleBarHeight'], min: 0)
                ?.toDouble() ??
            kToolbarHeight;

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

    PreferredSizeWidget? fixedAppBar;
    if (!isScrollableView) {
      fixedAppBar = buildFixedAppBar(widget._pageModel, hasDrawer);
    }

    // whether we have a header and if the close button is already there-
    bool hasHeader = widget._pageModel.headerModel != null || hasDrawer;
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
                  ? buildScrollablePageContent(hasDrawer)
                  : buildFixedPageContent(fixedAppBar != null),
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
      bool? ignoreSafeArea =
          Utils.optionalBool(widget._pageModel.runtimeStyles?['ignoreSafeArea']);
      if (ignoreSafeArea != null) {
        useSafeArea = !ignoreSafeArea;
      }
    }

    // by default don't use Safe Area
    return useSafeArea ?? false;
  }

  Widget buildFixedPageContent(bool hasAppBar) {
    return getBody(hasAppBar);
  }

  Widget buildScrollablePageContent(bool hasDrawer) {
    List<Widget> slivers = [];

    // appBar
    Widget? appBar = buildSliverAppBar(widget._pageModel, hasDrawer);
    if (appBar != null) {
      slivers.add(appBar);
    }

    // body
    slivers.add(SliverToBoxAdapter(
      child: getBody(appBar != null),
    ));

    return CustomScrollView(slivers: slivers);
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
            padding: Utils.getInsets(sidebarMenu.styles?['itemPadding']),
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

      MenuItemDisplay itemDisplay =
          MenuItemDisplay.values.from(sidebarMenu.styles?['itemDisplay']) ??
              MenuItemDisplay.stacked;

      // stacked's min gap seems to be 72 regardless of what we set. For side by side optimal min gap is around 40
      // we set this minGap and let user controls with itemPadding
      int minGap = itemDisplay == MenuItemDisplay.sideBySide ? 40 : 72;

      // minExtendedWidth is applicable only for side by side, and should never be below minWidth (or exception)
      int minWidth =
          Utils.optionalInt(sidebarMenu.styles?['minWidth'], min: minGap) ??
              200;

      List<Widget> content = [];
      // process menu styles
      Color? menuBackground =
          Utils.getColor(sidebarMenu.styles?['backgroundColor']);
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
          Utils.getColor(widget._pageModel.menu!.styles?['borderColor']);
      int? borderWidth =
          Utils.optionalInt(widget._pageModel.menu!.styles?['borderWidth']);
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
    List<ListTile> navItems = [];
    for (int i = 0; i < menu.menuItems.length; i++) {
      MenuItem item = menu.menuItems[i];
      navItems.add(ListTile(
        selected: i == selectedPage,
        title: Text(Utils.translate(item.label ?? '', context)),
        leading: ensemble.Icon(item.icon ?? '', library: item.iconLibrary),
        horizontalTitleGap: 0,
        onTap: () => selectNavigationIndex(context, item),
      ));
    }
    return Drawer(
      backgroundColor: Utils.getColor(menu.styles?['backgroundColor']),
      child: ListView(
        children: navItems,
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
        backgroundColor: Utils.getColor(menu.styles?['backgroundColor']),
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
      final widget = _scopeManager.buildWidget(customWidgetModel!);
      final dataScopeWidget = widget as DataScopeWidget;
      final customWidget = dataScopeWidget.child as CustomView;
      iconWidget = _scopeManager.buildWidget(customWidget.body);
    }
    return iconWidget;
  }

  void selectNavigationIndex(BuildContext context, MenuItem menuItem) {
    ScreenController().navigateToScreen(context,
        screenName: menuItem.page, isExternal: menuItem.isExternal);
  }

  @override
  void dispose() {
    Ensemble.routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);

    //log('Disposing View ${widget.hashCode}');
    _scopeManager.dispose();
    //_scopeManager.debugListenerMap();
    super.dispose();
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
