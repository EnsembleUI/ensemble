import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/widget/view_util.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:yaml/yaml.dart';

abstract class Menu {
  Menu(this.menuItems, {this.styles, this.headerModel, this.footerModel});

  List<MenuItem> menuItems;
  Map<String, dynamic>? styles;
  WidgetModel? headerModel;
  WidgetModel? footerModel;

  static Menu fromYaml(
      dynamic menu, Map<String, dynamic>? customViewDefinitions) {
    if (menu is YamlMap) {
      MenuDisplay? menuType = MenuDisplay.values.from(menu.keys.first);
      YamlMap payload = menu[menu.keys.first];

      // build menu items
      List<MenuItem> menuItems = [];
      if (payload['items'] is YamlList) {
        for (final YamlMap item in (payload['items'] as YamlList)) {
          if (item['label'] == null) {
            throw LanguageError("Menu Item's label is required");
          }
          if (item['page'] == null) {
            throw LanguageError("Menu Item's 'page' attribute is required.");
          }
          menuItems.add(MenuItem(item['label'], item['page'],
              icon: item['icon'],
              iconLibrary: Utils.optionalString(item['iconLibrary']),
              selected: item['selected']));
        }
      }
      if (menuItems.length < 2) {
        throw LanguageError("Menu requires two or more menu items.");
      }

      // menu headers/footers
      WidgetModel? menuHeaderModel;
      if (payload['header'] != null) {
        menuHeaderModel =
            ViewUtil.buildModel(payload['header'], customViewDefinitions);
      }
      WidgetModel? menuFooterModel;
      if (payload['footer'] != null) {
        menuFooterModel =
            ViewUtil.buildModel(payload['footer'], customViewDefinitions);
      }

      Map<String, dynamic>? styles = Utils.getMap(payload['styles']);
      if (menuType == MenuDisplay.BottomNavBar) {
        return BottomNavBarMenu.fromYaml(menuItems: menuItems, styles: styles);
      } else if (menuType == MenuDisplay.Drawer ||
          menuType == MenuDisplay.EndDrawer) {
        return DrawerMenu.fromYaml(
            menuItems: menuItems,
            styles: styles,
            atStart: menuType != MenuDisplay.EndDrawer,
            headerModel: menuHeaderModel,
            footerModel: menuFooterModel);
      } else if (menuType == MenuDisplay.Sidebar ||
          menuType == MenuDisplay.EndSidebar) {
        return SidebarMenu.fromYaml(
            menuItems: menuItems,
            styles: styles,
            atStart: menuType != MenuDisplay.EndSidebar,
            headerModel: menuHeaderModel,
            footerModel: menuFooterModel);
      }
    }
    throw LanguageError("Invalid Menu type.",
        recovery: "Please use one of Ensemble-provided menu types.");
  }
}

class BottomNavBarMenu extends Menu {
  BottomNavBarMenu._(super.menuItems, {super.styles});

  factory BottomNavBarMenu.fromYaml(
      {required List<MenuItem> menuItems, Map<String, dynamic>? styles}) {
    return BottomNavBarMenu._(menuItems, styles: styles);
  }
}

class DrawerMenu extends Menu {
  DrawerMenu._(super.menuItems, this.atStart,
      {super.styles, super.headerModel, super.footerModel});
  // show the drawer at start (left for LTR languages) or at the end
  bool atStart = true;

  factory DrawerMenu.fromYaml(
      {required List<MenuItem> menuItems,
      required bool atStart,
      Map<String, dynamic>? styles,
      WidgetModel? headerModel,
      WidgetModel? footerModel}) {
    return DrawerMenu._(menuItems, atStart,
        styles: styles, headerModel: headerModel, footerModel: footerModel);
  }
}

class SidebarMenu extends Menu {
  SidebarMenu._(super.menuItems, this.atStart,
      {super.styles, super.headerModel, super.footerModel});
  // show the sidebar at start (left for LTR languages) or at the end
  bool atStart = true;

  factory SidebarMenu.fromYaml(
      {required List<MenuItem> menuItems,
      required bool atStart,
      Map<String, dynamic>? styles,
      WidgetModel? headerModel,
      WidgetModel? footerModel}) {
    return SidebarMenu._(menuItems, atStart,
        styles: styles, headerModel: headerModel, footerModel: footerModel);
  }
}

enum MenuDisplay {
  BottomNavBar, // bottom navigation bar. Default if not specified
  Drawer, // hamburger drawer menu
  EndDrawer,
  Sidebar, // side-bar navigation, which will becomes a drawer on low resolution
  EndSidebar,

  // legacy for backward compatible
  leftNavBar, // fixed navigation to the left. Only recommend for Web
  navBar, // bottom nav bar
  navBar_left, // fixed navigation on the left of the screen
  navBar_right // fixed navigation on the right of the screen
}

enum MenuItemDisplay { stacked, sideBySide }

class MenuItem {
  MenuItem(this.label, this.page, {this.icon, this.iconLibrary, this.selected});

  final String? label;
  final String page;
  final dynamic icon;
  final String? iconLibrary;
  final dynamic selected;
}
