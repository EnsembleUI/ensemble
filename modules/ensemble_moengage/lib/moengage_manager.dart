// ignore_for_file: public_member_api_docs
// ignore_for_file: type=lint

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import './ensemble_moengage.dart';
import 'package:moengage_flutter_platform_interface/moengage_flutter_platform_interface.dart';
// import 'package:moengage_flutter_example/constants.dart';
// import 'package:moengage_geofence/moengage_geofence.dart';
// import 'package:moengage_inbox/moengage_inbox.dart';
// import 'package:permission_handler/permission_handler.dart';

// import 'cards/cards_home.dart';
// import 'inapp.dart';
// import 'second_page.dart';
// import 'utils.dart';

const String tag = 'MoeExample_';

class MoengageManager {
  final MoEngageFlutter _moengagePlugin = MoEngageFlutter(
      '3OZCFBJPB6KZ7A8B6H1AOA70',
      moEInitConfig: MoEInitConfig(
          pushConfig: PushConfig(shouldDeliverCallbackOnForegroundClick: true),
          analyticsConfig:
              AnalyticsConfig(shouldTrackUserAttributeBooleanAsNumber: false)));
  // final MoEngageGeofence _moEngageGeofence =
  //     MoEngageGeofence('3OZCFBJPB6KZ7A8B6H1AOA70');
  // final MoEngageInbox _moEngageInbox =
  //     MoEngageInbox('3OZCFBJPB6KZ7A8B6H1AOA70');

  // void _onPushClick(PushCampaignData message) {
  //   debugPrint(
  //       '$tag Main : _onPushClick(): This is a push click callback from native to flutter. Payload $message');
  //   if (message.data.selfHandledPushRedirection) {
  //     Navigator.push(
  //         context,
  //         MaterialPageRoute(
  //             builder: (BuildContext context) => const SecondPage()));
  //   }
  // }

  MoengageManager() {
    initializeMoengage();
  }

  void _onPushTokenGenerated(PushTokenData pushToken) {
    debugPrint(
        '$tag Main : _onPushTokenGenerated() : This is callback on push token generated from native to flutter: PushToken: $pushToken');
  }

  void _permissionCallbackHandler(PermissionResultData data) {
    debugPrint('$tag Permission Result: $data');
  }

  // @override
  void initializeMoengage() {
    // super.initState();
    // initPlatformState();
    debugPrint('$tag initState() : start ');
    // _moengagePlugin.setPushClickCallbackHandler(_onPushClick);
    // _moengagePlugin.setPushTokenCallbackHandler(_onPushTokenGenerated);
    // _moengagePlugin.setPermissionCallbackHandler(_permissionCallbackHandler);
    // _moengagePlugin.configureLogs(LogLevel.VERBOSE);

    _moengagePlugin.initialise();
    debugPrint('initState() : end ');
    // _moengagePlugin.setUniqueId('reddeadarthormorgan');
  }

  // Future<void> initPlatformState() async {
  //   if (!mounted) return;
  //   //Push.getTokenStream.listen(_onTokenEvent, onError: _onTokenError);
  // }

  // late BuildContext buildContext;
}
