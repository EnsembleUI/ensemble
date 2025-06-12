import 'package:flutter_aepuserprofile/flutter_aepuserprofile.dart';

class AdobeAnalyticsUserProfile {
  AdobeAnalyticsUserProfile();

  // Get user profile attributes which match the provided keys
  Future<String> getUserAttributes(List<String> attributes) async {
    return await UserProfile.getUserAttributes(attributes);
  }

  // Remove provided user profile attributes if they exist
  Future<void> removeUserAttributes(List<String> attributeName) async {
    return await UserProfile.removeUserAttributes(attributeName);
  }

  // Set multiple user profile attributes
  Future<void> updateUserAttributes(Map<String, Object> attributeMap) async {
    return await UserProfile.updateUserAttributes(attributeMap);
  }
}
