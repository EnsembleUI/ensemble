/// Loads an asset needed while expanding a test definition.
typedef AssetStringLoader = Future<String> Function(String assetPath);

/// Raised by an asset loader when a referenced file cannot be read.
///
/// This error type keeps pure planning code independent of Flutter's
/// `FlutterError` while allowing runtime adapters to preserve useful context.
final class AssetLoadException implements Exception {
  const AssetLoadException(this.assetPath, [this.cause]);

  final String assetPath;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'Could not load asset "$assetPath".'
      : 'Could not load asset "$assetPath": $cause';
}
