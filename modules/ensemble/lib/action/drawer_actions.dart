import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

/// Action to open drawer in the current context
/// Will open screen-level drawer if exists, otherwise app-level drawer
class OpenDrawerAction extends EnsembleAction {
  OpenDrawerAction({super.initiator});

  factory OpenDrawerAction.from({Invokable? initiator, Map? payload}) {
    return OpenDrawerAction(initiator: initiator);
  }

  @override
  Future<void> execute(BuildContext context, ScopeManager scopeManager) {
    try {
      // Get nearest Scaffold
      ScaffoldState? scaffold = Scaffold.maybeOf(context);
      
      // Check if scaffold exists and has drawer
      if (scaffold != null && scaffold.hasDrawer) {
        scaffold.openDrawer();
      }
    } catch (e) {
      debugPrint('Error opening drawer: $e');
    }
    return Future.value();
  }
}

class CloseDrawerAction extends EnsembleAction {
  CloseDrawerAction({super.initiator});

  factory CloseDrawerAction.from({Invokable? initiator, Map? payload}) {
    return CloseDrawerAction(initiator: initiator);
  }


  bool isDrawerRoute(Route<dynamic>? route, BuildContext context) {
    if (route == null) return false;
    
    // If it's a MaterialPageRoute, we need additional checks
    if (route is MaterialPageRoute) {
      // When a drawer is open, scaffold.hasDrawer becomes false
      final scaffold = Scaffold.maybeOf(context);
      return scaffold != null && !scaffold.hasDrawer;
    }
    
    return false;
  }

  @override
  Future execute(BuildContext context, ScopeManager scopeManager) async {
    try {
      print("Executing close drawer action");
      
      // Get the current route
      final currentRoute = Ensemble().getCurrentRoute();
      final scaffold = Scaffold.maybeOf(context);
      print("Scaffold found: ${scaffold != null}");
      print("Current route type: ${currentRoute?.runtimeType}");
      print("isCurrent: ${currentRoute?.isCurrent}");
      print("navigator: ${currentRoute?.navigator != null}");
      print("currentRoute is MaterialPageRoute: ${currentRoute is MaterialPageRoute}");
      print("scaffold.hasDrawer: ${scaffold!.hasDrawer}");
      print("scaffold.isDrawerOpen: ${scaffold.isDrawerOpen}");

      // Check if we're in a drawer route
      if (currentRoute != null && 
          currentRoute.isCurrent && 
          currentRoute.navigator != null &&
          currentRoute is MaterialPageRoute) {
            if(scaffold != null && !scaffold.hasDrawer) {
              print("Found active drawer route - closing drawer");
              currentRoute.navigator!.maybePop();
              return Future.value(true); 
            }
      }

      

      // if (scaffold != null) {
      //   final hasDrawer = scaffold.hasDrawer;
      //   final isDrawerOpen = scaffold.isDrawerOpen;
      //   print("Has drawer: $hasDrawer");
      //   print("Has drawer: $isDrawerOpen");

      //   if (hasDrawer) {
      //     // If hasDrawer is true, drawer exists but is closed
      //     print("Drawer exists but is closed - no action needed");
      //   }
      // }

      return Future.value(false);
    } catch (e) {
      debugPrint('Error closing drawer: $e');
      print(e.toString());
      return Future.value(false);
    }
  }
}

// In a new file named drawer_actions.dart

// import 'package:ensemble/ensemble.dart';
// import 'package:ensemble/framework/action.dart';
// import 'package:ensemble/framework/scope.dart';
// import 'package:ensemble/util/utils.dart';
// import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
// import 'package:flutter/material.dart';

// /// Static class to hold the global scaffold key
// class DrawerActions {
//   static final GlobalKey<ScaffoldState> mainScaffoldKey = GlobalKey<ScaffoldState>();
  
//   // Optional: helper methods to check drawer state
//   static bool isDrawerOpen() {
//     return mainScaffoldKey.currentState?.isDrawerOpen ?? false;
//   }
  
//   static bool hasDrawer() {
//     return mainScaffoldKey.currentState?.hasDrawer ?? false;
//   }
// }

// /// Action to open drawer in the current context
// class OpenDrawerAction extends EnsembleAction {
//   OpenDrawerAction({super.initiator});

//   factory OpenDrawerAction.from({Invokable? initiator, Map? payload}) {
//     return OpenDrawerAction(initiator: initiator);
//   }

//   @override
//   Future<void> execute(BuildContext context, ScopeManager scopeManager) {
//     try {
//       final scaffold = DrawerActions.mainScaffoldKey.currentState;
//       if (scaffold != null && scaffold.hasDrawer && !scaffold.isDrawerOpen) {
//         scaffold.openDrawer();
//       }
//     } catch (e) {
//       debugPrint('Error opening drawer: $e');
//     }
//     return Future.value();
//   }
// }

// /// Action to close drawer
// class CloseDrawerAction extends EnsembleAction {
//   CloseDrawerAction({super.initiator});

//   factory CloseDrawerAction.from({Invokable? initiator, Map? payload}) {
//     return CloseDrawerAction(initiator: initiator);
//   }

//   @override
//   Future execute(BuildContext context, ScopeManager scopeManager) async {
//     try {
//       final scaffold = DrawerActions.mainScaffoldKey.currentState;
      
//       if (scaffold != null && scaffold.isDrawerOpen) {
//         scaffold.closeDrawer();
//         return Future.value(true);
//       }
      
//       return Future.value(false);
//     } catch (e) {
//       debugPrint('Error closing drawer: $e');
//       return Future.value(false);
//     }
//   }
// }