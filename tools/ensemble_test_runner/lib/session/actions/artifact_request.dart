/// Request to capture a diagnostic artifact.
class ArtifactRequest {
  final String kind;
  final Map<String, dynamic> options;

  const ArtifactRequest({
    required this.kind,
    this.options = const {},
  });

  Map<String, dynamic> toJson() => {
        'kind': kind,
        if (options.isNotEmpty) 'options': options,
      };

  factory ArtifactRequest.fromJson(Map<String, dynamic> json) {
    final optionsRaw = json['options'];
    return ArtifactRequest(
      kind: json['kind']?.toString() ?? 'screenshot',
      options:
          optionsRaw is Map ? Map<String, dynamic>.from(optionsRaw) : const {},
    );
  }
}

/// Captured artifact metadata (bytes live outside the JSON contract).
class TestArtifact {
  final String artifactId;
  final String kind;
  final String? path;
  final String? mimeType;
  final int? byteLength;

  const TestArtifact({
    required this.artifactId,
    required this.kind,
    this.path,
    this.mimeType,
    this.byteLength,
  });

  Map<String, dynamic> toJson() => {
        'artifactId': artifactId,
        'kind': kind,
        if (path != null) 'path': path,
        if (mimeType != null) 'mimeType': mimeType,
        if (byteLength != null) 'byteLength': byteLength,
      };

  factory TestArtifact.fromJson(Map<String, dynamic> json) => TestArtifact(
        artifactId: json['artifactId']?.toString() ?? '',
        kind: json['kind']?.toString() ?? '',
        path: json['path']?.toString(),
        mimeType: json['mimeType']?.toString(),
        byteLength: json['byteLength'] as int?,
      );
}
