import 'package:ensemble/framework/stub/camera_manager.dart';
// import 'package:ensemble/framework/stub/ensemble_chat.dart';
import 'package:ensemble/framework/stub/file_manager.dart';
import 'package:ensemble/framework/stub/contacts_manager.dart';
import 'package:ensemble/framework/stub/plaid_link_manager.dart';
import 'package:ensemble/module/auth_module.dart';
import 'package:get_it/get_it.dart';

// Uncomment to enable ensemble_chat widget
// import 'package:ensemble_chat/ensemble_chat.dart';

// Uncomment to enable Auth service
// import 'package:ensemble_auth/auth_module.dart';

// Uncomment to enable ensemble_contacts service
// import 'package:ensemble_contacts/contact_manager.dart';

// Uncomment to enable ensemble_connect service
// import 'package:ensemble_connect/plaid_link/plaid_link_manager.dart';

// Uncomment to enable camera services
// import 'package:ensemble_camera/camera_manager.dart';

// Uncomment to enable file manager services
// import 'package:ensemble_file_manager/file_manager.dart';

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

  // widgets
  static const enableChat = false;

  // optional modules
  static const useAuth = false;

  void init() {
    if (useCamera) {
      // Uncomment to enable camera service
      // GetIt.I.registerSingleton<CameraManager>(CameraManagerImpl());
    } else {
      GetIt.I.registerSingleton<CameraManager>(CameraManagerStub());
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

    if (useAuth) {
      // Uncomment to enable Auth service
      // AuthModuleImpl().init();
    } else {
      AuthModuleStub().init();
    }

    if (enableChat) {
      // Uncomment to enable ensemble chat
      // GetIt.I.registerSingleton<EnsembleChat>(EnsembleChatImpl());
    } else {
      // GetIt.I.registerSingleton<EnsembleChat>(const EnsembleChatStub());
    }
  }
}
