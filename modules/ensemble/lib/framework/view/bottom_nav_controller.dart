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
  Function(int)? _originalOnTabSelected;
  late BuildContext _originalContext;
  late PageController _pageController;

  String? _activePageGroupId;
  BottomNavBarMenu? _currentMenu;

  // Debug tracking
  final List<String> _debugLog = [];

  // Getters
  Widget? get bottomNavWidget => _storedBottomNavWidget;
  Widget? get floatingActionButton => _storedFloatingActionButton;
  FloatingActionButtonLocation? get floatingActionButtonLocation => _storedFloatingActionButtonLocation;
  bool get hasBottomNav => _storedBottomNavWidget != null;
  String? get currentPageGroup => _activePageGroupId;
  BottomNavBarMenu? get currentMenu => _currentMenu;
  List<String> get debugLog => List.unmodifiable(_debugLog);
  
  // Original context getter
  BuildContext get originalContext => _originalContext;
  
  // PageController getter
  PageController get pageController => _pageController;
  
  // Original context setter
  set originalContext(BuildContext context) {
    _originalContext = context;
    notifyListeners();
  }

  // PageController setter
  set pageController(PageController controller) {
    _pageController = controller;
    notifyListeners();
  }

  /// Register the built widgets from PageGroup
  void registerBottomNavWidgets({
    required Widget? bottomNavWidget,
    required Function(int) onTabSelected,
    required Widget? floatingActionButton,
    required FloatingActionButtonLocation? floatingActionButtonLocation,
    required String pageGroupId,
    BottomNavBarMenu? menu,
    PageController? pageController, // Add optional PageController parameter
  }) {
    
    _storedBottomNavWidget = bottomNavWidget;
    _storedFloatingActionButton = floatingActionButton;
    _storedFloatingActionButtonLocation = floatingActionButtonLocation;
    _activePageGroupId = pageGroupId;
    _currentMenu = menu;
    _originalOnTabSelected = onTabSelected;  // Store the callback correctly
    
    // Store PageController if provided
    if (pageController != null) {
      _pageController = pageController;
    }
    

    notifyListeners();
  }

  /// Handle tab selection from external context
  void selectTab(int index) {
    if (_originalOnTabSelected != null) {
      _originalOnTabSelected!(index);
    } 
  }

  /// Jump to page using stored PageController
  void jumpToPage(int index) {
    try {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(index);
      } else {
      }
    } catch (e) {
      _addDebugLog('Error jumping to page: $e');
    }
  }

  /// Animate to page using stored PageController
  void animateToPage(int index, {
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.ease,
  }) {
    try {
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          index,
          duration: duration,
          curve: curve,
        );
      } else {
        _addDebugLog('❌ PageController has no clients');
      }
    } catch (e) {
      _addDebugLog('❌ Error animating to page: $e');
    }
  }

  /// Unregister widgets when PageGroup is disposed
  void unregisterBottomNavWidgets(String pageGroupId) {
    if (_activePageGroupId == pageGroupId) {      
      _storedBottomNavWidget = null;
      _storedFloatingActionButton = null;
      _storedFloatingActionButtonLocation = null;
      _originalOnTabSelected = null;
      _activePageGroupId = null;
      _currentMenu = null;
      
      notifyListeners();
    }
  }

  /// Check if a specific PageGroup is currently active
  bool isPageGroupActive(String pageGroupId) {
    return _activePageGroupId == pageGroupId;
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

  // Debug helpers
  void _addDebugLog(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    final logEntry = '[$timestamp] $message';
    _debugLog.add(logEntry);
    
    // Keep only last 100 entries
    if (_debugLog.length > 100) {
      _debugLog.removeAt(0);
    }
    
    debugPrint('🌍 GlobalBottomNav: $logEntry');
  }

  @override
  void dispose() {
    _addDebugLog('🗑️ Controller disposed');
    super.dispose();
  }
}

/// Extension to make it easier to access the controller
extension GlobalBottomNavControllerExtension on BuildContext {
  GlobalBottomNavController get globalBottomNav => GlobalBottomNavController.instance;
}