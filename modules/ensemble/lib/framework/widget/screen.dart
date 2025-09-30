import 'dart:async';
import 'dart:math';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/ensemble_app.dart';
import 'package:ensemble/framework/apiproviders/api_provider.dart';
import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/definition_providers/ensemble_provider.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble/framework/theme/theme_loader.dart';
import 'package:ensemble/framework/theme_manager.dart';
import 'package:ensemble/framework/view/page_group.dart';
import 'package:ensemble/framework/view/page.dart' as ensemble;
import 'package:ensemble/page_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yaml/yaml.dart';

class Screen extends StatefulWidget {
  const Screen(
      {super.key,
      required this.appProvider,
      this.screenPayload,
      required this.apiProviders,
      this.navigatorKey,
      this.placeholderBackgroundColor});

  final AppProvider appProvider;
  final ScreenPayload? screenPayload;
  final Map<String, APIProvider> apiProviders;
  // If we are using only screen widget to render screen, we need to pass navigator key from host app to work with external screens
  final GlobalKey<NavigatorState>? navigatorKey;
  final Color? placeholderBackgroundColor;

  @override
  State<Screen> createState() => _ScreenState();
}

class _ScreenState extends State<Screen> {
  late Future<ScreenDefinition> screenRequester;
  Widget? externalScreen;
  Key _contentKey = UniqueKey();
  ScreenPayload? _enhancedPayload; // Store enhanced payload for refresh matching

  @override
  void initState() {
    super.initState();

    // this external app navigate key is used to navigate to external screens in screen controller
    if (widget.navigatorKey != null) {
      externalAppNavigateKey = widget.navigatorKey;
    }

    if (widget.screenPayload?.isExternal ?? false) {
      if (widget.screenPayload?.screenName == null) {
        throw LanguageError('ScreenName is mandatory, when external is true');
      }
      externalScreen = Ensemble()
          .externalScreenWidgets[widget.screenPayload!.screenName]
          ?.call(context, widget.screenPayload?.arguments);
      return;
    }
    screenRequester =
        widget.appProvider.getDefinition(payload: widget.screenPayload);
  }

  @override
  Widget build(BuildContext context) {
    //log("Screen build() - $hashCode (${Ensemble().deviceInfo.size.width} x ${Ensemble().deviceInfo.size.height})");
    return widget.screenPayload?.isExternal ?? false
        ? ExternalScreen(screen: externalScreen)
        : FutureBuilder(
            key: _contentKey,
            future: screenRequester,
            builder: (context, snapshot) {
              // show error
              if (snapshot.hasError) {
                throw LanguageError("Invalid YAML definition");
              }
              // show progress bar
              else if (!snapshot.hasData) {
                return Scaffold(
                    backgroundColor: widget.placeholderBackgroundColor ??
                        Theme.of(context)
                            .extension<EnsembleThemeExtension>()
                            ?.loadingScreenBackgroundColor,
                    resizeToAvoidBottomInset: false,
                    body: Center(
                        child: CircularProgressIndicator(
                            color: Theme.of(context)
                                .extension<EnsembleThemeExtension>()
                                ?.loadingScreenIndicatorColor)));
              }

              return APIProviders(
                  providers: widget.apiProviders,
                  child: renderScreen(snapshot.data!));
            });
  }

  @override
  void dispose() {
    super.dispose();
    widget.apiProviders.forEach((key, value) {
      value.dispose();
    });
  }

  /// Called when this screen needs to refresh due to artifact or resource updates
  void _refreshScreen() {
    if (kDebugMode) {
      print('🔄 Refreshing Screen widget: ${widget.screenPayload?.screenId}/${widget.screenPayload?.screenName}');
    }
    setState(() {
      // Create a new key to force FutureBuilder to rebuild completely
      _contentKey = UniqueKey();
      // Create a new Future to force FutureBuilder to rebuild with fresh data
      screenRequester = widget.appProvider.getDefinition(payload: widget.screenPayload);
    });
  }

  Widget renderScreen(ScreenDefinition screenDefinition) {
    if (kDebugMode) {
      print('🏗️ renderScreen() called for ${widget.screenPayload?.screenName} - building PageModel');
    }
    PageModel pageModel =
        screenDefinition.getModel(widget.screenPayload?.arguments);

    // Track screen after we have the pageModel - this ensures we can check if it's a ViewGroup
    // Only track if NOT a ViewGroup container (ViewGroup tabs track themselves)
    if (pageModel is! PageGroupModel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final inViewGroup = PageGroupWidget.getScope(context) != null;
          final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? false;

          if (!inViewGroup && isCurrentRoute) {
            final currentScreen = ScreenTracker().currentScreen;
            final payload = widget.screenPayload;

            // Only track if screen not already tracked
            final alreadyTracked = currentScreen != null && payload != null && (
              (payload.screenId != null && currentScreen.screenId == payload.screenId) ||
              (payload.screenName != null && currentScreen.screenName == payload.screenName)
            );

            if (!alreadyTracked) {
              if (kDebugMode) {
                print('✅ Tracking from renderScreen: ${payload?.screenName}');
              }
              _trackScreenWithEnhancement();
            }
          }
        }
      });
    } else {
      if (kDebugMode) {
        print('⏭️ Skipping tracking - PageGroupModel container (tabs will track themselves)');
      }
    }

    //here add the js code
    //widget.appProvider.definitionProvider.getAppBundle().
    // build the data context
    Map<String, dynamic>? initialMap = widget.screenPayload?.arguments;
    //we add the imported code context first before adding the arguments so in case of conflict, arguments win
    // if ( pageModel.importedCodeContext != null ) {
    //   initialMap = Map<String,dynamic>.of(pageModel.importedCodeContext!);
    //   initialMap.addAll(widget.screenPayload?.arguments ?? {});
    // }
    DataContext dataContext =
        DataContext(buildContext: context, initialMap: initialMap);
    //theme will get applied if one exists

    if (pageModel is HasStyles) {
      (pageModel as HasStyles).runtimeStyles = EnsembleThemeManager()
          .getRuntimeStyles(dataContext, pageModel as HasStyles);
    }

    // add all the API names to our context as Invokable, even though their result
    // will be null. This is so we can always reference it API responses come back
    pageModel.apiMap?.forEach((key, value) {
      // have to be careful here. API response on page load may exists,
      // don't overwrite if that is the case
      if (!dataContext.hasContext(key)) {
        dataContext.addInvokableContext(key, APIResponse());
      }
    });

    return PageInitializer(
      pageModel: pageModel,
      dataContext: dataContext,
      screenPayload: _enhancedPayload ?? widget.screenPayload,
    );
  }

  /// Track screen with enhancement for missing identifiers - called during initial tracking
  void _trackScreenWithEnhancement() {
    var payload = widget.screenPayload;

    // If payload is null, try to create one for the home screen
    if (payload == null) {
      final homeScreenName = _findScreenNameFromDefinitionProvider();
      if (homeScreenName != null) {
        if (kDebugMode) {
          print('✅ Creating payload for home screen: $homeScreenName');
        }
        payload = ScreenPayload(
          screenName: homeScreenName,
          screenId: homeScreenName,
        );
      } else {
        if (kDebugMode) {
          print('❌ Could not determine screen name for tracking (payload is null)');
        }
        return;
      }
    }

    // Try to enhance the payload before tracking
    final enhancedPayload = _createEnhancedPayload(payload);
    _enhancedPayload = enhancedPayload;
    ScreenTracker().trackScreenFromPayload(enhancedPayload);
  }

  /// Create an enhanced payload with proper screen identifiers when missing
  ScreenPayload _createEnhancedPayload(ScreenPayload originalPayload) {
    // If we already have both identifiers populated, return original payload
    final hasCompleteIdentifiers = (originalPayload.screenId?.isNotEmpty == true) &&
                                     (originalPayload.screenName?.isNotEmpty == true);
    if (hasCompleteIdentifiers) {
      return originalPayload;
    }

    // Try to find the actual screen name from provider mappings
    final actualScreenName = _findScreenNameFromDefinitionProvider();

    if (actualScreenName != null) {
      if (kDebugMode) {
        print('✅ Enhanced external integration with actual screen name: $actualScreenName');
      }

      // Create new payload with enhanced identifiers
      return ScreenPayload(
        screenId: originalPayload.screenId ?? actualScreenName,
        screenName: actualScreenName,
        pageType: originalPayload.pageType,
        arguments: originalPayload.arguments,
        isExternal: originalPayload.isExternal,
      );
    }

    // No enhancement possible, return original payload
    return originalPayload;
  }


  /// Try to find the actual screen name by checking how this screen was loaded
  String? _findScreenNameFromDefinitionProvider() {
    try {
      final provider = widget.appProvider.definitionProvider;
      if (provider is! EnsembleDefinitionProvider) return null; // Only EnsembleDefinitionProvider has access to screenNameMappings
      final appModel = provider.appModel;
      final payload = widget.screenPayload;

      // If we have no identifiers at all, check if this is the home screen
      if (payload?.screenId == null && payload?.screenName == null) {
        final homeScreenName = provider.getHomeScreenName();
        if (homeScreenName != null) return homeScreenName;
      }

      // Try to reverse-lookup the screen name from mappings using screenId
      if (payload?.screenId != null) {
        final foundName = appModel.screenNameMappings.entries
            .where((entry) => entry.value == payload!.screenId)
            .map((entry) => entry.key)
            .firstOrNull;
        if (foundName != null) return foundName;
      }

      // If we have a screenName, validate it exists in mappings and return it
      if (payload?.screenName != null) {
        final screenName = payload!.screenName!;
        if (appModel.screenNameMappings.containsKey(screenName)) {
          return screenName; // Confirmed it exists in mappings
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error accessing definition provider for screen name lookup: $e');
      }
      return null;
    }
  }
}

class PageInitializer extends StatefulWidget {
  const PageInitializer({
    super.key,
    required this.pageModel,
    required this.dataContext,
    required this.screenPayload,
  });

  final PageModel pageModel;
  final DataContext dataContext;
  final ScreenPayload? screenPayload;

  @override
  State<PageInitializer> createState() => _PageInitializerState();
}

class _PageInitializerState extends State<PageInitializer>
    with WidgetsBindingObserver {

  late StreamSubscription _screenRefreshSubscription;
  late StreamSubscription _resourceRefreshSubscription;
  // Key used for PageGroup/Page widgets to maintain state across refreshes
  final Key _widgetKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Listen for screen refresh events
    _screenRefreshSubscription = AppEventBus().eventBus.on<ScreenRefreshEvent>().listen((event) {
      _handleScreenRefresh(event);
    });

    // Listen for resource refresh events (resources, theme, config, etc.)
    _resourceRefreshSubscription = AppEventBus().eventBus.on<ResourceRefreshEvent>().listen((event) {
      _handleResourceRefresh(event);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      executeCallbacks();
    });
  }

  void _handleScreenRefresh(ScreenRefreshEvent event) {
    if (!mounted) return;

    // Check if this screen matches the updated artifact
    String? myScreenId = widget.screenPayload?.screenId;
    String? myScreenName = widget.screenPayload?.screenName;

    bool shouldRefresh = false;
    String? matchReason;

    if (myScreenId != null && myScreenId == event.screenId) {
      shouldRefresh = true;
      matchReason = 'Screen ID: $myScreenId';
    } else if (myScreenName != null && myScreenName == event.screenName) {
      shouldRefresh = true;
      matchReason = 'Screen Name: $myScreenName';
    } else if (widget.pageModel is PageGroupModel) {
      // For ViewGroup screens, also refresh if any child screen is updated
      shouldRefresh = true;
      matchReason = 'ViewGroup container - child screen updated: ${event.screenName}';
    }

    if (shouldRefresh) {
      if (kDebugMode) {
        print('🔄 Screen refresh triggered for: $matchReason');
      }
      _refreshParentScreen();
    } else {
      if (kDebugMode) {
        print('⏭️ Ignoring refresh - not for this screen (my: $myScreenId/$myScreenName, event: ${event.screenId}/${event.screenName})');
      }
    }
  }

  void _handleResourceRefresh(ResourceRefreshEvent event) {
    if (!mounted) return;

    // Resource refresh events affect ALL screens since resources are global
    if (kDebugMode) {
      print('🔄 Resource refresh triggered for artifact: ${event.artifactId} (type: ${event.artifactType}) clearCaches: ${event.clearCaches}');
    }
    // Clear resource caches if requested to force re-parsing
    if (event.clearCaches) {
      Ensemble().getConfig()?.clearResourceCaches();
      // Also refresh AppBundle to get fresh resources from artifact cache
      Ensemble().getConfig()?.refreshAppBundleResources();
    }
    // For resources, always refresh since they affect all screens
    _refreshParentScreen();
  }

  void _refreshParentScreen() {
    // Find the Screen widget ancestor and trigger its refresh
    // This updates the Screen's _contentKey and screenRequester which forces a complete rebuild
    // of the entire widget tree (FutureBuilder → PageInitializer → PageGroup/Page)
    final screenState = context.findAncestorStateOfType<_ScreenState>();
    if (screenState != null) {
      screenState._refreshScreen();
    } else {
      if (kDebugMode) {
        print('⚠️ Could not find parent Screen to refresh');
      }
    }
  }



  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      executeCallbacks();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _screenRefreshSubscription.cancel();
    _resourceRefreshSubscription.cancel();
    super.dispose();
  }

  Future<void> executeCallbacks() async {
    final callbacks = List.from(Ensemble().getCallbacksAfterInitialization());

    callbacks.asMap().forEach((index, function) async {
      // Removing a method and getting the function with index to execute it
      Ensemble().getCallbacksAfterInitialization().remove(function);
      try {
        await Function.apply(function, null);
      } catch (e) {
        print('Failed to execute a method: $e');
      }
    });
  }

  Future<void> executePushNotificationCallbacks() async {
    final callbacks = List.from(Ensemble().getPushNotificationCallbacks());

    callbacks.asMap().forEach((index, function) async {
      // Removing a method and getting the function with index to execute it
      Ensemble().getPushNotificationCallbacks().remove(function);
      try {
        await Function.apply(function, null);
      } catch (e) {
        print('Failed to execute a method: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pageModel is PageGroupModel && widget.pageModel.menu != null) {
      final pageModel = widget.pageModel as PageGroupModel;

      return PageGroup(
          key: _widgetKey,
          pageArgs: widget.screenPayload?.arguments,
          initialDataContext: widget.dataContext,
          model: pageModel,
          menu: pageModel.menu!);
    } else if (widget.pageModel is SinglePageModel) {
      final pageModel = widget.pageModel as SinglePageModel;

      // overwrite the pageType as modal only if specified in the payload
      if (widget.screenPayload?.pageType == PageType.modal) {
        if (pageModel.screenOptions != null) {
          pageModel.screenOptions!.pageType = widget.screenPayload!.pageType!;
        } else {
          pageModel.screenOptions =
              ScreenOptions(pageType: widget.screenPayload!.pageType!);
        }
      }
      return ensemble.Page(
          key: _widgetKey,
          dataContext: widget.dataContext,
          pageModel: pageModel,

          // on terminated state, we want push notification's screen to load AFTER
          // the landing screen has finished its onLoad, which may have logic to
          // redirect to other pages. Without this, the notification's screen
          // may load in between, causing the back button to malfunction
          onRendered: () => executePushNotificationCallbacks());
    }

    throw LanguageError("Invalid Screen Definition");
  }
}

class ScreenDefinition {
  ScreenDefinition(this._content);

  final YamlMap _content;

  PageModel getModel(Map<String, dynamic>? inputParams) {
    YamlMap output = _content;

    /// manipulate the screen definition to account for custom widget
    if ((_content.keys.length == 1 && _content['Widget'] != null) ||
        (_content.keys.length == 2 &&
            _content.containsKey(PageModel.importToken) &&
            _content.containsKey('Widget'))) {
      output = _getWidgetAsScreen(_content, inputParams);
    }

    return PageModel.fromYaml(output);
  }

  /// wrap a widget so it can be displayed as if it's an actual Screen
  /// the widgetContent is the full yaml map that contains Widget and optional Import as keys.
  YamlMap _getWidgetAsScreen(
      YamlMap widgetYaml, Map<String, dynamic>? inputParams) {
    YamlList? imports = widgetYaml[PageModel.importToken] as YamlList?;
    YamlMap widgetContent = widgetYaml['Widget'] as YamlMap;

    /// build the input map if specified
    Map<String, dynamic>? inputMap;
    if (widgetContent['inputs'] is List) {
      for (var key in (widgetContent['inputs'] as List)) {
        if (inputParams != null && inputParams.containsKey(key)) {
          (inputMap ??= {})[key] = '\${$key}';
        }
      }
    }

    // use random name so we don't accidentally collide with other names
    String randomWidgetName = "Widget${Random().nextInt(100)}";

    Map widgetContentMap = {
      'View': {
        'styles': {'useSafeArea': true},
        'body': {
          randomWidgetName: inputMap == null ? null : {'inputs': inputMap}
        }
      },
      randomWidgetName: widgetContent
    };
    if (imports != null) {
      widgetContentMap[PageModel.importToken] = imports;
    }
    return YamlMap.wrap(widgetContentMap);
  }
}

class ExternalScreen extends StatelessWidget {
  const ExternalScreen({super.key, this.screen});

  final Widget? screen;

  @override
  Widget build(BuildContext context) {
    return screen ??
        Scaffold(
          body: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 32.0, vertical: 64.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.arrow_back_ios)),
                const SizedBox(height: 32),
                const Text(
                  'External Screen',
                  style: TextStyle(fontSize: 24),
                ),
                const SizedBox(height: 24),
                const Text(
                    'Currently studio preview doesn\'t supports external screen.'),
                const SizedBox(height: 24),
                const Text(
                    'If you are seeing screen on native device please make sure you have passed valid screenName and given screenbuilder for corresponding screenName.'),
                const SizedBox(height: 24),
                const Text('For more information check the following docs'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    launchUrl(Uri.parse('https://docs.ensembleui.com/#/'));
                  },
                  child: const Text('Ensemble docs'),
                ),
              ],
            ),
          ),
        );
  }
}
