import 'dart:developer';

import 'package:ensemble/action/haptic_action.dart';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/menu.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/bottom_nav_page_view.dart';
import 'package:ensemble/framework/view/page_group.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/icon.dart' as ensemble;
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:flutter/material.dart';

class BottomNavBarItem {
  BottomNavBarItem({
    required this.icon,
    required this.text,
    required this.isCustom,
    this.activeIcon,
    this.isFloating = false,
    this.floatingMargin,
    this.switchScreen = true,
    this.onTap,
    this.onTapHaptic,
  });

  Widget icon;
  Widget? activeIcon;
  String text;
  bool isFloating;
  bool isCustom;
  double? floatingMargin;
  bool? switchScreen;
  EnsembleAction? onTap;
  String? onTapHaptic;
}

enum FloatingAlignment {
  left,
  center,
  right,
  none,
}

extension EnumActionExtension on FloatingAlignment {
  FloatingActionButtonLocation get location {
    switch (this) {
      case FloatingAlignment.left:
        return FloatingActionButtonLocation.startDocked;
      case FloatingAlignment.right:
        return FloatingActionButtonLocation.endDocked;
      default:
        return FloatingActionButtonLocation.centerDocked;
    }
  }
}

class PageGroupWidgetWrapper extends StatelessWidget {
  const PageGroupWidgetWrapper({
    super.key,
    required this.scopeManager,
    required this.reloadView,
    required this.child,
  });

  final ScopeManager scopeManager;
  final bool? reloadView;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reloadView == false) {
      return PageGroupWidget(
        scopeManager: scopeManager,
        pageController:
            PageController(initialPage: viewGroupNotifier.viewIndex),
        child: child,
      );
    }
    return child;
  }
}

class BottomNavPageGroup extends StatefulWidget {
  const BottomNavPageGroup({
    super.key,
    required this.scopeManager,
    required this.menu,
    required this.selectedPage,
    required this.children,
  });

  final ScopeManager scopeManager;
  final Menu menu;
  final int selectedPage;
  final List<Widget> children;

  @override
  State<BottomNavPageGroup> createState() => _BottomNavPageGroupState();
}

class _BottomNavPageGroupState extends State<BottomNavPageGroup>
    with RouteAware {
  late List<MenuItem> menuItems;
  late PageController controller;
  FloatingAlignment floatingAlignment = FloatingAlignment.center;
  int? floatingMargin;
  MenuItem? fabMenuItem;

  @override
  void initState() {
    super.initState();
    if (widget.menu.reloadView == false) {
      controller = PageController(initialPage: widget.selectedPage);
    }
    viewGroupNotifier.updatePage(widget.selectedPage, isReload: false);
    menuItems = widget.menu.menuItems
        .where((element) => element.floating != true)
        .toList();
    final fabItems = widget.menu.menuItems
        .where((element) => element.floating == true)
        .toList();
    if (fabItems.length > 1) {
      throw LanguageError('There should be only one floating nav bar item');
    }
    if (fabItems.isNotEmpty) {
      fabMenuItem = fabItems.first;
    }
    if (fabMenuItem != null && fabMenuItem?.floatingAlignment != null) {
      floatingAlignment =
          FloatingAlignment.values.byName(fabMenuItem!.floatingAlignment);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // TODO: this should be moved to PageGroup for the other ViewGroup types all behave the same way
    var route = ModalRoute.of(context);
    if (route is PageRoute) {
      Ensemble.routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    if (widget.menu.reloadView == false) {
      controller.dispose();
    }
    Ensemble.routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// this is when a screen is popped and we go back to the screen with this ViewGroup
  @override
  void didPopNext() {
    // TODO: dispatch onRevisit so the child Page can execute onResume()
  }

  Widget? _buildFloatingButton() {
    if (fabMenuItem != null) {
      floatingMargin = fabMenuItem!.floatingMargin;
      final dynamic customIcon = _buildCustomIcon(fabMenuItem!);

      final floatingItemColor =
          Utils.getColor(widget.menu.styles?['floatingIconColor']) ??
              Theme.of(context).colorScheme.onSecondary;
      final floatingBackgroundColor =
          Utils.getColor(widget.menu.styles?['floatingBackgroundColor']) ??
              Theme.of(context).colorScheme.secondary;

      return Visibility(
        visible: MediaQuery.of(context).viewInsets.bottom == 0.0,
        child: Theme(
          data: ThemeData(useMaterial3: false),
          child: customIcon ??
              FloatingActionButton(
                backgroundColor: floatingBackgroundColor,
                child: (fabMenuItem!.icon != null
                    ? ensemble.Icon.fromModel(
                        fabMenuItem!.icon!,
                        fallbackLibrary: fabMenuItem!.iconLibrary,
                        fallbackColor: floatingItemColor,
                      )
                    : ensemble.Icon('')),
                onPressed: () => _floatingButtonTapped(fabMenuItem!),
              ),
        ),
      );
    }
    return null;
  }

  void _floatingButtonTapped(MenuItem fabMenuItem) {
    final onTapAction = EnsembleAction.fromYaml(fabMenuItem.onTap);
    if (onTapAction != null) {
      if (fabMenuItem.onTapHaptic != null) {
        ScreenController().executeAction(
          context,
          HapticAction(type: fabMenuItem.onTapHaptic!, onComplete: null),
        );
      }

      ScreenController()
          .executeActionWithScope(context, widget.scopeManager, onTapAction);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notchColor = Utils.getColor(widget.menu.styles?['notchColor']) ??
        Theme.of(context).scaffoldBackgroundColor;

    return PageGroupWidgetWrapper(
      reloadView: widget.menu.reloadView,
      scopeManager: widget.scopeManager,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: notchColor,
        bottomNavigationBar: _buildBottomNavBar(),
        floatingActionButtonLocation:
            floatingAlignment == FloatingAlignment.none
                ? null
                : floatingAlignment.location,
        floatingActionButton: _buildFloatingButton(),
        body: widget.menu.reloadView == true
            ? ListenableBuilder(
                listenable: viewGroupNotifier,
                builder: (_, __) =>
                    widget.children[viewGroupNotifier.viewIndex])
            : Builder(
                builder: (context) {
                  final controller = PageGroupWidget.getPageController(context);

                  return BottomNavPageView(
                    controller: controller ?? PageController(),
                    children: widget.children,
                  );
                },
              ),
      ),
    );
  }

  Widget? _buildBottomNavBar() {
    List<BottomNavBarItem> navItems = [];

    final unselectedColor = Utils.getColor(widget.menu.styles?['color']) ??
        Theme.of(context).unselectedWidgetColor;
    final selectedColor =
        Utils.getColor(widget.menu.styles?['selectedColor']) ??
            Theme.of(context).primaryColor;

    // final menu = widget.menu;
    for (int i = 0; i < menuItems.length; i++) {
      MenuItem item = menuItems[i];
      final dynamic customIcon = _buildCustomIcon(item);
      final dynamic customActiveIcon = _buildCustomIcon(item, isActive: true);

      final isCustom = customIcon != null || customActiveIcon != null;
      final label = isCustom ? '' : Utils.translate(item.label ?? '', context);

      final icon = customIcon ??
          (item.icon != null
              ? ensemble.Icon.fromModel(item.icon!,
                  fallbackLibrary: item.iconLibrary,
                  fallbackColor: unselectedColor)
              : ensemble.Icon(''));

      final activeIcon = customActiveIcon ??
          (item.activeIcon != null || item.icon != null
              ? ensemble.Icon.fromModel((item.activeIcon ?? item.icon)!,
                  fallbackColor: selectedColor,
                  fallbackLibrary: item.iconLibrary)
              : null);

      navItems.add(
        BottomNavBarItem(
          icon: icon,
          activeIcon: activeIcon,
          isCustom: isCustom,
          text: label,
          switchScreen: item.switchScreen,
          onTap: EnsembleAction.fromYaml(item.onTap),
          onTapHaptic: item.onTapHaptic,
        ),
      );
    }

    return ListenableBuilder(
      listenable: viewGroupNotifier,
      builder: (context, _) {
        final viewIndex = viewGroupNotifier.viewIndex;

        return EnsembleBottomAppBar(
          key: UniqueKey(),
          selectedIndex: viewIndex,
          backgroundColor:
              Utils.getColor(widget.menu.styles?['backgroundColor']) ??
                  Colors.white,
          height: Utils.optionalDouble(widget.menu.styles?['height'] ?? 60),
          margin: widget.menu.styles?['margin'],
          padding: widget.menu.styles?['padding'],
          borderRadius:
              Utils.getBorderRadius(widget.menu.styles?['borderRadius'])
                  ?.getValue(),
          color: unselectedColor,
          selectedColor: selectedColor,
          boxShadow: Utils.getBoxShadow(widget.menu.styles?['boxShadow']),
          shadowColor: Utils.getColor(widget.menu.styles?['shadowColor']),
          shadowRadius:
              Utils.optionalDouble(widget.menu.styles?['shadowRadius']),
          shadowBlurRadius:
              Utils.optionalDouble(widget.menu.styles?['shadowBlurRadius']),
          shadowStyle:
              Utils.getShadowBlurStyle(widget.menu.styles?['shadowStyle']),
          notchedShape: const CircularNotchedRectangle(),
          onTabSelected: (index) {
            final isSwitchScreen =
                Utils.getBool(navItems[index].switchScreen, fallback: true);
            if (isSwitchScreen) {
              if (widget.menu.reloadView == true) {
                viewGroupNotifier.updatePage(index);
              } else {
                PageGroupWidget.getPageController(context)!.jumpToPage(index);
                viewGroupNotifier.updatePage(index);
              }

              _onTap(navItems[index]);
            } else {
              // Execute only onTap action. Page switching is handled by the developer with onTap
              _onTap(navItems[index]);
            }

            // Executing haptic feedback action
            if (navItems[index].onTapHaptic != null) {
              ScreenController().executeAction(
                context,
                HapticAction(
                    type: navItems[index].onTapHaptic!, onComplete: null),
              );
            }
          },
          items: navItems,
          isFloating: fabMenuItem != null,
          floatingAlignment: floatingAlignment,
          floatingMargin: floatingMargin,
        );
      },
    );
  }

  void _onTap(BottomNavBarItem menuItem) {
    if (menuItem.onTap != null) {
      ScreenController().executeActionWithScope(
          context, widget.scopeManager, menuItem.onTap!);
    }
  }

  Widget? _buildCustomIcon(MenuItem item, {bool isActive = false}) {
    dynamic customWidgetModel =
        isActive ? item.customActiveWidget : item.customWidget;
    if (customWidgetModel != null) {
      return widget.scopeManager.buildWidget(customWidgetModel!);
    }
  }
}

class EnsembleBottomAppBar extends StatefulWidget {
  EnsembleBottomAppBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    this.height,
    this.margin,
    this.padding,
    this.borderRadius,
    this.boxShadow,
    this.shadowColor,
    this.shadowRadius,
    this.shadowBlurRadius,
    this.shadowStyle,
    this.iconSize = 24.0,
    required this.backgroundColor,
    required this.color,
    required this.selectedColor,
    required this.notchedShape,
    required this.onTabSelected,
    required this.isFloating,
    required this.floatingAlignment,
    this.onFabTapped,
    this.floatingMargin,
  }) {
    // assert(items.length == 2 || items.length == 4);
  }

  final List<BottomNavBarItem> items;
  final int selectedIndex;
  final double? height;
  final dynamic margin;
  final dynamic padding;
  final double iconSize;
  final int? floatingMargin;
  final Color backgroundColor;
  final Color color;
  final Color selectedColor;

  final BoxShadow? boxShadow;

  @Deprecated("Use boxShadow")
  final Color? shadowColor;
  @Deprecated("Use boxShadow")
  final double? shadowRadius;
  @Deprecated("Use boxShadow")
  final double? shadowBlurRadius;
  @Deprecated("Use boxShadow")
  final BlurStyle? shadowStyle;

  final bool isFloating;
  final FloatingAlignment floatingAlignment;
  final NotchedShape notchedShape;
  final BorderRadius? borderRadius;
  final VoidCallback? onFabTapped;
  final ValueChanged<int> onTabSelected;

  @override
  State<StatefulWidget> createState() => EnsembleBottomAppBarState();
}

class EnsembleBottomAppBarState extends State<EnsembleBottomAppBar> {
  int _selectedIndex = 0;
  double _defaultFloatingNotch = 5.0;

  void _updateIndex(int index) {
    widget.onTabSelected(index);
    if (widget.items[index].switchScreen == true) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  int? getFabIndex() {
    if (!widget.isFloating) return null;

    switch (widget.floatingAlignment) {
      case FloatingAlignment.center:
        switch (widget.items.length) {
          case 2:
            return 1;
          case 4:
            return 2;
          default:
            return 0;
        }
      case FloatingAlignment.left:
        return 0;
      case FloatingAlignment.right:
        return widget.items.length;
      default:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> items = List.generate(widget.items.length, (int index) {
      return _buildTabItem(
        item: widget.items[index],
        index: index,
        onPressed: _updateIndex,
      );
    });

    final fabIndex = getFabIndex();
    if (fabIndex != null) {
      items.insert(fabIndex, _buildEmptyTabItem());
    }

    if (widget.floatingMargin != null) {
      _defaultFloatingNotch =
          double.tryParse(widget.floatingMargin!.toString()) ?? 5.0;
    }

    return Theme(
      data: ThemeData(useMaterial3: false),
      child: Container(
        margin: Utils.optionalInsets(widget.margin) ?? EdgeInsets.zero,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius ?? BorderRadius.zero,
          boxShadow: widget.boxShadow != null || widget.shadowColor != null
              ? [
                  widget.boxShadow ??
                      BoxShadow(
                        color: widget.shadowColor!,
                        spreadRadius: widget.shadowRadius ?? 0.0,
                        blurRadius: widget.shadowBlurRadius ?? 0.0,
                        blurStyle: widget.shadowStyle ?? BlurStyle.normal,
                      ),
                ]
              : [],
        ),
        clipBehavior: widget.borderRadius != null ? Clip.hardEdge : Clip.none,
        child: BottomAppBar(
          padding: Utils.optionalInsets(widget.padding) ?? EdgeInsets.zero,
          shape: widget.notchedShape,
          color: widget.backgroundColor,
          notchMargin: _defaultFloatingNotch,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyTabItem() {
    return const Expanded(
      child: SizedBox(),
    );
  }

  Widget _buildTabItem({
    required BottomNavBarItem item,
    required int index,
    required ValueChanged<int> onPressed,
  }) {
    Color color = _selectedIndex == index ? widget.selectedColor : widget.color;
    Widget icon = item.icon;
    if (_selectedIndex == index) {
      icon = item.activeIcon ?? item.icon;
    }

    return Expanded(
      child: SizedBox(
        height: widget.height,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => onPressed(index),
            child: item.isCustom
                ? icon
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      icon,
                      Text(
                        item.text,
                        style: TextStyle(color: color),
                      )
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
