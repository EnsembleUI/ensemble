import 'dart:async';
import 'dart:developer';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/i18n_loader.dart';
import 'package:ensemble/framework/widget/screen.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:yaml/yaml.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ensemble/provider.dart';
import 'package:flutter_i18n/flutter_i18n.dart';

/// Connecting to Ensemble-hosted definitions
class EnsembleDefinitionProvider extends DefinitionProvider {
  EnsembleDefinitionProvider(String appId, super.i18nProps) {
    appModel = AppModel(appId);
  }

  late final AppModel appModel;
  FlutterI18nDelegate? _i18nDelegate;

  /// prefix for i18n in Firebase
  static const i18nPrefix = 'i18n_';

  // hardcoded Ensemble widget library app ID
  static const ensembleLibraryId = '8PghcmhtGkWiWffmhDDl';

  @override
  Future<AppBundle> getAppBundle({bool? bypassCache = false}) async {
    return appModel.getAppBundle();
  }

  static void getAppDefinition(
      String appId, Function callback, Function onError) {
    final app = Ensemble().ensembleFirebaseApp!;
    FirebaseFirestore db = FirebaseFirestore.instanceFor(app: app);
    db.collection('apps').doc(appId).get().then(
        (doc) => callback(doc.id, doc.data()),
        onError: (error) => onError(error));
  }

  @override
  Future<ScreenDefinition> getDefinition(
      {String? screenId, String? screenName}) async {
    YamlMap? content;

    // search by ID
    if (screenId != null) {
      content = await appModel.getScreenById(screenId);
    }
    // search by name
    else if (screenName != null) {
      content = await appModel.getScreenByName(screenName);
    }
    // get home screen
    else {
      content = await appModel.getHomeScreen();
    }

    if (content == null) {
      throw LanguageError('invalid-content',
          detailError:
              "Invalid screen content: ${screenId ?? screenName ?? 'Home'}");
    }
    return ScreenDefinition(content);
  }

  @override
  FlutterI18nDelegate getI18NDelegate() {
    _i18nDelegate ??= FlutterI18nDelegate(
        translationLoader: DataTranslationLoader(
            defaultLocaleMap:
                appModel.artifactCache[i18nPrefix + i18nProps.defaultLocale],
            fallbackLocaleMap:
                appModel.artifactCache[i18nPrefix + i18nProps.fallbackLocale]));
    return _i18nDelegate!;
  }

  @override
  UserAppConfig? getAppConfig() {
    return appModel.appConfig;
  }

  @override
  Map<String, String> getSecrets() {
    return appModel.secrets ?? {};
  }
}

class InvalidDefinition {}

class AppModel {
  AppModel(this.appId) {
    initListeners();
  }

  final String appId;

  // the cache for ID -> screen content
  Map<String, dynamic> artifactCache = {};

  // these are mappings from home/screen name to IDs
  Map<String, String> screenNameMappings = {};
  String? homeMapping;
  String? themeMapping;
  UserAppConfig? appConfig;
  Map<String, String>? secrets;

  // storing the resource cache from imported apps
  Map<String, dynamic> importCache = {};

  /// fetch async and cache our entire App's artifacts.
  /// Plus listen for changes and update the cache
  String? listenerError;

  void initListeners() {
    final app = Ensemble().ensembleFirebaseApp!;
    FirebaseFirestore db = FirebaseFirestore.instanceFor(app: app);
    db
        .collection('apps')
        .doc(appId)
        .collection('artifacts')
        .where("isArchived", isEqualTo: false)
        .snapshots()
        .listen((event) {
      for (var change in event.docChanges) {
        if (change.type == DocumentChangeType.removed) {
          removeArtifact(change.doc);
        } else {
          updateArtifact(
              change.doc, change.type == DocumentChangeType.modified);
        }
      }
    }, onError: (error) {
      log("Provider listener error");
      listenerError = error.toString();
    });

    // hardcoded to Ensemble public widget library
    initWidgetArtifactListeners(EnsembleDefinitionProvider.ensembleLibraryId);
  }

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>
      initWidgetArtifactListeners(String appId) {
    final app = Ensemble().ensembleFirebaseApp!;

    return FirebaseFirestore.instanceFor(app: app)
        .collection('apps')
        .doc(appId)
        .collection('artifacts')
        .doc('resources')
        .snapshots()
        .listen((event) {
      dynamic content = event.data()?['content'];
      if (content != null) {
        importCache[appId] = content;
      } else {
        importCache.remove(appId);
      }
    });
  }

  Future<bool> updateArtifact(
      DocumentSnapshot<Map<String, dynamic>> doc, bool isModified) async {
    // adjust the theme and home screen
    if (doc.data()?['isRoot'] == true) {
      if (doc.data()?['type'] == ArtifactType.screen.name) {
        homeMapping = doc.id;
      } else if (doc.data()?['type'] == ArtifactType.theme.name) {
        themeMapping = doc.id;
      } else if (doc.data()?['type'] == ArtifactType.config.name) {
        // environment variable
        Map<String, dynamic>? envVariables;
        dynamic env = doc.data()!['envVariables'];
        if (env is Map) {
          envVariables = {};
          env.forEach((key, value) => envVariables![key] = value);
        }
        appConfig = UserAppConfig(
            baseUrl: doc.data()?['appBaseUrl'],
            useBrowserUrl: Utils.optionalBool(doc.data()?['appUseBrowserUrl']),
            envVariables: envVariables);
      } else if (doc.data()?['type'] == ArtifactType.secrets.name) {
        dynamic rawSecrets = doc.data()!['secrets'];
        if (rawSecrets is Map) {
          secrets = {};
          rawSecrets.forEach((key, value) => secrets![key] = value);
        }
      }

      // mark the app bundle as dirty
      if (isModified &&
          [
            ArtifactType.theme.name,
            ArtifactType.config.name,
            ArtifactType.resources.name
          ].contains(doc.data()!['type'])) {
        log("Changed Artifact: " + doc.data()!['type']);
        Ensemble().notifyAppBundleChanges();
      }
    }

    // since the screen name might have changed, update our mappings
    screenNameMappings.removeWhere((key, value) => (value == doc.id));
    if (doc.data()?['name'] != null) {
      screenNameMappings[doc.data()!['name']] = doc.id;
    }

    dynamic yamlContent;
    dynamic content = doc.data()?['content'];
    if (content != null && content.isNotEmpty) {
      try {
        yamlContent = await loadYaml(content);
      } on Exception catch (e) {
        // invalid YAML need to be suppressed until we actually reach the page,
        // so we'll just ignore this error here
      }
    }
    // non-screen (i.e. theme is perfectly fine to be null)
    if (yamlContent == null && doc.data()?['type'] == 'screen') {
      yamlContent = InvalidDefinition();
    }
    artifactCache[doc.id] = yamlContent;

    log("Cached: ${artifactCache.keys}. Home: $homeMapping. Theme: $themeMapping. Names: ${screenNameMappings.keys}");
    return Future<bool>.value(true);
  }

  void removeArtifact(DocumentSnapshot<Map<String, dynamic>> doc) {
    log("Removed ${doc.id}");
    screenNameMappings.removeWhere((key, value) => (value == doc.id));
    artifactCache.remove(doc.id);
  }

  Future<YamlMap?> getScreenById(String screenId) async {
    dynamic content = artifactCache[screenId];
    // fetch if not in cache. Should only be the first time when
    // our listeners are not done initialized yet.
    if (content == null) {
      DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _getArtifacts().doc(screenId).get();
      await updateArtifact(snapshot, false);
      content = artifactCache[screenId];
      log("Cache missed for $screenId");
    }
    return content is YamlMap ? content : null;
  }

  Future<YamlMap?> getScreenByName(String screenName) async {
    dynamic content;
    String? screenId = screenNameMappings[screenName];
    if (screenId != null) {
      content = artifactCache[screenId];
    }
    // not in cache. Fetch it. Should be the first time only
    // until our cache is populated by the listeners
    if (content == null) {
      QuerySnapshot<Map<String, dynamic>> searchByName = await _getArtifacts()
          .where("type", isEqualTo: 'screen')
          .where('isArchived', isEqualTo: false)
          .where('name', isEqualTo: screenName)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (searchByName.docs.isNotEmpty) {
        await updateArtifact(searchByName.docs[0], false);
        content = artifactCache[screenName];
        log("Cache missed for $screenName");
      }
    }
    if (content is YamlMap) {
      return content;
    }
    return null;
  }

  Future<YamlMap?> getHomeScreen() {
    dynamic content;
    if (homeMapping != null) {
      content = artifactCache[homeMapping];
    }
    if (content is YamlMap) {
      return Future.value(content);
    }
    return Future.value(null);
  }

  CollectionReference<Map<String, dynamic>> _getArtifacts() {
    final app = Ensemble().ensembleFirebaseApp!;
    FirebaseFirestore db = FirebaseFirestore.instanceFor(app: app);
    return db.collection('apps').doc(appId).collection('artifacts');
  }

  /// App bundle for now only expects the theme, but we'll use this
  /// opportunity to also cache the home page
  Future<AppBundle> getAppBundle() async {
    QuerySnapshot<Map<String, dynamic>> snapshot = await _getArtifacts()
        .where('isArchived', isEqualTo: false)
        .where('isRoot', isEqualTo: true)
        .get();
    for (var doc in snapshot.docs) {
      await updateArtifact(doc, false);
      if (doc.data()['type'] == ArtifactType.theme.name) {
        themeMapping = doc.id;
      } else if (doc.data()['type'] == 'screen' && homeMapping == null) {
        homeMapping = doc.id;
      }
    }
    return AppBundle(
        theme: themeMapping != null ? artifactCache[themeMapping] : null,
        resources: await getCombinedResources());
  }

  /// combine our App's resources with imported Apps' widgets (no APIs for now)
  Future<Map?> getCombinedResources() async {
    Map code = {};
    Map output = {};
    Map widgets = {};

    YamlMap? resources = artifactCache[ArtifactType.resources.name];
    resources?.forEach((key, value) {
      if (key == ResourceArtifactEntry.Widgets.name) {
        if (value is YamlMap) {
          widgets.addAll(value.value);
        }
      } else if (key == ResourceArtifactEntry.Scripts.name) {
        if (value is YamlMap) {
          //code will be in the format -
          // Scripts:
          //  #apiUtils is the name of the code artifact
          //  apiUtils: |-
          //    function callAPI(name,payload) {
          //      ensemble.invokeAPI(name, payload);
          //    }
          //  #common is the name of the code artifact
          //  common: |-
          //    function sayHello() {
          //      return 'hello';
          //    }
          code.addAll(value.value);
        }
      } else {
        // copy over non-Widgets
        output[key] = value;
      }
    });

    // go through each imported App to include their widgets with proper namespace
    for (String appId in importCache.keys) {
      // prefix the imported App with its ID, or use 'ensemble' if belong to us
      String namespace = appId == EnsembleDefinitionProvider.ensembleLibraryId
          ? 'ensemble'
          : appId;
      try {
        YamlMap appResources = await loadYaml(importCache[appId]);
        if (appResources[ResourceArtifactEntry.Widgets.name] is YamlMap) {
          // iterate through each widgets in this app to add the namespace prefix
          (appResources[ResourceArtifactEntry.Widgets.name] as YamlMap)
              .forEach((key, value) {
            widgets['$namespace.$key'] = value;
          });
        }
      } on Exception catch (e) {
        // silently ignore default ensemble import. Not ideal but we are not
        // sure if the user actually uses it since it's automatically imported.
        if (namespace == 'ensemble') {
          log("Imported app 'ensemble' has errors. Ignoring...");
          continue;
        } else {
          throw LanguageError("Imported app '$namespace' has errors.",
              recovery: "Please check the imported library or remove it.");
        }
      }
    }

    // finally add the widgets and code to the output
    output[ResourceArtifactEntry.Widgets.name] = widgets;
    output[ResourceArtifactEntry.Scripts.name] = code;
    //log(">>" + output.toString());
    //return YamlMap.wrap(output);
    return output;
  }
}
