import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/menu.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/page_group.dart';
import 'package:ensemble/framework/widget/icon.dart' as ensemble;
import 'package:ensemble/page_model.dart';
import 'package:ensemble/page_model.dart' as model;
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/button.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:flutter/material.dart';

import '../widget/custom_view.dart';

/// The root View. Every Ensemble page will have at least one at its root
class Page extends StatefulWidget {
  Page({
    super.key,
    required DataContext dataContext,
    required SinglePageModel pageModel,
  })  : _initialDataContext = dataContext,
        _pageModel = pageModel;

  final DataContext _initialDataContext;
  final SinglePageModel _pageModel;

  /// The reference to DataContext is needed for API invoked before
  /// the page load. In these cases we do not have the context to travel
  /// to the DataScopeWidget. This should only be used for this purpose.
  ScopeManager? rootScopeManager;

  //final Widget bodyWidget;
  //final Menu? menu;
  //final Widget? footer;

  @override
  State<Page> createState() => PageState();
}

class PageState extends State<Page> with AutomaticKeepAliveClientMixin {
  late Widget rootWidget;
  late ScopeManager _scopeManager;

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
  }

  @override
  void initState() {
    _scopeManager = ScopeManager(
        widget._initialDataContext.clone(newBuildContext: context),
        PageData(
            customViewDefinitions: widget._pageModel.customViewDefinitions,
            apiMap: widget._pageModel.apiMap));
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScreenController().executeActionWithScope(
            context, _scopeManager, widget._pageModel.viewBehavior.onLoad!);
      });
    }

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
        widget._pageModel.pageStyles?['backgroundGradient']);
    Color? backgroundColor =
        Utils.getColor(widget._pageModel.pageStyles?['backgroundColor']);
    // if we have a background image, set the background color to transparent
    // since our image is outside the Scaffold
    dynamic evaluatedBackgroundImg = _scopeManager.dataContext
        .eval(widget._pageModel.pageStyles?['backgroundImage']);
    BackgroundImage? backgroundImage =
        Utils.getBackgroundImage(evaluatedBackgroundImg);
    if (backgroundImage != null || backgroundGradient != null) {
      backgroundColor = Colors.transparent;
    }

    // whether to usse CustomScrollView for the entire page
    bool isScrollableView =
        widget._pageModel.pageStyles?['scrollableView'] == true;

    PreferredSizeWidget? fixedAppBar;
    if (!isScrollableView) {
      fixedAppBar = buildFixedAppBar(widget._pageModel, hasDrawer);
    }

    // whether we have a header and if the close button is already there
    bool hasHeader = widget._pageModel.headerModel != null || hasDrawer;
    bool? showNavigationIcon =
        widget._pageModel.pageStyles?['showNavigationIcon'];

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
      child: Scaffold(
          resizeToAvoidBottomInset: true,
          // slight optimization, if body background is set, let's paint
          // the entire screen including the Safe Area
          backgroundColor: backgroundColor,

          // appBar is inside CustomScrollView if defined
          appBar: fixedAppBar,
          body: isScrollableView
              ? buildScrollablePageContent(hasDrawer)
              : buildFixedPageContent(fixedAppBar != null),
          bottomNavigationBar: _bottomNavBar,
          drawer: _drawer,
          endDrawer: _endDrawer,
          bottomSheet: _buildFooter(
            _scopeManager,
            widget._pageModel,
          ),
          floatingActionButton: closeModalButton,
          floatingActionButtonLocation:
              widget._pageModel.pageStyles?['navigationIconPosition'] == 'start'
                  ? FloatingActionButtonLocation.startTop
                  : FloatingActionButtonLocation.endTop),
    );

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
        Utils.optionalBool(widget._pageModel.pageStyles?['useSafeArea']);

    // backward compatible with legacy attribute
    if (useSafeArea == null) {
      bool? ignoreSafeArea =
          Utils.optionalBool(widget._pageModel.pageStyles?['ignoreSafeArea']);
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
        minWidth: minGap
            .toDouble(), // this is important for optimal default item spacing
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

      return Row(
          crossAxisAlignment: CrossAxisAlignment.start, children: content);
    }

    return SafeArea(top: _useSafeArea, bottom: _useSafeArea, child: rootWidget);
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
      iconWidget = customWidget.childWidget;
    }
    return iconWidget;
  }

  void selectNavigationIndex(BuildContext context, MenuItem menuItem) {
    ScreenController().navigateToScreen(context, screenName: menuItem.page);
  }

  Widget? _buildFooter(ScopeManager scopeManager, SinglePageModel pageModel) {
    // Footer can only take 1 child by our design. Ignore the rest
    if (pageModel.footer != null && pageModel.footer!.children.isNotEmpty) {
      final footerStyles = pageModel.footer?.styles;
      final boxController = BoxController()
        ..padding = Utils.getInsets(footerStyles?['padding'])
        ..margin = Utils.optionalInsets(footerStyles?['margin'])
        ..width = Utils.optionalInt(footerStyles?['width'])
        ..height = Utils.optionalInt(footerStyles?['height'])
        ..backgroundColor = Utils.getColor(footerStyles?['backgroundColor'])
        ..backgroundGradient =
            Utils.getBackgroundGradient(footerStyles?['backgroundGradient'])
        ..shadowColor = Utils.getColor(footerStyles?['shadowColor'])
        ..borderRadius = Utils.getBorderRadius(footerStyles?['borderRadius'])
        ..borderColor = Utils.getColor(footerStyles?['borderColor'])
        ..borderWidth = Utils.optionalInt(footerStyles?['borderWidth']);

      return AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 500),
        child: BoxWrapper(
          boxController: boxController,
          widget: scopeManager.buildWidget(pageModel.footer!.children.first),
        ),
      );
    }
    return null;
  }

  @override
  void dispose() {
    //log('Disposing View ${widget.hashCode}');
    _scopeManager.dispose();
    //_scopeManager.debugListenerMap();
    super.dispose();
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
