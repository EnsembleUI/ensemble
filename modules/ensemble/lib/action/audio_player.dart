// ignore_for_file: use_build_context_synchronously

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Shared audio player registry used by audio actions.
class SingletonAudioPlayer {
  SingletonAudioPlayer._();

  static final SingletonAudioPlayer _instance = SingletonAudioPlayer._();
  static final Map<String, AudioPlayer> _audioPlayers = {};

  /// Configuration value for instance.
  static SingletonAudioPlayer get instance => _instance;

  /// Starts playback for an audio source and stores the player by id.
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

  /// Pauses the audio player with the given id.
  Future<void> pause(String id) async {
    if (_audioPlayers.containsKey(id)) {
      await _audioPlayers[id]?.pause();
    }
  }

  /// Stops and disposes the audio player with the given id.
  Future<void> stop(String id) async {
    if (_audioPlayers.containsKey(id)) {
      await _audioPlayers[id]?.stop();
    }
  }

  /// Resumes the audio player with the given id.
  Future<void> resume(String id) async {
    if (_audioPlayers.containsKey(id)) {
      await _audioPlayers[id]?.resume();
    }
  }

  /// Moves the audio player to the requested position.
  Future<void> seek(String id, Duration position) async {
    if (_audioPlayers.containsKey(id)) {
      await _audioPlayers[id]?.seek(position);
    }
  }
}

/// Ensemble action that starts audio playback.
class PlayAudio extends EnsembleAction {
  /// Creates a [PlayAudio] action.
  PlayAudio({
    required this.id,
    required this.source,
    required this.onComplete,
    this.volume = 1,
    this.balance = 0,
    this.position = const Duration(seconds: 0),
  });

  /// Identifier used to store results, target an existing resource, or correlate callbacks.
  final String id;
  /// File source, URL, or audio source used by the action.
  final String source;
  /// Audio playback volume.
  final double volume;
  /// Audio stereo balance.
  final double balance;
  /// Playback position used to start or seek audio.
  final Duration position;
  /// Action executed after the operation completes successfully.
  final EnsembleAction? onComplete;

  /// Creates a [PlayAudio] from a YAML or map action payload.
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
      onComplete: EnsembleAction.from(payload['onComplete']),
    );
  }

  /// Runs this action and performs the play audio operation.
  @override
  Future<dynamic> execute(
      BuildContext context, ScopeManager scopeManager) async {
    AudioCache.instance = AudioCache(prefix: '');
    var parsedSource; // Source
    if (source.startsWith('https://') || source.startsWith('http://')) {
      String assetName = Utils.getAssetName(source);
      if (Utils.isAssetAvailableLocally(assetName)) {
        parsedSource = AssetSource(Utils.getLocalAssetFullPath(assetName));
      } else {
        parsedSource = UrlSource(source);
      }
    } else {
      parsedSource = AssetSource(Utils.getLocalAssetFullPath(source));
    }

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

/// Ensemble action that seeks an audio player to a position.
class SeekAudio extends EnsembleAction {
  /// Creates a [SeekAudio] action.
  SeekAudio({
    required this.id,
    this.position = const Duration(seconds: 0),
  });

  /// Identifier used to store results, target an existing resource, or correlate callbacks.
  final String id;
  /// Playback position used to start or seek audio.
  final Duration position;

  /// Creates a [SeekAudio] from a YAML or map action payload.
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

  /// Runs this action and performs the seek audio operation.
  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    return SingletonAudioPlayer.instance.seek(id, position);
  }
}

/// Ensemble action that pauses audio playback.
class PauseAudio extends EnsembleAction {
  /// Creates a [PauseAudio] action.
  PauseAudio({
    required this.id,
  });

  /// Identifier used to store results, target an existing resource, or correlate callbacks.
  final String id;

  /// Creates a [PauseAudio] from a YAML or map action payload.
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

  /// Runs this action and performs the pause audio operation.
  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    return SingletonAudioPlayer.instance.pause(id);
  }
}

/// Ensemble action that stops audio playback.
class StopAudio extends EnsembleAction {
  /// Creates a [StopAudio] action.
  StopAudio({
    required this.id,
  });

  /// Identifier used to store results, target an existing resource, or correlate callbacks.
  final String id;

  /// Creates a [StopAudio] from a YAML or map action payload.
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

  /// Runs this action and performs the stop audio operation.
  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    return SingletonAudioPlayer.instance.stop(id);
  }
}

/// Ensemble action that resumes paused audio playback.
class ResumeAudio extends EnsembleAction {
  /// Creates a [ResumeAudio] action.
  ResumeAudio({
    required this.id,
  });

  /// Identifier used to store results, target an existing resource, or correlate callbacks.
  final String id;

  /// Creates a [ResumeAudio] from a YAML or map action payload.
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

  /// Runs this action and performs the resume audio operation.
  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    return SingletonAudioPlayer.instance.resume(id);
  }
}
