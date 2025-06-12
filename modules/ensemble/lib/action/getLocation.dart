import 'dart:async';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/stub/location_manager.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

class GetLocationAction extends EnsembleAction {
  GetLocationAction({
    super.initiator,
    this.onLocationReceived,
    this.onError,
    this.recurring,
    this.recurringDistanceFilter,
  });

  final EnsembleAction? onLocationReceived;
  final EnsembleAction? onError;
  final bool? recurring;
  final int? recurringDistanceFilter;

  factory GetLocationAction.fromYaml({Invokable? initiator, Map? payload}) {
    return GetLocationAction(
      initiator: initiator,
      onLocationReceived: EnsembleAction.from(payload?['onLocationReceived']),
      onError: EnsembleAction.from(payload?['onError']),
      recurring: Utils.optionalBool(payload?['options']?['recurring']),
      recurringDistanceFilter: Utils.optionalInt(
          payload?['options']?['recurringDistanceFilter'],
          min: 50),
    );
  }

  @override
  Future<void> execute(BuildContext context, ScopeManager scopeManager) async {
    if (onLocationReceived == null) {
      throw LanguageError(
          '${ActionType.getLocation.name} requires onLocationReceived callback');
    }

    try {
      final status = await GetIt.I<LocationManager>().getLocationStatus();

      if (status == LocationStatus.ready) {
        // Handle recurring location updates
        if (recurring == true) {
          StreamSubscription<LocationData> streamSubscription =
              GetIt.I<LocationManager>()
                  .getPositionStream(
                      distanceFilter: recurringDistanceFilter ?? 1000)
                  .map((position) => LocationData(
                      latitude: position.latitude,
                      longitude: position.longitude))
                  .listen((LocationData? location) {
            if (location != null) {
              // Update last known location
              Device().updateLastLocation(location);

              // Add location data to context and execute callback
              scopeManager.dataContext
                  .addDataContextById('latitude', location.latitude);
              scopeManager.dataContext
                  .addDataContextById('longitude', location.longitude);
              ScreenController().executeAction(context, onLocationReceived!);
            } else if (onError != null) {
              scopeManager.dataContext.addDataContextById('reason', 'unknown');
              ScreenController().executeAction(context, onError!);
            }
          });
          scopeManager.addLocationListener(streamSubscription);
        }
        // Handle one-time location request
        else {
          final location = await GetIt.I<LocationManager>().simplyGetLocation();
          if (location != null) {
            Device().updateLastLocation(location);
            scopeManager.dataContext
                .addDataContextById('latitude', location.latitude);
            scopeManager.dataContext
                .addDataContextById('longitude', location.longitude);
            ScreenController().executeAction(context, onLocationReceived!);
          }
        }
      } else if (onError != null) {
        scopeManager.dataContext.addDataContextById('reason', status.name);
        ScreenController().executeAction(context, onError!);
      }
    } catch (e) {
      if (onError != null) {
        scopeManager.dataContext.addDataContextById('reason', e.toString());
        ScreenController().executeAction(context, onError!);
      } else {
        rethrow;
      }
    }
  }
}
