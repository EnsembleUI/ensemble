import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/webview/webviewstate.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/framework/action.dart' as ensemble;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:yaml/yaml.dart';

class EnsembleWebView extends StatefulWidget
    with Invokable, HasController<EnsembleWebViewController, WebViewState> {
  static const type = 'WebView';
  EnsembleWebView({Key? key}) : super(key: key);

  final EnsembleWebViewController _controller = EnsembleWebViewController();
  @override
  get controller => _controller;

  @override
  State<StatefulWidget> createState() => WebViewState();

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {"clearCookie": () => _controller.cookieMethods?.clearCookie()};
  }

  @override
  Map<String, Function> setters() {
    return {
      'headers': (value) => _controller.headers = parseYamlMap(value),
      'cookieHeader': (value) =>
          _controller.singleCookie = Utils.optionalString(value),
      'cookies': (value) => _controller.cookies = getListOfMap(value),
      'url': (value) => _controller.url = Utils.getUrl(value),
      'height': (value) => _controller.height = Utils.optionalDouble(value),
      'width': (value) => _controller.width = Utils.optionalDouble(value),
      'onPageStart': (funcDefinition) => _controller.onPageStart =
          ensemble.EnsembleAction.from(funcDefinition, initiator: this),
      'onPageFinished': (funcDefinition) => _controller.onPageFinished =
          ensemble.EnsembleAction.from(funcDefinition, initiator: this),
      'onNavigationRequest': (funcDefinition) =>
          _controller.onNavigationRequest =
              ensemble.EnsembleAction.from(funcDefinition, initiator: this),
      'onWebResourceError': (funcDefinition) => _controller.onWebResourceError =
          ensemble.EnsembleAction.from(funcDefinition, initiator: this),
      'headerOverrideRules': (value) => _controller.headerOverrideRules = 
          parseHeaderRules(value),
      // legacy
      'uri': (value) => _controller.url = Utils.getUrl(value),
      'allowedLaunchSchemes': (value) => _controller.schemes =
          Utils.getList<String>(value) ??
              EnsembleWebViewController.defaultSchemes,
    };
  }

  List<HeaderOverrideRule> parseHeaderRules(dynamic value) {
    if (value == null) return [];
    
    List<dynamic> rulesList = value is List ? value : [];
    return rulesList.map((rule) {
      Map<String, String> headers = {};
      final headersMap = rule['headers'];
      if (headersMap is Map) {
        headersMap.forEach((key, value) {
          headers[key.toString()] = value.toString();
        });
      }

      return HeaderOverrideRule(
        urlPattern: rule['urlPattern']?.toString() ?? '',
        headers: headers,
        mergeExisting: rule['mergeExisting'] ?? true,
        matchType: HeaderMatchType.values.from(rule['matchType']) ?? HeaderMatchType.CONTAINS,
      );
    }).toList();
  }
}

mixin CookieMethods on EWidgetState<EnsembleWebView> {
  void clearCookie();
  void inputCookie(String? value);
}

class EnsembleWebViewController extends WidgetController {
  // params for each URI set
  int? loadingPercent = 0;
  String? error;
  // List of default schemes to handle, this can be overwritten by an app
  static const List<String> defaultSchemes = [
    'tel:',
    'sms:',
    'mailto:',
    'geo:' //for launching maps
  ];
  List<String> schemes = defaultSchemes;
  CookieMethods? cookieMethods;
  Map<String, String> headers = {};
  InAppWebViewController? webViewController;
  late CookieManager cookieManager;
  bool isInitialized = false;
  List<HeaderOverrideRule> headerOverrideRules = [];

  ensemble.EnsembleAction? onPageStart,
      onPageFinished,
      onNavigationRequest,
      onWebResourceError;

  String? _url;
  String? get url => _url;
  set url(String? url) {
    _url = url;
    error = null;

    if (url != null) {
      try {
        WebUri? uri = WebUri(url);
        webViewController?.loadUrl(urlRequest: URLRequest(url: uri, headers: headers));
      } catch (e) {
        error = '${_url} is an Invalid URL';
      }
    }
  }

  List<Map<String, dynamic>> cookies = [];
  String? singleCookie;
  double? height;
  double? width;

  Future<void> initializeCookieManager() async {
    if (!isInitialized) {
      cookieManager = CookieManager.instance();
      isInitialized = true;
    }
  }
}

List<Map<String, dynamic>> getListOfMap(list) {
  List<Map<String, dynamic>> result = <Map<String, dynamic>>[];
  if (list is List) {
    for (var i in list) {
      Map<String, dynamic> map = Utils.getMap(i) ?? {};
      result.add(map);
    }
    return result;
  }
  return [];
}

Map<String, String> parseYamlMap(value) {
  Map<String, String> result = {};
  if (value is YamlMap) {
    YamlMap yamlMap = value;
    for (var entry in yamlMap.entries) {
      String? key = Utils.optionalString(entry.key);
      if (key != null && key.isNotEmpty) {
        result.addAll({key: Utils.getString(entry.value, fallback: "")});
      }
    }
  }
  return result;
}

enum HeaderMatchType { CONTAINS, EXACT, REGEX }
class HeaderOverrideRule {
  final String urlPattern;
  final Map<String, String> headers;
  final bool mergeExisting;
  final HeaderMatchType matchType;

  HeaderOverrideRule({
    required this.urlPattern,
    required this.headers,
    this.mergeExisting = true,
    this.matchType = HeaderMatchType.CONTAINS,
  });

  Map<String, dynamic> toJson() => {
    'urlPattern': urlPattern,
    'headers': headers,
    'mergeExisting': mergeExisting,
    'matchType': matchType.toString(),
  };
}
