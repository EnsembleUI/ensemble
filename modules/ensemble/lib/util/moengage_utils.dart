import 'utils.dart';

enum EnsembleGender with EnumParseMixin {
  male,
  female,
  other;

  static EnsembleGender? fromString(String? value) =>
    EnumParseMixin.fromString(values, value, other);
}

enum EnsembleAppStatus with EnumParseMixin {
  install,
  update,
  active;

  static EnsembleAppStatus? fromString(String? value) =>
    EnumParseMixin.fromString(values, value, install);
}

enum EnsembleNudgePosition with EnumParseMixin {
  top,
  bottom,
  bottomRight,
  bottomLeft,
  any;

  static EnsembleNudgePosition? fromString(String? value) =>
    EnumParseMixin.fromString(values, value, bottom);
}

class EnsembleGeoLocation {
  final double latitude;
  final double longitude;
  
  const EnsembleGeoLocation(this.latitude, this.longitude);
  
  Map<String, double> toMap() => {
    'latitude': latitude,
    'longitude': longitude
  };

  @override 
  String toString() => 'EnsembleGeoLocation(lat: $latitude, lng: $longitude)';

  static EnsembleGeoLocation? parse(dynamic value) {
    if (value is Map) {
      final lat = Utils.getDouble(value['latitude'], fallback: 0);
      final lng = Utils.getDouble(value['longitude'], fallback: 0);
      return EnsembleGeoLocation(lat, lng);
    }
    
    final locationData = Utils.getLatLng(value);
    if (locationData != null) {
      return EnsembleGeoLocation(locationData.latitude, locationData.longitude);
    }
    return null;
  }
}

class EnsembleProperties {
  final Map<String, dynamic> generalAttributes = {};
  final Map<String, Map<String, double>> locationAttributes = {};
  final Map<String, String> dateTimeAttributes = {};
  bool isNonInteractive = false;

  void addAttribute(String key, dynamic value) {
    if (key.isEmpty) return;
    
    if (value is EnsembleGeoLocation) {
      locationAttributes[key] = value.toMap();
    } else if (value != null) { // Only add non-null values
      generalAttributes[key] = value;
    }
  }

  void addISODateTime(String key, String value) {
    if (key.isEmpty) return;
    dateTimeAttributes[key] = value;
  }

  void setNonInteractiveEvent() {
    isNonInteractive = true;
  }

  Map<String, dynamic> toMap() => {
    'eventAttributes': {
      'generalAttributes': generalAttributes,
      'locationAttributes': locationAttributes,
      'dateTimeAttributes': dateTimeAttributes,
    },
    'isNonInteractive': isNonInteractive
  };

  // Helper to batch add attributes
  void addAttributes(Map<String, dynamic> attributes) {
    attributes.forEach((key, value) => addAttribute(key, value));
  }
}

// Common mixin for enum parsing
mixin EnumParseMixin<T> {
  static T? fromString<T extends Enum>(List<T> values, String? value, T defaultValue) {
    if (value == null) return null;
    return values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => defaultValue
    );
  }
}