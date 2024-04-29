import 'dart:developer';

import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/menu.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/theme_manager.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/view/page.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/framework/widget/icon.dart' as ensemble;
import 'package:ensemble/page_model.dart' as model;
import 'package:ensemble/framework/extensions.dart';

import '../widget/custom_view.dart';
import 'bottom_nav_page_group.dart';

/// a collection of pages grouped under a navigation menu
class PageGroup extends StatefulWidget {
  const PageGroup(
      {super.key,
      required this.initialDataContext,
      required this.model,
      required this.menu,
      this.pageArgs});

  // keep it simple, all pages under PageGroup receives the same
  // input arguments that the PageGroup is getting
  final Map<String, dynamic>? pageArgs;

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
    this.navigationEndDrawer,
    this.pageController,
  });

  final Drawer? navigationDrawer;
  final Drawer? navigationEndDrawer;
  final PageController? pageController;

  static Drawer? getNavigationDrawer(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PageGroupWidget>()
      ?.navigationDrawer;

  static Drawer? getNavigationEndDrawer(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PageGroupWidget>()
      ?.navigationEndDrawer;

  static PageController? getPageController(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PageGroupWidget>()
      ?.pageController;

  /// return the ScopeManager which includes the dataContext
  /// TODO: have to repeat this function in DataScopeWidget?
  static ScopeManager? getScope(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<PageGroupWidget>()
        ?.scopeManager;
  }

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return true;
  }
}

class PageGroupState extends State<PageGroup> with MediaQueryCapability {
  late ScopeManager _scopeManager;

  // managing the list of pages
  List<ScreenPayload> pagePayloads = [];
  List<Widget> pageWidgets = [];

  @override
  void initState() {
    super.initState();
    _scopeManager = ScopeManager(
      widget.initialDataContext.clone(newBuildContext: context),
      PageData(
        customViewDefinitions: widget.model.customViewDefinitions,
        apiMap: widget.model.apiMap,
        socketData: widget.model.socketData,
      ),
    );

    int? selectedIndex = Utils.optionalInt(widget.pageArgs?["viewIndex"],
        min: 0, max: widget.menu.menuItems.length - 1);
    // init the pages (TODO: need to update if definition changes)
    for (int i = 0; i < widget.menu.menuItems.length; i++) {
      MenuItem menuItem = widget.menu.menuItems[i];
      pagePayloads.add(
        ScreenPayload(
          screenName: menuItem.page,
          arguments: widget.pageArgs,
          isExternal: menuItem.isExternal,
        ),
      );
      pageWidgets.add(ScreenController().getScreen(
        key: UniqueKey(),
        // ensure each screen is different for Flutter not to optimize
        screenName: menuItem.page,
        pageArgs: widget.pageArgs,
        isExternal: menuItem.isExternal,
      ));
      // mark as selected only if selectedIndex is not passed
      if (selectedIndex == null) {
        dynamic selected = _scopeManager.dataContext.eval(menuItem.selected);
        if (selected == true || selected == 'true') {
          viewGroupNotifier.updatePage(i, isReload: false);
        }
      }
    }
    // select a page if passed via argument
    if (selectedIndex != null) {
      viewGroupNotifier.updatePage(selectedIndex, isReload: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    EnsembleThemeManager()
        .configureStyles(_scopeManager.dataContext, widget.menu, widget.menu);
    // skip rendering the menu if only 1 menu item, just the content itself
    if (widget.menu.menuItems.length == 1) {
      return pageWidgets[0];
    } else if (widget.menu.menuItems.length >= 2) {
      // drawer menu will be injected in the child Page since the icon
      // has to be on the header, which only exists on the Page.
      // Here we wrap the widget in a provider such that its children
      // can get access to the drawer menu.
      if (widget.menu is DrawerMenu) {
        Drawer? drawer = _buildDrawer(context, widget.menu);
        bool atStart = (widget.menu as DrawerMenu).atStart;
        return ListenableBuilder(
          listenable: viewGroupNotifier,
          builder: (context, _) {
            final screenPayload = pagePayloads[viewGroupNotifier.viewIndex];
            final screen = ScreenController().getScreen(
              key: UniqueKey(),
              screenName: screenPayload.screenName,
              isExternal: screenPayload.isExternal,
              pageArgs: viewGroupNotifier.payload ?? screenPayload.arguments,
            );
            return PageGroupWidget(
              scopeManager: _scopeManager,
              navigationDrawer: atStart ? drawer : null,
              navigationEndDrawer: !atStart ? drawer : null,
              child: widget.menu.reloadView == true
                  ? screen
                  : IndexedStack(
                      index: viewGroupNotifier.viewIndex,
                      children: pageWidgets,
                    ),
            );
          },
        );
      } else if (widget.menu is SidebarMenu) {
        return PageGroupWidget(
            scopeManager: _scopeManager,
            child: buildSidebarNavigation(context, widget.menu as SidebarMenu));
      } else if (widget.menu is BottomNavBarMenu) {
        return PageGroupWidget(
            scopeManager: _scopeManager,
            child: BottomNavPageGroup(
              scopeManager: _scopeManager,
              selectedPage: viewGroupNotifier.viewIndex,
              menu: widget.menu,
              screenPayload: pagePayloads,
              children: pageWidgets,
            ));
      }
    }
    throw LanguageError('ViewGroup requires a menu and at least one page.');
  }

  /// build the sidebar and its children content
  Widget buildSidebarNavigation(BuildContext context, SidebarMenu menu) {
    Widget sidebar = _buildSidebar(context, menu);
    Widget? separator = _buildSidebarSeparator(menu);
    Widget content = Expanded(
      child: ListenableBuilder(
        listenable: viewGroupNotifier,
        builder: (context, _) {
          final screenPayload = pagePayloads[viewGroupNotifier.viewIndex];
          final screen = ScreenController().getScreen(
            key: UniqueKey(),
            screenName: screenPayload.screenName,
            isExternal: screenPayload.isExternal,
            pageArgs: viewGroupNotifier.payload ?? screenPayload.arguments,
          );
          return menu.reloadView == true
              ? screen
              : IndexedStack(
                  index: viewGroupNotifier.viewIndex,
                  children: pageWidgets,
                );
        },
      ),
    );
    // figuring out the direction to lay things out
    bool rtlLocale = Directionality.of(context) == TextDirection.rtl;
    // standard layout is the sidebar menu then content
    bool standardLayout = menu.atStart ? !rtlLocale : rtlLocale;

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
          padding: Utils.getInsets(menu.runtimeStyles?['itemPadding']),
          icon: item.icon != null
              ? ensemble.Icon.fromModel(item.icon!)
              : const SizedBox.shrink(),
          label: Text(Utils.translate(item.label ?? '', context))));
    }

    // sidebar footer
    Widget? menuFooter;
    if (menu.footerModel != null) {
      // push footer to the bottom of the rail
      menuFooter = Expanded(
        child: Align(
            alignment: Alignment.bottomCenter,
            child: _scopeManager.buildWidget(menu.footerModel!)),
      );
    }

    // misc styles
    Color? menuBackground =
        Utils.getColor(menu.runtimeStyles?['backgroundColor']);
    MenuItemDisplay itemDisplay =
        MenuItemDisplay.values.from(menu.runtimeStyles?['itemDisplay']) ??
            MenuItemDisplay.stacked;

    // stacked's min gap seems to be 72 regardless of what we set. For side by side optimal min gap is around 40
    // we set this minGap and let user controls with itemPadding
    int minGap = itemDisplay == MenuItemDisplay.sideBySide ? 40 : 72;

    // minExtendedWidth is applicable only for side by side, and should never be below minWidth (or exception)
    int minWidth =
        Utils.optionalInt(menu.runtimeStyles?['minWidth'], min: minGap) ?? 200;

    return ListenableBuilder(
      listenable: viewGroupNotifier,
      builder: (context, _) {
        return NavigationRail(
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
          selectedIndex: viewGroupNotifier.viewIndex,
          onDestinationSelected: viewGroupNotifier.updatePage,
        );
      },
    );
  }

  Widget? _buildSidebarSeparator(Menu menu) {
    Color? borderColor = Utils.getColor(menu.runtimeStyles?['borderColor']);
    int? borderWidth = Utils.optionalInt(menu.runtimeStyles?['borderWidth']);
    if (borderColor != null || borderWidth != null) {
      return VerticalDivider(
          thickness: (borderWidth ?? 1).toDouble(),
          width: (borderWidth ?? 1).toDouble(),
          color: borderColor);
    }
    return null;
  }

  // /// Build a Bottom Navigation Bar (default if display is not specified)
  // BottomNavigationBar? _buildBottomNavBar(BuildContext context, Menu menu) {
  //   List<BottomNavigationBarItem> navItems = [];

  //   for (int i = 0; i < menu.menuItems.length; i++) {
  //     MenuItem item = menu.menuItems[i];
  //     // final customItem = menuWidget?.childWidget;
  //     final dynamic customIcon = _buildCustomIcon(item);
  //     final dynamic customActiveIcon = _buildCustomIcon(item, isActive: true);

  //     final isCustom = customIcon != null || customActiveIcon != null;
  //     final label = isCustom ? '' : Utils.translate(item.label ?? '', context);

  //     navItems.add(
  //       BottomNavigationBarItem(
  //         activeIcon: customActiveIcon ??
  //             ensemble.Icon(item.activeIcon ?? item.icon,
  //                 library: item.iconLibrary),
  //         icon: customIcon ??
  //             ensemble.Icon(item.icon ?? '', library: item.iconLibrary),
  //         label: label,
  //       ),
  //     );
  //   }

  //   return BottomNavigationBar(
  //     items: navItems,
  //     backgroundColor: Utils.getColor(menu.styles?['backgroundColor']),
  //     type: BottomNavigationBarType.fixed,
  //     onTap: (index) {
  //       setState(() {
  //         selectedPage = index;
  //       });
  //     },
  //     currentIndex: selectedPage,
  //   );
  // }

  Drawer? _buildDrawer(BuildContext context, Menu menu) {
    List<ListenableBuilder> navItems = [];
    for (var i = 0; i < menu.menuItems.length; i++) {
      MenuItem item = menu.menuItems[i];
      navItems.add(ListenableBuilder(
          listenable: viewGroupNotifier,
          builder: (context, _) {
            return ListTile(
              selected: i == viewGroupNotifier.viewIndex,
              title: Text(Utils.translate(item.label ?? '', context)),
              leading:
                  ensemble.Icon(item.icon ?? '', library: item.iconLibrary),
              horizontalTitleGap: 0,
              onTap: () {
                //close the drawer
                Navigator.maybePop(context);
                viewGroupNotifier.updatePage(i);
              },
            );
          }));
    }
    return Drawer(
      backgroundColor: Utils.getColor(menu.runtimeStyles?['backgroundColor']),
      child: ListView(
        children: navItems,
      ),
    );
  }

  /// TODO: can't do this anymore without Conditional widget
  /// get the menu mode depending on user spec + device types / screen resolutions
// MenuDisplay _getPreferredMenuDisplay(Menu menu) {
//   MenuDisplay? display =
//       MenuDisplay.values.from(_scopeManager.dataContext.eval(menu.display));
//   // left nav becomes drawer in lower resolution. TODO: take in user settings
//   if (screenWidth < 1024) {
//     if (display == MenuDisplay.sidebar) {
//       display = MenuDisplay.drawer;
//     } else if (display == MenuDisplay.endSidebar) {
//       display = MenuDisplay.endDrawer;
//     }
//   }
//   display ??= MenuDisplay.bottomNavBar;
//
//   return display;
// }
}

class ViewGroupNotifier extends ChangeNotifier {
  int _viewIndex = 0;
  Map<String, dynamic>? _payload;

  int get viewIndex => _viewIndex;

  Map<String, dynamic>? get payload => _payload;

  void updatePage(int index,
      {bool isReload = true, Map<String, dynamic>? payload}) {
    _viewIndex = index;
    _payload = payload;
    if (isReload) {
      notifyListeners();
    }
  }
}

final viewGroupNotifier = ViewGroupNotifier();
