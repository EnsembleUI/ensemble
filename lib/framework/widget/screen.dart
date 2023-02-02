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
          return _appPlaceholderWrapper(
              loadingBackgroundColor:
              const Color(0XFF000000).withOpacity(0.9),
              widget: AlertDialog(
                backgroundColor: const Color(0xff011A23),
                actions: [
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      child: const Text(
                        "OK",
                        style: TextStyle(
                          color: Color(0xff059ACD),
                        ),
                      ))
                ],
                title: const Text(
                  "Invalid App ",
                  style: TextStyle(
                    color: Color(0xffFFFFFF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                content: const Text(
                    "Make sure you are entering an app Id provided by Ensemble studio.",
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: Color(0xffFFFFFF),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    )),
              ));

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

    // overwrite the pageType as modal only if specified in the payload
    if (widget.screenPayload?.pageType == PageType.modal) {
      if (pageModel.screenOptions != null) {
        pageModel.screenOptions!.pageType = widget.screenPayload!.pageType!;
      } else {
        pageModel.screenOptions =
            ScreenOptions(pageType: widget.screenPayload!.pageType!);
      }
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
    return View(dataContext: dataContext, pageModel: pageModel);
  }
  Widget _appPlaceholderWrapper(
      {Widget? widget, Color? loadingBackgroundColor}) {
    return MaterialApp(
        home: Scaffold(backgroundColor: loadingBackgroundColor, body: widget));
  }
}

