import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/menu.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/page.dart';
import 'package:ensemble/framework/view/page_group.dart';
import 'package:ensemble/framework/widget/custom_view.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/icon.dart' as ensemble;
import 'package:flutter/material.dart';

class FABBottomAppBarItem {
  FABBottomAppBarItem({
    required this.icon,
    required this.text,
    this.activeIcon,
    this.isFloating = false,
    this.floatingMargin,
  });

  Icon icon;
  Icon? activeIcon;
  String text;
  bool isFloating;
  double? floatingMargin;
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

class BottomNavPageGroup extends StatefulWidget {
  const BottomNavPageGroup({
    super.key,
    required this.scopeManager,
    required this.menu,
    required this.onTabSelected,
    required this.child,
  });

  final ScopeManager scopeManager;
  final Menu menu;
  final Function(int) onTabSelected;
  final Widget child;

  @override
  State<BottomNavPageGroup> createState() => _BottomNavPageGroupState();
}

class _BottomNavPageGroupState extends State<BottomNavPageGroup> {
  late List<MenuItem> menuItems;
  Widget? fab;
  FloatingAlignment floatingAlignment = FloatingAlignment.none;
  int? floatingMargin;

  @override
  void initState() {
    super.initState();
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
      // 'onTap': (funcDefinition) => _controller.onTap =
      //     EnsembleAction.fromYaml(funcDefinition, initiator: this),
      final fabMenuItem = fabItems.first;
      floatingMargin = fabMenuItem.floatingMargin;
      final dynamic customIcon = _buildCustomIcon(fabMenuItem);
      fab = Theme(
        data: ThemeData(useMaterial3: false),
        child: customIcon ??
            FloatingActionButton(
              child: ensemble.Icon(
                fabMenuItem.icon ?? '',
                library: fabMenuItem.iconLibrary,
                color: Colors.white,
              ),
              onPressed: () => _floatingButtonTapped(fabMenuItem),
            ),
      );
      if (fab != null) {
        floatingAlignment =
            FloatingAlignment.values.byName(fabMenuItem.floatingAlignment);
      }
    }
  }

  void _floatingButtonTapped(MenuItem fabMenuItem) {
    final onTapAction = EnsembleAction.fromYaml(fabMenuItem.onTap);
    if (onTapAction != null) {
      ScreenController()
          .executeActionWithScope(context, widget.scopeManager, onTapAction);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      bottomNavigationBar: _buildBottomNavBar(),
      floatingActionButtonLocation: floatingAlignment == FloatingAlignment.none
          ? null
          : floatingAlignment.location,
      floatingActionButton:
          floatingAlignment == FloatingAlignment.none ? null : fab,
      body: PageGroupWidget(
        scopeManager: widget.scopeManager,
        child: widget.child,
      ),
    );
  }

  EnsembleBottomAppBar? _buildBottomNavBar() {
    List<FABBottomAppBarItem> navItems = [];

    // final menu = widget.menu;
    for (int i = 0; i < menuItems.length; i++) {
      MenuItem item = menuItems[i];
      final dynamic customIcon = _buildCustomIcon(item);
      final dynamic customActiveIcon = _buildCustomIcon(item, isActive: true);

      final isCustom = customIcon != null || customActiveIcon != null;
      final label = isCustom ? '' : Utils.translate(item.label ?? '', context);

      final activeIcon = customActiveIcon ??
          ensemble.Icon(
            item.activeIcon ?? item.icon,
            library: item.iconLibrary,
            color: Colors.white,
          );
      final icon = customIcon ??
          ensemble.Icon(
            item.icon ?? '',
            library: item.iconLibrary,
            color: Colors.white60,
          );
      navItems.add(
        FABBottomAppBarItem(
          icon: icon,
          activeIcon: activeIcon,
          text: label,
        ),
      );
    }

    return EnsembleBottomAppBar(
      backgroundColor: Utils.getColor(widget.menu.styles?['backgroundColor']) ??
          Colors.white,
      color: Colors.white60,
      selectedColor: Colors.white,
      notchedShape: const CircularNotchedRectangle(),
      onTabSelected: widget.onTabSelected,
      items: navItems,
      floatingAlignment: floatingAlignment,
      floatingMargin: floatingMargin,
    );
  }

  Widget? _buildCustomIcon(MenuItem item, {bool isActive = false}) {
    Widget? iconWidget;
    dynamic customWidgetModel =
        isActive ? item.customActiveWidget : item.customWidget;
    if (customWidgetModel != null) {
      final child = widget.scopeManager.buildWidget(customWidgetModel!);
      final dataScopeWidget = child as DataScopeWidget;
      final customWidget = dataScopeWidget.child as CustomView;
      iconWidget = customWidget.childWidget;
    }
    return iconWidget;
  }
}

class EnsembleBottomAppBar extends StatefulWidget {
  EnsembleBottomAppBar({
    super.key,
    required this.items,
    this.height = 80.0,
    this.iconSize = 24.0,
    required this.backgroundColor,
    required this.color,
    required this.selectedColor,
    required this.notchedShape,
    required this.onTabSelected,
    required this.floatingAlignment,
    this.onFabTapped,
    this.floatingMargin,
  }) {
    // assert(items.length == 2 || items.length == 4);
  }
  final List<FABBottomAppBarItem> items;
  final double height;
  final double iconSize;
  final int? floatingMargin;
  final Color backgroundColor;
  final Color color;
  final Color selectedColor;
  final FloatingAlignment floatingAlignment;
  final NotchedShape notchedShape;
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
    setState(() {
      _selectedIndex = index;
    });
  }

  int? getFabIndex() {
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
      child: BottomAppBar(
        padding: const EdgeInsets.all(0),
        shape: widget.notchedShape,
        color: widget.backgroundColor,
        notchMargin: _defaultFloatingNotch,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: items,
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
    required FABBottomAppBarItem item,
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
            onTap: () => onPressed(index),
            child: Column(
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

class CustomNotchClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const space = 80;
    final path = Path();
    final halfWidth = size.width / 2;
    const halfSpace = space / 2;
    const curve = space / 6;
    const height = halfSpace / 1.7;
    path.lineTo(halfWidth - halfSpace, 0);
    path.cubicTo(halfWidth - halfSpace, 0, halfWidth - halfSpace + curve,
        height, halfWidth, height);

    path.cubicTo(halfWidth, height, halfWidth + halfSpace - curve, height,
        halfWidth + halfSpace, 0);

    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
