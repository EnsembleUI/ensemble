import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:flutter/cupertino.dart';

/// Ensemble action that changes the active application locale.
class SetLocaleAction extends EnsembleAction {
  /// Creates a [SetLocaleAction] action.
  SetLocaleAction({required this.languageCode, this.countryCode});

  /// Language code for the locale override.
  String languageCode;
  /// Optional country code for the locale override.
  String? countryCode;

  /// Runs this action and performs the set locale operation.
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

/// Ensemble action that clears the stored locale override.
class ClearLocaleAction extends EnsembleAction {
  /// Runs this action and performs the clear locale operation.
  @override
  Future execute(BuildContext context, ScopeManager scopeManager) {
    Ensemble().clearLocale();
    return Future.value(true);
  }
}
