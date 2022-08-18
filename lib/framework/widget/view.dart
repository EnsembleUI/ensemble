import 'dart:developer';
import 'dart:math';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/widget/icon.dart' as ensemble;
import 'package:ensemble/page_model.dart';
import 'package:ensemble/page_model.dart' as model;
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';

/// The root View. Every Ensemble page will have at least one at its root
class View extends StatefulWidget {
  View({
    Key? key,
    required DataContext dataContext,
    required PageModel pageModel,
  }) : super(key: key) {
    _initialDataContext = dataContext;
    _pageModel = pageModel;
  }

  late final DataContext _initialDataContext;
  late final PageModel _pageModel;

  /// The reference to DataContext is needed for API invoked before
  /// the page load. In these cases we do not have the context to travel
  /// to the DataScopeWidget. This should only be used for this purpose.
  late ScopeManager rootScopeManager;


  /**
   * PageData pageData = PageData(
      pageTitle: pageModel.title,
      pageStyles: pageModel.pageStyles,
      pageName: pageName,
      pageType: pageModel.pageType,
      datasourceMap: {},
      customViewDefinitions: pageModel.customViewDefinitions,
      //dataContext: pageModel.dataContext,
      apiMap: apiMap
      );
   */



  //final Widget bodyWidget;
  //final Menu? menu;
  //final Widget? footer;

  @override
  State<View> createState() => ViewState();


}


class ViewState extends State<View>{
  late ScopeManager _scopeManager;
  String menuDisplay = MenuDisplay.navBar.name;
  late Widget rootWidget;

  @override
  void initState() {
    // initialize our root ScopeManager, which can have many child scopes.
    // All scopes will have access to the page-level PageData
    _scopeManager = ScopeManager(
      widget._initialDataContext.clone(newBuildContext: context),
      PageData(
          customViewDefinitions: widget._pageModel.customViewDefinitions,
          apiMap: widget._pageModel.apiMap
      )
    );
    widget.rootScopeManager = _scopeManager;

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

    buildRootWidget();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Widget? bottomNavBar;
    Widget? drawer;
    bool showAppBar = false;

    // modal page has certain criteria (no navBar, no header)
    if (widget._pageModel.pageType != PageType.modal) {
      // navigation
      if (widget._pageModel.menu != null &&
          widget._pageModel.menu!.menuItems.length >= 2) {

        if (widget._pageModel.menu!.display != null) {
          menuDisplay = _scopeManager.dataContext.eval(widget._pageModel.menu!.display);
          if (menuDisplay == MenuDisplay.navBar.name) {
            bottomNavBar = _buildBottomNavBar(context, widget._pageModel.menu!.menuItems);
          } else if (menuDisplay == MenuDisplay.drawer.name) {
            drawer = _buildDrawer(context, widget._pageModel.menu!.menuItems);
          }
        }
        // left/right navBar will be rendered as part of the body
      }

      // use the AppBar if we have a title, or have a drawer (to show the menu)
      showAppBar = widget._pageModel.title != null || drawer != null;
      if (menuDisplay == MenuDisplay.navBar_left.name ||
              menuDisplay == MenuDisplay.navBar_right.name) {
        showAppBar = false;
      }
    }

    Color? backgroundColor =
      widget._pageModel.pageStyles?['backgroundColor'] is int ?
      Color(widget._pageModel.pageStyles!['backgroundColor']) :
      null;
    // if we have a background image, set the background color to transparent
    // since our image is outside the Scaffold
    bool showBackgroundImage = false;
    if (backgroundColor == null && widget._pageModel.pageStyles?['backgroundImage'] != null) {
      showBackgroundImage = true;
      backgroundColor = Colors.transparent;
    }

    Widget rtn = DataScopeWidget(
      scopeManager: _scopeManager,
      child: Scaffold(
        // slight optimization, if body background is set, let's paint
        // the entire screen including the Safe Area
        backgroundColor: backgroundColor,
        appBar: !showAppBar ? null : AppBar(
              title: Text(Utils.translate(widget._pageModel.title ?? '', context))),
        body: getBody(),
        bottomNavigationBar: bottomNavBar,
        drawer: drawer,
        bottomSheet: _buildFooter(_scopeManager, widget._pageModel),
      ),
    );

    // if backgroundImage is set, put it outside of the Scaffold so
    // keyboard sliding up (when entering value) won't resize the background
    if (showBackgroundImage) {
      return Container(
        constraints: const BoxConstraints.expand(),
        decoration: BoxDecoration(
          image: DecorationImage (
            image: buildBackgroundImage(widget._pageModel.pageStyles!['backgroundImage']!.toString()),
            fit: BoxFit.cover
          )
        ),
        child: rtn
      );
    }
    return rtn;

  }

  ImageProvider buildBackgroundImage(String source) {
    if (source.startsWith('https://') || source.startsWith('http://')) {
      return NetworkImage(source);
    }
    // attempt local asset
    return AssetImage('assets/images/$source');
  }

  Widget getBody () {

    if (menuDisplay == MenuDisplay.navBar_left.name) {
      List<model.MenuItem> menuItems = widget._pageModel.menu!.menuItems;
      int selectedIndex = 0;
      List<NavigationRailDestination> navItems = [];
      for (int i=0; i<menuItems.length; i++) {
        model.MenuItem item = menuItems[i];
        navItems.add(NavigationRailDestination(
          padding: Utils.getInsets(widget._pageModel.menu!.styles?['itemPadding']),
          icon: ensemble.Icon(item.icon ?? '', library: item.iconLibrary),
          label: Text(Utils.translate(item.label ?? '', context))));
        if (item.selected) {
          selectedIndex = i;
        }
      }

      // TODO: consolidate buildWidget into 1 place
      double paddingFromSafeSpace = 15;
      Widget? headerWidget;
      if (widget._pageModel.menu!.headerModel != null) {
        headerWidget = _scopeManager.buildWidget(widget._pageModel.menu!.headerModel!);
      }
      Widget menuHeader = Column(children: [
       SizedBox(height: paddingFromSafeSpace),
       Container(
         child: headerWidget,
       )
      ]);

      Widget? menuFooter;
      if (widget._pageModel.menu!.footerModel != null) {
        // push footer to the bottom of the rail
        menuFooter = Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: _scopeManager.buildWidget(widget._pageModel.menu!.footerModel!)
          ),
        );
      }

      MenuItemDisplay itemDisplay = MenuItemDisplay.values.from(widget._pageModel.menu!.styles?['itemDisplay']) ?? MenuItemDisplay.stacked;

      // stacked's min gap seems to be 72 regardless of what we set. For side by side optimal min gap is around 40
      // we set this minGap and let user controls with itemPadding
      int minGap = itemDisplay == MenuItemDisplay.sideBySide ? 40 : 72;

      // minExtendedWidth is applicable only for side by side, and should never be below minWidth (or exception)
      int minWidth = Utils.optionalInt(widget._pageModel.menu!.styles?['minWidth'], min: minGap) ?? 200;



      List<Widget> content = [];
      // process menu styles
      Color? menuBackground = Utils.getColor(widget._pageModel.menu!.styles?['backgroundColor']);
      content.add(NavigationRail(
        extended: itemDisplay == MenuItemDisplay.sideBySide ? true : false,
        minExtendedWidth: minWidth.toDouble(),
        minWidth: minGap.toDouble(),     // this is important for optimal default item spacing
        labelType: itemDisplay != MenuItemDisplay.sideBySide ? NavigationRailLabelType.all : null,
        backgroundColor: menuBackground,
        leading: menuHeader,
        destinations: navItems,
        trailing: menuFooter,
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => selectNavigationIndex(context, menuItems[index]),
      ));

      // show a divider between the NavigationRail and the content
      Color? borderColor = Utils.getColor(widget._pageModel.menu!.styles?['borderColor']);
      int? borderWidth = Utils.optionalInt(widget._pageModel.menu!.styles?['borderWidth']);
      if (borderColor != null || borderWidth != null) {
        content.add(VerticalDivider(
          thickness: (borderWidth ?? 1).toDouble(),
          width: (borderWidth ?? 1).toDouble(),
          color: borderColor
        ));
      }

      // add the bodyWidget
      content.add(Expanded(
          child: SafeArea(
            top: widget._pageModel.pageType == PageType.modal ? false : true,
              child: rootWidget)));

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: content);
    }

    return SafeArea(
        top: widget._pageModel.pageType == PageType.modal ? false : true,
        child: rootWidget
    );
  }



  Drawer? _buildDrawer(BuildContext context, List<model.MenuItem> menuItems) {
    List<ListTile> navItems = [];
    for (model.MenuItem item in menuItems) {
      navItems.add(ListTile(
        selected: item.selected,
        title: Text(Utils.translate(item.label ?? '', context)),
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
  BottomNavigationBar? _buildBottomNavBar(BuildContext context, List<model.MenuItem> menuItems) {
    int selectedIndex = 0;
    List<BottomNavigationBarItem> navItems = [];
    for (int i=0; i<menuItems.length; i++) {
      model.MenuItem item = menuItems[i];
      navItems.add(BottomNavigationBarItem(
          icon: ensemble.Icon(item.icon ?? '', library: item.iconLibrary),
          label: item.label ?? ''));
      if (item.selected) {
        selectedIndex = i;
      }
    }
    return BottomNavigationBar(
        items: navItems,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (!menuItems[index].selected) {
            selectNavigationIndex(context, menuItems[index]);
          }
        },
        currentIndex: selectedIndex);

  }

  void selectNavigationIndex(BuildContext context, model.MenuItem menuItem) {
    Ensemble().navigateApp(context, screenName: menuItem.page);
  }


  Widget? _buildFooter(ScopeManager scopeManager, PageModel pageModel) {
    // Footer can only take 1 child by our design. Ignore the rest
    if (pageModel.footer != null && pageModel.footer!.children.isNotEmpty) {
      return AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 500),
          child: SizedBox(
              width: double.infinity,
              height: 110,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 32),
                child: scopeManager.buildWidget(pageModel.footer!.children.first),
              )
          )
      );
    }
    return null;
  }

  @override
  void dispose() {
    //log('Disposing View ${widget.hashCode}');
    _scopeManager.debugListenerMap();
    _scopeManager.eventBus.destroy();
    super.dispose();
  }

  void buildRootWidget() {
    rootWidget = _scopeManager.buildWidget(widget._pageModel.rootWidgetModel);

    // execute Global Code
    if (widget._pageModel.globalCode != null) {
      _scopeManager.dataContext.evalCode(widget._pageModel.globalCode!);
    }
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
