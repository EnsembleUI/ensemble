import 'dart:async';

import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble_test_runner/actions/test_execution_config.dart';
import 'package:ensemble_test_runner/application/application_test_types.dart';
import 'package:ensemble_test_runner/models/test_results.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/event_driven_settler.dart';
import 'package:ensemble_test_runner/runner/flutter_error_filters.dart';
import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:ensemble_test_runner/src/core/operation_input.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Waits for navigation state and records evidence at the matched route.
///
/// This collaborator owns route tracking and the bounded live-call drain. The
/// executor remains responsible for dispatching the wait operation.
final class NavigationWaiter {
  const NavigationWaiter({
    required this.tester,
    required this.context,
    required this.navigation,
    required this.config,
  });

  final WidgetTester tester;
  final EnsembleTestContext context;
  final NavigationTestService? navigation;
  final TestExecutionConfig config;

  static int timeoutMsFor(
    OperationInput operation, {
    required Duration defaultTimeout,
  }) {
    final timeoutMs = operation.arguments['timeoutMs'];
    return timeoutMs is int ? timeoutMs : defaultTimeout.inMilliseconds;
  }

  Future<void> waitForNavigation({
    required String screen,
    required int timeoutMs,
    Future<void> Function()? onMatched,
  }) async {
    return RunnerBenchmark.async('execution', 'waitForNavigation', () async {
      if (screen.isEmpty) {
        throw EnsembleTestFailure('waitForNavigation requires "screen"');
      }
      final tracker = ScreenTracker();
      final navigationFlow = context.navigationFlow;
      final navigation = this.navigation;
      var captureFired = false;
      var screenEventObserved = false;
      var navigationEventObserved = false;
      final waitWallClock = Stopwatch()..start();
      final completedCallsAtWaitStart =
          context.apiOverlay.completedLiveCallCount;
      DateTime? targetScreenEventAt;
      VisibleScreen? lastScreenEvent;
      DateTime? lastScreenEventAt;

      bool isTargetVisible() =>
          tracker.isScreenVisible(screenName: screen) ||
          tracker.isScreenVisible(screenId: screen);

      bool visitedInHistory() => navigationFlow.flow.contains(screen);
      bool routeReached() =>
          isTargetVisible() ||
          screenEventObserved ||
          visitedInHistory() ||
          navigationEventObserved ||
          (navigation != null &&
              (navigation.currentRoute == screen ||
                  navigation.routeHistory.contains(screen)));

      String timeoutDiagnostics() {
        final now = DateTime.now().toUtc();
        final flow = navigationFlow.flow;
        final recentFlow = flow.length <= 8 ? flow : flow.skip(flow.length - 8);
        final visibleScreen = tracker.getCurrentScreenIdentifier();
        final lastEventScreen =
            lastScreenEvent?.screenName ?? lastScreenEvent?.screenId;
        final pendingSnapshot = context.apiOverlay.pendingLiveCallsSnapshot();
        final lastCompletion = context.apiOverlay.lastLiveCallCompletedAt;
        return 'deadlineAt=${now.toIso8601String()}, '
            'wallElapsedMs=${waitWallClock.elapsedMilliseconds}, '
            'targetEventAt=${targetScreenEventAt?.toIso8601String() ?? 'not-observed'}, '
            'targetVisibleAtDeadline=${isTargetVisible()}, '
            'visibleScreen=${visibleScreen ?? 'unknown'}, '
            'serviceRoute=${navigation?.currentRoute ?? 'unknown'}, '
            'lastScreenEvent=${lastEventScreen ?? 'none'}'
            '${lastScreenEventAt == null ? '' : '@${lastScreenEventAt!.toIso8601String()}'}, '
            'flow=${recentFlow.isEmpty ? '[]' : recentFlow.join(' -> ')}, '
            'liveCallsPendingAtDeadline=${context.apiOverlay.hasPendingLiveCalls}, '
            'liveCallSnapshotPresent=${pendingSnapshot != null}, '
            'liveCallsCompletedDuringWait=${context.apiOverlay.completedLiveCallCount - completedCallsAtWaitStart}, '
            'lastLiveCallCompletedAt=${lastCompletion?.toIso8601String() ?? 'none'}';
      }

      Future<void> captureIfVisible() async {
        if (captureFired || onMatched == null) return;
        // A route event can be delivered after its widget tree has already
        // been replaced. Do not attach the replacement screen's frame to the
        // transient route's match boundary; the normal step-finished capture
        // will record the frame that is actually visible at completion.
        if (!isTargetVisible()) return;
        if (treeHasFlutterErrorWidget(tester)) return;
        captureFired = true;
        await onMatched();
      }

      if (visitedInHistory() ||
          (navigation != null &&
              (navigation.currentRoute == screen ||
                  navigation.routeHistory.contains(screen)))) {
        await captureIfVisible();
        return;
      }

      Future<void> waitForRequestedRoute() async {
        try {
          await _waitForNavigationRoute(
            timeout: Duration(milliseconds: timeoutMs),
            condition: routeReached,
            onPump: navigationFlow.flushPending,
          );
        } on FlutterError catch (error) {
          if (!error.toString().contains('timed out')) rethrow;
          // A target event may be queued at the exact authored deadline. Check
          // it before deciding whether already-running live work gets a
          // bounded completion window.
          if (routeReached()) return;

          final authoredDeadlineDiagnostics = timeoutDiagnostics();
          final liveCallSnapshot =
              context.apiOverlay.pendingLiveCallsSnapshot();
          if (liveCallSnapshot == null) {
            throw EnsembleTestFailure(
              'Timed out after ${timeoutMs}ms waiting for navigation to '
              '"$screen" ($authoredDeadlineDiagnostics)',
            );
          }

          // Calls already in flight at the authored deadline can start a chain
          // of follow-up work. Drain that chain while watching for the route,
          // but keep the extension finite even if calls never settle.
          final drainStartedAt = tester.binding.clock.now();
          // Give a pending chain up to twice the authored timeout, capped at
          // twenty seconds, then retain a short route-settling tail.
          // The same total bound applies whether work is one request or a
          // sequence of continuations.
          final drainBudget = timeoutMs >= 10000
              ? const Duration(seconds: 20)
              : Duration(milliseconds: timeoutMs * 2);
          final routeTransitionTail = timeoutMs < 2000
              ? Duration(milliseconds: timeoutMs)
              : const Duration(seconds: 2);
          final elapsed = tester.binding.clock.now().difference(drainStartedAt);
          var remainingDrain = drainBudget + routeTransitionTail;
          remainingDrain -= elapsed.isNegative ? Duration.zero : elapsed;
          if (remainingDrain > Duration.zero) {
            try {
              await RunnerBenchmark.async(
                  'execution', 'navigationLiveCallDrain', () async {
                RunnerBenchmark.dimension('authoredTimeoutMs', timeoutMs);
                RunnerBenchmark.dimension(
                  'drainBudgetMs',
                  drainBudget.inMilliseconds +
                      routeTransitionTail.inMilliseconds,
                );
                RunnerBenchmark.count(
                  'pendingCallsAtDrainStart',
                  context.apiOverlay.pendingLiveCallCount,
                );
                await EventDrivenSettler(
                  tester: tester,
                  hasExternalWork: () => context.apiOverlay.hasPendingLiveCalls,
                  waitForExternalWork: context.apiOverlay.waitForLiveCalls,
                  externalWorkPollTimeout: config.waitPollInterval,
                  activeFrameDuration: config.settleStepDuration,
                  onPump: navigationFlow.flushPending,
                ).waitFor(
                  timeout: remainingDrain,
                  condition: routeReached,
                );
              });
            } on FlutterError catch (drainError) {
              if (!drainError.toString().contains('timed out')) rethrow;
            }
          }
          if (!routeReached()) {
            final liveCallsStillPending =
                context.apiOverlay.hasPendingLiveCalls;
            throw EnsembleTestFailure(
              'Timed out after ${timeoutMs}ms waiting for navigation to '
              '"$screen"; ${liveCallsStillPending ? 'bounded live-call drain '
                  'expired' : 'pending live calls completed without the '
                  'expected route'} ($authoredDeadlineDiagnostics)',
            );
          }
        }
      }

      final screenSub = tracker.onScreenChange.listen((visible) {
        if (visible == null) return;
        lastScreenEvent = visible;
        lastScreenEventAt = DateTime.now().toUtc();
        if (visible.screenName == screen || visible.screenId == screen) {
          // Capture the transient target event even when its route has already
          // been replaced by the time the next frame or recorder flush runs.
          screenEventObserved = true;
          targetScreenEventAt ??= lastScreenEventAt;
        }
      });

      final previousOnScreenAdded = navigationFlow.onScreenAdded;
      navigationFlow.onScreenAdded = (name) async {
        final prior = previousOnScreenAdded;
        if (prior != null) await prior(name);
        if (name == screen) {
          navigationEventObserved = true;
        }
      };

      try {
        if (navigation != null) {
          await navigationFlow.flushPending();
          if (routeReached()) {
            if (navigationEventObserved || isTargetVisible()) {
              await captureIfVisible();
            }
            return;
          }
          await waitForRequestedRoute();
          if (navigationEventObserved || isTargetVisible()) {
            await captureIfVisible();
          }
          return;
        }
        // Give application-owned navigation callbacks one microtask turn before
        // advancing Flutter frames. A zero-duration timer is tied to the fake
        // async clock in widget tests and can deadlock before the timeout pump.
        await Future<void>.value();
        await navigationFlow.flushPending();
        if (routeReached()) {
          if (isTargetVisible()) await captureIfVisible();
          return;
        }
        if (isTargetVisible()) {
          await captureIfVisible();
          return;
        }
        if (routeReached()) return;

        await waitForRequestedRoute();
        if (screenEventObserved || isTargetVisible()) {
          await captureIfVisible();
          return;
        }
        if (visitedInHistory()) return;
        throw EnsembleTestFailure(
          'Timed out after ${timeoutMs}ms waiting for navigation to "$screen"',
        );
      } on FlutterError catch (error) {
        if (!error.toString().contains('timed out')) rethrow;
        throw EnsembleTestFailure(
          'Timed out after ${timeoutMs}ms waiting for navigation to "$screen"',
        );
      } finally {
        unawaited(screenSub.cancel().catchError((Object _) {}));
        navigationFlow.onScreenAdded = previousOnScreenAdded;
      }
    });
  }

  Future<void> _waitForNavigationRoute({
    required Duration timeout,
    required bool Function() condition,
    required FutureOr<void> Function() onPump,
  }) async {
    await _settler(onPump: onPump).waitFor(
      timeout: timeout,
      condition: condition,
    );
  }

  EventDrivenSettler _settler({
    FutureOr<void> Function()? onPump,
  }) =>
      EventDrivenSettler(
        tester: tester,
        hasExternalWork: () => context.apiOverlay.hasPendingLiveCalls,
        waitForExternalWork: context.apiOverlay.waitForLiveCalls,
        externalWorkPollTimeout: config.waitPollInterval,
        activeFrameDuration: config.settleStepDuration,
        onPump: onPump,
      );
}
