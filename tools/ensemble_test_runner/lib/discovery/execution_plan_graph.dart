import 'package:ensemble_test_runner/src/benchmark_measurement.dart';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';

import 'ensemble_test_execution_planner.dart';

/// Selection and dependency graph operations used while assembling a plan.
///
/// This boundary keeps graph policy independent from asset parsing and mock
/// expansion. It deliberately works on the planner's public value objects so
/// callers get the same ordering and selection semantics as before.
class ExecutionPlanGraph {
  const ExecutionPlanGraph._();

  static Map<String, EnsembleTestDefinition> applySelection(
    Map<String, EnsembleTestDefinition> byId,
    EnsembleTestSelection selection,
  ) {
    return RunnerBenchmark.sync('planner', 'applySelection', () {
      if (selection.isEmpty) return byId;

      final selectedIds = byId.entries
          .where((entry) => matchesSelection(entry.value, selection))
          .map((entry) => entry.key)
          .toSet();
      if (selectedIds.isEmpty) {
        throw EnsembleTestFailure(
          'No tests matched the provided selection flags',
        );
      }

      void includeDependencies(String id) {
        final test = byId[id]?.testCase;
        final dependencies = <String>[
          if (test?.session != null) test!.session!,
        ];
        for (final dependency in dependencies) {
          if (!byId.containsKey(dependency)) {
            throw EnsembleTestFailure(
              'Selected test "$id" references unknown dependency "$dependency"',
            );
          }
          if (selectedIds.add(dependency)) includeDependencies(dependency);
        }
      }

      for (final id in selectedIds.toList()) {
        includeDependencies(id);
      }

      return {
        for (final id in byId.keys)
          if (selectedIds.contains(id)) id: byId[id]!,
      };
    });
  }

  static Map<String, EnsembleTestDefinition> applyExactIdSelection(
    Map<String, EnsembleTestDefinition> byId,
    Set<String> exactIds,
  ) {
    final selectedIds = <String>{};

    void includeWithDependencies(String id) {
      final definition = byId[id];
      if (definition == null) {
        throw EnsembleTestFailure('Selected test "$id" was not found.');
      }
      if (!selectedIds.add(id)) return;
      final session = definition.testCase.session;
      if (session != null) includeWithDependencies(session);
    }

    for (final id in exactIds) {
      includeWithDependencies(id);
    }

    return {
      for (final id in byId.keys)
        if (selectedIds.contains(id)) id: byId[id]!,
    };
  }

  static EnsembleTestSelection expandProfileGroupSelection(
    EnsembleTestSelection selection,
    Map<String, List<String>> profileGroups,
  ) {
    if (selection.profiles.isEmpty || profileGroups.isEmpty) return selection;
    final expanded = <String>{};
    for (final profile in selection.profiles) {
      expanded.add(profile);
      final group = profileGroups[profile];
      if (group != null) expanded.addAll(group);
    }
    return EnsembleTestSelection(
      ids: selection.ids,
      features: selection.features,
      profiles: expanded,
      tags: selection.tags,
      paths: selection.paths,
      exactIds: selection.exactIds,
    );
  }

  static List<EnsembleTestDefinition> topologicalSort(
    Map<String, EnsembleTestDefinition> byId,
  ) {
    return RunnerBenchmark.sync('planner', 'topologicalSort', () {
      final inDegree = <String, int>{};
      final dependents = <String, List<String>>{};

      for (final id in byId.keys) {
        inDegree[id] = 0;
        dependents[id] = [];
      }

      for (final entry in byId.entries) {
        final session = entry.value.testCase.session;
        if (session != null) {
          inDegree[entry.key] = (inDegree[entry.key] ?? 0) + 1;
          dependents[session]!.add(entry.key);
        }
      }

      final ready = <String>[];
      for (final id in byId.keys) {
        if (inDegree[id] == 0) ready.add(id);
      }
      ready.sort((a, b) => byId[a]!.assetPath.compareTo(byId[b]!.assetPath));

      final orderedIds = <String>[];
      while (ready.isNotEmpty) {
        ready.sort((a, b) => byId[a]!.assetPath.compareTo(byId[b]!.assetPath));
        final id = ready.removeAt(0);
        orderedIds.add(id);
        for (final dependent in dependents[id]!) {
          inDegree[dependent] = inDegree[dependent]! - 1;
          if (inDegree[dependent] == 0) ready.add(dependent);
        }
      }

      if (orderedIds.length != byId.length) {
        throw EnsembleTestFailure(
          'Circular test dependency among tests: '
          '${byId.keys.where((id) => !orderedIds.contains(id)).join(", ")}',
        );
      }

      return orderedIds.map((id) => byId[id]!).toList();
    });
  }

  static bool idBelongsToSelection(String testId, Set<String> selectedIds) {
    if (selectedIds.contains(testId)) return true;
    for (final selectedId in selectedIds) {
      if (testId.startsWith('$selectedId[')) return true;
    }
    return false;
  }

  static bool matchesProfileSelection(
    EnsembleTestCase test,
    EnsembleTestSelection selection,
  ) {
    if (selection.profiles.isEmpty) return true;
    final profile = test.profile;
    if (profile != null && selection.profiles.contains(profile)) return true;
    return test.profiles.any((name) => selection.profiles.contains(name));
  }

  static bool matchesSelection(
    EnsembleTestDefinition def,
    EnsembleTestSelection selection,
  ) {
    final test = def.testCase;
    final idMatches = selection.ids.isNotEmpty &&
        selection.ids.any(
          (id) =>
              test.id == id ||
              test.id.startsWith('$id[') ||
              id.startsWith('${test.id}['),
        );
    final featureMatches = selection.features.isNotEmpty &&
        selection.features.contains(test.feature);
    final profileMatches = selection.profiles.isNotEmpty &&
        matchesProfileSelection(test, selection);
    final tagMatches = selection.tags.isNotEmpty &&
        test.tags.any((tag) => selection.tags.contains(tag));
    final pathMatches = selection.paths.isNotEmpty &&
        selection.paths.any((path) => def.assetPath.contains(path));
    return idMatches ||
        featureMatches ||
        profileMatches ||
        tagMatches ||
        pathMatches;
  }
}
