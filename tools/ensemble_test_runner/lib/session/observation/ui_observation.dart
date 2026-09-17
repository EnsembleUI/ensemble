import 'package:ensemble_test_runner/session/observation/ui_element.dart';

/// Active screen / navigation slice of a [UiObservation].
class ScreenObservation {
  final String? name;
  final String? routeId;
  final List<String> navigationStack;
  final bool? isLoading;
  final bool? hasModal;
  final bool unknown;

  const ScreenObservation({
    this.name,
    this.routeId,
    this.navigationStack = const [],
    this.isLoading,
    this.hasModal,
    this.unknown = false,
  });

  factory ScreenObservation.unknown() => const ScreenObservation(unknown: true);

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (routeId != null) 'routeId': routeId,
        if (navigationStack.isNotEmpty) 'navigationStack': navigationStack,
        if (isLoading != null) 'isLoading': isLoading,
        if (hasModal != null) 'hasModal': hasModal,
        if (unknown) 'unknown': true,
      };

  factory ScreenObservation.fromJson(Map<String, dynamic> json) {
    final stack = json['navigationStack'];
    return ScreenObservation(
      name: json['name']?.toString(),
      routeId: json['routeId']?.toString(),
      navigationStack:
          stack is List ? stack.map((e) => e.toString()).toList() : const [],
      isLoading: json['isLoading'] as bool?,
      hasModal: json['hasModal'] as bool?,
      unknown: json['unknown'] == true,
    );
  }
}

/// Viewport size for the observation.
class UiViewport {
  final double width;
  final double height;
  final double devicePixelRatio;

  const UiViewport({
    required this.width,
    required this.height,
    this.devicePixelRatio = 1,
  });

  Map<String, dynamic> toJson() => {
        'width': width,
        'height': height,
        'devicePixelRatio': devicePixelRatio,
      };

  factory UiViewport.fromJson(Map<String, dynamic> json) => UiViewport(
        width: (json['width'] as num?)?.toDouble() ?? 0,
        height: (json['height'] as num?)?.toDouble() ?? 0,
        devicePixelRatio: (json['devicePixelRatio'] as num?)?.toDouble() ?? 1,
      );
}

/// What fields were actually populated in this observation.
class ObservationCompleteness {
  final bool semanticTree;
  final bool runtimeMetadata;
  final bool navigationState;
  final bool screenshot;
  final bool partial;

  const ObservationCompleteness({
    this.semanticTree = false,
    this.runtimeMetadata = false,
    this.navigationState = false,
    this.screenshot = false,
    this.partial = false,
  });

  Map<String, dynamic> toJson() => {
        'semanticTree': semanticTree,
        'runtimeMetadata': runtimeMetadata,
        'navigationState': navigationState,
        'screenshot': screenshot,
        'partial': partial,
      };

  factory ObservationCompleteness.fromJson(Map<String, dynamic> json) =>
      ObservationCompleteness(
        semanticTree: json['semanticTree'] == true,
        runtimeMetadata: json['runtimeMetadata'] == true,
        navigationState: json['navigationState'] == true,
        screenshot: json['screenshot'] == true,
        partial: json['partial'] == true,
      );
}

/// Serializable snapshot of the currently rendered UI.
///
/// Describes runtime state, not EDL definitions. [revision] advances when
/// observable UI state changes (text, enabled, visibility, bounds, values,
/// actions, navigation) — not merely because an action completed or because
/// widget IDs / counts changed.
class UiObservation {
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String observationId;
  final int revision;
  final DateTime timestamp;
  final ScreenObservation screen;
  final List<UiElement> elements;
  final UiViewport? viewport;
  final String? screenshotArtifactId;

  /// Digest of observable semantic fields used for revision comparison.
  final String? observableFingerprint;
  final ObservationCompleteness completeness;

  const UiObservation({
    this.schemaVersion = currentSchemaVersion,
    required this.observationId,
    required this.revision,
    required this.timestamp,
    required this.screen,
    this.elements = const [],
    this.viewport,
    this.screenshotArtifactId,
    this.observableFingerprint,
    this.completeness = const ObservationCompleteness(),
  });

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'observationId': observationId,
        'revision': revision,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'screen': screen.toJson(),
        'elements': elements.map((e) => e.toJson()).toList(),
        if (viewport != null) 'viewport': viewport!.toJson(),
        if (screenshotArtifactId != null)
          'screenshotArtifactId': screenshotArtifactId,
        if (observableFingerprint != null)
          'observableFingerprint': observableFingerprint,
        'completeness': completeness.toJson(),
      };

  factory UiObservation.fromJson(Map<String, dynamic> json) {
    final screenRaw = json['screen'];
    final elementsRaw = json['elements'];
    final viewportRaw = json['viewport'];
    final completenessRaw = json['completeness'];
    final ts = json['timestamp']?.toString();
    return UiObservation(
      schemaVersion: json['schemaVersion'] as int? ?? currentSchemaVersion,
      observationId: json['observationId']?.toString() ?? '',
      revision: json['revision'] as int? ?? 0,
      timestamp: ts != null ? DateTime.parse(ts) : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      screen: screenRaw is Map
          ? ScreenObservation.fromJson(Map<String, dynamic>.from(screenRaw))
          : ScreenObservation.unknown(),
      elements: elementsRaw is List
          ? elementsRaw
              .whereType<Map>()
              .map((e) => UiElement.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      viewport: viewportRaw is Map
          ? UiViewport.fromJson(Map<String, dynamic>.from(viewportRaw))
          : null,
      screenshotArtifactId: json['screenshotArtifactId']?.toString(),
      observableFingerprint: json['observableFingerprint']?.toString(),
      completeness: completenessRaw is Map
          ? ObservationCompleteness.fromJson(
              Map<String, dynamic>.from(completenessRaw),
            )
          : const ObservationCompleteness(),
    );
  }
}
