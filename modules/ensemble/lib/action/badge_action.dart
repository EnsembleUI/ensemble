import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:ensemble_app_badger/ensemble_app_badger.dart';

/// Ensemble action that updates the application icon badge count.
class UpdateBadgeCount extends EnsembleAction {
  /// Creates a [UpdateBadgeCount] object.
  UpdateBadgeCount(dynamic count) : _count = count;
  final dynamic _count;

  /// Creates a [UpdateBadgeCount] from a YAML or map action payload.
  factory UpdateBadgeCount.from({Map? payload}) {
    dynamic count = payload?['count'];
    if (count == null) {
      throw LanguageError(
          "${ActionType.updateBadgeCount.name} requires a count");
    }
    return UpdateBadgeCount(count);
  }

  /// Runs this action and performs the update badge count operation.
  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    int? count = Utils.optionalInt(scopeManager.dataContext.eval(_count));
    if (count != null) {
      return AppBadger().updateBadge(count);
    }
    return Future.value(null);
  }
}

/// Ensemble action that clears the application icon badge count.
class ClearBadgeCount extends EnsembleAction {
  /// Runs this action and performs the clear badge count operation.
  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    return AppBadger().removeBadge();
  }
}

/// Small helper that delegates badge updates to the platform badger plugin.
/// Helper for applying app icon badge updates through the platform plugin.
class AppBadger {
  static final AppBadger _instance = AppBadger._();
  AppBadger._();
  /// Creates a [AppBadger] from parsed runtime data.
  factory AppBadger() => _instance;

  /// Updates the app icon badge count through the platform plugin.
  Future<void> updateBadge(int count) =>
      FlutterAppBadger.updateBadgeCount(count);

  /// Clears the app icon badge through the platform plugin.
  Future<void> removeBadge() => FlutterAppBadger.removeBadge();
}
