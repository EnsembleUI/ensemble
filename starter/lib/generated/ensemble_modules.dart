import 'package:ensemble/framework/logging/log_provider.dart';
import 'package:ensemble/framework/notification_manager.dart';
import 'package:ensemble/framework/stub/analytics_provider.dart';
import 'package:ensemble/framework/stub/camera_manager.dart';
import 'package:ensemble/framework/stub/network_info.dart';
import 'package:ensemble/framework/stub/qr_code_scanner.dart';
import 'package:ensemble/framework/stub/deferred_link_manager.dart';
// import 'package:ensemble/framework/stub/ensemble_chat.dart';
import 'package:ensemble/framework/stub/file_manager.dart';
import 'package:ensemble/framework/stub/contacts_manager.dart';
import 'package:ensemble/framework/stub/location_manager.dart';
import 'package:ensemble/framework/stub/plaid_link_manager.dart';
import 'package:ensemble/module/auth_module.dart';
import 'package:ensemble/module/location_module.dart';
//import 'package:ensemble_network_info/network_info.dart';
//import 'package:ensemble_firebase_analytics/firebase_analytics.dart';
// import 'package:ensemble_location/location_module.dart';
import 'package:get_it/get_it.dart';

// Uncomment to enable ensemble_chat widget
// import 'package:ensemble_chat/ensemble_chat.dart';

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
  static const useNetworkInfo = false;

  // widgets
  static const enableChat = false;

  // optional modules
  static const useAuth = false;

  void init() {
    // Note that notifications is not a module
    if (useNotifications) {
      // TODO: use Firebase config in ensemble-config if specified
      // TODO: how to do notificationCallbacks in YAML
      // Currently we need to drop the iOS/Android Firebase config into the root folder
      NotificationManager().init();
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
      // GetIt.I.registerSingleton<EnsembleChat>(const EnsembleChatStub());
    }
    if (useFirebaseAnalytics) {
      //uncomment to enable firebase analytics
      //GetIt.I.registerSingleton<LogProvider>(FirebaseAnalyticsProvider());
    } else {
      GetIt.I.registerSingleton<LogProvider>(LogProviderStub());
    }

    if (useNetworkInfo) {
      //uncomment to enable network info
      //GetIt.I.registerSingleton<NetworkInfoManager>(NetworkInfoImpl());
    } else {
      GetIt.I.registerSingleton<NetworkInfoManager>(NetworkInfoManagerStub());
    }
  }
}
