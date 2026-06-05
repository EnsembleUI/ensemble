import 'dart:async';
import 'dart:developer';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/i18n_loader.dart';
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/framework/widget/screen.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ensemble/framework/definition_providers/provider.dart';
import 'package:ensemble/framework/view/page_group.dart';
import 'package:flutter_i18n/flutter_i18n.dart';

/**
 * DefinitionProvider for connecting to Ensemble-hosted apps
 * TODO: support initialForcedLocale
 */
class EnsembleDefinitionProvider extends DefinitionProvider {
  EnsembleDefinitionProvider(this.appId, {super.initialForcedLocale,this.isListenerMode = false}) {
    if (isListenerMode) {
      appModel = AppModelListenerMode(appId);
    } else {
      appModel = AppModelTimerMode(appId);
    }
  }
  Future<EnsembleDefinitionProvider> init() async {
    await appModel.init();
    return this;
  }
  final bool isListenerMode;
  final String appId;
  late final AppModel appModel;

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

    return content != null
        ? ScreenDefinition(content)
        : ScreenDefinition(YamlMap());
  }

  @override
  FlutterI18nDelegate getI18NDelegate({Locale? forcedLocale}) {
    return FlutterI18nDelegate(
      translationLoader: DataTranslationLoader(
          getTranslationMap: getTranslationMap,
          defaultLocale: Locale(appModel.defaultLocale ?? 'en'),
          forcedLocale: forcedLocale),
    );
  }

  Map? getTranslationMap(Locale locale) =>
      appModel.artifactCache[i18nPrefix + locale.languageCode];

  @override
  UserAppConfig? getAppConfig() {
    return appModel.appConfig;
  }

  @override
  Map<String, String> getSecrets() {
    return appModel.secrets ?? {};
  }

  @override
  String? getHomeScreenName() {
    // Find the screen name that maps to the homeMapping ID
    if (appModel.homeMapping != null) {
      return appModel.screenNameMappings.entries
          .where((entry) => entry.value == appModel.homeMapping)
          .map((entry) => entry.key)
          .firstOrNull;
    }
    return null;
  }

  @override
  List<String> getSupportedLanguages() {
    List<String> supportedLanguages = [];
    appModel.artifactCache.forEach((key, value) {
      if (key.startsWith(i18nPrefix)) {
        supportedLanguages.add(key.substring(i18nPrefix.length));
      }
    });
    return supportedLanguages;
  }

  @override
  void onAppLifecycleStateChanged(AppLifecycleState state) {
    // Reset defer flag when app resumes to allow immediate firing of pending events
    bool wasResumed = (state == AppLifecycleState.resumed);
    bool wasBackgrounded = (state == AppLifecycleState.paused || state == AppLifecycleState.inactive);

    if (wasBackgrounded) {
      if (kDebugMode) {
        print('📱 App backgrounded - storing current visible screen and stopping timers');
      }
      _storeVisibleScreenOnBackground();
      // Stop timers/listeners
      if (appModel is AppModelTimerMode) {
        (appModel as AppModelTimerMode)._stopTimer();
      } else {
        (appModel as AppModelListenerMode).cancelListeners();
      }
    } else if (wasResumed) {
      if (kDebugMode) {
        print('📱 App Resumed - triggering refresh events and restoring screen state');
      }
      // Fire any pending refresh events accumulated since last resume (async operation)
      // Only fire events if refresh is enabled
      if (isArtifactRefreshEnabled()) {
        appModel._firePendingRefreshEvents().then((_) {
          // Restore screen state after refresh events complete
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _restoreVisibleScreenOnForeground();
          });
        });
      } 
      // Start timers/listeners
      if (appModel is AppModelTimerMode) {
        (appModel as AppModelTimerMode)._startTimer();
      } else {
        (appModel as AppModelListenerMode).initListeners();
      }
    }
  }

  /// Store the currently visible screen when app backgrounds
  void _storeVisibleScreenOnBackground() {
    final currentScreen = ScreenTracker().currentScreen;
    if (currentScreen != null) {
      final screenData = {
        'screenId': currentScreen.screenId,
        'screenName': currentScreen.screenName,
        'viewGroupIndex': currentScreen.viewGroupIndex,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      StorageManager().writeToSystemStorage(AppModel._visibleScreenOnBackgroundKey, screenData);
      if (kDebugMode) {
        print('Stored visible screen on background: ${currentScreen.screenName ?? currentScreen.screenId} (index: ${currentScreen.viewGroupIndex})');
      }
    }
  }

  /// Restore the screen that was visible when app was backgrounded
  void _restoreVisibleScreenOnForeground() {
    final storedData = StorageManager().readFromSystemStorage<Map<String, dynamic>>(AppModel._visibleScreenOnBackgroundKey);
    if (storedData != null) {
      final viewGroupIndex = storedData['viewGroupIndex'] as int?;
      // If the screen was in a ViewGroup, restore that specific tab
      if (viewGroupIndex != null) {
        // Import the viewgroup notifier
        final viewGroupNotifier = _getViewGroupNotifier();
        if (viewGroupNotifier != null) {
          // Update to the preserved screen index
          viewGroupNotifier.updatePage(viewGroupIndex);
          if (kDebugMode) {
            print('Restored ViewGroup to index: $viewGroupIndex');
          }
        }
      }

      // Clear the stored data after restoration
      StorageManager().removeFromSystemStorage(AppModel._visibleScreenOnBackgroundKey);
    }
  }

  /// Get the ViewGroup notifier
  ViewGroupNotifier? _getViewGroupNotifier() {
    try {
      // This references the global viewGroupNotifier from page_group.dart
      return viewGroupNotifier;
    } catch (e) {
      if (kDebugMode) {
        print('Could not access ViewGroup notifier: $e');
      }
      return null;
    }
  }
}

class InvalidDefinition {}
class AppModel {
  final String appId;
  AppModel(this.appId);

  // Storage keys for persistent update tracking
  static const String _lastCheckedTimeKey = 'artifact_last_checked_time';
  static const String _updateCheckDurationKey = 'artifact_update_check_duration';
  static const String _pendingRefreshEventsKey = 'artifact_pending_refresh_events';
  static const String _pendingResourceRefreshEventsKey = 'artifact_pending_resource_refresh_events';
  static const String _visibleScreenOnBackgroundKey = 'visible_screen_on_background';

  // Default update check duration (60 minutes in milliseconds)
  static const int _defaultUpdateCheckDuration = 60 * 60 * 1000;

  // Store pending UI refresh events
  List<Map<String, dynamic>> _pendingRefreshEvents = [];
  List<Map<String, dynamic>> _pendingResourceRefreshEvents = [];

  // Track if this is initial app load vs runtime update for optimal refresh logic
  bool _isInitialLoad = true;

  // Only defer UI refresh events for runtime updates, not initial loads
  bool get _shouldDeferRefreshEvents => !_isInitialLoad;

  // Get the configurable update check duration from environment or use default
  int get _updateCheckDuration {
    String? envDuration = appConfig?.envVariables?['UPDATE_CHECK_DURATION'];
    if (envDuration != null) {
      int parsedDuration = int.parse(envDuration);

      // Update storage to track current env value
      int? storedDuration = StorageManager().readFromSystemStorage<int>(_updateCheckDurationKey);
      if (storedDuration != parsedDuration) {
        StorageManager().writeToSystemStorage(_updateCheckDurationKey, parsedDuration);
      }
      return parsedDuration;
    } else {
      // No env variable - clear storage and use default
      if (StorageManager().hasDataFromSystemStorage(_updateCheckDurationKey)) {
        StorageManager().removeFromSystemStorage(_updateCheckDurationKey);
      }
      return _defaultUpdateCheckDuration;
    }
  }

  // Check if artifact refresh is enabled via environment variable
  bool get _isArtifactRefreshEnabled {
    String? enableRefresh = appConfig?.envVariables?['ENABLE_ARTIFACT_REFRESH'];
    if (enableRefresh != null) {
      return enableRefresh.toLowerCase() == 'true';
    }
    return false; // Default: disabled
  }

  // Get the last checked time from persistent storage
  int? get _lastCheckedTime {
    return StorageManager().readFromSystemStorage<int>(_lastCheckedTimeKey);
  }

  // Update the last checked time in persistent storage
  void _updateLastCheckedTime() {
    int currentTime = DateTime.now().millisecondsSinceEpoch;
    StorageManager().writeToSystemStorage(_lastCheckedTimeKey, currentTime);
  }

  // Check if configured time has passed since last update check
  bool _shouldCheckForUpdates() {
    int? lastChecked = _lastCheckedTime;
    if (lastChecked == null) {
      return true; // First time, should check
    }
    int currentTime = DateTime.now().millisecondsSinceEpoch;
    int timeSinceLastCheck = currentTime - lastChecked;
    return timeSinceLastCheck >= _updateCheckDuration;
  }

  /// Smart update function that respects the time duration
  Future<void> updateAppIfNeeded() async {
    if (_shouldCheckForUpdates()) {
      await updateApp();
    }
  }

  /// Load pending screen refresh events from storage
  void _loadPendingRefreshEvents() {
    List<dynamic>? stored = StorageManager().readFromSystemStorage<List<dynamic>>(_pendingRefreshEventsKey);
    if (stored != null) {
      _pendingRefreshEvents = stored.cast<Map<String, dynamic>>();
    }
  }

  /// Save pending screen refresh events to storage
  void _savePendingRefreshEvents() {
    StorageManager().writeToSystemStorage(_pendingRefreshEventsKey, _pendingRefreshEvents);
  }

  /// Add a refresh event to pending list (cache already updated)
  void _addPendingRefreshEvent(String screenId, String? screenName) {
    // Remove any existing pending refresh for the same screen
    _pendingRefreshEvents.removeWhere((event) =>
        event['screenId'] == screenId ||
        (screenName != null && event['screenName'] == screenName)
    );

    // Add new pending refresh event
    _pendingRefreshEvents.add({
      'screenId': screenId,
      'screenName': screenName,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    _savePendingRefreshEvents();
  }

  /// Fire all pending refresh events and clear the list
  Future<void> _firePendingRefreshEvents() async {
    int totalEvents = _pendingRefreshEvents.length + _pendingResourceRefreshEvents.length;
    if (totalEvents == 0) return;

    if (kDebugMode) {
      print('Firing $totalEvents pending refresh events (${_pendingRefreshEvents.length} screen, ${_pendingResourceRefreshEvents.length} resource)...');
    }

    bool needsCacheClear = _pendingResourceRefreshEvents.any(
      (event) => ['resources'].contains(event['artifactType'])
    );

    if (needsCacheClear) {
      // Clear resource caches if requested to force re-parsing
      Ensemble().getConfig()?.clearResourceCaches();
      // Refresh AppBundle once (fetches from Firebase)
      await Ensemble().getConfig()?.refreshAppBundleResources();
    }

    // Fire screen refresh events
    for (var refreshEvent in _pendingRefreshEvents) {
      try {
        AppEventBus().eventBus.fire(ScreenRefreshEvent(
          screenId: refreshEvent['screenId'],
          screenName: refreshEvent['screenName'],
        ));
      } catch (e) {
        if (kDebugMode) {
          print('Failed to fire screen refresh event for: ${refreshEvent['screenId']}: $e');
        }
      }
    }

    // Fire resource refresh events
    for (var refreshEvent in _pendingResourceRefreshEvents) {
      try {
        AppEventBus().eventBus.fire(ResourceRefreshEvent(
          artifactId: refreshEvent['artifactId'],
          artifactType: refreshEvent['artifactType'],
        ));
      } catch (e) {
        if (kDebugMode) {
          print('Failed to fire resource refresh event for: ${refreshEvent['artifactId']}: $e');
        }
      }
    }

    // Clear pending refresh events
    _pendingRefreshEvents.clear();
    _savePendingRefreshEvents();
    _pendingResourceRefreshEvents.clear();
    _savePendingResourceRefreshEvents();
  }

  /// Load pending resource refresh events from storage
  void _loadPendingResourceRefreshEvents() {
    List<dynamic>? stored = StorageManager().readFromSystemStorage<List<dynamic>>(_pendingResourceRefreshEventsKey);
    if (stored != null) {
      _pendingResourceRefreshEvents = stored.cast<Map<String, dynamic>>();
    }
  }

  /// Save pending resource refresh events to storage
  void _savePendingResourceRefreshEvents() {
    StorageManager().writeToSystemStorage(_pendingResourceRefreshEventsKey, _pendingResourceRefreshEvents);
  }

  /// Add a resource refresh event to pending list (cache already updated)
  void _addPendingResourceRefreshEvent(String artifactId, String artifactType) {
    // Remove any existing pending refresh for the same artifact
    _pendingResourceRefreshEvents.removeWhere((event) =>
        event['artifactId'] == artifactId && event['artifactType'] == artifactType
    );

    // Add new pending resource refresh event
    _pendingResourceRefreshEvents.add({
      'artifactId': artifactId,
      'artifactType': artifactType,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    _savePendingResourceRefreshEvents();
    if (kDebugMode) {
      print('Added pending resource refresh for: $artifactId (type: $artifactType)');
    }
  }


  Future<void> init() async {
    _loadPendingRefreshEvents();
    _loadPendingResourceRefreshEvents();
    return;
  }

  // Base updateApp method - will be overridden by subclasses
  Future<void> updateApp() async {
    return;
  }
  // the cache for ID -> screen content
  Map<String, dynamic> artifactCache = {};

  // these are mappings from home/screen name to IDs
  Map<String, String> screenNameMappings = {};
  String? homeMapping;
  String? themeMapping;
  String? defaultLocale;
  UserAppConfig? appConfig;
  Map<String, String>? secrets;

  // storing the resource cache from imported apps
  Map<String, dynamic> importCache = {};

  Future<bool> updateArtifact(
      DocumentSnapshot<Map<String, dynamic>> doc, bool isModified) async {
    // adjust the theme and home screen
    if (doc.data()?['isRoot'] == true) {
      if (doc.data()?['type'] == ArtifactType.screen.name) {
        homeMapping = doc.id;
      } else if (doc.data()?['type'] == ArtifactType.theme.name) {
        themeMapping = doc.id;
      } else if (doc.data()?['type'] == ArtifactType.i18n.name &&
          doc.data()?['defaultLocale'] == true) {
        String id = doc.id;
        if (id.startsWith(EnsembleDefinitionProvider.i18nPrefix)) {
          defaultLocale =
              id.substring(EnsembleDefinitionProvider.i18nPrefix.length);
        }
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

    if (doc.data()?['type'] == 'screen' && doc.data()?['name'] != null) {
      screenNameMappings[doc.data()!['name']] = doc.id;
    }

    dynamic yamlContent;
    String? content = doc.data()?['content'];
    if (content != null && content.isNotEmpty) {
      try {
        yamlContent = await loadYaml(content);
      } on Exception catch (e) {
        // invalid YAML need to be suppressed until we actually reach the page,
        // so we'll just ignore this error here
        log("Invalid YAML for doc '${doc.id}'\n${e.toString()}");
        // throw error right away for resources
        if (doc.id == ArtifactType.resources.name) {
          throw LanguageError(
              "Invalid YAML for 'resources': \n${e.toString()}");
        }
      }
    }
    // non-screen (i.e. theme is perfectly fine to be null)
    if (yamlContent == null && doc.data()?['type'] == 'screen') {
      yamlContent = InvalidDefinition();
    }
    artifactCache[doc.id] = yamlContent;

    // Handle refresh events - screen-specific and resource-specific
    // Only add events if refresh is enabled
    if (_isArtifactRefreshEnabled) {
      String? artifactType = doc.data()?['type'];
      if (artifactType == 'screen') {
        String? screenName = doc.data()?['name'];
        if (_shouldDeferRefreshEvents) {
          // Runtime update - defer refresh until app resumes for better UX
          _addPendingRefreshEvent(doc.id, screenName);
        }
      } else if (artifactType != null && ['resources', 'theme', 'config', 'secrets'].contains(artifactType)) {
        // Handle non-screen artifacts that should trigger global refresh
        if (_shouldDeferRefreshEvents) {
          // Runtime update - defer refresh until app resumes
          _addPendingResourceRefreshEvent(doc.id, artifactType);
        }
      }
    }

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
  CollectionReference<Map<String, dynamic>> _getInternalArtifacts() {
    final app = Ensemble().ensembleFirebaseApp!;
    FirebaseFirestore db = FirebaseFirestore.instanceFor(app: app);
    return db.collection('apps').doc(appId).collection('internal_artifacts');
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
    QuerySnapshot<Map<String, dynamic>> snapshot = await _getInternalArtifacts()
        .where('isArchived', isEqualTo: false)
        .get();
     for (var doc in snapshot.docs) {
        var type = doc.data()['type'];
        var name = doc.data()['name'];
        var content = doc.data()['content'];
      if (type == ArtifactType.internal_widget.name) {
        YamlMap yamlContent = await loadYaml(content);
        widgets[name] = yamlContent["Widget"];
      } 
      if (type == ArtifactType.internal_script.name) {
        code[name] = content;
      } 
    }

    // YamlMap? resources = artifactCache[ArtifactType.resources.name];
    // resources?.forEach((key, value) {
    //   if (key == ResourceArtifactEntry.Widgets.name) {
    //     if (value is YamlMap) {
    //       widgets.addAll(value.value);
    //     }
    //   } else if (key == ResourceArtifactEntry.Scripts.name) {
    //     if (value is YamlMap) {
    //       //code will be in the format -
    //       // Scripts:
    //       //  #apiUtils is the name of the code artifact
    //       //  apiUtils: |-
    //       //    function callAPI(name,payload) {
    //       //      ensemble.invokeAPI(name, payload);
    //       //    }
    //       //  #common is the name of the code artifact
    //       //  common: |-
    //       //    function sayHello() {
    //       //      return 'hello';
    //       //    }
    //       code.addAll(value.value);
    //     }
    //   } else {
    //     // copy over non-Widgets
    //     output[key] = value;
    //   }
    // });

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
class AppModelListenerMode extends AppModel {
  AppModelListenerMode(String appId): super(appId);
  Future<void> init() async {
    await initListeners();
  }
  // only 1 instance of these listeners
  static StreamSubscription? _artifactListener;
  static StreamSubscription? _dependentArtifactListener;
  /// fetch async and cache our entire App's artifacts.
  /// Plus listen for changes and update the cache
  String? listenerError;

  void cancelListeners() async {
    if (_artifactListener != null) {
      await _artifactListener!.cancel();
      _artifactListener = null;
    }
    if (_dependentArtifactListener != null) {
      await _dependentArtifactListener!.cancel();
      _dependentArtifactListener = null;
    }
  }

  Future<void> initListeners() async {
    final app = Ensemble().ensembleFirebaseApp;
    FirebaseFirestore db = FirebaseFirestore.instanceFor(app: app);

    await _artifactListener?.cancel();
    _artifactListener = db
        .collection('apps')
        .doc(appId)
        .collection('artifacts')
        .where("isArchived", isEqualTo: false)
        .snapshots()
        .listen((event) {
      bool isInitialSnapshot = _isInitialLoad;

      for (var change in event.docChanges) {
        if (change.type == DocumentChangeType.removed) {
          removeArtifact(change.doc);
        } else {
          updateArtifact(
              change.doc, change.type == DocumentChangeType.modified);
        }
      }

      // Mark initial load as complete after processing first snapshot
      if (isInitialSnapshot) {
        _isInitialLoad = false;
      }
    }, onError: (error) {
      log("Provider listener error");
      listenerError = error.toString();
    });

    // hardcoded to Ensemble public widget library
    await initWidgetArtifactListeners(EnsembleDefinitionProvider.ensembleLibraryId);
  }

  Future<void> initWidgetArtifactListeners(String appId) async {
    final app = Ensemble().ensembleFirebaseApp;

    await _dependentArtifactListener?.cancel();
    _dependentArtifactListener = FirebaseFirestore.instanceFor(app: app)
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
}
class AppModelTimerMode extends AppModel {
  AppModelTimerMode(String appId): super(appId);
  Future<void> init() async {
    await updateApp(); // Direct call bypasses duration check
    await _startTimer();
  }
  /// this is latest timestamp of the updatedAt or createdAt among all artifacts
  Timestamp? lastUpdatedAt;
  Timestamp? internalArtifactLastUpdateAt;
  /// timer to check for updates
  Timer? _timer;
  // Interval based on configured duration
  Duration get _interval {
    int durationMs = _updateCheckDuration;
    return Duration(milliseconds: durationMs);
  }

  Future<void> _startTimer() async {
    // Call updateAppIfNeeded on resume (respects duration check)
    await updateAppIfNeeded();
    if (_timer == null || _timer!.isActive == false) {
      _timer = Timer.periodic(_interval, (timer) async {
        await updateAppIfNeeded();
      });
    }
  }

  void _stopTimer() {
    _timer?.cancel();
  }
  @override
  Future<AppBundle> getAppBundle({bool? bypassCache = false}) async {
    if (bypassCache == true || artifactCache.isEmpty) {
      await init();
    }
    return AppBundle(
        theme: themeMapping != null ? artifactCache[themeMapping] : null,
        resources: await getCombinedResources());
  }
  Future<void> updateInternalArtifacts() async {
    final app = Ensemble().ensembleFirebaseApp;
    final String appId = EnsembleDefinitionProvider.ensembleLibraryId;
    Map<String, dynamic>? data;
    bool isUpdate = internalArtifactLastUpdateAt != null;
    if (isUpdate) {
      print("Checking for updates of internal artifacts at: ${DateTime.now()}");
      QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore.instanceFor(app: app)
          .collection('apps')
          .doc(appId)
          .collection('artifacts')
          .where('updatedAt', isGreaterThan: internalArtifactLastUpdateAt)
          .get();
      if (snapshot.docs.isNotEmpty) {
        for (var doc in snapshot.docs) {
          internalArtifactLastUpdateAt = calculateLastUpdatedAt(doc, internalArtifactLastUpdateAt);
          if (doc.id == 'resources') {
            data = doc.data();
          }
        }
        print("updating internalArtifactLastUpdateAt to $internalArtifactLastUpdateAt");
      }
    } else {
      print("first time retrieving internal artifacts at: ${DateTime.now()}");
      final docSnapshot = await FirebaseFirestore.instanceFor(app: app)
          .collection('apps')
          .doc(appId)
          .collection('artifacts')
          .doc('resources')
          .get();
      if (docSnapshot.exists) {
        data = docSnapshot.data();
        internalArtifactLastUpdateAt = data?['updatedAt'];
        print("updating internalArtifactLastUpdateAt to $internalArtifactLastUpdateAt");
      }
    }
    if (data == null) {
      return;
    }
    dynamic content = data['content'];
    if (content != null) {
      importCache[appId] = content;
    } else {
      importCache.remove(appId);
    }
  }

  @override
  Future<void> updateApp() async {
    await updateInternalArtifacts();
    QuerySnapshot<Map<String, dynamic>> snapshot;
    bool isUpdate = lastUpdatedAt != null;
    if (isUpdate) {
      print("Checking for updates at: ${DateTime.now()}");
      snapshot = await _getArtifacts()
          .where('isArchived', isEqualTo: false)
          .where('updatedAt', isGreaterThan: lastUpdatedAt)
          .get();
    } else {
      print("first time retrieving app at: ${DateTime.now()}");
      snapshot = await _getArtifacts()
          .where('isArchived', isEqualTo: false)
          .get();
    }
    for (var doc in snapshot.docs) {
      await updateArtifact(doc, isUpdate);
      lastUpdatedAt = calculateLastUpdatedAt(doc, lastUpdatedAt);
    }
    _updateLastCheckedTime();

    // Mark initial load as complete after first successful app load
    if (_isInitialLoad) {
      _isInitialLoad = false;
    }
  }

  Timestamp? calculateLastUpdatedAt(var artifact, Timestamp? existingLastUpdatedAt) {
    // Get the 'updatedAt' or 'createdAt' timestamp
    Timestamp? currentUpdatedAt;
    if (artifact.data().containsKey('updatedAt') && artifact.data()['updatedAt'] != null) {
      currentUpdatedAt = artifact.data()['updatedAt'] as Timestamp;
    } else if (artifact.data().containsKey('createdAt') && artifact.data()['createdAt'] != null) {
      currentUpdatedAt = artifact.data()['createdAt'] as Timestamp;
    }

    // Update the lastUpdatedAt if currentUpdatedAt is more recent
    if (currentUpdatedAt != null) {
      if (existingLastUpdatedAt == null || currentUpdatedAt.millisecondsSinceEpoch > existingLastUpdatedAt!.millisecondsSinceEpoch) {
        print("updating lastUpdatedAt to $currentUpdatedAt");
        return currentUpdatedAt;
      }
    }
    return existingLastUpdatedAt;
  }

}
