import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/framework/widget/icon.dart' as ensemble;

class PageGroup extends StatefulWidget {
  const PageGroup({
    super.key,
    required this.initialDataContext,
    required this.pageModel
  });
  final DataContext initialDataContext;
  final PageGroupModel pageModel;

  @override
  State<StatefulWidget> createState() => PageGroupState();
}
abstract class IsPage extends State<PageGroup>{
  IsScopeManager getScopeManager();
  Menu? getMenu();
  int getScreenWidth();
}


class PageGroupState extends IsPage with MediaQueryCapability {
  late ScopeManager _scopeManager;
  List<Widget> pageGroupWidgets = [];

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

    initPageGroups();
  }

  @override
  Widget build(BuildContext context) {
    return buildPageGroup(widget.pageModel.menu!);
  }

  void initPageGroups() {

    for (var menuItem in widget.pageModel.menu!.menuItems) {
      pageGroupWidgets.add(ScreenController().getScreen(
          screenName: menuItem.page
      ));
    }
  }


  int selectedMenuIndex = 0;
  /// build a Page Group that comprise of the menu and its inner pages
  Widget buildPageGroup(Menu menu) {
    List<BottomNavigationBarItem> items = [];
    for (var menuItem in menu.menuItems) {
      items.add(BottomNavigationBarItem(
          icon: ensemble.Icon(menuItem.icon ?? '', library: menuItem.iconLibrary),
          label: Utils.translate(menuItem.label ?? '', context)
      ));

    }


    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        items: items,
        currentIndex: selectedMenuIndex,
        onTap: (index) {
          setState(() {
            selectedMenuIndex = index;
          });
        },
      ),
      body: IndexedStack(children: pageGroupWidgets, index: selectedMenuIndex),
    );
  }

  @override
  ScopeManager getScopeManager() {
    return _scopeManager;
  }

  @override
  Menu? getMenu() {
    return widget.pageModel.menu;
  }

  @override
  int getScreenWidth() {
    return screenWidth;
  }

}