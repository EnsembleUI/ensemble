import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/context.dart';
import 'package:ensemble/framework/data.dart';
import 'package:ensemble/framework/icon.dart' as ensemble;
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

/// The root View. Every Ensemble page will have at least one at its root
class View extends StatefulWidget {
  View(
      this._scopeManager,
      this.bodyWidget,
      {
        this.menu,
        this.footer
      }) : super(key: ValueKey(_scopeManager.pageData.pageName));

  // The Scope for our View, which all widgets will have access to.
  // Note that there can be many descendant scopes under our root scope.
  final ScopeManager _scopeManager;

  final Widget bodyWidget;
  final Menu? menu;
  final Widget? footer;

  @override
  State<View> createState() => ViewState();


}

class ViewState extends State<View>{
  @override
  Widget build(BuildContext context) {
    PageData pageData = widget._scopeManager.pageData;

    // modal page has certain criteria (no navBar, no header)
    if (pageData.pageType == PageType.modal) {
      // need a close button to go back to non-modal pages
      // also animate up and down (vs left and right)
      return Scaffold(
          body: DataScopeWidget(
            scopeManager: widget._scopeManager,
            child: widget.bodyWidget,
          ),
          bottomSheet: widget.footer);
    }
    // regular page
    else {

      // navigation
      Widget? bottomNavBar;
      Widget? drawer;
      if (widget.menu != null && widget.menu!.menuItems.length >= 2 ) {
        if (widget.menu!.display == MenuDisplay.navBar) {
          bottomNavBar = _buildBottomNavBar(context, widget.menu!.menuItems);
        } else if (widget.menu!.display == MenuDisplay.drawer) {
          drawer = _buildDrawer(context, widget.menu!.menuItems);
        }
        // left/right navBar will be rendered differently in the body
      }

      // use the AppBar if we have a title, or have a drawer (to show the menu)
      bool showAppBar = pageData.pageTitle != null || drawer != null;
      if (widget.menu != null &&
          (widget.menu!.display == MenuDisplay.navBar_left ||
          widget.menu!.display == MenuDisplay.navBar_right)) {
        showAppBar = false;
      }

      Color? backgroundColor =
        pageData.pageStyles?['backgroundColor'] is int ?
        Color(pageData.pageStyles!['backgroundColor']) :
        null;
      // if we have a background image, set the background color to transparent
      // since our image is outside the Scaffold
      bool showBackgroundImage = false;
      if (backgroundColor == null && pageData.pageStyles?['backgroundImage'] != null) {
        showBackgroundImage = true;
        backgroundColor = Colors.transparent;
      }

      Widget scaffold = Scaffold(
        // slight optimization, if body background is set, let's paint
        // the entire screen including the Safe Area
        backgroundColor: backgroundColor,
        appBar: !showAppBar ? null : AppBar(
              title: Text(pageData.pageTitle!)),
        body: DataScopeWidget(
          scopeManager: widget._scopeManager,
          child: getBody(),
        ),
        bottomNavigationBar: bottomNavBar,
        drawer: drawer,
        bottomSheet: widget.footer,
      );

      // if backgroundImage is set, put it outside of the Scaffold so
      // keyboard sliding up (when entering value) won't resize the background
      if (showBackgroundImage) {
        return Container(
          constraints: const BoxConstraints.expand(),
          decoration: BoxDecoration(
            image: DecorationImage (
              image: NetworkImage(pageData.pageStyles!['backgroundImage']!.toString()),
              fit: BoxFit.cover
            )
          ),
          child: scaffold
        );
      }
      return scaffold;


    }
  }

  Widget getBody () {

    if (widget.menu != null && widget.menu!.display == MenuDisplay.navBar_left) {
      List<MenuItem> menuItems = widget.menu!.menuItems;
      int selectedIndex = 0;
      List<NavigationRailDestination> navItems = [];
      for (int i=0; i<menuItems.length; i++) {
        MenuItem item = menuItems[i];
        navItems.add(NavigationRailDestination(
            icon: ensemble.Icon(item.icon ?? '', library: item.iconLibrary),
            label: Text(item.label ?? '')));
        if (item.selected) {
          selectedIndex = i;
        }
      }

      // TODO: consolidate buildWidget into 1 place
      Widget? menuHeader;
      if (widget.menu!.headerModel != null) {
        menuHeader = widget._scopeManager.buildWidget(widget.menu!.headerModel!);
      }
      Widget? menuFooter;
      if (widget.menu!.footerModel != null) {
        menuFooter = widget._scopeManager.buildWidget(widget.menu!.footerModel!);
      }


      NavigationRail menu = NavigationRail(
        labelType: NavigationRailLabelType.all,
        leading: menuHeader,
        destinations: navItems,
        trailing: menuFooter,
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => selectNavigationIndex(context, menuItems[index]),
      );

      return Row(
        children: [
          menu,
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: SafeArea(
              child: widget.bodyWidget))
        ],
      );
    }

    return SafeArea(
        child: widget.bodyWidget
    );
  }



  Drawer? _buildDrawer(BuildContext context, List<MenuItem> menuItems) {
    List<ListTile> navItems = [];
    for (MenuItem item in menuItems) {
      navItems.add(ListTile(
        selected: item.selected,
        title: Text(item.label ?? ''),
        leading: ensemble.Icon(item.icon ?? '', library: item.iconLibrary),
        horizontalTitleGap: 0,
        onTap: () => selectNavigationIndex(context, item),
      ));
    }
    return Drawer(
      child: ListView(
        children: navItems,
      ),
    );

  }

  /// navigation bar
  BottomNavigationBar? _buildBottomNavBar(BuildContext context, List<MenuItem> menuItems) {
    int selectedIndex = 0;
    List<BottomNavigationBarItem> navItems = [];
    for (int i=0; i<menuItems.length; i++) {
      MenuItem item = menuItems[i];
      navItems.add(BottomNavigationBarItem(
          icon: ensemble.Icon(item.icon ?? '', library: item.iconLibrary),
          label: item.label ?? ''));
      if (item.selected) {
        selectedIndex = i;
      }
    }
    return BottomNavigationBar(
        items: navItems,
        onTap: (index) {
          if (!menuItems[index].selected) {
            selectNavigationIndex(context, menuItems[index]);
          }
        },
        currentIndex: selectedIndex);

  }

  void selectNavigationIndex(BuildContext context, MenuItem menuItem) {
    Ensemble().navigateToPage(context, menuItem.page, replace: true);
  }

}



/// a wrapper InheritedWidget to expose the ScopeManager
/// to every widgets in our tree
class DataScopeWidget extends InheritedWidget {
  const DataScopeWidget({
    Key? key,
    required this.scopeManager,
    required Widget child
  }) : super(key: key, child: child);

  final ScopeManager scopeManager;

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return false;
  }

  /// return the ScopeManager which includes the dataContext
  static ScopeManager? getScope(BuildContext context) {
    DataScopeWidget? viewWidget = context.dependOnInheritedWidgetOfExactType<DataScopeWidget>();
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
