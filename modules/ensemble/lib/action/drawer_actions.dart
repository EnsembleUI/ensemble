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

  @override
  Future execute(BuildContext context, ScopeManager scopeManager) async {
    try {
      // Get the current route
      final currentRoute = Ensemble().getCurrentRoute();
      final scaffold = Scaffold.maybeOf(context);

      // Check if we're in a drawer route
      if (currentRoute != null && 
          currentRoute.isCurrent && 
          currentRoute.navigator != null &&
          currentRoute is MaterialPageRoute) {
            if(scaffold != null && !scaffold.hasDrawer) {
              currentRoute.navigator!.maybePop();
              return Future.value(true); 
            }
      }
      return Future.value(false);
    } catch (e) {
      debugPrint('Error closing drawer: $e');
      return Future.value(false);
    }
  }
}
