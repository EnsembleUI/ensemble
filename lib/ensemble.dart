import 'dart:async';
import 'dart:developer';

import 'package:ensemble/ensemble_theme.dart';
import 'package:ensemble/error_handling.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/widget/view.dart';
import 'package:ensemble/provider.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/http_utils.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/layout/ensemble_page_route.dart';
import 'package:flutter/services.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:yaml/yaml.dart';

class I18nProps {
  String defaultLocale;
  String fallbackLocale;
  bool useCountryCode;
  late String path;
  I18nProps(this.defaultLocale,this.fallbackLocale,this.useCountryCode);

}
class Ensemble {
  static final Ensemble _instance = Ensemble._internal();
  Ensemble._internal();
  factory Ensemble() {
    return _instance;
  }

  DefinitionProvider? definitionProvider;
  AppBundle? _appBundle;

  /// init Ensemble from the config file
  Future<bool> initialize() async {
    if ( definitionProvider != null ) {
      return true;
    }
    try {
      final yamlString = await rootBundle.loadString('ensemble/ensemble-config.yaml');
      final YamlMap yamlMap = loadYaml(yamlString);
      I18nProps i18nProps = I18nProps(
          yamlMap['definitions']?['i18n']?['defaultLocale']??'',
          yamlMap['definitions']?['i18n']?['fallbackLocale']??'en',
          yamlMap['definitions']?['i18n']?['useCountryCode']??false
      );
      String? definitionType = yamlMap['definitions']?['from'];
      if (definitionType == 'ensemble') {
        String? path = yamlMap['definitions']?['ensemble']?['path'];
        if (path == null || !path.startsWith('https')) {
          throw ConfigError(
            'Invalid URL to Ensemble server. The original value should not be changed');
        }
        String? appId = yamlMap['definitions']?['ensemble']?['appId'];
        if (appId == null) {
          throw ConfigError(
              "appId is required. Your App Key can be found on "
              "Ensemble Studio under each application");
        }
        String? i18nPath = yamlMap['definitions']?['ensemble']?['i18nPath'];
        if (i18nPath == null) {
          throw ConfigError(
              "i18nPath is required. If you don't have any changes, just leave the default as-is.");
        }
        i18nProps.path = i18nPath;
        definitionProvider = EnsembleDefinitionProvider(path, appId, i18nProps);

      } else if (definitionType == 'local' || definitionType == 'remote'){
        String? path = yamlMap['definitions']?[definitionType]?['path'];
        if (path == null) {
          throw ConfigError(
              "Path to the root definition directory is required.");
        }
        String? appId = yamlMap['definitions']?[definitionType]?['appId'];
        if (appId == null) {
          throw ConfigError(
              "appId is required. This is your App's directory under the root path.");
        }
        String? appHome = yamlMap['definitions']?[definitionType]?['appHome'];
        if (appHome == null) {
          throw ConfigError(
              "appHome is required. This is the home screen's name or ID for your App"
          );
        }
        String? i18nPath = yamlMap['definitions']?[definitionType]?['i18nPath'];
        if (i18nPath == null) {
          throw ConfigError(
              "i18nPath is required. If you don't have any changes, just leave the default as-is.");
        }
        i18nProps.path = i18nPath;
        String fullPath = concatDirectory(path, appId);
        definitionProvider = definitionType == 'local' ?
          LocalDefinitionProvider(fullPath, appHome, i18nProps) :
            RemoteDefinitionProvider(fullPath, appHome, i18nProps);

      } else {
          throw ConfigError(
              "Definitions needed to be defined as 'local', 'remote', or 'ensemble'");
      }
    } catch (error) {
      log("Error loading ensemble-config.yaml.\n$error");
      rethrow;
    }
    // initialize our App Bundle (theme, translation, ...)
    await initAppBundle();
    return definitionProvider != null;
  }

  /// initialize Ensemble with params (no config file)
  Future initializeWithParams(DefinitionProvider provider) async {
    definitionProvider = provider;
    await initAppBundle();
    return;
  }


  /// initialize our App Bundle (theme, translations, ...)
  Future initAppBundle() async {
    if (definitionProvider != null) {
      _appBundle = await definitionProvider!.getAppBundle();
    }
  }
  /// pass custom Theme overrides and return the App Theme
  ThemeData getAppTheme() {
    return EnsembleTheme.getAppTheme(_appBundle?.theme);
  }

  /// fetch the page definition
  Future<YamlMap> getPageDefinition(BuildContext context, String? screenId) async {
    if (definitionProvider == null) {
      await initialize();
    }
    return definitionProvider!.getDefinition(screenId: screenId);
  }

  /// process the page definition into a Widget
  Widget processPageDefinition(
      BuildContext context,
      AsyncSnapshot snapshot,
      {
        Map<String, dynamic>? pageArgs
      }) {

    if (snapshot.hasError) {
      return Scaffold(
          body: Center(
              child: Text(snapshot.error!.toString())
          )
      );
    } else if (!snapshot.hasData) {
      return const Scaffold(
          body: Center(
              child: CircularProgressIndicator()
          )
      );
    }

    // init our context with the Page arguments
    DataContext dataContext = DataContext(buildContext: context, initialMap: pageArgs);

    // load page
    if (snapshot.data['View'] != null) {
      // first create the API Map
      Map<String, YamlMap> apiMap = {};
      if (snapshot.data['API'] is YamlMap) {
        snapshot.data['API'].forEach((key, value) {
          apiMap[key] = value;
        });
      }

      // fetch data remotely before loading page
      EnsembleAction? action = Utils.getAction(snapshot.data['Action']?['onPageLoad']);
      if (action is InvokeAPIAction && apiMap[action.apiName] is YamlMap) {
        YamlMap apiPayload = apiMap[action.apiName]!;

        // evaluate input arguments and add them to context
        if (apiPayload['inputs'] is YamlList && action.inputs != null) {
          for (var input in apiPayload['inputs']) {
            if (action.inputs![input] != null) {
              dataContext.addDataContextById(
                  input, dataContext.eval(action.inputs![input]));
            }
          }
        }



        return FutureBuilder(
            future: HttpUtils.invokeApi(apiPayload, dataContext),
            builder: (context, AsyncSnapshot apiSnapshot) {
              if (!apiSnapshot.hasData) {
                return const Scaffold(
                    body: Center(
                        child: CircularProgressIndicator()
                    )
                );
              } else if (apiSnapshot.hasError) {
                ScreenController().processAPIError(dataContext, apiPayload, apiSnapshot.error, apiMap, null);
                return const Scaffold(
                    body: Center(
                        child: Text(
                            "Unable to retrieve data. Please check your API definition.")
                    )
                );
              }

              Response response = Response(apiSnapshot.data);

              // Since our widgets have not been rendered yet, simply update our
              // data context with API result (no need to dispatch any event)
              dataContext.addInvokableContext(action.apiName, APIResponse(response: response));

              // render the page
              View page = _renderPage(context, dataContext, snapshot);

              // once page has been rendered, run the onResponse code block of the API
              EnsembleAction? onResponseAction = Utils.getAction(apiPayload['onResponse']);
              if (onResponseAction is InvokeAPIAction) {
                ScreenController().processAPIResponse(
                    dataContext, onResponseAction, response, apiMap, null);

              }

              // now run the onResponse block of onPageLoad. Note that here we may want to reference
              // the widgets, so we have to wait until the page has rendered before executing
              if (action.onResponse != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  // once the page rendered, we use the dataContext from the page.
                  DataContext pageDataContext = page.rootScopeManager.dataContext;
                  ScreenController().processAPIResponse(
                      pageDataContext, action.onResponse!, response, apiMap, page.rootScopeManager);

                });
              }

              return page;
            }
        );
      } else {
        return _renderPage(context, dataContext, snapshot);
      }
    }
    // else error
    return const Scaffold(
        body: Center(
            child: Text('Error loading page. Invalid definition')
        )
    );
  }

  /// Navigate to another screen
  /// [screenName] - navigate to screen if specified, otherwise to appHome
  void navigateApp(BuildContext context, {
    String? screenName,
    bool replace = false,
    Map<String, dynamic>? pageArgs,
  }) {
    MaterialPageRoute pageRoute = getAppRoute(screenName: screenName, pageArgs: pageArgs);
    if (replace) {
      Navigator.pushReplacement(context, pageRoute);
    } else {
      Navigator.push(context, pageRoute);
    }
  }


  /// return Ensemble App's PageRoute, suitable to be embedded as a PageRoute
  /// [screenName] optional screen name or id to navigate to. Otherwise use the appHome
  MaterialPageRoute getAppRoute({
    String? screenName,
    Map<String, dynamic>? pageArgs
  }) {
    return EnsemblePageRoute(
        builder: (context) => FutureBuilder(
            future: getPageDefinition(context, screenName),
            builder: (context, AsyncSnapshot snapshot) =>
                processPageDefinition(context, snapshot, pageArgs: pageArgs))
    );
  }

  View _renderPage(
      BuildContext context,
      DataContext dataContext,
      AsyncSnapshot<dynamic> snapshot,
      {
        bool replace=false
      }) {
    //log ("Screen Arguments: " + args.toString());
    return ScreenController().renderPage(dataContext, snapshot.data);
  }


  /// concat into the format root/folder/
  @visibleForTesting
  String concatDirectory(String root, String folder) {
    // strip out all slashes
    RegExp slashPattern = RegExp(r'^[\/]?(.+?)[\/]?$');

    return slashPattern.firstMatch(root)!.group(1)! + '/' +
        slashPattern.firstMatch(folder)!.group(1)! + '/';
  }


}


class AppBundle {
  AppBundle({this.theme});

  YamlMap? theme;
}