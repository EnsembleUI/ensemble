import 'dart:developer';

import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/page.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/framework/widget/icon.dart' as ensemble;
import 'package:ensemble/page_model.dart' as model;
import 'package:ensemble/framework/extensions.dart';

/// a collection of pages grouped under a navigation menu
class PageGroup extends StatefulWidget {
  const PageGroup({
    super.key,
    required this.initialDataContext,
    required this.model,
    required this.menu
  });
  final DataContext initialDataContext;
  final PageGroupModel model;
  final Menu menu;

  @override
  State<StatefulWidget> createState() => PageGroupState();
}

/// wrapper widget to enable a Page to get the navigation menu from its parent PageGroup
/// We need this because the menu (i.e. drawer) is determined at the PageGroup
/// level, but need to be injected under each child Page to render.
class PageGroupWidget extends DataScopeWidget {
  const PageGroupWidget({
    super.key,
    required super.scopeManager,
    required super.child,
    this.navigationDrawer,
    this.navigationEndDrawer
  });
  final Drawer? navigationDrawer;
  final Drawer? navigationEndDrawer;

  static Drawer? getNavigationDrawer(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PageGroupWidget>()
      ?.navigationDrawer;

  static Drawer? getNavigationEndDrawer(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PageGroupWidget>()
      ?.navigationEndDrawer;

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return true;
  }
}

class PageGroupState extends State<PageGroup> with MediaQueryCapability {
  late ScopeManager _scopeManager;

  // managing the list of pages
  List<Widget> pageWidgets = [];
  int selectedPage = 0;

  @override
  void initState() {
    super.initState();
    _scopeManager = ScopeManager(
        widget.initialDataContext.clone(newBuildContext: context),
        PageData(
            customViewDefinitions: widget.model.customViewDefinitions,
            apiMap: widget.model.apiMap
        )
    );

    // init the pages (TODO: need to update if definition changes)
    for (int i=0; i<widget.menu.menuItems.length; i++) {
      model.MenuItem menuItem = widget.menu.menuItems[i];
      pageWidgets.add(ScreenController().getScreen(
          screenName: menuItem.page
      ));
      if (menuItem.selected) {
        selectedPage = i;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // skip rendering the menu if only 1 menu item, just the content itself
    if (widget.menu.menuItems.length == 1) {
      return pageWidgets[0];
    } else if (widget.menu.menuItems.length >= 2) {
      MenuDisplay display = _getPreferredMenuDisplay(widget.menu);

      // drawer menu will be injected in the child Page since the icon
      // has to be on the header, which only exists on the Page.
      // Here we wrap the widget in a provider such that its children
      // can get access to the drawer menu.
      if (display == MenuDisplay.drawer || display == MenuDisplay.endDrawer) {
        Drawer? drawer = _buildDrawer(context, widget.menu);
        return PageGroupWidget(
          scopeManager: _scopeManager,
          navigationDrawer: display == MenuDisplay.drawer ? drawer : null,
          navigationEndDrawer: display == MenuDisplay.endDrawer ? drawer : null,
          child: IndexedStack(children: pageWidgets, index: selectedPage)
        );
      }
      else if (display == MenuDisplay.sidebar || display == MenuDisplay.endSidebar) {
        return buildSidebarNavigation(context, display, widget.menu);
      }
      else if (display == MenuDisplay.bottomNavBar){
        return Scaffold(
          bottomNavigationBar: _buildBottomNavBar(context, widget.menu),
          body: IndexedStack(children: pageWidgets, index: selectedPage)
        );
      }
    }
    throw LanguageError('ViewGroup requires a menu and at least one page.');
  }

  /// build the sidebar and its children content
  Widget buildSidebarNavigation(BuildContext context, MenuDisplay preferredMenuDisplay, Menu menu) {
    Widget sidebar = _buildSidebar(context, menu);
    Widget? separator = _buildSidebarSeparator(menu);
    Widget content = Expanded(
      child: IndexedStack(children: pageWidgets, index: selectedPage)
    );

    // figuring out the direction to lay things out
    bool rtlLocale = Directionality.of(context) == TextDirection.rtl;
    // standard layout is the sidebar menu then content
    bool standardLayout = preferredMenuDisplay == MenuDisplay.sidebar ? !rtlLocale : rtlLocale;

    List<Widget> children = [];
    if (standardLayout) {
      children.add(sidebar);
      if (separator != null) {
        children.add(separator);
      }
      children.add(content);
    } else {
      children.add(content);
      if (separator != null) {
        children.add(separator);
      }
      children.add(sidebar);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  // build the sidebar with optional header/footer
  Widget _buildSidebar(BuildContext context, Menu menu) {
    // sidebar header
    double paddingFromSafeSpace = 15;
    Widget? headerWidget;
    if (menu.headerModel != null) {
      headerWidget = _scopeManager.buildWidget(menu.headerModel!);
    }
    Widget menuHeader = Column(children: [
      SizedBox(height: paddingFromSafeSpace),
      Container(
        child: headerWidget,
      )
    ]);

    // build each menu item
    List<NavigationRailDestination> navItems = [];
    for (var item in menu.menuItems) {
      navItems.add(NavigationRailDestination(
          padding: Utils.getInsets(menu.styles?['itemPadding']),
          icon: ensemble.Icon(item.icon ?? '', library: item.iconLibrary),
          label: Text(Utils.translate(item.label ?? '', context))));
    }

    // sidebar footer
    Widget? menuFooter;
    if (menu.footerModel != null) {
      // push footer to the bottom of the rail
      menuFooter = Expanded(
        child: Align(
            alignment: Alignment.bottomCenter,
            child: _scopeManager.buildWidget(menu.footerModel!)
        ),
      );
    }

    // misc styles
    Color? menuBackground = Utils.getColor(menu.styles?['backgroundColor']);
    MenuItemDisplay itemDisplay = MenuItemDisplay.values.from(
        menu.styles?['itemDisplay']
    ) ?? MenuItemDisplay.stacked;

    // stacked's min gap seems to be 72 regardless of what we set. For side by side optimal min gap is around 40
    // we set this minGap and let user controls with itemPadding
    int minGap = itemDisplay == MenuItemDisplay.sideBySide ? 40 : 72;

    // minExtendedWidth is applicable only for side by side, and should never be below minWidth (or exception)
    int minWidth = Utils.optionalInt(menu.styles?['minWidth'], min: minGap) ?? 200;

    return NavigationRail(
      extended: itemDisplay == MenuItemDisplay.sideBySide ? true : false,
      minExtendedWidth: minWidth.toDouble(),
      minWidth: minGap.toDouble(),     // this is important for optimal default item spacing
      labelType: itemDisplay != MenuItemDisplay.sideBySide ? NavigationRailLabelType.all : null,
      backgroundColor: menuBackground,
      leading: menuHeader,
      destinations: navItems,
      trailing: menuFooter,
      selectedIndex: selectedPage,
      onDestinationSelected: (index) {
        setState(() {
          selectedPage = index;
        });
      },
    );
  }

  Widget? _buildSidebarSeparator(Menu menu) {
    Color? borderColor = Utils.getColor(menu.styles?['borderColor']);
    int? borderWidth = Utils.optionalInt(menu.styles?['borderWidth']);
    if (borderColor != null || borderWidth != null) {
      return VerticalDivider(
          thickness: (borderWidth ?? 1).toDouble(),
          width: (borderWidth ?? 1).toDouble(),
          color: borderColor
      );
    }
    return null;
  }

  /// Build a Bottom Navigation Bar (default if display is not specified)
  BottomNavigationBar? _buildBottomNavBar(BuildContext context, Menu menu) {
    List<BottomNavigationBarItem> navItems = [];
    for (int i=0; i<menu.menuItems.length; i++) {
      model.MenuItem item = menu.menuItems[i];
      navItems.add(BottomNavigationBarItem(
          icon: ensemble.Icon(item.icon ?? '', library: item.iconLibrary),
          label: Utils.translate(item.label ?? '', context)));
    }
    return BottomNavigationBar(
        items: navItems,
        backgroundColor: Utils.getColor(menu.styles?['backgroundColor']),
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            selectedPage = index;
          });
        },
        currentIndex: selectedPage);

  }

  Drawer? _buildDrawer(BuildContext context, Menu menu) {
    List<ListTile> navItems = [];
    for (var i=0; i<menu.menuItems.length; i++) {
      model.MenuItem item = menu.menuItems[i];
      navItems.add(ListTile(
        selected: i == selectedPage,
        title: Text(Utils.translate(item.label ?? '', context)),
        leading: ensemble.Icon(item.icon ?? '', library: item.iconLibrary),
        horizontalTitleGap: 0,
        onTap: () {
          setState(() {
            //close the drawer
            Navigator.maybePop(context);
            selectedPage = i;
          });
        },
      ));
    }
    return Drawer(
      backgroundColor: Utils.getColor(menu.styles?['backgroundColor']),
      child: ListView(
        children: navItems,
      ),
    );
  }


  /// get the menu mode depending on user spec + device types / screen resolutions
  MenuDisplay _getPreferredMenuDisplay(Menu menu) {
    MenuDisplay? display = MenuDisplay.values.from(
        _scopeManager.dataContext.eval(menu.display)
    );
    log("screen width " + screenWidth.toString());
    // left nav becomes drawer in lower resolution. TODO: take in user settings
    if (screenWidth < 900) {
      if (display == MenuDisplay.sidebar) {
        display = MenuDisplay.drawer;
      } else if (display == MenuDisplay.endSidebar) {
        display = MenuDisplay.endDrawer;
      }
    }
    display ??= MenuDisplay.bottomNavBar;

    return display;
  }

}