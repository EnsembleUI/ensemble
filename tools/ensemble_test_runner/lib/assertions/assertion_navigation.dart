import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/test_session.dart';
import 'package:ensemble_test_runner/assertions/assertion_value_comparison.dart';

/// Assertions that inspect navigation state rather than rendered widgets.
///
/// Keeping these checks together gives the assertion engine one small boundary
/// for navigation state and prevents it from accumulating application flow
/// details as new widget assertions are added.
class AssertionNavigation {
  AssertionNavigation({required NavigationFlowRecorder navigationFlow})
      : _navigationFlow = navigationFlow;

  final NavigationFlowRecorder _navigationFlow;

  void expectNotVisited(String screenName) {
    final flow = _navigationFlow.flow;
    if (flow.contains(screenName)) {
      throw EnsembleTestFailure(
        'Expected screen "$screenName" not to be visited.',
      );
    }
  }

  void expectBackStack(List<String> screens) {
    final history = ScreenTracker()
        .screenHistory
        .map((s) => s.screenName ?? s.screenId)
        .whereType<String>()
        .toList();
    if (history.length < screens.length) {
      throw EnsembleTestFailure(
        'Back stack too short. Expected suffix $screens, got $history',
      );
    }
    final suffix = history.sublist(history.length - screens.length);
    if (!AssertionValueComparison.deepEquals(suffix, screens)) {
      throw EnsembleTestFailure(
        'Expected back stack suffix $screens, got $suffix (full: $history)',
      );
    }
  }

  void expectCanGoBack(bool expected) {
    final history = ScreenTracker().screenHistory;
    final canPop = history.isNotEmpty;
    if (canPop != expected) {
      throw EnsembleTestFailure(
        'Expected canGoBack=$expected, but history length is '
        '${history.length}.',
      );
    }
  }

  void expectNavigateTo(String screenName) {
    final tracker = ScreenTracker();
    if (!tracker.isScreenVisible(screenName: screenName) &&
        !tracker.isScreenVisible(screenId: screenName)) {
      final current = tracker.getCurrentScreenIdentifier();
      final history = tracker.screenHistory
          .map((s) => s.screenName ?? s.screenId)
          .whereType<String>()
          .toList();
      throw EnsembleTestFailure(
        'Expected navigation to "$screenName", but current screen is "$current". '
        'History: $history. Navigation flow: ${_navigationFlow.flow}',
      );
    }
  }

  void expectVisited(String screenName) {
    final flow = _navigationFlow.flow;
    if (!flow.contains(screenName)) {
      throw EnsembleTestFailure(
        'Expected screen "$screenName" in navigation history, but visited '
        '$flow',
      );
    }
  }
}
