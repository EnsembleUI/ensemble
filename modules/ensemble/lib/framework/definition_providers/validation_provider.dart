import 'dart:ui';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/definition_providers/provider.dart';
import 'package:ensemble/framework/widget/screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_i18n/flutter_i18n_delegate.dart';
import 'package:form_validator/form_validator.dart';
import 'package:yaml/yaml.dart';

/**
 * This definition is used to validate an EDL. It simply uses the content passed
 * in as the screen definition.
 */
class ValidationProvider extends DefinitionProvider {
  ValidationProvider(String contentStr) : this.content = loadYaml(contentStr);
  final YamlMap content;

  @override
  Future<AppBundle> getAppBundle({bool? bypassCache = false}) =>
      Future.value(AppBundle());

  @override
  UserAppConfig? getAppConfig() => null;

  @override
  Future<ScreenDefinition> getDefinition(
      {String? screenId, String? screenName}) {
    // debugPrint("returning definition $content");
    return Future.value(ScreenDefinition(content));
  }

  @override
  FlutterI18nDelegate? getI18NDelegate({Locale? forcedLocale}) => null;

  @override
  Map<String, String> getSecrets() => {};

  @override
  List<String> getSupportedLanguages() => [];
}