import 'package:ensemble/framework/stub/location_manager.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

const _placesAutocompleteHost =
    'services-googleplacesautocomplete-2czdl2akpq-uc.a.run.app';
const _placesDetailHost =
    'services-googleplacesdetail-2czdl2akpq-uc.a.run.app';

/// Builds the Google Places autocomplete proxy URL with encoded query parameters
/// so user-controlled [input] cannot inject additional `&key=value` pairs.
@visibleForTesting
Uri buildPlacesAutocompleteUri({
  required String input,
  LocationData? center,
  int? proximityRadiusMeters,
  List<String>? countryFilter,
}) {
  final queryParameters = <String, String>{'input': input};
  if (center != null) {
    final radius = proximityRadiusMeters ?? 20000;
    queryParameters['locationbias'] =
        'circle:$radius@${center.latitude},${center.longitude}';
  }
  if (countryFilter != null && countryFilter.isNotEmpty) {
    queryParameters['components'] =
        countryFilter.map((code) => 'country:$code').join('|');
  }
  return Uri.https(_placesAutocompleteHost, '/', queryParameters);
}

/// Builds the Google Places detail proxy URL with an encoded [placeId].
@visibleForTesting
Uri buildPlacesDetailUri(String placeId) {
  return Uri.https(_placesDetailHost, '/', {'placeId': placeId});
}
