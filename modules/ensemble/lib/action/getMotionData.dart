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
    this.recurring,
    this.sensorType,
    this.updateInterval,
  });

  final String? id;
  final EnsembleAction? onDataReceived;
  final EnsembleAction? onError;
  final bool? recurring;
  final MotionSensorType? sensorType;
  final int? updateInterval; // in milliseconds

  factory GetMotionDataAction.fromYaml({Invokable? initiator, Map? payload}) {
    MotionSensorType? sensorType;
    if (payload?['options']?['sensorType'] != null) {
      final sensorTypeStr = Utils.getString(
        payload?['options']?['sensorType'],
        fallback: 'all',
      );
      sensorType = MotionSensorType.values.firstWhere(
        (e) => e.name == sensorTypeStr.toLowerCase(),
        orElse: () => MotionSensorType.all,
      );
    }

    return GetMotionDataAction(
      initiator: initiator,
      id: Utils.optionalString(payload?['id']),
      onDataReceived: EnsembleAction.from(payload?['onDataReceived']),
      onError: EnsembleAction.from(payload?['onError']),
      recurring: Utils.optionalBool(payload?['options']?['recurring']),
      sensorType: sensorType,
      updateInterval: Utils.optionalInt(payload?['options']?['updateInterval']),
    );
  }

  @override
  Future<void> execute(BuildContext context, ScopeManager scopeManager) async {
    if (onDataReceived == null) {
      throw LanguageError(
          '${ActionType.getMotionData.name} requires onDataReceived callback');
    }

    try {
      // Handle recurring motion updates
      if (recurring == true) {
        StreamSubscription<MotionData> streamSubscription =
            GetIt.I<ActivityManager>()
                .startMotionStream(
          sensorType: sensorType,
          updateInterval: updateInterval != null
              ? Duration(milliseconds: updateInterval!)
              : null,
        )
                .listen((MotionData? data) {
          if (data != null) {
            ScreenController().executeActionWithScope(
              context,
              scopeManager,
              onDataReceived!,
              event: EnsembleEvent(initiator, data: data.toJson()),
            );
          } else if (onError != null) {
            ScreenController().executeActionWithScope(
              context,
              scopeManager,
              onError!,
              event: EnsembleEvent(initiator, error: 'unknown'),
            );
          }
        }, onError: (error) {
          if (onError != null) {
            ScreenController().executeActionWithScope(
              context,
              scopeManager,
              onError!,
              event: EnsembleEvent(initiator, error: error.toString()),
            );
          }
        });
        // Store subscription for cleanup
        scopeManager.addMotionListener(streamSubscription, id: id);
      }
      // Handle one-time motion request
      else {
        final data = await GetIt.I<ActivityManager>()
            .getMotionData(sensorType: sensorType);
        if (data != null) {
          ScreenController().executeActionWithScope(
            context,
            scopeManager,
            onDataReceived!,
            event: EnsembleEvent(initiator, data: data.toJson()),
          );
        } else if (onError != null) {
          ScreenController().executeActionWithScope(
            context,
            scopeManager,
            onError!,
            event: EnsembleEvent(initiator, error: 'noData'),
          );
        }
      }
    } catch (e) {
      if (onError != null) {
        ScreenController().executeActionWithScope(
          context,
          scopeManager,
          onError!,
          event: EnsembleEvent(initiator, error: e.toString()),
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
