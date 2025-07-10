import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:ensemble_app_badger/ensemble_app_badger.dart';

class UpdateBadgeCount extends EnsembleAction {
  UpdateBadgeCount(dynamic count) : _count = count;
  final dynamic _count;

  factory UpdateBadgeCount.from({Map? payload}) {
    dynamic count = payload?['count'];
    if (count == null) {
      throw LanguageError(
          "${ActionType.updateBadgeCount.name} requires a count");
    }
    return UpdateBadgeCount(count);
  }

  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    int? count = Utils.optionalInt(scopeManager.dataContext.eval(_count));
    if (count != null) {
      return AppBadger().updateBadge(count);
    }
    return Future.value(null);
  }
}

class ClearBadgeCount extends EnsembleAction {
  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    return AppBadger().removeBadge();
  }
}

class AppBadger {
  static final AppBadger _instance = AppBadger._();
  AppBadger._();
  factory AppBadger() => _instance;

  Future<void> updateBadge(int count) =>
      FlutterAppBadger.updateBadgeCount(count);

  Future<void> removeBadge() => FlutterAppBadger.removeBadge();
}
