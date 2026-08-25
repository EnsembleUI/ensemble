import 'package:collection/collection.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/page_model.dart';
import 'package:flutter/widgets.dart';

/// Unevaluated EDL representation of an entry in `navigateScreen.stack`.
class NavigationStackEntry {
  const NavigationStackEntry({required this.name, this.inputs});

  /// A literal screen name or expression evaluated in the initiating context.
  final dynamic name;

  /// Unevaluated inputs; nested values are evaluated immediately before use.
  final Map<String, dynamic>? inputs;

  /// Parses the object-only stack entry syntax and reports its indexed path.
  factory NavigationStackEntry.from(dynamic value, int index) {
    if (value is! Map) {
      throw LanguageError(
          'navigateScreen.stack[$index] must be an object with a name.');
    }
    if (!value.containsKey('name') || value['name'] == null) {
      throw LanguageError(
          'navigateScreen.stack[$index] requires the name of a screen.');
    }
    final rawInputs = value['inputs'];
    if (rawInputs != null && rawInputs is! Map) {
      throw LanguageError(
          'navigateScreen.stack[$index].inputs must be an object.');
    }
    return NavigationStackEntry(
      name: value['name'],
      inputs: rawInputs == null
          ? null
          : Map<String, dynamic>.from(rawInputs as Map),
    );
  }
}

/// Evaluated identity and reconstruction data for an Ensemble route.
class EnsembleRouteDescriptor {
  EnsembleRouteDescriptor({
    this.screenId,
    this.screenName,
    Map<String, dynamic>? inputs,
    this.isExternal = false,
    String? routeId,
  })  : inputs =
            inputs == null ? null : Map<String, dynamic>.unmodifiable(inputs),
        routeId = routeId ?? _nextRouteId();

  static int _routeSequence = 0;

  static String _nextRouteId() =>
      'ensemble_route_${DateTime.now().microsecondsSinceEpoch}_${_routeSequence++}';

  /// Definition ID when navigation addressed the screen by ID.
  final String? screenId;

  /// Definition name when navigation addressed the screen by name.
  final String? screenName;

  /// Evaluated inputs used both for reconstruction and route identity.
  final Map<String, dynamic>? inputs;

  /// Whether the descriptor targets a registered external Ensemble screen.
  final bool isExternal;

  /// Unique identity for this descriptor instance.
  final String routeId;

  /// Human-readable identifier used by diagnostics.
  String get identifier => screenName ?? screenId ?? '';

  /// Converts typed metadata to the legacy route argument format.
  ScreenPayload toPayload({PageType pageType = PageType.regular}) =>
      ScreenPayload(
        screenId: screenId,
        screenName: screenName,
        arguments: inputs,
        pageType: pageType,
        isExternal: isExternal,
      );

  /// Performs exact descriptor equality for snapshots and browser restoration.
  bool isEquivalentTo(EnsembleRouteDescriptor other) =>
      screenId == other.screenId &&
      screenName == other.screenName &&
      isExternal == other.isExternal &&
      const DeepCollectionEquality().equals(inputs, other.inputs);

  /// Whether this existing route can satisfy a requested history entry.
  ///
  /// Inputs are directional here: omitted or empty requested inputs mean
  /// "retain the existing route with its current inputs". Once the request
  /// supplies inputs, they must match exactly.
  bool satisfiesHistoryRequest(EnsembleRouteDescriptor requested) {
    if (screenId != requested.screenId ||
        screenName != requested.screenName ||
        isExternal != requested.isExternal) {
      return false;
    }
    if (requested.inputs == null || requested.inputs!.isEmpty) return true;
    return const DeepCollectionEquality().equals(inputs, requested.inputs);
  }

  @override
  String toString() => identifier;
}

/// Route settings used by every route created by Ensemble navigation.
class EnsembleRouteSettings extends RouteSettings {
  EnsembleRouteSettings({
    required this.descriptor,
    required ScreenPayload payload,
  }) : super(arguments: payload);

  /// Typed metadata retained alongside the legacy [ScreenPayload] arguments.
  final EnsembleRouteDescriptor descriptor;
}

/// Why an Ensemble route stopped being active.
enum EnsembleRouteExitReason {
  /// The user or platform performed a real back navigation.
  back,

  /// A normal navigation replaced the current route.
  replaced,

  /// Declarative reconciliation removed an obsolete history suffix.
  historyReconciled,

  /// Navigation intentionally cleared every prior route.
  rootCleared,
}

/// Associates a live Flutter route with its reconstructable descriptor.
class ManagedEnsembleRoute {
  ManagedEnsembleRoute({required this.route, required this.descriptor});

  final Route<dynamic> route;
  final EnsembleRouteDescriptor descriptor;
}
