import 'dart:async';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/stub/activity_manager.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

class GetMotionDataAction extends EnsembleAction {
  GetMotionDataAction({
    super.initiator,
    this.id,
    this.onDataReceived,
    this.onError,
    this.recurring = true,
    this.sensors,
    this.updateInterval,
  });

  final String? id;
  final EnsembleAction? onDataReceived;
  final EnsembleAction? onError;
  final bool? recurring;
  final List<MotionSensorType>? sensors;
  final int? updateInterval; // in milliseconds

  factory GetMotionDataAction.fromYaml({
    Invokable? initiator,
    Map? payload,
  }) {
    List<MotionSensorType>? sensors;

    final rawSensors = payload?['options']?['sensors'];
    if (rawSensors is List) {
      sensors = rawSensors
          .map((e) => MotionSensorType.values.firstWhere(
                (v) => v.name == e.toString().toLowerCase(),
                orElse: () => throw LanguageError(
                  'Invalid sensor type: $e',
                ),
              ))
          .toList();
    }

    return GetMotionDataAction(
      initiator: initiator,
      id: Utils.optionalString(payload?['id']),
      onDataReceived:
          EnsembleAction.from(payload?['options']?['onDataReceived']),
      onError: EnsembleAction.from(payload?['options']?['onError']),
      recurring:
          Utils.getBool(payload?['options']?['recurring'], fallback: true),
      sensors: sensors,
      updateInterval: Utils.optionalInt(
        payload?['options']?['updateInterval'],
      ),
    );
  }

  @override
  Future<void> execute(
    BuildContext context,
    ScopeManager scopeManager,
  ) async {
    if (onDataReceived == null) {
      throw LanguageError(
        '${ActionType.getMotionData.name} requires onDataReceived callback',
      );
    }

    try {
      if (recurring == true) {
        final subscription = GetIt.I<ActivityManager>()
            .startMotionStream(
          sensors: sensors,
          updateInterval: updateInterval != null
              ? Duration(milliseconds: updateInterval!)
              : null,
        )
            .listen(
          (MotionData data) {
            ScreenController().executeActionWithScope(
              context,
              scopeManager,
              onDataReceived!,
              event: EnsembleEvent(
                initiator,
                data: data.toJson(),
              ),
            );
          },
          onError: (error) {
            if (onError != null) {
              ScreenController().executeActionWithScope(
                context,
                scopeManager,
                onError!,
                event: EnsembleEvent(
                  initiator,
                  error: error.toString(),
                ),
              );
            }
          },
        );

        scopeManager.addMotionListener(subscription, id: id);
      } else {
        final data =
            await GetIt.I<ActivityManager>().getMotionData(sensors: sensors);

        if (data != null) {
          ScreenController().executeActionWithScope(
            context,
            scopeManager,
            onDataReceived!,
            event: EnsembleEvent(
              initiator,
              data: data.toJson(),
            ),
          );
        } else if (onError != null) {
          ScreenController().executeActionWithScope(
            context,
            scopeManager,
            onError!,
            event: EnsembleEvent(
              initiator,
              error: 'noData',
            ),
          );
        }
      }
    } catch (e) {
      if (onError != null) {
        ScreenController().executeActionWithScope(
          context,
          scopeManager,
          onError!,
          event: EnsembleEvent(
            initiator,
            error: e.toString(),
          ),
        );
      } else {
        rethrow;
      }
    }
  }
}

class StopMotionDataAction extends EnsembleAction {
  StopMotionDataAction({this.id});
  final String? id;
  factory StopMotionDataAction.fromYaml({Map? payload}) {
    return StopMotionDataAction(
      id: Utils.optionalString(payload?['id']),
    );
  }
  @override
  Future<void> execute(BuildContext context, ScopeManager scopeManager) async {
    scopeManager.stopMotionListener(id);
  }
}
