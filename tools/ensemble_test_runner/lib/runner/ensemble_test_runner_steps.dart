part of 'ensemble_test_runner.dart';

extension _EnsembleTestRunnerSteps on EnsembleTestRunner {
  Future<EnsembleSingleTestResult> _executeSteps({
    required EnsembleTestCase test,
    required WidgetTester tester,
    required EnsembleTestContext ctx,
    required EnsembleConfig config,
    required Stopwatch stopwatch,
    CompiledPlanReuse? planReuse,
  }) async {
    return await RunnerBenchmark.async('workflow', 'executeSteps', () async {
      final executorServices = StandaloneEnsembleApplicationHandle(
        context: ctx,
        configDescription: const {},
        ownsNavigationFlow: false,
      ).services;
      final session = LocalTestExecutionSession.attach(
        tester: tester,
        context: ctx,
        harness: harness,
        services: executorServices,
        config: config,
        sessionId: test.id,
      );
      final executor = session.executor;
      var kernelOwnsSession = false;
      final stepDurationsMs = <int>[];
      final stepStartTimes = <String>[];
      final stepTiming = StepTimingSubscriber();
      final storageDiffs = StorageStepDiffSubscriber(
        enabled: ctx.config.logStorage.enabled,
        recordDiff: (stepIndex, before) =>
            _artifactCoordinator.recordStorageStepDiff(
          context: ctx,
          stepIndex: stepIndex,
          before: before,
        ),
      );
      _ActiveStep? activeStep;
      final stepEvidence = StepEvidenceSubscriber(
          shouldCaptureStep: (stepIndex) => ctx.config.screenshots
              .shouldCaptureStep(test.steps[stepIndex].type),
          capture: (stepIndex) async {
            return _visuals.captureStepArtifacts(
              executor: executor,
              step: test.steps[stepIndex],
              stepIndex: stepIndex,
              options:
                  StepScreenshotOptions.afterCondition(test.steps[stepIndex]),
            );
          },
          captureBeforeMutation: (event) async {
            final step = test.steps[event.stepIndex!];
            switch (StepEvidencePolicy.classify(event.detail)) {
              case StepEvidenceBoundary.condition:
                return _visuals.captureStepArtifacts(
                  executor: executor,
                  step: step,
                  stepIndex: event.stepIndex!,
                  options: StepScreenshotOptions.matchedCondition(),
                );
              case StepEvidenceBoundary.textMatch:
                await _visuals.waitForHighlightTargetToPaint(executor, step);
                return _visuals.captureStepArtifacts(
                  executor: executor,
                  step: step,
                  stepIndex: event.stepIndex!,
                  options: StepScreenshotOptions.waitForTextMatched(),
                );
              case StepEvidenceBoundary.navigation:
                return _visuals.captureStepArtifacts(
                  executor: executor,
                  step: step,
                  stepIndex: event.stepIndex!,
                  options: StepScreenshotOptions.waitForNavigationMatched(),
                  captureScreenshot: () =>
                      _visuals.captureWaitForNavigationScreenshot(
                    executor: executor,
                    step: step,
                    stepIndex: event.stepIndex!,
                  ),
                );
              case StepEvidenceBoundary.orderedOperation:
                return _visuals.captureStepArtifacts(
                  executor: executor,
                  step: step,
                  stepIndex: event.stepIndex!,
                  options: StepScreenshotOptions.beforeAction(
                    targetAlreadyResolved: true,
                  ),
                );
              case StepEvidenceBoundary.none:
                return false;
            }
          });
      Object? eventFailure;
      StackTrace? eventFailureStack;
      final cancellation = ExecutionCancellation();

      void recordStepDuration(_ActiveStep state) {
        if (state.durationRecorded) return;
        stepDurationsMs.add(
          stepTiming.durationFor(state.index) ??
              stepTiming.elapsedMsFor(state.index),
        );
        state.durationRecorded = true;
      }

      void recordStepPerformance(_ActiveStep state) {
        _recordPerformanceMarker(
          ctx: ctx,
          testId: test.id,
          stepIndex: state.index + 1,
          label:
              '${test.id} step ${state.index + 1} ${formatStepBrief(test.steps[state.index])}',
          phase: _phaseForStep(test.steps[state.index]),
          startFrame: state.startFrame,
          startTime: state.startTime,
        );
        _visuals.captureScreenArtifacts(ctx);
      }

      final performanceEvidence = StepPerformanceSubscriber(
        capture: (stepIndex) async {
          final state = activeStep;
          if (state?.index == stepIndex) recordStepPerformance(state!);
        },
      );
      final attemptArtifacts = AttemptArtifactSubscriber(
        publish: () => _artifactCoordinator.attachLogArtifactsOnce(ctx),
      );
      final stepContext = StepContextSubscriber(
        onStepStarted: (index) => ctx.runtime.currentStepIndex = index,
      );

      Future<void> beginStep(int index) async {
        final state = _ActiveStep(
          index: index,
          startFrame: ctx.runtime.appFrameTimings.length + 1,
          startTime: DateTime.now(),
        );
        activeStep = state;
        stepStartTimes.add(stepTiming.startTimeFor(index) ??
            state.startTime.toIso8601String());
        _drainFlutterExceptions(tester);
      }

      Future<void> finishStep(int index) async {
        final state = activeStep;
        if (state == null || state.index != index) {
          throw StateError('Step boundary $index finished without starting.');
        }
        final step = test.steps[index];
        if (ctx.config.screenshots.enabled && isUserActionStep(step)) {
          await _visuals.paintAfterUserAction(executor, ctx);
        }
        _drainFlutterExceptions(tester);
        await ctx.navigationFlow.flushPending();
        recordStepDuration(state);
        if (ctx.config.performance.enabled) {
          await performanceEvidence.flush(index);
        }
        activeStep = null;
      }

      final stepBoundary = StepBoundarySubscriber(
        onStarted: beginStep,
        onFinished: finishStep,
        onError: (error, stackTrace) {
          eventFailure ??= error;
          eventFailureStack ??= stackTrace;
          cancellation.cancel();
        },
      );

      Future<EnsembleSingleTestResult> failStep(
          int index, Object error, StackTrace stackTrace,
          {String? failureOperation,
          SourceLocation? failureSource,
          TestFailureDetails? failureDetails,
          List<TestFailureDetails> secondaryFailures = const []}) async {
        final step = test.steps[index];
        final state = activeStep;
        if (state != null) {
          recordStepDuration(state);
        }
        final idleStartFrame = ctx.runtime.appFrameTimings.length + 1;
        final idleStartTime = DateTime.now();
        _drainFlutterExceptions(tester);
        if (state == null || !stepEvidence.hasCaptured(index)) {
          await stepEvidence.captureOnce(
              index,
              () => _visuals.captureStepArtifacts(
                    executor: executor,
                    step: step,
                    stepIndex: index,
                    options: StepScreenshotOptions.onFailure(),
                  ),
              enabled: ctx.config.screenshots.shouldCaptureStep(step.type));
        }
        await _settleLiveApiWorkBestEffort(tester, ctx);
        final failureMessage = error.toString();
        await _flushPendingScreenshots(
          ctx,
          status: TestStatus.failed,
          durationMs: stopwatch.elapsedMilliseconds,
          failedStepIndex: index,
          failedStepLabel: formatStepBrief(step),
          failureMessage: failureMessage,
        );
        await ctx.navigationFlow.flushPending();
        _recordPerformanceMarker(
          ctx: ctx,
          testId: test.id,
          stepIndex: null,
          label: '${test.id} failure cleanup',
          phase: 'idle',
          startFrame: idleStartFrame,
          startTime: idleStartTime,
        );
        await _artifactCoordinator.attachPerTestDebugArtifactsOnce(ctx);
        return EnsembleSingleTestResult.failed(
          testId: test.id,
          metadata: test.metadataJson,
          failedStepIndex: index,
          failedStep: step,
          message: failureMessage,
          stackTrace: stackTrace.toString(),
          failureOperation: failureOperation,
          failureSource: failureSource,
          durationMs: stopwatch.elapsedMilliseconds,
          logs: ctx.logger.logs,
          failure: failureDetails ??
              TestFailureDetails.fromMessage(
                failureMessage,
                phase: 'execution',
                target: {
                  if (step.args['id'] != null) 'id': step.args['id'],
                  if (step.args['target'] is Map)
                    'target': Map<String, dynamic>.from(
                      step.args['target'] as Map,
                    ),
                },
              ),
          secondaryFailures: secondaryFailures,
          report: buildTestReportDetails(
            test,
            stepDurationsMs: stepDurationsMs,
            stepStartTimes: stepStartTimes,
            screens: ctx.runtime.screenArtifacts,
            navigationFlow: ctx.navigationFlow,
          ),
        );
      }

      try {
        final plan = planReuse?.plan ?? CompiledPlanCompiler().compile(test);
        final runtime = FlutterTestRuntime(session);
        final kernel = ExecutionKernelRunner(
          plan: plan,
          runtime: runtime,
          cancellation: cancellation,
          eventSubscriptions: [
            EventSubscription(
              kinds: {
                ExecutionEventKind.stepStarted,
                ExecutionEventKind.stepFinished,
              },
              handle: stepTiming.call,
            ),
            EventSubscription(
              kinds: {
                ExecutionEventKind.stepStarted,
                ExecutionEventKind.stepFinished,
              },
              handle: stepContext.call,
            ),
            if (ctx.config.logStorage.enabled)
              EventSubscription(
                kinds: {
                  ExecutionEventKind.stepStarted,
                  ExecutionEventKind.stepFinished,
                  ExecutionEventKind.attemptFinished,
                },
                handle: storageDiffs.call,
              ),
            if (ctx.config.performance.enabled)
              EventSubscription(
                kinds: {ExecutionEventKind.stepFinished},
                handle: performanceEvidence.call,
              ),
            EventSubscription(
              kinds: {ExecutionEventKind.attemptFinished},
              handle: attemptArtifacts.call,
            ),
            EventSubscription(
              kinds: {
                ExecutionEventKind.stepStarted,
                ExecutionEventKind.stepFinished,
              },
              handle: stepBoundary.call,
            ),
            if (ctx.config.screenshots.enabled)
              EventSubscription(
                kinds: {
                  ExecutionEventKind.evidenceBoundary,
                  ExecutionEventKind.stepFinished,
                },
                handle: stepEvidence.call,
              ),
          ],
        );
        // ExecutionKernel owns runtime cleanup after run starts. The local
        // finally remains responsible only for pre-run setup failures.
        kernelOwnsSession = true;
        final result = await kernel.run();

        if (eventFailure != null || result.outcome != AttemptOutcome.passed) {
          final index = activeStep?.index ??
              _stepIndexFromSource(result.failureSource) ??
              test.steps.length - 1;
          final error = eventFailure ??
              result.cause ??
              EnsembleTestFailure(
                  result.primaryFailure ?? 'Execution did not pass.');
          final stackTrace =
              eventFailureStack ?? result.stackTrace ?? StackTrace.current;
          return await failStep(
            index,
            error,
            stackTrace,
            failureOperation: result.failureOperation,
            failureSource: result.failureSource,
            failureDetails: eventFailure == null
                ? TestFailureDetails.fromExecutionCode(
                    result.failureCode,
                    error.toString(),
                    phase: 'execution',
                    target: {
                      if (test.steps[index].args['id'] != null)
                        'id': test.steps[index].args['id'],
                      if (test.steps[index].args['target'] is Map)
                        'target': Map<String, dynamic>.from(
                          test.steps[index].args['target'] as Map,
                        ),
                    },
                  )
                : null,
            secondaryFailures: result.secondaryFailures
                .map(TestFailureDetails.fromSecondaryMessage)
                .toList(growable: false),
          );
        }
        ctx.runtime.currentStepIndex = null;

        await ctx.navigationFlow.flushPending();
        final idleStartFrame = ctx.runtime.appFrameTimings.length + 1;
        final idleStartTime = DateTime.now();
        await _settleLiveApiWorkBestEffort(tester, ctx);
        _drainFlutterExceptions(tester);
        await _flushPendingScreenshots(
          ctx,
          status: TestStatus.passed,
          durationMs: stopwatch.elapsedMilliseconds,
        );
        _recordPerformanceMarker(
          ctx: ctx,
          testId: test.id,
          stepIndex: null,
          label: '${test.id} idle',
          phase: 'idle',
          startFrame: idleStartFrame,
          startTime: idleStartTime,
        );
        await _artifactCoordinator.attachPerTestDebugArtifactsOnce(ctx);

        return EnsembleSingleTestResult.passed(
          testId: test.id,
          metadata: test.metadataJson,
          durationMs: stopwatch.elapsedMilliseconds,
          logs: ctx.logger.logs,
          report: buildTestReportDetails(
            test,
            stepDurationsMs: stepDurationsMs,
            stepStartTimes: stepStartTimes,
            screens: ctx.runtime.screenArtifacts,
            navigationFlow: ctx.navigationFlow,
          ),
        );
      } finally {
        if (!kernelOwnsSession) await session.close();
      }
    });
  }
}
