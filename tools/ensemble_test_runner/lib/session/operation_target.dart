/// A rectangular region used to narrow a target when labels are ambiguous.
class ElementBounds {
  final double left;
  final double top;
  final double width;
  final double height;

  const ElementBounds({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  Map<String, dynamic> toJson() => {
        'left': left,
        'top': top,
        'width': width,
        'height': height,
      };

  factory ElementBounds.fromJson(Map<String, dynamic> json) => ElementBounds(
        left: (json['left'] as num).toDouble(),
        top: (json['top'] as num).toDouble(),
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
      );
}

/// A semantic or structural description of an element in the current view.
class ElementLocator {
  final String? id;
  final String? text;
  final String? label;
  final String? role;
  final ElementLocator? within;
  final int? occurrence;
  final ElementBounds? bounds;

  const ElementLocator({
    this.id,
    this.text,
    this.label,
    this.role,
    this.within,
    this.occurrence,
    this.bounds,
  });

  bool get isEmpty =>
      id == null &&
      text == null &&
      label == null &&
      role == null &&
      within == null &&
      occurrence == null &&
      bounds == null;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (text != null) 'text': text,
        if (label != null) 'label': label,
        if (role != null) 'role': role,
        if (within != null) 'within': within!.toJson(),
        if (occurrence != null) 'occurrence': occurrence,
        if (bounds != null) 'bounds': bounds!.toJson(),
      };

  factory ElementLocator.fromJson(Map<String, dynamic> json) => ElementLocator(
        id: json['id']?.toString(),
        text: json['text']?.toString(),
        label: json['label']?.toString(),
        role: json['role']?.toString(),
        within: json['within'] is Map
            ? ElementLocator.fromJson(
                Map<String, dynamic>.from(json['within'] as Map),
              )
            : null,
        occurrence: json['occurrence'] as int?,
        bounds: json['bounds'] is Map
            ? ElementBounds.fromJson(
                Map<String, dynamic>.from(json['bounds'] as Map),
              )
            : null,
      );
}

/// Identifies an element either from an observation or through a locator.
class ElementTarget {
  final String? testId;
  final String? elementId;
  final String? observationId;
  final int? occurrence;
  final ElementLocator? locator;

  const ElementTarget({
    this.testId,
    this.elementId,
    this.observationId,
    this.occurrence,
    this.locator,
  });

  bool get usesSnapshotElement => elementId != null && elementId!.isNotEmpty;

  bool get usesStructuredTarget =>
      usesSnapshotElement || occurrence != null || locator != null;

  Map<String, dynamic> toJson() => {
        if (testId != null) 'testId': testId,
        if (elementId != null) 'elementId': elementId,
        if (observationId != null) 'observationId': observationId,
        if (occurrence != null) 'occurrence': occurrence,
        if (locator != null) 'locator': locator!.toJson(),
      };

  factory ElementTarget.fromJson(Map<String, dynamic> json) => ElementTarget(
        testId: json['testId']?.toString(),
        elementId: json['elementId']?.toString(),
        observationId: json['observationId']?.toString(),
        occurrence: json['occurrence'] as int?,
        locator: json['locator'] is Map
            ? ElementLocator.fromJson(
                Map<String, dynamic>.from(json['locator'] as Map),
              )
            : null,
      );

  /// Reads the target shape used by an operation's input map.
  static ElementTarget fromOperationArgs(Map<String, dynamic> args) {
    final raw = args['target'];
    if (raw is Map) {
      final target = Map<String, dynamic>.from(raw);
      if (target.containsKey('testId') ||
          target.containsKey('elementId') ||
          target.containsKey('observationId') ||
          target.containsKey('locator')) {
        return ElementTarget.fromJson(target);
      }
      return ElementTarget(locator: ElementLocator.fromJson(target));
    }
    final testId = args['id']?.toString();
    return testId == null
        ? const ElementTarget()
        : ElementTarget(testId: testId);
  }

  ElementLocator? get normalizedLocator {
    if (locator != null) return locator;
    if (testId == null || testId!.isEmpty) return null;
    return ElementLocator(id: testId, occurrence: occurrence);
  }
}
