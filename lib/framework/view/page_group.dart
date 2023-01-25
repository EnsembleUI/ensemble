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

      // drawer menu will be injected in the child Page, so we wraps
      // the widget in a provider such that its children can get access
      // to the drawer menu.
      if (display == MenuDisplay.drawer || display == MenuDisplay.endDrawer) {
        Drawer? drawer = _buildDrawer(context, widget.menu);
        return PageGroupWidget(
          scopeManager: _scopeManager,
          navigationDrawer: display == MenuDisplay.drawer ? drawer : null,
          navigationEndDrawer: display == MenuDisplay.endDrawer ? drawer : null,
          child: IndexedStack(children: pageWidgets, index: selectedPage)
        );
      }
      else if (display == MenuDisplay.leftNavBar) {

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
    // left nav becomes drawer in lower resolution
    if (display == MenuDisplay.leftNavBar && screenWidth < 1000) {
      display = MenuDisplay.drawer;
    }
    display ??= MenuDisplay.bottomNavBar;

    return display;
  }

}