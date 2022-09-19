import 'dart:developer';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/ensemble_theme.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/widget/error_screen.dart';
import 'package:ensemble/framework/widget/view.dart';
import 'package:ensemble/page_model.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

class Screen extends StatefulWidget {
  const Screen({
    super.key,
    required this.appProvider,
    this.screenPayload
  });

  final AppProvider appProvider;
  final ScreenPayload? screenPayload;

  @override
  State<Screen> createState() => _ScreenState();
}

class _ScreenState extends State<Screen> {
  late Future<YamlMap> screenRequester;

  @override
  void initState() {
    super.initState();
    screenRequester = widget.appProvider.getDefinition(payload: widget.screenPayload);
  }

  @override
  Widget build(BuildContext context) {
    //log("Screen build() - $hashCode (${Ensemble().deviceInfo.size.width} x ${Ensemble().deviceInfo.size.height})");
    return FutureBuilder(
      future: screenRequester,
      builder: (context, snapshot) {
        // show error
        if (snapshot.hasError) {
          return ErrorScreen(
            LanguageError(
              "I'm not able to read your page definition",
              detailError: snapshot.error.toString()
            )
          );

        }
        // show progress bar
        else if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: Theme.of(context).extension<EnsembleThemeExtension>()?.loadingScreenBackgroundColor,
            body: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).extension<EnsembleThemeExtension>()?.loadingScreenIndicatorColor
              )
            )
          );
        }

        return renderScreen(PageModel.fromYaml(snapshot.data as YamlMap));


      }
    );
  }

  Widget renderScreen(PageModel pageModel) {
    // build the data context
    DataContext dataContext = DataContext(
      buildContext: context,
      initialMap: widget.screenPayload?.arguments
    );

    // add all the API names to our context as Invokable, even though their result
    // will be null. This is so we can always reference it API responses come back
    pageModel.apiMap?.forEach((key, value) {
      // have to be careful here. API response on page load may exists,
      // don't overwrite if that is the case
      if (!dataContext.hasContext(key)) {
        dataContext.addInvokableContext(key, APIResponse());
      }
    });
    return View(dataContext: dataContext, pageModel: pageModel);
  }
}

