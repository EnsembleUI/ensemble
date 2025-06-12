import 'package:flutter/foundation.dart';
import 'package:flutter_aepassurance/flutter_aepassurance.dart';

class AdobeAnalyticsAssurance {
  AdobeAnalyticsAssurance();

  // Starting an Assurance session
  Future<void> setupAssurance(Map<String, dynamic> parameters) async {
    final url = parameters['url'] as String;
    if (url.isEmpty) {
      throw ArgumentError('url parameter cannot be empty');
    }
    try {
      await Assurance.startSession(url);
    } catch (e) {
      debugPrint('Error setting up Adobe Analytics Assurance: $e');
      throw StateError('Error setting up Adobe Analytics Assurance: $e');
    }
  }
}
