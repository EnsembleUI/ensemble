import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/framework/widget/icon.dart' as ensemble;
import 'package:ensemble/page_model.dart' as model;
import 'package:ensemble/framework/extensions.dart';

/// a collection of page behind a navigation menu
class PageGroup extends StatefulWidget {
  const PageGroup({
    super.key,
    required this.initialDataContext,
    required this.pageModel,
    required this.menu
  });
  final DataContext initialDataContext;
  final PageGroupModel pageModel;
  final Menu menu;

  @override
  State<StatefulWidget> createState() => PageGroupState();
}


class PageGroupState extends State<PageGroup> with MediaQueryCapability {
  late ScopeManager _scopeManager;

  // list of pages and the selectd one
  List<Widget> pageWidgets = [];
  int selectedPage = 0;

  @override
  void initState() {
    super.initState();
    _scopeManager = ScopeManager(
        widget.initialDataContext.clone(newBuildContext: context),
        PageData(
            customViewDefinitions: widget.pageModel.customViewDefinitions,
            apiMap: widget.pageModel.apiMap
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
    if (widget.menu.menuItems.length >= 2) {
      MenuDisplay display = _getPreferredMenuDisplay(widget.menu);

      // left nav bar is special as only its child content is inside Scaffold
      if (display == MenuDisplay.leftNavBar) {

      } else {
        return _addPageNavigation(display);
      }
    }
    return Text("unsupported");
  }

  /// add standards navigation menus
  Widget _addPageNavigation(MenuDisplay display) {
    BottomNavigationBar? bottomNavBar;
    if (display == MenuDisplay.bottomNavBar) {
      bottomNavBar = _buildBottomNavBar(context, widget.menu);
    }

    Drawer? drawer;
    if (display == MenuDisplay.drawer) {

    }


    return Scaffold(
      bottomNavigationBar: bottomNavBar,
      body: IndexedStack(children: pageWidgets, index: selectedPage),
    );

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


  // get the menu mode depending on user spec + device types / screen resolutions
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