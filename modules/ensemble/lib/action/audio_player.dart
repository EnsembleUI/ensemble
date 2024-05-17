// ignore_for_file: use_build_context_synchronously

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

// Singleton class for AudioPlayer
class SingletonAudioPlayer {
  SingletonAudioPlayer._();

  static final SingletonAudioPlayer _instance = SingletonAudioPlayer._();
  static final Map<String, AudioPlayer> _audioPlayers = {};

  static SingletonAudioPlayer get instance => _instance;

  Future<void> play({
    required String id,
    required Source source,
    required double volume,
    required double balance,
    required Duration position,
  }) async {
    _audioPlayers[id] ??= AudioPlayer();

    await _audioPlayers[id]?.play(
      source,
      volume: volume,
      balance: balance,
      position: position,
    );
  }

  Future<void> pause(String id) async {
    if (_audioPlayers.containsKey(id)) {
      await _audioPlayers[id]?.pause();
    }
  }

  Future<void> stop(String id) async {
    if (_audioPlayers.containsKey(id)) {
      await _audioPlayers[id]?.stop();
    }
  }

  Future<void> resume(String id) async {
    if (_audioPlayers.containsKey(id)) {
      await _audioPlayers[id]?.resume();
    }
  }

  Future<void> seek(String id, Duration position) async {
    if (_audioPlayers.containsKey(id)) {
      await _audioPlayers[id]?.seek(position);
    }
  }
}

class PlayAudio extends EnsembleAction {
  PlayAudio({
    required this.id,
    required this.source,
    required this.onComplete,
    this.volume = 1,
    this.balance = 0,
    this.position = const Duration(seconds: 0),
  });

  final String id;
  final String source;
  final double volume;
  final double balance;
  final Duration position;
  final EnsembleAction? onComplete;

  factory PlayAudio.from(dynamic inputs) {
    Map? payload;

    if (inputs is! Map) payload = Utils.getYamlMap(inputs);
    if (inputs is Map) payload = inputs;

    if (payload == null) {
      throw LanguageError("Payload needs to be passed");
    }
    if (payload['id'] == null) {
      throw LanguageError("${ActionType.seekAudio.name} requires 'id'");
    }
    if (payload['source'] == null) {
      throw LanguageError("${ActionType.playAudio.name} requires 'source'");
    }

    print(payload['source']);

    return PlayAudio(
      id: payload['id'],
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
    AudioCache.instance = AudioCache(prefix: '');

    final parsedSource =
        source.startsWith('https://') || source.startsWith('http://')
            ? UrlSource(source)
            : AssetSource(Utils.getLocalAssetFullPath(source));

    await SingletonAudioPlayer.instance.play(
      id: id,
      source: parsedSource,
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
    required this.id,
    this.position = const Duration(seconds: 0),
  });

  final String id;
  final Duration position;

  factory SeekAudio.from(dynamic inputs) {
    Map? payload;

    if (inputs is! Map) payload = Utils.getYamlMap(inputs);
    if (inputs is Map) payload = inputs;

    if (payload == null) {
      throw LanguageError("Payload needs to be passed");
    }
    if (payload['id'] == null) {
      throw LanguageError("${ActionType.seekAudio.name} requires 'id'");
    }
    if (payload['position'] == null) {
      throw LanguageError("${ActionType.seekAudio.name} requires 'position'");
    }

    return SeekAudio(
      id: payload['id'],
      position:
          Utils.getDuration(payload['position']) ?? const Duration(seconds: 0),
    );
  }

  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    return SingletonAudioPlayer.instance.seek(id, position);
  }
}

class PauseAudio extends EnsembleAction {
  PauseAudio({
    required this.id,
  });

  final String id;

  factory PauseAudio.from(dynamic inputs) {
    Map? payload;

    if (inputs is! Map) payload = Utils.getYamlMap(inputs);
    if (inputs is Map) payload = inputs;

    if (payload == null) {
      throw LanguageError("Payload needs to be passed");
    }
    if (payload['id'] == null) {
      throw LanguageError("${ActionType.seekAudio.name} requires 'id'");
    }

    return PauseAudio(id: payload['id']);
  }

  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    return SingletonAudioPlayer.instance.pause(id);
  }
}

class StopAudio extends EnsembleAction {
  StopAudio({
    required this.id,
  });

  final String id;

  factory StopAudio.from(dynamic inputs) {
    Map? payload;

    if (inputs is! Map) payload = Utils.getYamlMap(inputs);
    if (inputs is Map) payload = inputs;

    if (payload == null) {
      throw LanguageError("Payload needs to be passed");
    }
    if (payload['id'] == null) {
      throw LanguageError("${ActionType.seekAudio.name} requires 'id'");
    }

    return StopAudio(id: payload['id']);
  }

  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    return SingletonAudioPlayer.instance.stop(id);
  }
}

class ResumeAudio extends EnsembleAction {
  ResumeAudio({
    required this.id,
  });

  final String id;

  factory ResumeAudio.from(dynamic inputs) {
    Map? payload;

    if (inputs is! Map) payload = Utils.getYamlMap(inputs);
    if (inputs is Map) payload = inputs;

    if (payload == null) {
      throw LanguageError("Payload needs to be passed");
    }
    if (payload['id'] == null) {
      throw LanguageError("${ActionType.seekAudio.name} requires 'id'");
    }

    return ResumeAudio(id: payload['id']);
  }

  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    return SingletonAudioPlayer.instance.resume(id);
  }
}
