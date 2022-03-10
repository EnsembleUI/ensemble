import 'dart:async';
import 'dart:developer';

import 'package:ensemble/provider.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/http_utils.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/layout/ensemble_page_route.dart';
import 'package:yaml/yaml.dart';

class Ensemble {
  static final Ensemble _instance = Ensemble._internal();
  Ensemble._internal();
  factory Ensemble() {
    return _instance;
  }

  bool init = false;
  bool? useRemoteDefinition;
  String? localPath;
  String? remoteApiKey;

  /// initialize Ensemble configurations. This will be called
  /// automatically upon first page load. However call it in your existing
  /// code will enable faster load for the initial page.
  Future<void> initialize(BuildContext context) async {
    if (!init) {
      init = true;
      try {
        final yamlString = await DefaultAssetBundle.of(context)
            .loadString('ensemble-config.yaml');
        final YamlMap yamlMap = loadYaml(yamlString);

        String? definitionType = yamlMap['definitions']?['from'];
        if (definitionType == null) {
          throw ConfigError(
              "Definitions needed to be defined as local or remote");
        }
        if (definitionType == 'local') {
          String? path = yamlMap['definitions']?['local']?['path'];
          if (path == null) {
            throw ConfigError(
                "Path to page definitions is required for Local definitions");
          }
          useRemoteDefinition = false;
          localPath = path;
        } else {
          String? myApiKey = yamlMap['definitions']?['remote']?['apiKey'];
          if (myApiKey == null) {
            throw ConfigError("apiKey is required for Remote definitions");
          }
          useRemoteDefinition = true;
          remoteApiKey = myApiKey;
        }
      } catch (error) {
        log("Error loading ensemble-config.yaml.\n$error");
      }
    }
  }

  /// return an Ensemble page as an embeddable Widget
  FutureBuilder getPage(
      BuildContext context,
      String pageName, {
        Map<String, dynamic>? pageArgs
      }) {
    return FutureBuilder(
        future: getPageDefinition(context, pageName),
        builder: (context, AsyncSnapshot snapshot) {
          // loading
          if (!snapshot.hasData) {
            return const Scaffold(
                body: Center(
                    child: CircularProgressIndicator()
                )
            );
          }
          // load page
          if (snapshot.data['View'] != null) {
            // fetch data remotely before loading page
            String? apiName = snapshot.data['Action']?['pageload']?['api'];
            if (apiName != null) {
              return FutureBuilder(
                  future: HttpUtils.invokeApi(
                      snapshot.data['API'][apiName], dataMap: pageArgs),
                  builder: (context, AsyncSnapshot apiSnapshot) {
                    if (!apiSnapshot.hasData) {
                      return const Scaffold(
                          body: Center(
                              child: CircularProgressIndicator()
                          )
                      );
                    } else if (apiSnapshot.hasError) {
                      return const Scaffold(
                          body: Center(
                              child: Text(
                                  "Unable to retrieve data. Please check your API definition.")
                          )
                      );
                    }
                    // merge API data with page arguments, then load
                    pageArgs ??= {};
                    pageArgs?[snapshot.data['Action']?['pageload']?['api']] =
                        apiSnapshot.data;

                    // itemTemplate listens for data changes, but the page has not been loaded yet,
                    // so we will dispatch the data changes AFTER screen rendering
                    WidgetsBinding.instance!.addPostFrameCallback((_) =>
                        ScreenController().onActionResponse(
                            context,
                            snapshot.data['Action']?['pageload']?['api'],
                            apiSnapshot.data));

                    return _renderPage(
                        context, pageName, snapshot, args: pageArgs);
                  }
              );
            } else {
              return _renderPage(context, pageName, snapshot, args: pageArgs);
            }
          }
          // else error
          return Scaffold(
              body: Center(
                  child: Text('Error loading reference page $pageName')
              )
          );
        }
    );
  }

  /// Navigate to an Ensemble-powered page
  void navigateToPage(
      BuildContext context,
      String pageName,
      {
        bool replace = false,
        Map<String, dynamic>? pageArgs,
      }) {

    MaterialPageRoute pageRoute = getPageRoute(pageName, pageArgs: pageArgs);
    if (replace) {
      Navigator.pushReplacement(context, pageRoute);
    } else {
      Navigator.push(context, pageRoute);
    }

  }


  /// return an Ensemble page's PageRoute, suitable to be embedded as a PageRoute
  MaterialPageRoute getPageRoute(
      String pageName,
      {
        Map<String, dynamic>? pageArgs
      }) {
    return EnsemblePageRoute(
        builder: (context) => getPage(context, pageName, pageArgs: pageArgs)
    );
  }


  /// get Page Definition from local or remote
  @protected
  Future<YamlMap> getPageDefinition(BuildContext context, String pageName) async {
    if (!init) {
      await initialize(context);
    }
    return
      useRemoteDefinition! ?
      RemoteDefinitionProvider(pageName, remoteApiKey!).getDefinition() :
      LocalDefinitionProvider(pageName, localPath!).getDefinition();
  }


  Widget _renderPage(
      BuildContext context,
      String pageName,
      AsyncSnapshot<dynamic> snapshot,
      {
        bool replace=false,
        Map<String, dynamic>? args
      }) {
    log ("Screen Arguments: " + args.toString());
    return ScreenController().renderPage(context, pageName, snapshot.data, args: args);
  }

}