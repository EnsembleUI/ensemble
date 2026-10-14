# Ensemble Test Runner architecture

Status: current architecture
Scope: test discovery, planning, execution, evidence, and reporting

This document describes the architecture implemented in the single
`ensemble_test_runner` package.

## System flow

```text
CLI / host entry points
  -> discover and parse test definitions
  -> validate, expand, and compile an execution plan
  -> schedule test cases across workers
  -> create an attempt scope and execution kernel
  -> dispatch operations through the runtime registry
  -> execute through the Flutter session and application adapter
  -> publish execution events to evidence and result consumers
  -> write ensemble_test.db, index.html, and screenshots.zip
```

The runner keeps public host integration in `runEnsembleTests` and
`runEnsembleIntegrationTests`. Standalone, widget, and application-hosted runs
share compiled operation execution and attempt-level lifecycle services. The
host adapters provide application startup and cleanup; the runner owns test
planning, scheduling, step execution, and reporting.

All code is in one package. The Flutter-free contracts in `lib/src/core` keep
the execution kernel independent of Flutter APIs, while the production runtime
and most test execution code use Flutter.

## Components and ownership

| Component | Owns |
| --- | --- |
| CLI and process coordination | Command options, app preparation, worker processes, cancellation, resource cleanup, and result merging |
| Discovery and compiler | Loading definitions, parsing, validation, scenario/profile expansion, mock resolution, source mapping, and compiled plans |
| Suite scheduler | Test selection, device expansion, worker capacity, retries, shared-state ordering, and aggregate results |
| Execution kernel | Per-attempt state, operation limits, cancellation, event ordering, primary failure selection, and guaranteed runtime close |
| Operation registry | Supported operation names, aliases, kinds, input policies, permissions, and handler keys |
| Flutter runtime and session | Operation dispatch, UI lookup, gestures, text entry, waits, assertions, navigation, and stable failure mapping |
| Application adapters | App bootstrap, test environment setup, storage reset, start-screen launch, and host-specific teardown |
| Evidence and reporting | Step timing, screenshots, logs, storage/API records, report projections, database persistence, and HTML resources |

The kernel executes one attempt. It does not launch processes, schedule a suite,
render HTML, or encode screenshots. Runtime handlers perform Flutter operations
through the local session. The session scopes mutable UI state, target
resolution, capabilities, permissions, observation revisions, and artifacts to
the active test attempt.

The registry is the runtime source of operation metadata and handler routing.
The compiler validates definitions before execution; runtime dispatch validates
the operation kind and handler identity before invoking the selected behavior.
The parser and plan compiler own test-document normalization. Flutter handlers
receive normalized operation inputs rather than parsing source documents.

## Execution lifecycle

1. The CLI discovers definitions and loads runner configuration.
2. The compiler parses, validates, expands, and compiles test cases into plans.
3. The scheduler selects cases, expands device runs, and assigns work to
   workers.
4. An attempt scope creates its runtime, session, event consumers, and cleanup
   boundary.
5. The execution kernel advances the compiled plan and dispatches each
   operation to the runtime.
6. The runtime observes or acts on the Flutter application and returns a
   structured result. The kernel records sequence, timing, outcome, and
   failure state.
7. Event consumers capture configured evidence and project results for the
   console, database, and HTML report.
8. Attempt and suite cleanup run even when an operation fails.

Plan control flow includes operations, branches, loops, checkpoints, and end
nodes. Runtime limits and cancellation are checked at the kernel boundary.
Retries create separate attempt scopes so failures and artifacts retain their
attempt identity.

## Runtime behavior

The operation registry supplies the handler key used by runtime dispatch.
Interactions, waits, assertions, lifecycle operations, and configured
environment or storage operations use the same operation model. Handler
implementations remain separated by responsibility; the registry centralizes
the supported vocabulary and dispatch metadata.

The Flutter session owns target resolution and invalidates revision-scoped
finder state after UI mutations. It records observation revisions and exposes
the current application state to actions, assertions, wait conditions, and
diagnostics. Normal execution requests only the information required by its
operation; richer observation is used for report evidence or failure
diagnostics.

Wait operations are condition-driven where the condition can be observed. Frame
pumping is limited to operations that need Flutter to advance, such as a
pending route transition or a scheduled UI update. Post-action settling is
bounded, and an idle event loop is not used as a substitute for a specific
condition.

Application-hosted and standalone execution retain their own bootstrap and
suite entry points. Both use the shared attempt execution kernel and Flutter
session. Application-specific setup and teardown remain inside their adapters.

## Events, evidence, and reporting

The execution kernel publishes ordered events for attempt lifecycle,
operation execution, observations, checkpoints, artifacts, warnings, and
failures. Event consumers handle timing, screenshots, storage diffs, API and
console logs, performance markers, and report data. Optional evidence capture
does not make execution decisions or replace a test's primary failure.

The report directory contains three durable artifacts:

- `ensemble_test.db` stores live report state, current results, recent run
  history, test catalog entries, and scheduling durations.
- `index.html` is the report shell. Its JavaScript and CSS are packaged as
  frontend resources, and the page reads report data from the database.
- `screenshots.zip` stores screenshot assets in WebP format. The report reads
  the archive without extracting it.

The database uses `report_state`, `test_results`, and `test_catalog`; run
summary rows and test rows are represented in `test_results`. Result
projections provide the fields consumed by the console, database, and HTML so
those outputs do not independently reinterpret execution records.

## Package organization

```text
ensemble_test_runner/
  lib/src/core/                 operations, plans, kernel, events, and contracts
  lib/src/runtime/              Flutter runtime and operation dispatch
  lib/{discovery,parser}/       test loading and plan compilation
  lib/{runner,application}/     suite/attempt lifecycle and host adapters
  lib/{session,actions}/        Flutter session, locators, waits, and operations
  lib/reporters/                database, report projections, and screenshot archive
  resources/report/             HTML, CSS, and JavaScript resources
  lib/cli/ + bin/               CLI and process coordination
  tool/benchmarks/              runner benchmark tooling
```

The runner is a development dependency. It is not included in released
application binaries. Core contracts are Flutter-free, but the package's
default execution and CLI dependency graph requires Flutter.

## Runtime invariants

1. The test-definition format and supported operation vocabulary are stable
   inputs to planning and execution.
2. The compiler owns definition parsing, validation, and plan construction.
3. The registry owns operation metadata and runtime handler routing.
4. The kernel owns per-attempt state transitions, limits, cancellation, and
   primary failure selection.
5. The runtime is the only layer that interacts with the application UI.
6. Evidence consumers record results but do not change test execution state.
7. Mutable state is scoped to a suite, attempt, session, or operation.
8. App setup and cleanup remain in the appropriate application adapter.
9. Changes to execution timing or target resolution must preserve the
   application test suite's observed behavior.
10. Performance claims use warmed suite timings on the same machine and worker count.
