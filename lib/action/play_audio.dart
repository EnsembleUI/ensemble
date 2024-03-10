// ignore_for_file: use_build_context_synchronously

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

// Singleton class for AudioPlayer
class SingletonAudioPlayer {
  SingletonAudioPlayer._();

  static final SingletonAudioPlayer _instance = SingletonAudioPlayer._();
  static final AudioPlayer _audioPlayer = AudioPlayer();

  static SingletonAudioPlayer get instance => _instance;

  AudioPlayer get audioPlayer => _audioPlayer;
}

class PlayAudio extends EnsembleAction {
  PlayAudio({
    required this.source,
    required this.onComplete,
    this.volume = 1,
    this.balance = 0,
    this.position = const Duration(seconds: 0),
  });

  final String source;
  final double volume;
  final double balance;
  final Duration position;
  final EnsembleAction? onComplete;

  factory PlayAudio.from(dynamic inputs) {
    Map? payload;

    if (inputs is! Map) payload = Utils.getYamlMap(inputs);
    if (inputs is Map) payload = inputs;

    if (payload == null || payload['source'] == null) {
      throw LanguageError("${ActionType.playAudio.name} requires 'source'");
    }

    return PlayAudio(
      source: payload['source'],
      balance: Utils.getDouble(
        payload['balance'],
        fallback: 0,
        max: 1,
        min: -1,
      ),
      volume: Utils.getDouble(
        payload['volume'],
        fallback: 1,
        max: 1,
        min: 0,
      ),
      position: Utils.getDuration(payload['position']) ?? //
          const Duration(seconds: 0),
      onComplete: EnsembleAction.fromYaml(payload['onComplete']),
    );
  }

  @override
  Future<dynamic> execute(
      BuildContext context, ScopeManager scopeManager) async {
    final parsedSource =
        source.startsWith('https://') || source.startsWith('http://')
            ? UrlSource(source)
            : AssetSource(Utils.getLocalAssetFullPath(source));

    await SingletonAudioPlayer.instance.audioPlayer.play(
      parsedSource,
      volume: volume,
      balance: balance,
      position: position,
    );

    if (onComplete != null) {
      ScreenController().executeActionWithScope(
        context,
        scopeManager,
        onComplete!,
      );
    }

    return Future.value(null);
  }
}

class SeekAudio extends EnsembleAction {
  SeekAudio({
    this.position = const Duration(seconds: 0),
  });
  final Duration position;

  factory SeekAudio.from(dynamic inputs) {
    Map? payload;

    if (inputs is! Map) payload = Utils.getYamlMap(inputs);
    if (inputs is Map) payload = inputs;

    if (payload == null || payload['audio'] == null) {
      throw LanguageError("${ActionType.playAudio.name} requires 'position'");
    }

    return SeekAudio(
      position:
          Utils.getDuration(payload['position']) ?? const Duration(seconds: 0),
    );
  }

  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    return SingletonAudioPlayer.instance.audioPlayer.seek(position);
  }
}

class PauseAudio extends EnsembleAction {
  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    return SingletonAudioPlayer.instance.audioPlayer.pause();
  }
}

class StopAudio extends EnsembleAction {
  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    return SingletonAudioPlayer.instance.audioPlayer.stop();
  }
}

class ResumeAudio extends EnsembleAction {
  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    return SingletonAudioPlayer.instance.audioPlayer.resume();
  }
}
