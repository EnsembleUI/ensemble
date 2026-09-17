import 'package:ensemble_test_runner/session/yaml/session_step_routing.dart';

/// What a session **adapter** can honestly provide.
///
/// Distinct from [SessionPermissions], which is what a **caller** may invoke.
/// An operation is allowed only when it is both capable and permitted.
class SessionCapabilities {
  final Set<String> actions;
  final Set<String> assertionDomains;
  final Set<String> waits;
  final bool semanticTree;
  final bool runtimeMetadata;
  final bool navigationState;
  final bool screenshots;
  final bool coordinateActions;
  final bool apiAssertions;
  final bool storageAssertions;
  final bool secureFieldRedaction;
  final bool observationRevisions;
  final bool snapshotElementTargets;

  const SessionCapabilities({
    this.actions = const {},
    this.assertionDomains = const {},
    this.waits = const {},
    this.semanticTree = false,
    this.runtimeMetadata = false,
    this.navigationState = false,
    this.screenshots = false,
    this.coordinateActions = false,
    this.apiAssertions = false,
    this.storageAssertions = false,
    this.secureFieldRedaction = false,
    this.observationRevisions = false,
    this.snapshotElementTargets = false,
  });

  /// Local adapter capabilities derived from [TestStepRegistry] UI actions.
  static final SessionCapabilities local = SessionCapabilities(
    actions: SessionStepRouting.uiActionNames(),
    assertionDomains: SessionStepRouting.assertionDomains,
    waits: SessionStepRouting.waitKinds,
    semanticTree: true,
    runtimeMetadata: true,
    navigationState: true,
    screenshots: true,
    coordinateActions: false,
    apiAssertions: true,
    storageAssertions: true,
    secureFieldRedaction: true,
    observationRevisions: true,
    snapshotElementTargets: true,
  );

  Map<String, dynamic> toJson() => {
        'actions': actions.toList()..sort(),
        'assertionDomains': assertionDomains.toList()..sort(),
        'waits': waits.toList()..sort(),
        'semanticTree': semanticTree,
        'runtimeMetadata': runtimeMetadata,
        'navigationState': navigationState,
        'screenshots': screenshots,
        'coordinateActions': coordinateActions,
        'apiAssertions': apiAssertions,
        'storageAssertions': storageAssertions,
        'secureFieldRedaction': secureFieldRedaction,
        'observationRevisions': observationRevisions,
        'snapshotElementTargets': snapshotElementTargets,
      };

  factory SessionCapabilities.fromJson(Map<String, dynamic> json) {
    Set<String> stringSet(dynamic value) {
      if (value is! List) return {};
      return value.map((e) => e.toString()).toSet();
    }

    bool flag(String key) => json[key] == true;

    return SessionCapabilities(
      actions: stringSet(json['actions']),
      assertionDomains: stringSet(json['assertionDomains']),
      waits: stringSet(json['waits']),
      semanticTree: flag('semanticTree'),
      runtimeMetadata: flag('runtimeMetadata'),
      navigationState: flag('navigationState'),
      screenshots: flag('screenshots'),
      coordinateActions: flag('coordinateActions'),
      apiAssertions: flag('apiAssertions'),
      storageAssertions: flag('storageAssertions'),
      secureFieldRedaction: flag('secureFieldRedaction'),
      observationRevisions: flag('observationRevisions'),
      snapshotElementTargets: flag('snapshotElementTargets'),
    );
  }
}

/// What a **caller** is allowed to invoke on a session.
///
/// Intersected with [SessionCapabilities] at runtime.
class SessionPermissions {
  final Set<String> actions;
  final Set<String> assertionDomains;
  final Set<String> waits;
  final bool privilegedOperations;
  final bool lifecycleOperations;
  final bool captureArtifacts;

  const SessionPermissions({
    this.actions = const {},
    this.assertionDomains = const {},
    this.waits = const {},
    this.privilegedOperations = false,
    this.lifecycleOperations = false,
    this.captureArtifacts = false,
  });

  /// Full grant matching today's YAML runner power.
  ///
  /// Action names are derived from [TestStepRegistry] via [SessionStepRouting].
  static final SessionPermissions yamlController = SessionPermissions(
    actions: SessionStepRouting.uiActionNames(),
    assertionDomains: SessionStepRouting.assertionDomains,
    waits: SessionStepRouting.waitKinds,
    privilegedOperations: true,
    lifecycleOperations: true,
    captureArtifacts: true,
  );

  /// Restricted grant: UI actions/waits/asserts only (no privileged ops).
  static final SessionPermissions restrictedUi = SessionPermissions(
    actions: SessionStepRouting.restrictedUiActionNames(),
    assertionDomains: const {'ui', 'navigation'},
    waits: const {'pump', 'settle', 'uiElement', 'text', 'navigation'},
    privilegedOperations: false,
    lifecycleOperations: false,
    captureArtifacts: true,
  );

  Map<String, dynamic> toJson() => {
        'actions': actions.toList()..sort(),
        'assertionDomains': assertionDomains.toList()..sort(),
        'waits': waits.toList()..sort(),
        'privilegedOperations': privilegedOperations,
        'lifecycleOperations': lifecycleOperations,
        'captureArtifacts': captureArtifacts,
      };

  factory SessionPermissions.fromJson(Map<String, dynamic> json) {
    Set<String> stringSet(dynamic value) {
      if (value is! List) return {};
      return value.map((e) => e.toString()).toSet();
    }

    return SessionPermissions(
      actions: stringSet(json['actions']),
      assertionDomains: stringSet(json['assertionDomains']),
      waits: stringSet(json['waits']),
      privilegedOperations: json['privilegedOperations'] == true,
      lifecycleOperations: json['lifecycleOperations'] == true,
      captureArtifacts: json['captureArtifacts'] == true,
    );
  }
}
