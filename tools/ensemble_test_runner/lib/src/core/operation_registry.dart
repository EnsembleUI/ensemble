import 'dart:collection';

import 'operation.dart';

/// A canonical operation and the source names that compile to it.
final class OperationDescriptor {
  OperationDescriptor({
    required this.name,
    required this.kind,
    required Map<String, dynamic> argumentSchema,
    String? handlerKey,
    Iterable<String> aliases = const [],
    this.restrictedUiAllowed = true,
    this.userAction = false,
    this.orderedEvidence = false,
    Iterable<String> orderedEvidenceAliases = const [],
    this.acceptsTimeout = false,
    this.notifiesConditionMatched = false,
    Iterable<String> requiredCapabilities = const [],
    this.waitKind,
    this.waitTargetState,
    Iterable<String>? supportedWaitKinds,
  })  : handlerKey = handlerKey ?? name,
        argumentSchema = _freezeMap(argumentSchema),
        aliases = List.unmodifiable(aliases),
        orderedEvidenceAliases = Set.unmodifiable(orderedEvidenceAliases),
        requiredCapabilities = Set.unmodifiable(requiredCapabilities),
        supportedWaitKinds = Set.unmodifiable(
          supportedWaitKinds ??
              (waitKind == null ? const <String>[] : [waitKind]),
        ) {
    if (acceptsTimeout && !_hasIntegerTimeoutProperty(this.argumentSchema)) {
      throw ArgumentError.value(
        this.argumentSchema,
        'argumentSchema',
        'Operations that accept a timeout must declare an integer timeoutMs '
            'property.',
      );
    }
    if (name.trim().isEmpty || name != name.trim()) {
      throw ArgumentError.value(name, 'name');
    }
    if (this.handlerKey.trim().isEmpty ||
        this.handlerKey != this.handlerKey.trim()) {
      throw ArgumentError.value(
        this.handlerKey,
        'handlerKey',
        'Handler key must not be empty.',
      );
    }
    if (this.aliases.any(
          (alias) => alias.trim().isEmpty || alias != alias.trim(),
        )) {
      throw ArgumentError.value(this.aliases, 'aliases');
    }
    if (!this.aliases.toSet().containsAll(this.orderedEvidenceAliases)) {
      throw ArgumentError.value(
        this.orderedEvidenceAliases,
        'orderedEvidenceAliases',
        'Ordered evidence names must be declared aliases.',
      );
    }
    if (this.supportedWaitKinds.any(
          (kind) => kind.trim().isEmpty || kind != kind.trim(),
        )) {
      throw ArgumentError.value(
        this.supportedWaitKinds,
        'supportedWaitKinds',
        'Wait kinds must not be empty.',
      );
    }
    if (waitKind != null &&
        (waitKind!.trim().isEmpty || waitKind != waitKind!.trim())) {
      throw ArgumentError.value(
        waitKind,
        'waitKind',
        'Wait kind must not be empty or padded.',
      );
    }
    if (waitKind != null && kind != OperationKind.wait) {
      throw ArgumentError.value(
        waitKind,
        'waitKind',
        'Only wait operations may declare a primary wait kind.',
      );
    }
    if (kind != OperationKind.wait && this.supportedWaitKinds.isNotEmpty) {
      throw ArgumentError.value(
        this.supportedWaitKinds,
        'supportedWaitKinds',
        'Only wait operations may declare wait kinds.',
      );
    }
    if (waitKind != null && !this.supportedWaitKinds.contains(waitKind)) {
      throw ArgumentError.value(
        this.supportedWaitKinds,
        'supportedWaitKinds',
        'Supported wait kinds must include the primary wait kind "$waitKind".',
      );
    }
    if (waitTargetState != null &&
        waitTargetState != 'present' &&
        waitTargetState != 'absent') {
      throw ArgumentError.value(
        waitTargetState,
        'waitTargetState',
        'Must be "present" or "absent".',
      );
    }
    if (waitTargetState != null && kind != OperationKind.wait) {
      throw ArgumentError.value(
        waitTargetState,
        'waitTargetState',
        'Only wait operations may declare a target state.',
      );
    }
  }

  final String name;
  final OperationKind kind;

  /// Stable runtime dispatch key, independent of the source spelling.
  final String handlerKey;

  /// Immutable JSON Schema describing this operation's argument map.
  final Map<String, dynamic> argumentSchema;
  final List<String> aliases;

  /// Whether a restricted UI session may invoke this operation.
  final bool restrictedUiAllowed;

  /// Whether the operation performs a user-facing action that should receive
  /// action-timed evidence and post-action settling.
  final bool userAction;

  /// Whether this operation owns a pre-mutation or matched-state evidence
  /// boundary. The runtime adapter derives this from the generated registry.
  final bool orderedEvidence;

  /// Aliases that independently declare an ordered evidence boundary.
  final Set<String> orderedEvidenceAliases;

  /// Whether explicit timeout input is part of this operation's contract.
  final bool acceptsTimeout;

  /// Whether success means an explicitly requested condition was reached.
  final bool notifiesConditionMatched;

  /// Application service contracts required to execute the operation.
  final Set<String> requiredCapabilities;

  /// Synchronization/permission category for wait operations.
  final String? waitKind;

  /// Required final state when a wait resolves an element target.
  final String? waitTargetState;

  /// All wait categories used by this operation and its input aliases.
  ///
  /// A canonical operation can have aliases with more specific wait
  /// semantics (for example, `waitForText` shares the `waitFor` command).
  /// Keeping the union here lets capability and permission projections account
  /// for every authored name without creating a second operation descriptor.
  final Set<String> supportedWaitKinds;
}

bool _hasIntegerTimeoutProperty(Map<String, dynamic> schema) {
  final properties = schema['properties'];
  if (properties is! Map) return false;
  final timeout = properties['timeoutMs'];
  return timeout is Map && timeout['type'] == 'integer';
}

Map<String, dynamic> _freezeMap(Map<String, dynamic> value) =>
    Map.unmodifiable({
      for (final entry in value.entries) entry.key: _freezeValue(entry.value),
    });

Object? _freezeValue(Object? value) => switch (value) {
      Map<String, dynamic>() => _freezeMap(value),
      Map() => Map.unmodifiable({
          for (final entry in value.entries)
            entry.key: _freezeValue(entry.value),
        }),
      List() => List.unmodifiable(value.map(_freezeValue)),
      _ => value,
    };

enum ControlKind { group, repeat, optional, ifVisible }

final class ControlDescriptor {
  const ControlDescriptor({required this.name, required this.kind});

  final String name;
  final ControlKind kind;
}

/// The compiler and runtime share this validated operation name map.
final class OperationRegistry {
  factory OperationRegistry(
    Iterable<OperationDescriptor> descriptors, {
    Iterable<ControlDescriptor> controls = const [],
  }) {
    final descriptorList = List<OperationDescriptor>.unmodifiable(descriptors);
    final controlList = List<ControlDescriptor>.unmodifiable(controls);
    final controlsByName = _indexControls(controlList);
    final byName = _index(descriptorList, controlsByName.keys.toSet());
    _validateHandlerKinds(descriptorList);
    return OperationRegistry._(
      descriptorList,
      controlsByName,
      byName,
      Set.unmodifiable(descriptorList.map((descriptor) => descriptor.name)),
      Set.unmodifiable(
        descriptorList.map((descriptor) => descriptor.handlerKey),
      ),
      _indexNamesByKind(descriptorList),
      _indexRestrictedUiNames(descriptorList),
      _indexRestrictedUiExcludedNames(descriptorList),
      _indexWaitKinds(descriptorList),
    );
  }

  OperationRegistry._(
    this._descriptors,
    this._controlsByName,
    this._byName,
    this._canonicalNames,
    this._handlerKeys,
    this._namesByKind,
    this._restrictedUiNames,
    this._restrictedUiExcludedNames,
    this._waitKinds,
  );

  final List<OperationDescriptor> _descriptors;
  final Map<String, ControlKind> _controlsByName;
  final Map<String, OperationDescriptor> _byName;
  final Set<String> _canonicalNames;
  final Set<String> _handlerKeys;
  final Map<OperationKind, Set<String>> _namesByKind;
  final Set<String> _restrictedUiNames;
  final Set<String> _restrictedUiExcludedNames;
  final Set<String> _waitKinds;

  List<OperationDescriptor> get descriptors => _descriptors;

  OperationDescriptor? lookup(String name) => _byName[name];

  /// Resolves a core operation and verifies that its selected kind and route
  /// still match this registry.
  OperationDescriptor requireDescriptor(
    TestOperation operation, {
    OperationKind? expectedKind,
  }) {
    final descriptor = lookup(operation.name);
    if (descriptor == null ||
        descriptor.kind != operation.kind ||
        (expectedKind != null && descriptor.kind != expectedKind) ||
        descriptor.handlerKey != operation.handlerKey) {
      throw ArgumentError.value(
        operation,
        'operation',
        'Operation name, kind, or handler does not match the registry.',
      );
    }
    return descriptor;
  }

  ControlKind? controlKind(String name) => _controlsByName[name];

  /// Resolves a registered alias to the canonical dispatch name.
  String canonicalName(String name) => _byName[name]?.name ?? name;

  bool isControl(String name) => controlKind(name) != null;

  /// Stable immutable view reused by capability and runtime consumers.
  Set<String> get canonicalNames => _canonicalNames;

  /// Stable dispatch identities selected by the operation registry.
  Set<String> get handlerKeys => _handlerKeys;

  Set<String> namesForKind(OperationKind kind) =>
      _namesByKind[kind] ?? const <String>{};

  /// Canonical interaction names permitted in restricted UI sessions.
  Set<String> get restrictedUiNames => _restrictedUiNames;

  /// UI action names excluded from the restricted session grant.
  Set<String> get restrictedUiExcludedNames => _restrictedUiExcludedNames;

  /// Wait permission categories declared by canonical operations or aliases.
  Set<String> get waitKinds => _waitKinds;

  static Map<String, ControlKind> _indexControls(
    Iterable<ControlDescriptor> controls,
  ) {
    final result = <String, ControlKind>{};
    for (final control in controls) {
      if (control.name.trim().isEmpty ||
          control.name != control.name.trim() ||
          result.containsKey(control.name)) {
        throw ArgumentError.value(
          control.name,
          'controls',
          'Empty or duplicate control name',
        );
      }
      result[control.name] = control.kind;
    }
    return Map.unmodifiable(result);
  }

  static Map<String, OperationDescriptor> _index(
    Iterable<OperationDescriptor> descriptors,
    Set<String> controlNames,
  ) {
    final result = <String, OperationDescriptor>{};
    for (final descriptor in descriptors) {
      for (final name in [descriptor.name, ...descriptor.aliases]) {
        if (result.containsKey(name)) {
          throw ArgumentError.value(name, 'name', 'Duplicate operation name');
        }
        result[name] = descriptor;
      }
    }
    for (final name in controlNames) {
      if (name.trim().isEmpty ||
          name != name.trim() ||
          result.containsKey(name)) {
        throw ArgumentError.value(name, 'controls', 'Invalid control name');
      }
    }
    return UnmodifiableMapView(result);
  }

  static Map<OperationKind, Set<String>> _indexNamesByKind(
    Iterable<OperationDescriptor> descriptors,
  ) {
    final names = <OperationKind, Set<String>>{};
    for (final descriptor in descriptors) {
      names.putIfAbsent(descriptor.kind, () => <String>{}).add(descriptor.name);
    }
    return Map.unmodifiable({
      for (final entry in names.entries)
        entry.key: Set.unmodifiable(entry.value),
    });
  }

  static Set<String> _indexRestrictedUiNames(
    Iterable<OperationDescriptor> descriptors,
  ) =>
      Set.unmodifiable(
        descriptors
            .where((descriptor) =>
                descriptor.kind == OperationKind.interaction &&
                descriptor.restrictedUiAllowed)
            .map((descriptor) => descriptor.name),
      );

  static Set<String> _indexRestrictedUiExcludedNames(
    Iterable<OperationDescriptor> descriptors,
  ) =>
      Set.unmodifiable(
        descriptors
            .where((descriptor) =>
                descriptor.kind == OperationKind.interaction &&
                !descriptor.restrictedUiAllowed)
            .map((descriptor) => descriptor.name),
      );

  static Set<String> _indexWaitKinds(
    Iterable<OperationDescriptor> descriptors,
  ) =>
      Set.unmodifiable(
        descriptors.expand((descriptor) => descriptor.supportedWaitKinds),
      );

  /// A handler key may serve several operations, but those operations must
  /// share one execution contract. A cross-kind key would make a kind-level
  /// fallback and a specialized override silently route different contracts
  /// through the same function.
  static void _validateHandlerKinds(
    Iterable<OperationDescriptor> descriptors,
  ) {
    final kindsByHandler = <String, OperationKind>{};
    for (final descriptor in descriptors) {
      final previous = kindsByHandler[descriptor.handlerKey];
      if (previous != null && previous != descriptor.kind) {
        throw ArgumentError.value(
          descriptor.handlerKey,
          'handlerKey',
          'Handler key is used by multiple operation kinds: '
              '${previous.name} and ${descriptor.kind.name}.',
        );
      }
      kindsByHandler[descriptor.handlerKey] = descriptor.kind;
    }
  }
}
