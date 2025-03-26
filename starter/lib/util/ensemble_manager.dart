import 'package:flutter/material.dart';
import 'package:ensemble/ensemble.dart';
import '../screens/content_detail_screen.dart';

/// A utility class to manage Ensemble initialization and callbacks
class EnsembleManager {
  EnsembleManager._();
  static final EnsembleManager instance = EnsembleManager._();

  bool _isInitialized = false;

  /// Initialize Ensemble once during app startup
  Future<void> initialize() async {
    if (!_isInitialized) {
      // Pre-initialize Ensemble to load configuration
      await Ensemble().initialize();
      _isInitialized = true;
      debugPrint('Ensemble initialized');
    }
  }

  /// Get the external methods to register with Ensemble
  Map<String, Function> getExternalMethods(BuildContext context, GlobalKey<NavigatorState> navigatorKey) {
    return {
      'openContentDetail': ({required String mediaId}) {
        _openContentDetail(context, mediaId, navigatorKey);
      },
      'logMessage': ({required String message}) {
        debugPrint('From Ensemble: $message');
      }
    };
  }

  /// Open the content detail screen (simulating KPN's flow)
  void _openContentDetail(BuildContext context, String mediaId, GlobalKey<NavigatorState> navigatorKey) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ContentDetailScreen(
          mediaId: mediaId,
          navigatorKey: navigatorKey,
        ),
      ),
    );
    debugPrint('Opening content detail for media ID: $mediaId');
  }
}