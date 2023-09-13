
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/widget/helpers/pull_to_refresh_container.dart';

mixin HasPullToRefresh {
  EnsembleAction? onPullToRefresh;
  RefreshIndicatorType? refreshIndicatorType;
}