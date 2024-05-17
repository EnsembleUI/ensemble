import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/theme_manager.dart';
import 'package:ensemble/framework/widget/view_util.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:yaml/yaml.dart';

abstract class Menu extends Object with HasStyles, Invokable {
  Menu(this.menuItems,
      {String? widgetType,
      Map<String, dynamic>? widgetTypeStyles,
      String? widgetId,
      Map<String, dynamic>? idStyles,
      Map<String, dynamic>? inlineStyles,
      List<String>? classList,
      this.headerModel,
      this.footerModel,
      this.reloadView}) {
    this.widgetType = widgetType;
    this.widgetTypeStyles = widgetTypeStyles;
    this.widgetId = widgetId;
    this.idStyles = idStyles;
    this.inlineStyles = inlineStyles;
    this.classList = classList;
  }

  List<MenuItem> menuItems;
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
      //   EnsembleThemeManager().currentTheme()?.getWidgetTypeStyles(widgetType),
      // EnsembleThemeManager().currentTheme()?.getIDStyles(props['id']),
      // styles,
      // classList,
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
      List<String>? classList;
      if (payload[ViewUtil.classNameAttribute] != null) {
        classList = (payload[ViewUtil.classNameAttribute] as String?)
            ?.split(RegExp('\\s+'));
      }
      String? id = payload['id'] as String?;
      Map<String, dynamic>? styles = Utils.getMap(payload['styles']);
      final isReloadView = payload['reloadView'] as bool? ?? true;
      if (menuType == MenuDisplay.BottomNavBar) {
        return BottomNavBarMenu(menuItems,
            widgetType: menuType!.name,
            widgetTypeStyles: EnsembleThemeManager()
                .currentTheme()
                ?.getWidgetTypeStyles(menuType!.name),
            widgetId: id,
            idStyles: EnsembleThemeManager().currentTheme()?.getIDStyles(id),
            inlineStyles: styles,
            classList: classList,
            reloadView: isReloadView);
      } else if (menuType == MenuDisplay.Drawer ||
          menuType == MenuDisplay.EndDrawer) {
        return DrawerMenu(menuItems, menuType != MenuDisplay.EndDrawer,
            widgetType: menuType!.name,
            widgetTypeStyles: EnsembleThemeManager()
                .currentTheme()
                ?.getWidgetTypeStyles(menuType!.name),
            widgetId: id,
            idStyles: EnsembleThemeManager().currentTheme()?.getIDStyles(id),
            inlineStyles: styles,
            classList: classList,
            headerModel: menuHeaderModel,
            footerModel: menuFooterModel,
            reloadView: isReloadView);
      } else if (menuType == MenuDisplay.Sidebar ||
          menuType == MenuDisplay.EndSidebar) {
        return SidebarMenu(menuItems, menuType != MenuDisplay.EndSidebar,
            widgetType: menuType!.name,
            widgetTypeStyles: EnsembleThemeManager()
                .currentTheme()
                ?.getWidgetTypeStyles(menuType!.name),
            widgetId: id,
            idStyles: EnsembleThemeManager().currentTheme()?.getIDStyles(id),
            inlineStyles: styles,
            classList: classList,
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
  BottomNavBarMenu(super.menuItems,
      {super.widgetType,
      super.widgetTypeStyles,
      super.widgetId,
      super.idStyles,
      super.inlineStyles,
      super.classList,
      super.reloadView});

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {};
  }
}

class DrawerMenu extends Menu {
  DrawerMenu(super.menuItems, this.atStart,
      {super.widgetType,
      super.widgetTypeStyles,
      super.widgetId,
      super.idStyles,
      super.inlineStyles,
      super.classList,
      super.headerModel,
      super.footerModel,
      super.reloadView});

  // show the drawer at start (left for LTR languages) or at the end
  bool atStart = true;

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {};
  }
}

class SidebarMenu extends Menu {
  SidebarMenu(super.menuItems, this.atStart,
      {super.widgetType,
      super.widgetTypeStyles,
      super.widgetId,
      super.idStyles,
      super.inlineStyles,
      super.classList,
      super.headerModel,
      super.footerModel,
      super.reloadView});

  // show the sidebar at start (left for LTR languages) or at the end
  bool atStart = true;

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {};
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
