import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/context.dart';
import 'package:ensemble/framework/icon.dart' as ensemble;
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

/// The root View. Every Ensemble page will have at least one at the root
class View extends StatefulWidget {
  View(
      this.pageData,
      this.bodyWidget,
      {
        this.menu,
        this.footer
      }) : super(key: ValueKey(pageData.pageName));

  final ViewState currentState = ViewState();
  final PageData pageData;
  final Widget bodyWidget;
  final Menu? menu;
  final Widget? footer;

  @override
  State<View> createState() => currentState;

  ViewState getState() {
    return currentState;
  }


}

class ViewState extends State<View>{
  @override
  Widget build(BuildContext context) {

    // modal page has certain criteria (no navBar, no header)
    if (widget.pageData.pageType == PageType.modal) {
      // need a close button to go back to non-modal pages
      // also animate up and down (vs left and right)
      return Scaffold(
          body: widget.bodyWidget,
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
      bool showAppBar = widget.pageData.pageTitle != null || drawer != null;
      if (widget.menu != null &&
          (widget.menu!.display == MenuDisplay.navBar_left ||
          widget.menu!.display == MenuDisplay.navBar_right)) {
        showAppBar = false;
      }

      Color? backgroundColor =
        widget.pageData.pageStyles?['backgroundColor'] is int ?
        Color(widget.pageData.pageStyles!['backgroundColor']) :
        null;
      // if we have a background image, set the background color to transparent
      // since our image is outside the Scaffold
      bool showBackgroundImage = false;
      if (backgroundColor == null && widget.pageData.pageStyles?['backgroundImage'] != null) {
        showBackgroundImage = true;
        backgroundColor = Colors.transparent;
      }

      Widget scaffold = Scaffold(
        // slight optimization, if body background is set, let's paint
        // the entire screen including the Safe Area
        backgroundColor: backgroundColor,
        appBar: !showAppBar ? null : AppBar(
              title: Text(widget.pageData.pageTitle!)),
        body: getBody(),
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
              image: NetworkImage(widget.pageData.pageStyles!['backgroundImage']!.toString()),
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
        menuHeader = ScreenController().buildWidget(widget.pageData._eContext, widget.menu!.headerModel!);
      }
      Widget? menuFooter;
      if (widget.menu!.footerModel != null) {
        menuFooter = ScreenController().buildWidget(widget.pageData._eContext, widget.menu!.footerModel!);
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




/// data for the current page
class PageData {
  PageData({
    required this.pageName,
    required this.datasourceMap,
    required EnsembleContext eContext,
    this.subViewDefinitions,
    this.pageStyles,
    this.pageTitle,
    this.pageType,
    this.apiMap
  }) {
    _eContext = eContext;
  }

  final String? pageTitle;

  final PageType? pageType;

  // unique page name
  final String pageName;

  final Map<String, dynamic>? pageStyles;

  // store the data sources (e.g API result) and their callbacks
  final Map<String, ActionResponse> datasourceMap;

  // store the raw definition of the SubView (to be accessed by itemTemplates)
  final Map<String, YamlMap>? subViewDefinitions;

  // arguments passed into this page
  late final EnsembleContext _eContext;

  // API model mapping
  Map<String, YamlMap>? apiMap;

  /// everytime we call this, we make sure any populated API result will have its updated values here
  EnsembleContext getEnsembleContext() {
    for (var element in datasourceMap.values) {
      if (element._resultData != null) {
        _eContext.addDataContext(element._resultData!);
      }
    }
    return _eContext;
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
