import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:yaml/yaml.dart';

/// Applies command line selectors to discovered declarative test definitions.
///
/// Keeping selector parsing in one value-oriented component makes discovery
/// and sharding independent from the CLI orchestration lifecycle.
final class CliTestSelection {
  const CliTestSelection._();

  /// Reads repeatable `--name=value` options shared by CLI selection paths.
  static List<String> values(List<String> arguments, String name) {
    return arguments
        .where((arg) => arg.startsWith('$name='))
        .map((arg) => arg.substring(name.length + 1))
        .where((value) => value.isNotEmpty)
        .toList();
  }

  /// Reads comma-separated values from repeatable CLI options.
  static Set<String> valueSet(List<String> arguments, String name) {
    return {
      for (final value in values(arguments, name))
        for (final part in value.split(','))
          if (part.trim().isNotEmpty) part.trim(),
    };
  }

  static bool hasShardSelection(List<String> arguments) {
    const options = {'--id', '--feature', '--profile', '--tag', '--path'};
    return options.any((option) => valueSet(arguments, option).isNotEmpty);
  }

  /// Whether any user selection can change the historical duration cache.
  static bool hasSelection(List<String> arguments) {
    const options = {
      '--id',
      '--feature',
      '--profile',
      '--tag',
      '--path',
      '--device',
    };
    return options.any((option) => valueSet(arguments, option).isNotEmpty);
  }

  static bool matchesExpandedShardSelection(
    ExpandedShardDefinition definition,
    List<String> arguments, {
    EnsembleTestConfig? config,
  }) {
    final ids = valueSet(arguments, '--id');
    final features = valueSet(arguments, '--feature');
    final profiles = _expandedProfileSelections(
      valueSet(arguments, '--profile'),
      config,
    );
    final tags = valueSet(arguments, '--tag');
    final paths = valueSet(arguments, '--path');
    final devices = valueSet(arguments, '--device');

    if (devices.isNotEmpty) {
      final deviceId = definition.deviceId;
      if (deviceId == null || !devices.contains(deviceId)) return false;
    }
    if (ids.isNotEmpty &&
        !ids.any(
          (id) => definition.id == id || definition.id.startsWith('$id['),
        )) {
      return false;
    }
    if (features.isNotEmpty && !features.contains(definition.feature)) {
      return false;
    }
    if (profiles.isNotEmpty) {
      final profile = definition.profile;
      if (profile == null || !profiles.contains(profile)) return false;
    }
    if (tags.isNotEmpty && !definition.tags.any(tags.contains)) return false;
    if (paths.isNotEmpty &&
        !paths.any((path) => definition.assetPath.contains(path))) {
      return false;
    }
    return true;
  }

  static List<String> profileNamesForShard(
    YamlMap doc, {
    required EnsembleTestConfig config,
  }) {
    final selectors = _stringList(doc['profiles']);
    final effectiveSelectors =
        selectors.isEmpty && config.defaultProfile != null
            ? [config.defaultProfile!]
            : selectors;
    final names = <String>[];
    for (final selector in effectiveSelectors) {
      final group = config.profileGroups[selector];
      if (group != null) {
        names.addAll(group);
      } else {
        names.add(selector);
      }
    }
    return names;
  }

  static List<String> scenarioIds(YamlMap doc) {
    final scenarios = doc['scenarios'];
    if (scenarios is! YamlList) return const [];
    return [
      for (final scenario in scenarios)
        if (scenario is YamlMap && scenario['id'] != null)
          scenario['id'].toString(),
    ];
  }

  static List<String> stringList(dynamic value) => _stringList(value);

  static bool matchesShardSelection(
    String relativePath,
    YamlMap? doc,
    List<String> arguments, {
    EnsembleTestConfig? config,
  }) {
    final ids = valueSet(arguments, '--id');
    final features = valueSet(arguments, '--feature');
    final profiles = _expandedProfileSelections(
      valueSet(arguments, '--profile'),
      config,
    );
    final tags = valueSet(arguments, '--tag');
    final paths = valueSet(arguments, '--path');
    if (ids.isEmpty &&
        features.isEmpty &&
        profiles.isEmpty &&
        tags.isEmpty &&
        paths.isEmpty) {
      return true;
    }
    if (paths.any(relativePath.contains)) return true;
    if (doc == null) return false;

    final id = doc['id']?.toString();
    if (id != null &&
        ids.any((selected) => id == selected || selected.startsWith('$id['))) {
      return true;
    }
    if (_scenarioIds(doc).any(ids.contains)) return true;

    final feature = doc['feature']?.toString();
    if (feature != null && features.contains(feature)) return true;
    if (_matchesProfileShardSelection(doc, profiles, config)) return true;
    final docTags = _stringList(doc['tags']);
    return docTags.any(tags.contains);
  }
}

final class ExpandedShardDefinition {
  final String id;
  final String assetPath;
  final String? feature;
  final List<String> tags;
  final String? profile;
  final String? deviceId;
  final String? session;

  const ExpandedShardDefinition({
    required this.id,
    required this.assetPath,
    required this.feature,
    required this.tags,
    required this.profile,
    required this.deviceId,
    required this.session,
  });
}

bool _matchesProfileShardSelection(
  YamlMap doc,
  Set<String> selectedProfiles,
  EnsembleTestConfig? config,
) {
  if (selectedProfiles.isEmpty) return false;
  if (config == null) return true;
  final selectors = _stringList(doc['profiles']);
  final effectiveSelectors = selectors.isEmpty && config.defaultProfile != null
      ? [config.defaultProfile!]
      : selectors;
  if (effectiveSelectors.isEmpty) return false;
  final expandedProfiles = <String>{};
  for (final selector in effectiveSelectors) {
    final group = config.profileGroups[selector];
    if (group != null) {
      expandedProfiles.addAll(group);
    } else {
      expandedProfiles.add(selector);
    }
  }
  return expandedProfiles.any(selectedProfiles.contains);
}

Set<String> _expandedProfileSelections(
  Set<String> selectedProfiles,
  EnsembleTestConfig? config,
) {
  if (selectedProfiles.isEmpty || config == null) return selectedProfiles;
  final expanded = <String>{};
  for (final profile in selectedProfiles) {
    expanded.add(profile);
    final group = config.profileGroups[profile];
    if (group != null) expanded.addAll(group);
  }
  return expanded;
}

List<String> _scenarioIds(YamlMap doc) {
  final scenarios = doc['scenarios'];
  if (scenarios is! YamlList) return const [];
  return [
    for (final scenario in scenarios)
      if (scenario is YamlMap && scenario['id'] != null)
        scenario['id'].toString(),
  ];
}

List<String> _stringList(dynamic value) {
  if (value is YamlList || value is List) {
    return [
      for (final item in value)
        if (item != null) item.toString()
    ];
  }
  if (value is String && value.trim().isNotEmpty) return [value.trim()];
  return const [];
}
