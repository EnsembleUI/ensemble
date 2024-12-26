import 'dart:convert';
import 'dart:io';
import 'package:ensemble/framework/notification_manager.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:moengage_flutter/moengage_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class MoEngageNotificationHandler {
  static final MoEngageNotificationHandler _instance =
      MoEngageNotificationHandler._internal();
  factory MoEngageNotificationHandler() => _instance;
  MoEngageNotificationHandler._internal();

  MoEngageFlutter? _moengagePlugin;
  bool _initialized = false;

  Future<void> initialize(MoEngageFlutter moengagePlugin) async {
    if (_initialized) {
      debugPrint('MoEngage notifications already initialized');
      return;
    }

    try {
      _moengagePlugin = moengagePlugin;

      await _registerHandlers();
      // await _setupPushToken();

      _initialized = true;
    } catch (e) {
      debugPrint('Error initializing MoEngage notification handler: $e');
    }
  }

  Future<void> _registerHandlers() async {
    _moengagePlugin?.setInAppClickHandler(_onInAppClick);
    _moengagePlugin?.setPushClickCallbackHandler(_onPushClick);
  }

  void _onInAppClick(ClickData message) {

    try {
      // Convert MoEngage InApp click data to common notification format
      Map<String, dynamic> inAppData = {
        'campaignId': message.campaignData.campaignId,
        'campaignName': message.campaignData.campaignName,
        'platform': message.platform.toString().split('.').last.toLowerCase(),
        'data': {}, // Base data object
      };

      // Add action data based on type
      if (message.action is NavigationAction) {
        final navAction = message.action as NavigationAction;
        inAppData['data'].addAll({
          'actionType': 'navigation',
          'navigationType': navAction.navigationType.toString(),
          'navigationUrl': navAction.navigationUrl,
          'keyValuePairs': navAction.keyValuePairs,
        });
      } else if (message.action is CustomAction) {
        final customAction = message.action as CustomAction;
        inAppData['data'].addAll({
          'actionType': 'custom',
          'keyValuePairs': customAction.keyValuePairs,
        });
      }

      NotificationManager().handleNotification(jsonEncode(inAppData));
    } catch (e) {
      debugPrint('Error processing InApp click: $e');
    }
  }

  void _onPushClick(PushCampaignData message) {
    try {
      final pushData = message.data;

      Map<String, dynamic> notificationData = {
        ...pushData.payload, // Include all original payload
        'clickedAction': pushData.clickedAction,
        'platform': message.platform.toString().split('.').last.toLowerCase(),
      };

      if (Platform.isAndroid) {
        notificationData['isDefaultAction'] = pushData.isDefaultAction;
      }

      // Pass to NotificationManager
      NotificationManager().handleNotification(jsonEncode(notificationData));
    } catch (e) {
      debugPrint('Error processing MoEngage push click: $e');
    }
  }

  bool get isInitialized => _initialized;
}
