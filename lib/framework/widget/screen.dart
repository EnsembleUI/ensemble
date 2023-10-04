import 'dart:math';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/theme/theme_loader.dart';
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

    // build the data context
    DataContext dataContext = DataContext(
        buildContext: context, initialMap: widget.screenPayload?.arguments);

    // add all the API names to our context as Invokable, even though their result
    // will be null. This is so we can always reference it API responses come back
    pageModel.apiMap?.forEach((key, value) {
      // have to be careful here. API response on page load may exists,
      // don't overwrite if that is the case
      if (!dataContext.hasContext(key)) {
        dataContext.addInvokableContext(key, APIResponse());
      }
    });

    if (pageModel is PageGroupModel && pageModel.menu != null) {
      return PageGroup(
          pageArgs: widget.screenPayload?.arguments,
          initialDataContext: dataContext,
          model: pageModel,
          menu: pageModel.menu!);
    } else if (pageModel is SinglePageModel) {
      // overwrite the pageType as modal only if specified in the payload
      if (widget.screenPayload?.pageType == PageType.modal) {
        if (pageModel.screenOptions != null) {
          pageModel.screenOptions!.pageType = widget.screenPayload!.pageType!;
        } else {
          pageModel.screenOptions =
              ScreenOptions(pageType: widget.screenPayload!.pageType!);
        }
      }
      return ensemble.Page(dataContext: dataContext, pageModel: pageModel);
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
    if (_content.keys.length == 1 && _content['Widget'] != null) {
      output = _getWidgetAsScreen(_content['Widget'], inputParams);
    }
    return PageModel.fromYaml(output);
  }

  /// wrap a widget so it can be displayed as if it's an actual Screen
  YamlMap _getWidgetAsScreen(
      YamlMap widgetContent, Map<String, dynamic>? inputParams) {
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

    return YamlMap.wrap({
      'View': {
        'styles': {'useSafeArea': true},
        'body': {
          randomWidgetName: inputMap == null ? null : {'inputs': inputMap}
        }
      },
      randomWidgetName: widgetContent
    });
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
