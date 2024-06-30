import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';

// add pull to refresh to a container
class PullToRefresh {
  PullToRefresh(this.onPullToRefresh,
      {this.indicatorType, this.indicatorMinDuration, this.indicatorPadding});

  EnsembleAction onPullToRefresh;
  RefreshIndicatorType? indicatorType;
  EdgeInsets? indicatorPadding;

  // if we invoke an API via YAML, we know when the async is returned so
  // the indicator knows when to stop, but we don't in situation like making
  // multiple async calls in Javascript. It is helpful to have the indicator
  // spin for a minimum duration to emulate async calls
  Duration? indicatorMinDuration;

  static PullToRefresh? fromMap(dynamic input, Invokable initiator) {
    if (input is Map) {
      var action = EnsembleAction.from(input['onPullToRefresh'],
          initiator: initiator);
      if (action != null) {
        return PullToRefresh(action,
            indicatorType:
                RefreshIndicatorType.values.from(input['indicatorType']),
            indicatorMinDuration:
                Utils.getDurationMs(input['indicatorMinDuration']),
            indicatorPadding: Utils.getInsets(input['indicatorPadding']));
      }
    }
    return null;
  }
}

@Deprecated("use PullToRefresh")
class PullToRefreshOptions {
  PullToRefreshOptions(
      {this.indicatorType, this.indicatorMinDuration, this.indicatorPadding});

  RefreshIndicatorType? indicatorType;

  // if we invoke an API via YAML, we know when the async is returned so
  // the indicator knows when to stop, but we don't in situation like making
  // multiple async calls in Javascript. It is helpful to have the indicator
  // spin for a minimum duration to emulate async calls
  Duration? indicatorMinDuration;

  EdgeInsets? indicatorPadding;

  static PullToRefreshOptions? fromMap(dynamic input) {
    if (input is Map) {
      return PullToRefreshOptions(
          indicatorType:
              RefreshIndicatorType.values.from(input['indicatorType']),
          indicatorMinDuration:
              Utils.getDurationMs(input['indicatorMinDuration']),
          indicatorPadding: Utils.getInsets(input['indicatorPadding']));
    }
    return null;
  }
}

enum RefreshIndicatorType { material, cupertino }
