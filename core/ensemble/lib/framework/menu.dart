import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/widget/view_util.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:yaml/yaml.dart';

abstract class Menu {
  Menu(this.menuItems,
      {this.styles, this.headerModel, this.footerModel, this.reloadView});

  List<MenuItem> menuItems;
  Map<String, dynamic>? styles;
  WidgetModel? headerModel;
  WidgetModel? footerModel;
  bool? reloadView = true;

  static Menu fromYaml(
      dynamic menu, Map<String, dynamic>? customViewDefinitions) {
    if (menu is YamlMap) {
      MenuDisplay? menuType = MenuDisplay.values.from(menu.keys.first);
      YamlMap payload = menu[menu.keys.first];
      WidgetModel? customIconModel;
      WidgetModel? customActiveIconModel;

      // build menu items
      List<MenuItem> menuItems = [];
      if (payload['items'] is YamlList) {
        for (final YamlMap item in (payload['items'] as YamlList)) {
          final isNormalMenuItem =
              item['floating'] == null || item['floating'] == false;
          if (item['label'] == null) {
            final YamlMap? customItem = item['customItem'];
            if (customItem == null && isNormalMenuItem) {
              throw LanguageError("Menu Item's label is required");
            }
          }

          if (item['page'] == null && isNormalMenuItem) {
            throw LanguageError("Menu Item's 'page' attribute is required.");
          }

          // custom menu
          final YamlMap? customItem = item['customItem'];
          if (customItem != null) {
            final dynamic iconWidget = customItem['widget'];
            if (iconWidget != null) {
              customIconModel =
                  ViewUtil.buildModel(iconWidget, customViewDefinitions);
            }

            final dynamic activeIconWidget = customItem['selectedWidget'];
            if (iconWidget != null) {
              customActiveIconModel =
                  ViewUtil.buildModel(activeIconWidget, customViewDefinitions);
            }
          }

          menuItems.add(
            MenuItem(
              item['label'],
              item['page'],
              customActiveWidget: customActiveIconModel,
              customWidget: customIconModel,
              activeIcon: Utils.getIcon(item['activeIcon']),
              icon: Utils.getIcon(item['icon']),
              iconLibrary: Utils.optionalString(item['iconLibrary']),
              selected: item['selected'],
              floating: Utils.getBool(item['floating'], fallback: false),
              floatingAlignment:
                  Utils.optionalString(item['floatingAlignment']) ?? 'center',
              floatingMargin: Utils.optionalInt(item['floatingMargin']),
              switchScreen: Utils.getBool(item['switchScreen'], fallback: true),
              onTap: item['onTap'],
              onTapHaptic: Utils.optionalString(item['onTapHaptic']),
              isExternal: Utils.getBool(item['isExternal'], fallback: false),
            ),
          );
          customIconModel = null; // Resetting custom icon model
          customActiveIconModel = null; // Resetting custom icon model
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
      final isReloadView = payload['reloadView'] as bool? ?? true;
      if (menuType == MenuDisplay.BottomNavBar) {
        return BottomNavBarMenu.fromYaml(
            menuItems: menuItems, styles: styles, reloadView: isReloadView);
      } else if (menuType == MenuDisplay.Drawer ||
          menuType == MenuDisplay.EndDrawer) {
        return DrawerMenu.fromYaml(
            menuItems: menuItems,
            styles: styles,
            atStart: menuType != MenuDisplay.EndDrawer,
            headerModel: menuHeaderModel,
            footerModel: menuFooterModel,
            reloadView: isReloadView);
      } else if (menuType == MenuDisplay.Sidebar ||
          menuType == MenuDisplay.EndSidebar) {
        return SidebarMenu.fromYaml(
            menuItems: menuItems,
            styles: styles,
            atStart: menuType != MenuDisplay.EndSidebar,
            headerModel: menuHeaderModel,
            footerModel: menuFooterModel,
            reloadView: isReloadView);
      }
    }
    throw LanguageError("Invalid Menu type.",
        recovery: "Please use one of Ensemble-provided menu types.");
  }
}

class BottomNavBarMenu extends Menu {
  BottomNavBarMenu._(super.menuItems, {super.styles, super.reloadView});

  factory BottomNavBarMenu.fromYaml(
      {required List<MenuItem> menuItems,
      Map<String, dynamic>? styles,
      bool? reloadView}) {
    return BottomNavBarMenu._(menuItems,
        styles: styles, reloadView: reloadView);
  }
}

class DrawerMenu extends Menu {
  DrawerMenu._(super.menuItems, this.atStart,
      {super.styles, super.headerModel, super.footerModel, super.reloadView});
  // show the drawer at start (left for LTR languages) or at the end
  bool atStart = true;

  factory DrawerMenu.fromYaml(
      {required List<MenuItem> menuItems,
      required bool atStart,
      Map<String, dynamic>? styles,
      WidgetModel? headerModel,
      WidgetModel? footerModel,
      bool? reloadView}) {
    return DrawerMenu._(menuItems, atStart,
        styles: styles,
        headerModel: headerModel,
        footerModel: footerModel,
        reloadView: reloadView);
  }
}

class SidebarMenu extends Menu {
  SidebarMenu._(super.menuItems, this.atStart,
      {super.styles, super.headerModel, super.footerModel, super.reloadView});
  // show the sidebar at start (left for LTR languages) or at the end
  bool atStart = true;

  factory SidebarMenu.fromYaml(
      {required List<MenuItem> menuItems,
      required bool atStart,
      Map<String, dynamic>? styles,
      WidgetModel? headerModel,
      WidgetModel? footerModel,
      bool? reloadView}) {
    return SidebarMenu._(menuItems, atStart,
        styles: styles,
        headerModel: headerModel,
        footerModel: footerModel,
        reloadView: reloadView);
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
  MenuItem(
    this.label,
    this.page, {
    this.customWidget,
    this.customActiveWidget,
    this.activeIcon,
    this.icon,
    this.iconLibrary,
    this.selected,
    this.floating = false,
    this.switchScreen = true,
    this.floatingAlignment = 'center',
    this.floatingMargin,
    this.onTap,
    this.onTapHaptic,
    required this.isExternal,
  });

  final String? label;
  final String? page;
  final IconModel? icon;
  final IconModel? activeIcon;
  final dynamic customWidget;
  final dynamic customActiveWidget;
  final String? iconLibrary;
  final dynamic selected;
  final bool floating;
  final bool switchScreen;
  final String floatingAlignment;
  final int? floatingMargin;
  final dynamic onTap;
  final String? onTapHaptic;
  final bool isExternal;
}
