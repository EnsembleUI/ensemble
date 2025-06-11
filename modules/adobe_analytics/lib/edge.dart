import 'package:flutter/foundation.dart';
import 'package:flutter_aepedge/flutter_aepedge.dart';

class AdobeAnalyticsEdge {
  AdobeAnalyticsEdge();

  // Sends an Experience event to Adobe Experience Platform Edge Network.
  Future<dynamic> sendEvent(
      String name, Map<String, dynamic>? parameters) async {
    try {
      late List<EventHandle> result;
      if (parameters == null) {
        throw StateError('Parameters are required for sendEvent');
      }
      final xdmData = parameters['xdmData'] is Map
          ? parameters['xdmData'] as Map<String, dynamic>
          : null;
      final data = parameters['data'] is Map
          ? parameters['data'] as Map<String, dynamic>
          : null;
      final datasetIdentifier =
          parameters['datasetIdentifier'] as String? ?? null;
      final datastreamConfigOverride =
          parameters['datastreamConfigOverride'] is Map
              ? parameters['datastreamConfigOverride'] as Map<String, dynamic>
              : null;
      final datastreamIdOverride =
          parameters['datastreamIdOverride'] as String? ?? null;

      final event = <String, dynamic>{
        if (xdmData != null) 'xdmData': xdmData,
        if (data != null) 'data': data,
        if (datasetIdentifier != null) 'datasetIdentifier': datasetIdentifier,
        if (datastreamIdOverride != null)
          'datastreamIdOverride': datastreamIdOverride,
        if (datastreamConfigOverride != null)
          'datastreamConfigOverride': datastreamConfigOverride,
      };
      final experienceEvent = ExperienceEvent(event);

      result = await Edge.sendEvent(experienceEvent).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw StateError('Edge.sendEvent timed out!');
        },
      );
      return result;
    } catch (e, stack) {
      debugPrint('Error sending Adobe Analytics event: $e\n$stack');
      throw StateError('Error sending Adobe Analytics event: $e');
    }
  }
}
