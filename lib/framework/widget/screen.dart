import 'package:ensemble/ensemble.dart';
import 'package:ensemble/ensemble_theme.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/styles/style_provider.dart';
import 'package:ensemble/framework/theme/theme_loader.dart';
import 'package:ensemble/framework/view/page_group.dart';
import 'package:ensemble/framework/widget/error_screen.dart';
import 'package:ensemble/framework/view/page.dart' as ensemble;
import 'package:ensemble/page_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:yaml/yaml.dart';
import 'package:provider/provider.dart';

import '../../ensemble_app.dart';

class Screen extends StatefulWidget {
  const Screen({
    super.key,
    required this.appProvider,
    this.screenPayload,
    this.styles,
  });

  final AppProvider appProvider;
  final ScreenPayload? screenPayload;
  final YamlMap? styles;

  @override
  State<Screen> createState() => _ScreenState();
}

class _ScreenState extends State<Screen> {
  late Future<YamlMap> screenRequester;

  @override
  void initState() {
    super.initState();
    GetIt.I.registerSingleton<StyleProvider>(
        StyleProvider(stylesPayload: widget.styles));
    screenRequester =
        widget.appProvider.getDefinition(payload: widget.screenPayload);
  }

  @override
  Widget build(BuildContext context) {
    //log("Screen build() - $hashCode (${Ensemble().deviceInfo.size.width} x ${Ensemble().deviceInfo.size.height})");

    final isPreview = GetIt.I<EnsemblePreviewConfig>().isPreview;

    return FutureBuilder(
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
                body: Center(
                    child: CircularProgressIndicator(
                        color: Theme.of(context)
                            .extension<EnsembleThemeExtension>()
                            ?.loadingScreenIndicatorColor)));
          }

          if (isPreview) {
            return renderScreen(PageModel.fromYaml(snapshot.data as YamlMap));
          }
          return SelectionArea(
              child:
                  renderScreen(PageModel.fromYaml(snapshot.data as YamlMap)));
        });
  }

  Widget renderScreen(PageModel pageModel) {
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
