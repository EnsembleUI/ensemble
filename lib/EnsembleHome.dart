import 'package:ensemble/ensemble.dart';
import 'package:ensemble/provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:yaml/yaml.dart';

class EnsembleHome extends StatefulWidget {
  const EnsembleHome(this.config, {
    this.initialPage,
    this.pageArgs,
    Key? key
  }) : super(key: key);

  final DefinitionProvider config;
  final String? initialPage;
  final Map<String, dynamic>? pageArgs;

  @override
  State<StatefulWidget> createState() => HomeState();

}

class HomeState extends State<EnsembleHome> {
  late Future<YamlMap> initialPageDefinition;

  @override
  void initState() {
    if (widget.initialPage == null && widget.config is! EnsembleDefinitionProvider) {
        throw ConfigError("Please enter an initial page");
    }
    initialPageDefinition = widget.config.getDefinition(widget.initialPage ?? Ensemble.ensembleRootPagePlaceholder);

    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: initialPageDefinition,
      builder: (context, AsyncSnapshot snapshot) => Ensemble().processPageDefinition(
          context,
          snapshot,
          widget.initialPage ?? Ensemble.ensembleRootPagePlaceholder,
          pageArgs: widget.pageArgs
      )
    );
  }


}
