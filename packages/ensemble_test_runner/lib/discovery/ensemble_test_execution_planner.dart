import 'package:flutter/foundation.dart';

import 'package:ensemble_test_runner/discovery/ensemble_test_discovery.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/parser/ensemble_test_parser.dart';

/// A parsed `*.test.yaml` file with its asset path.
class EnsembleTestDefinition {
  final String assetPath;
  final EnsembleTestCase testCase;

  const EnsembleTestDefinition({
    required this.assetPath,
    required this.testCase,
  });
}

/// Topologically sorted test run order (each test id appears once).
class EnsembleTestExecutionPlan {
  final List<EnsembleTestDefinition> ordered;

  const EnsembleTestExecutionPlan({required this.ordered});
}

/// Builds a dependency-ordered execution plan for all declarative tests.
class EnsembleTestExecutionPlanner {
  /// Discovers assets, parses every file, validates graph, returns run order.
  static Future<EnsembleTestExecutionPlan> build({
    EnsembleTestAppTarget? target,
  }) async {
    final resolvedTarget =
        target ?? await EnsembleTestDiscovery.loadAppTarget();
    final paths = await EnsembleTestDiscovery.findTestYamlAssets(
      resolvedTarget.testsAssetPrefix,
    );
    if (paths.isEmpty) {
      throw EnsembleTestFailure(
        'No declarative tests found. Add *.test.yaml files under '
        '${resolvedTarget.testsAssetPrefix}',
      );
    }

    final byId = <String, EnsembleTestDefinition>{};
    for (final path in paths) {
      final testCase = await EnsembleTestParser.parseFile(path);
      final existing = byId[testCase.id];
      if (existing != null) {
        throw EnsembleTestFailure(
          'Duplicate test id "${testCase.id}" in ${existing.assetPath} and $path',
        );
      }
      byId[testCase.id] = EnsembleTestDefinition(
        assetPath: path,
        testCase: testCase,
      );
    }

    for (final def in byId.values) {
      final prereq = def.testCase.prerequisite;
      if (prereq != null && !byId.containsKey(prereq)) {
        throw EnsembleTestFailure(
          'Test "${def.testCase.id}" in ${def.assetPath} references unknown '
          'prerequisite "$prereq"',
        );
      }
    }

    final ordered = _topologicalSort(byId);
    return EnsembleTestExecutionPlan(ordered: ordered);
  }

  /// IDs that participate in a shared session (`prerequisite` chain).
  static Set<String> _sessionConnectedIds(
    Map<String, EnsembleTestDefinition> byId,
  ) {
    final connected = <String>{};
    for (final def in byId.values) {
      final prereq = def.testCase.prerequisite;
      if (prereq == null) continue;
      connected.add(def.testCase.id);
      connected.add(prereq);
    }
    var expanded = true;
    while (expanded) {
      expanded = false;
      for (final def in byId.values) {
        final prereq = def.testCase.prerequisite;
        if (prereq != null &&
            connected.contains(prereq) &&
            connected.add(def.testCase.id)) {
          expanded = true;
        }
      }
    }
    return connected;
  }

  /// Kahn's algorithm: edge from test → its prerequisite (prereq runs first).
  ///
  /// Tests with [EnsembleTestCase.hasStartScreen] that are not in a prerequisite
  /// chain run **after** the chain so [EnsembleTestHarness.loadScreen] does not
  /// reset the session for continuation tests.
  static List<EnsembleTestDefinition> _topologicalSort(
    Map<String, EnsembleTestDefinition> byId,
  ) {
    final sessionConnected = _sessionConnectedIds(byId);
    final inDegree = <String, int>{};
    final dependents = <String, List<String>>{};

    for (final id in byId.keys) {
      inDegree[id] = 0;
      dependents[id] = [];
    }

    for (final entry in byId.entries) {
      final prereq = entry.value.testCase.prerequisite;
      if (prereq == null) continue;
      inDegree[entry.key] = (inDegree[entry.key] ?? 0) + 1;
      dependents[prereq]!.add(entry.key);
    }

    bool sessionChainComplete(List<String> ordered) {
      if (sessionConnected.isEmpty) return true;
      return sessionConnected.every(ordered.contains);
    }

    bool canSchedule(String id, List<String> ordered) {
      if (inDegree[id] != 0) return false;
      if (sessionConnected.contains(id)) return true;
      return sessionChainComplete(ordered);
    }

    final ready = <String>[];
    for (final id in byId.keys) {
      if (canSchedule(id, const [])) ready.add(id);
    }
    ready.sort((a, b) => byId[a]!.assetPath.compareTo(byId[b]!.assetPath));

    final orderedIds = <String>[];
    while (ready.isNotEmpty) {
      ready.sort((a, b) => byId[a]!.assetPath.compareTo(byId[b]!.assetPath));
      final id = ready.removeAt(0);
      orderedIds.add(id);
      for (final dependent in dependents[id]!) {
        inDegree[dependent] = inDegree[dependent]! - 1;
        if (inDegree[dependent] == 0 && canSchedule(dependent, orderedIds)) {
          ready.add(dependent);
        }
      }
      for (final candidate in byId.keys) {
        if (!orderedIds.contains(candidate) &&
            !ready.contains(candidate) &&
            canSchedule(candidate, orderedIds)) {
          ready.add(candidate);
        }
      }
    }

    if (orderedIds.length != byId.length) {
      throw EnsembleTestFailure(
        'Circular prerequisite dependency among tests: '
        '${byId.keys.where((id) => !orderedIds.contains(id)).join(", ")}',
      );
    }

    return orderedIds.map((id) => byId[id]!).toList();
  }

  /// Exposed for unit tests only.
  @visibleForTesting
  static List<String> orderIdsForTest(
    Map<String, EnsembleTestDefinition> byId,
  ) {
    return _topologicalSort(byId).map((d) => d.testCase.id).toList();
  }
}
