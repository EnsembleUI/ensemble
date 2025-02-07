import 'dart:io';
import '../utils.dart';

void main(List<String> arguments) async {
  List<String> platforms = getPlatforms(arguments);

  String? googleMapsApiKeyAndroid = getArgumentValue(
      arguments, 'androidGoogleMapsApiKey',
      required: platforms.contains('android'));
  String? googleMapsApiKeyIOS = getArgumentValue(
      arguments, 'iOSGoogleMapsApiKey',
      required: platforms.contains('ios'));
  String? googleMapsApiKeyWeb = getArgumentValue(
    arguments,
    'webGoogleMapsApiKey',
    required: platforms.contains('web'),
  );

  try {
    if (platforms.contains('android') && googleMapsApiKeyAndroid != null) {
      updatePropertiesFile('googleMapsAPIKey', googleMapsApiKeyAndroid);
    }
    if (platforms.contains('ios') && googleMapsApiKeyIOS != null) {
      updateAppDelegateForGoogleMaps(googleMapsApiKeyIOS);
    }

    if (platforms.contains('web') && googleMapsApiKeyWeb != null) {
      updateHtmlFile('</head>',
          '<script src="https://maps.googleapis.com/maps/api/js?key=$googleMapsApiKeyWeb"></script>',
          removalPattern: r'https://maps\.googleapis\.com/maps/api/js\?key=.*');
    }

    print(
        'Google Maps module enabled successfully for ${platforms.join(', ')}! 🎉');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}
