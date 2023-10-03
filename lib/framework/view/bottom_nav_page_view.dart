import 'package:flutter/cupertino.dart';

/// a PageView implementation that keeps track of visited screens of a
/// BottomNavBar. We use this to expose an onResume callback for each screen.
class BottomNavPageView extends StatefulWidget {
  BottomNavPageView(
      {required this.controller,
      required this.children,
      this.initialIndex = 0});
  final PageController controller;
  final List<Widget> children;
  final int initialIndex;

  @override
  State<StatefulWidget> createState() => BottomNavPageViewState();
}

class BottomNavPageViewState extends State<BottomNavPageView> {
  Set<int> _visitedScreens = {};
  List<BottomNavScreen> screens = [];
  BottomNavScreen? selectedScreen;

  @override
  void initState() {
    super.initState();

    // wrap each screen inside a InheritedWidget for sending changes
    screens = widget.children
        .map((child) => BottomNavScreen(
              child: child,
              bottomNavRoot: this,
            ))
        .toList();

    // mark the initial screen as visited
    _visitedScreens.add(widget.initialIndex);

    // every time we go to a new page, dispatch revisit event
    // if we have loaded this screen previously.
    widget.controller.addListener(() {
      int? newScreenIndex = widget.controller.page?.round();
      if (newScreenIndex != null) {
        if (_visitedScreens.contains(newScreenIndex)) {
          screens[newScreenIndex]._revisit();
        }
        _visitedScreens.add(newScreenIndex);
        selectedScreen = screens[newScreenIndex];
      }
    });
  }

  @override
  Widget build(BuildContext context) => PageView(
      physics: const NeverScrollableScrollPhysics(),
      controller: widget.controller,
      children: screens);
}

/// This InheritedWidget enables each Page to be notified when
/// the page is being revisited again
class BottomNavScreen extends InheritedWidget {
  BottomNavScreen({required super.child, required this.bottomNavRoot});
  BottomNavPageViewState bottomNavRoot;

  // This enable each page to attach its listener to
  Function()? _onRevisited;
  void onReVisited(Function() func) {
    _onRevisited = func;
  }

  // we privately call this from our PageView, no one else need to know
  void _revisit() {
    _onRevisited?.call();
  }

  bool isActive() {
    return bottomNavRoot.selectedScreen == this;
  }

  static BottomNavScreen? getScreen(BuildContext context) {
    BottomNavScreen? screen =
        context.dependOnInheritedWidgetOfExactType<BottomNavScreen>();
    if (screen != null) {
      return screen;
    }
    return null;
  }

  @override
  bool updateShouldNotify(covariant BottomNavScreen oldWidget) {
    return oldWidget._onRevisited != _onRevisited;
  }
}
