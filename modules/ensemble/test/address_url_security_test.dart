import 'package:ensemble/framework/stub/location_manager.dart';
import 'package:ensemble/widget/address_url_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildPlacesAutocompleteUri', () {
    test('percent-encodes user input so extra query params cannot be injected',
        () {
      const maliciousInput = 'foo&components=country:US';
      final uri = buildPlacesAutocompleteUri(
        input: maliciousInput,
        countryFilter: const ['CA'],
      );

      expect(uri.queryParameters['input'], maliciousInput);
      expect(uri.queryParameters['components'], 'country:CA');
      expect(uri.queryParameters.containsKey('country:US'), isFalse);
      expect(uri.query, contains('input=foo%26components%3Dcountry%3AUS'));
    });

    test('includes location bias when center is provided', () {
      final uri = buildPlacesAutocompleteUri(
        input: 'Paris',
        center: LocationData(latitude: 48.8566, longitude: 2.3522),
        proximityRadiusMeters: 15000,
      );

      expect(uri.queryParameters['locationbias'],
          'circle:15000@48.8566,2.3522');
    });
  });

  group('buildPlacesDetailUri', () {
    test('encodes placeId query value', () {
      const placeId = 'id&injected=1';
      final uri = buildPlacesDetailUri(placeId);

      expect(uri.queryParameters['placeId'], placeId);
      expect(uri.query, contains('placeId=id%26injected%3D1'));
    });
  });
}
