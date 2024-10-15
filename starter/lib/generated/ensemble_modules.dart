import 'package:ensemble/framework/logging/log_provider.dart';
import 'package:ensemble/framework/notification_manager.dart';
import 'package:ensemble/framework/stub/analytics_provider.dart';
import 'package:ensemble/framework/stub/camera_manager.dart';
import 'package:ensemble/framework/stub/ensemble_bracket.dart';
import 'package:ensemble/framework/stub/ensemble_chat.dart';
import 'package:ensemble/framework/stub/network_info.dart';
import 'package:ensemble/framework/stub/qr_code_scanner.dart';
import 'package:ensemble/framework/stub/deferred_link_manager.dart';
import 'package:ensemble/framework/stub/file_manager.dart';
import 'package:ensemble/framework/stub/contacts_manager.dart';
import 'package:ensemble/framework/stub/plaid_link_manager.dart';
import 'package:ensemble/module/auth_module.dart';
import 'package:ensemble/module/location_module.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
//import 'package:ensemble_network_info/network_info.dart';
//import 'package:ensemble_firebase_analytics/firebase_analytics.dart';
// import 'package:ensemble_location/location_module.dart';
import 'package:get_it/get_it.dart';

// Uncomment to enable ensemble_chat widget
// import 'package:ensemble_chat/ensemble_chat.dart';

// Uncomment to enable ensemble_bracket widget
// import 'package:ensemble_bracket/ensemble_bracket.dart';

// Uncomment to enable Auth service
// import 'package:ensemble_auth/auth_module.dart';

// Uncomment to enable ensemble_contacts service
// import 'package:ensemble_contacts/contact_manager.dart';

// Uncomment to enable ensemble_connect service
// import 'package:ensemble_connect/plaid_link/plaid_link_manager.dart';

// Uncomment to enable camera services or QRCodeScanner widget
// import 'package:ensemble_camera/camera_manager.dart';
// import 'package:ensemble_camera/qr_code_scanner.dart';

// Uncomment to enable file manager services
// import 'package:ensemble_file_manager/file_manager.dart';

// Uncomment to enable location services
// import 'package:ensemble_location/location_manager.dart';

// Uncomment to enable deeplink services
// import 'package:ensemble_deeplink/deferred_link_manager.dart';

// Uncomment to enable push notifications services or Firebase Analytics
// import 'package:flutter/foundation.dart';
// import 'dart:io';

/// TODO: This class should be generated to enable selected Services
class EnsembleModules {
  static final EnsembleModules _instance = EnsembleModules._internal();
  EnsembleModules._internal();
  factory EnsembleModules() {
    return _instance;
  }

  // capabilities
  static const useCamera = false;
  static const useFiles = false;
  static const useContacts = false;
  static const useConnect = false;
  static const useLocation = false;
  static const useDeeplink = false;
  static const useFirebaseAnalytics = false;
  static const useNotifications = false;

  static const useBracket = false;
  static const useNetworkInfo = false;

  // widgets
  static const enableChat = false;

  // optional modules
  static const useAuth = false;

  Future<void> init() async {
    // Note that notifications is not a module

    if (useNotifications || useFirebaseAnalytics) {
      // if payload is not passed, Firebase configuration files
      // are required to be added manualy to iOS and Android
      try {
        await Firebase.initializeApp();
      } catch (e) {
        print(
            "Failed to initialize firebase app, make sure you either have the firebase options specified in the config file (required for web) "
            "or have the right google file for the platform - google-services.json for android and GoogleService-Info.plist for iOS.");
        rethrow;
      }
    }

    if (useNotifications) {
      // TODO: use Firebase config in ensemble-config if specified
      // TODO: how to do notificationCallbacks in YAML
      // Currently we need to drop the iOS/Android Firebase config into the root folder
      await NotificationManager().init();
    }

    if (useCamera) {
      // Uncomment to enable camera service
      // GetIt.I.registerSingleton<CameraManager>(CameraManagerImpl());

      // Uncomment to enable QRCodeScanner widget support
      // GetIt.I.registerSingleton<EnsembleQRCodeScanner>(
      //     EnsembleQRCodeScannerImpl.build(EnsembleQRCodeScannerController()));
    } else {
      GetIt.I.registerSingleton<CameraManager>(CameraManagerStub());
      GetIt.I.registerSingleton<EnsembleQRCodeScanner>(
          const EnsembleQRCodeScannerStub());
    }

    if (useFiles) {
      // Uncomment to enable file manager service
      // GetIt.I.registerSingleton<FileManager>(FileManagerImpl());
    } else {
      GetIt.I.registerSingleton<FileManager>(FileManagerStub());
    }

    if (useContacts) {
      // Uncomment to enable contacts service
      // GetIt.I.registerSingleton<ContactManager>(ContactManagerImpl());
    } else {
      GetIt.I.registerSingleton<ContactManager>(ContactManagerStub());
    }

    if (useConnect) {
      // Uncomment to enable ensemble_connect service
      // GetIt.I.registerSingleton<PlaidLinkManager>(PlaidLinkManagerImpl());
    } else {
      GetIt.I.registerSingleton<PlaidLinkManager>(PlaidLinkManagerStub());
    }

    if (useLocation) {
      // Uncomment to enable ensemble_location service
      // GetIt.I.registerSingleton<LocationModule>(LocationModuleImpl());
    } else {
      GetIt.I.registerSingleton<LocationModule>(LocationModuleStub());
    }

    if (useDeeplink) {
      // Uncomment to enable ensemble_deeplink service
      // GetIt.I.registerSingleton<DeferredLinkManager>(DeferredLinkManagerImpl());
    } else {
      GetIt.I.registerSingleton<DeferredLinkManager>(DeferredLinkManagerStub());
    }

    if (useAuth) {
      // Uncomment to enable Auth service
      // GetIt.I.registerSingleton<AuthModule>(AuthModuleImpl());
    } else {
      GetIt.I.registerSingleton<AuthModule>(AuthModuleStub());
    }

    if (enableChat) {
      // Uncomment to enable ensemble chat
      // GetIt.I.registerSingleton<EnsembleChat>(EnsembleChatImpl());
    } else {
      GetIt.I.registerSingleton<EnsembleChat>(const EnsembleChatStub());
    }
    if (useFirebaseAnalytics) {
      //uncomment to enable firebase analytics
      // GetIt.I.registerSingleton<LogProvider>(FirebaseAnalyticsProvider());
    } else {
      GetIt.I.registerSingleton<LogProvider>(LogProviderStub());
    }

    if (useBracket) {
      //uncomment to enable ensemble bracket widget
      // GetIt.I.registerSingleton<EnsembleBracket>(EnsembleBracketImpl.build());
    } else {
      GetIt.I.registerSingleton<EnsembleBracket>(const EnsembleBracketStub());
    }

    if (useNetworkInfo) {
      //uncomment to enable network info
      //GetIt.I.registerSingleton<NetworkInfoManager>(NetworkInfoImpl());
    } else {
      GetIt.I.registerSingleton<NetworkInfoManager>(NetworkInfoManagerStub());
    }
  }
}
