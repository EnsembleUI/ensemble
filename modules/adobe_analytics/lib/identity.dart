import 'package:flutter/foundation.dart';
import 'package:flutter_aepcore/flutter_aepcore.dart';
import 'package:flutter_aepedgeidentity/flutter_aepedgeidentity.dart';
import 'dart:async';

class AdobeAnalyticsIdentity {
  AdobeAnalyticsIdentity();

  Future<dynamic> getExperienceCloudId() async {
    try {
      return await Identity.experienceCloudId;
    } catch (e) {
      debugPrint('Error getting Adobe Analytics Experience Cloud ID: $e');
      throw StateError('Error getting Adobe Analytics Experience Cloud ID: $e');
    }
  }

  Future<dynamic> getIdentities() async {
    try {
      return await Identity.identities;
    } catch (e) {
      debugPrint('Error getting Adobe Analytics Identities: $e');
      throw StateError('Error getting Adobe Analytics Identities: $e');
    }
  }

  Future<dynamic> getUrlVariables() async {
    try {
      return await Identity.urlVariables;
    } catch (e) {
      debugPrint('Error getting Adobe Analytics URL Variables: $e');
      throw StateError('Error getting Adobe Analytics URL Variables: $e');
    }
  }

  Future<dynamic> removeIdentity(Map<String, dynamic> parameters) async {
    final itemMap = parameters['item'] as Map<String, dynamic>;
    final namespace = parameters['namespace'] as String;

    try {
      AuthenticatedState authState;
      switch (itemMap['authenticatedState'] as String) {
        case 'authenticated':
          authState = AuthenticatedState.AUTHENTICATED;
          break;
        case 'ambiguous':
          authState = AuthenticatedState.AMBIGUOUS;
          break;
        case 'loggedOut':
          authState = AuthenticatedState.LOGGED_OUT;
          break;
        default:
          authState = AuthenticatedState.AMBIGUOUS;
      }

      final item = IdentityItem(
        itemMap['id'] as String,
        authState,
        itemMap['primary'] as bool? ?? false,
      );
      // Perform the removal with a timeout
      try {
        final removeFuture = Identity.removeIdentity(item, namespace);
        final timeoutFuture = Future.delayed(Duration(seconds: 1));
        await Future.any([removeFuture, timeoutFuture]);
        final afterRemovalIdentities = await Identity.identities;
        return afterRemovalIdentities;
      } catch (e) {
        print('Error during identity removal: $e');
        throw StateError('Failed to remove identity: $e');
      }
    } catch (e) {
      print('Error in removeIdentity: $e');
      debugPrint('Error in identity removal process: $e');
      throw StateError('Error in identity removal process: $e');
    }
  }

  Future<dynamic> resetIdentities() async {
    try {
      await MobileCore.resetIdentities();
      return await Identity.identities;
    } catch (e) {
      debugPrint('Error resetting Adobe Analytics Identity: $e');
      throw StateError('Error resetting Adobe Analytics Identity: $e');
    }
  }

  Future<dynamic> setAdvertisingIdentifier(String advertisingIdentifier) async {
    try {
      return await MobileCore.setAdvertisingIdentifier(advertisingIdentifier);
    } catch (e) {
      debugPrint('Error setting Adobe Analytics Advertising Identifier: $e');
      throw StateError(
          'Error setting Adobe Analytics Advertising Identifier: $e');
    }
  }

  Future<dynamic> updateIdentities(Map<String, dynamic> parameters) async {
    try {
      final identitiesMap = parameters['identities'] as Map<String, dynamic>;
      final identityMap = IdentityMap();

      // Process each namespace in the identities map
      identitiesMap.forEach((namespace, items) {
        if (items is List) {
          for (var item in items) {
            if (item is Map<String, dynamic>) {
              AuthenticatedState authState;
              switch (item['authenticatedState'] as String) {
                case 'authenticated':
                  authState = AuthenticatedState.AUTHENTICATED;
                  break;
                case 'ambiguous':
                  authState = AuthenticatedState.AMBIGUOUS;
                  break;
                case 'loggedOut':
                  authState = AuthenticatedState.LOGGED_OUT;
                  break;
                default:
                  authState = AuthenticatedState.AMBIGUOUS;
              }

              final identityItem = IdentityItem(
                item['id'] as String,
                authState,
                item['primary'] as bool? ?? false,
              );
              try {
                identityMap.addItem(identityItem, namespace);
              } catch (e) {
                throw StateError('Failed to add identity item: $e');
              }
            }
          }
        }
      });
      // Perform the update with a workaround for the hanging issue
      try {
        final updateFuture = Identity.updateIdentities(identityMap);
        final timeoutFuture = Future.delayed(Duration(seconds: 1));
        await Future.any([updateFuture, timeoutFuture]);
        final afterUpdateIdentities = await Identity.identities;

        return afterUpdateIdentities;
      } catch (e) {
        print('Error during identity update: $e');
        throw StateError('Failed to update identities: $e');
      }
    } catch (e) {
      debugPrint('Error updating Adobe Analytics Identities: $e');
      throw StateError('Error updating Adobe Analytics Identities: $e');
    }
  }
}
