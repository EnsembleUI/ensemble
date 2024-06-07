import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:flutter/cupertino.dart';

// Set the locale at runtime
class SetLocaleAction extends EnsembleAction {
  SetLocaleAction({required this.languageCode, this.countryCode});

  String languageCode;
  String? countryCode;

  @override
  Future execute(BuildContext context, ScopeManager scopeManager) {
    var realLanguageCode = scopeManager.dataContext.eval(languageCode);
    if (realLanguageCode is! String || realLanguageCode.length != 2) {
      throw LanguageError("Language Code must be exactly two characters.");
    }

    var realCountryCode = scopeManager.dataContext.eval(countryCode);
    if (realCountryCode != null && realCountryCode.toString().length != 2) {
      throw LanguageError(
          "Country Code if specified must be exactly two characters.");
    }

    Ensemble().setLocale(Locale(realLanguageCode, realCountryCode));
    return Future.value(true);
  }
}

// Clear the runtime locale if applicable
class ClearLocaleAction extends EnsembleAction {
  @override
  Future execute(BuildContext context, ScopeManager scopeManager) {
    Ensemble().clearLocale();
    return Future.value(true);
  }
}
