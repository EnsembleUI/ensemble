import 'dart:async';
import 'dart:math';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/theme/theme_loader.dart';
import 'package:ensemble/framework/theme_manager.dart';
import 'package:ensemble/framework/view/page_group.dart';
import 'package:ensemble/framework/widget/error_screen.dart';
import 'package:ensemble/framework/view/page.dart' as ensemble;
import 'package:ensemble/page_model.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yaml/yaml.dart';

class Screen extends StatefulWidget {
  const Screen({super.key, required this.appProvider, this.screenPayload});

  final AppProvider appProvider;
  final ScreenPayload? screenPayload;

  @override
  State<Screen> createState() => _ScreenState();
}

class _ScreenState extends State<Screen> {
  late Future<ScreenDefinition> screenRequester;
  Widget? externalScreen;

  @override
  void initState() {
    super.initState();
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
            future: screenRequester,
            builder: (context, snapshot) {
              // show error
              if (snapshot.hasError) {
                return ErrorScreen(LanguageError(
                    "I'm not able to read your page definition",
                    detailError: snapshot.error.toString()));
              }
              // show progress bar
              else if (!snapshot.hasData) {
                return Scaffold(
                    backgroundColor: Theme.of(context)
                        .extension<EnsembleThemeExtension>()
                        ?.loadingScreenBackgroundColor,
                    resizeToAvoidBottomInset: false,
                    body: Center(
                        child: CircularProgressIndicator(
                            color: Theme.of(context)
                                .extension<EnsembleThemeExtension>()
                                ?.loadingScreenIndicatorColor)));
              }
              return renderScreen(snapshot.data!);
            });
  }

  Widget renderScreen(ScreenDefinition screenDefinition) {
    PageModel pageModel =
        screenDefinition.getModel(widget.screenPayload?.arguments);
    //theme will get applied if one exists
    if (pageModel is SupportsThemes) {
      EnsembleThemeManager().applyTheme(context, pageModel as SupportsThemes,
          (pageModel as SupportsThemes).getStyles());
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
      screenPayload: widget.screenPayload,
    );
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      executeCallbacks();
    });
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
