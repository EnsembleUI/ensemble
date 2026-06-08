import 'package:ensemble/framework/definition_providers/cdn_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isCdnManifestIncomingNewer', () {
    test('fetches when remote timestamp is newer than cached', () {
      expect(isCdnManifestIncomingNewer(200, 100), isTrue);
    });

    test('skips fetch when remote is same or older', () {
      expect(isCdnManifestIncomingNewer(100, 100), isFalse);
      expect(isCdnManifestIncomingNewer(50, 100), isFalse);
    });

    test('fetches when there is no cached timestamp', () {
      expect(isCdnManifestIncomingNewer(1, null), isTrue);
    });

    test('does not fetch when remote timestamp is missing', () {
      expect(isCdnManifestIncomingNewer(null, 100), isFalse);
      expect(isCdnManifestIncomingNewer(null, null), isFalse);
    });
  });
}
