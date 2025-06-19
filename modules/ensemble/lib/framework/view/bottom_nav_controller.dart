import 'package:ensemble/framework/menu.dart';
import 'package:flutter/material.dart';

/// Singleton controller that stores and provides access to built bottom navigation widgets
class GlobalBottomNavController extends ChangeNotifier {
  static GlobalBottomNavController? _instance;

  // Private constructor
  GlobalBottomNavController._();

  // Singleton instance getter
  static GlobalBottomNavController get instance {
    _instance ??= GlobalBottomNavController._();
    return _instance!;
  }

  // Stored widgets
  Widget? _storedBottomNavWidget;
  Widget? _storedFloatingActionButton;
  FloatingActionButtonLocation? _storedFloatingActionButtonLocation;

  // Getters
  Widget? get bottomNavWidget => _storedBottomNavWidget;
  Widget? get floatingActionButton => _storedFloatingActionButton;
  FloatingActionButtonLocation? get floatingActionButtonLocation =>
      _storedFloatingActionButtonLocation;

  set bottomNavWidget(Widget? widget) {
    _storedBottomNavWidget = widget;
    notifyListeners();
  }

  set floatingActionButton(Widget? widget) {
    _storedFloatingActionButton = widget;
    notifyListeners();
  }

  set floatingLocation(FloatingActionButtonLocation? widget) {
    _storedFloatingActionButtonLocation = widget;
    notifyListeners();
  }


  /// Unregister widgets when PageGroup is disposed
  void unregisterBottomNavWidgets() {
      _storedBottomNavWidget = null;
      _storedFloatingActionButton = null;
      _storedFloatingActionButtonLocation = null;

      notifyListeners();
  }

  /// Get bottom nav widget
  Widget? getBottomNavWidget() {
    return _storedBottomNavWidget != null
        ? Container(child: _storedBottomNavWidget)
        : null;
  }

  /// Get floating action button
  Widget? getFloatingActionButton() {
    return _storedFloatingActionButton != null
        ? Container(child: _storedFloatingActionButton)
        : null;
  }

  @override
  void dispose() {
    super.dispose();
  }
}

/// Extension to make it easier to access the controller
extension GlobalBottomNavControllerExtension on BuildContext {
  GlobalBottomNavController get globalBottomNav =>
      GlobalBottomNavController.instance;
}