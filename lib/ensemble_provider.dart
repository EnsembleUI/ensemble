import 'dart:async';
import 'dart:developer';
import 'dart:ui';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/i18n_loader.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter_i18n/loaders/decoders/yaml_decode_strategy.dart';
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

  @override
  Future<AppBundle> getAppBundle() async {
    return appModel.getAppBundle();
  }

  static void getAppDefinition(
      String appId, Function callback, Function onError) {
    FirebaseFirestore db = FirebaseFirestore.instance;
    db.collection('apps').doc(appId).get().then(
        (doc) => callback(doc.id, doc.data()),
        onError: (error) => onError(error));
  }

  //each item in the list is <appid>:<appname> format
  static void getListOfDemoApps(Function callback, Function onError) {
    List<Map<String, dynamic>> apps = [];
    FirebaseFirestore db = FirebaseFirestore.instance;
    db
        .collection('apps')
        .where("category", isEqualTo: "Demo")
        .where("isPublic", isEqualTo: true)
        .where("isArchived", isEqualTo: false)
        //.orderBy("name")
        .get()
        .then((querySnapshot) {
      List<dynamic> allData = querySnapshot.docs
          .map((doc) => {'id': doc.id, 'props': doc.data()})
          .toList();
      for (Map<String, dynamic> doc in allData) {
        apps.add(doc);
      }
      callback(apps);
    }, onError: (error, stackTrace) => onError(error));
  }

  @override
  Future<YamlMap> getDefinition({String? screenId, String? screenName}) async {
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
      throw LanguageError(
          "Invalid screen content: ${screenId ?? screenName ?? 'Home'}");
    }
    return content;
  }

  @override
  FlutterI18nDelegate getI18NDelegate() {
    _i18nDelegate ??= FlutterI18nDelegate(
        translationLoader: DataTranslationLoader(
            defaultLocaleMap:
                appModel.contentCache[i18nPrefix + i18nProps.defaultLocale],
            fallbackLocaleMap:
                appModel.contentCache[i18nPrefix + i18nProps.fallbackLocale]));
    return _i18nDelegate!;
  }

  @override
  UserAppConfig? getAppConfig() {
    return appModel.appConfig;
  }
}

class InvalidDefinition {}

class AppModel {
  AppModel(this.appId) {
    initListeners();
  }

  final String appId;

  // the cache for ID -> screen content
  Map<String, dynamic> contentCache = {};

  // these are mappings from home/screen name to IDs
  Map<String, String> screenNameMappings = {};
  String? homeMapping;
  String? themeMapping;
  UserAppConfig? appConfig;

  /// fetch async and cache our entire App's artifacts.
  /// Plus listen for changes and update the cache
  String? listenerError;

  void initListeners() {
    FirebaseFirestore db = FirebaseFirestore.instance;
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
          updateArtifact(change.doc);
        }
      }
    }, onError: (error) {
      log("Provider listener error");
      listenerError = error.toString();
    });
  }

  Future<bool> updateArtifact(
      DocumentSnapshot<Map<String, dynamic>> doc) async {
    // adjust the theme and home screen
    if (doc.data()?['isRoot'] == true) {
      if (doc.data()?['type'] == 'screen') {
        homeMapping = doc.id;
      } else if (doc.data()?['type'] == 'theme') {
        themeMapping = doc.id;
      } else if (doc.data()?['type'] == 'config') {
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
    contentCache[doc.id] = yamlContent;

    log("Cached: ${contentCache.keys}. Home: $homeMapping. Theme: $themeMapping. Names: ${screenNameMappings.keys}");
    return Future<bool>.value(true);
  }

  void removeArtifact(DocumentSnapshot<Map<String, dynamic>> doc) {
    log("Removed ${doc.id}");
    screenNameMappings.removeWhere((key, value) => (value == doc.id));
    contentCache.remove(doc.id);
  }

  Future<YamlMap?> getScreenById(String screenId) async {
    dynamic content = contentCache[screenId];
    // fetch if not in cache. Should only be the first time when
    // our listeners are not done initialized yet.
    if (content == null) {
      DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _getArtifacts().doc(screenId).get();
      await updateArtifact(snapshot);
      content = contentCache[screenId];
      log("Cache missed for $screenId");
    }
    if (content is YamlMap) {
      return content;
    }
    return null;
  }

  Future<YamlMap?> getScreenByName(String screenName) async {
    dynamic content;
    String? screenId = screenNameMappings[screenName];
    if (screenId != null) {
      content = contentCache[screenId];
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
        await updateArtifact(searchByName.docs[0]);
        content = contentCache[screenName];
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
      content = contentCache[homeMapping];
    }
    if (content is YamlMap) {
      return Future.value(content);
    }
    return Future.value(null);
  }

  CollectionReference<Map<String, dynamic>> _getArtifacts() {
    FirebaseFirestore db = FirebaseFirestore.instance;
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
      await updateArtifact(doc);
      if (doc.data()['type'] == 'theme') {
        themeMapping = doc.id;
      } else if (doc.data()['type'] == 'screen' && homeMapping == null) {
        homeMapping = doc.id;
      }
    }
    return AppBundle(
        theme: themeMapping != null ? contentCache[themeMapping] : null);
  }
}
