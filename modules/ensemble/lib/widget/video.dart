import 'dart:developer';
import 'dart:io';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class Video extends StatefulWidget
    with Invokable, HasController<MyController, VideoState> {
  static const type = 'Video';
  Video({Key? key}) : super(key: key);

  final MyController _controller = MyController();
  @override
  MyController get controller => _controller;

  @override
  State<StatefulWidget> createState() => VideoState();

  @override
  Map<String, Function> getters() {
    return {
      'isInitialized': () => _controller._playerController?.value.isInitialized,
      'isBuffering': () => _controller._playerController?.value.isBuffering,
      'isLooping': () => _controller._playerController?.value.isLooping,
      'isPlaying': () => _controller._playerController?.value.isPlaying,
      'isEnded': () => _controller._playerController?.value.isCompleted,
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'stop': () => _controller.playerCapabilities?.stop(),
      'pause': () => _controller.playerCapabilities?.pause(),
      'play': () => _controller.playerCapabilities?.play(),
      'mute': () => _controller.playerCapabilities?.mute(),
      'unmute': () => _controller.playerCapabilities?.unmute(),
      'seekTo': (value) => _controller.playerCapabilities?.seekTo(value),
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'source': (value) => _controller.updateSource(Utils.getUrl(value)),
      'showControls': (value) =>
          _controller.showControls = Utils.getBool(value, fallback: true),
      'loadingWidget': (loadingWidget) =>
          _controller.loadingWidget = loadingWidget,
      'repeat': (value) => _controller._playerController
          ?.setLooping(Utils.getBool(value, fallback: false)),
      'autoplay': (value) =>
          controller.autoplay = Utils.getBool(value, fallback: false),
      'playbackRate': (value) => controller.setPlaybackRate(value),
      'volume': (value) => controller.setVolume(value),
      'onChange': (definition) => _controller.onChange =
          EnsembleAction.from(definition, initiator: this),
      'onStart': (definition) => _controller.onStart =
          EnsembleAction.from(definition, initiator: this),
      'onEnd': (definition) =>
          _controller.onEnd = EnsembleAction.from(definition, initiator: this),
    };
  }
}

class MyController extends WidgetController {
  PlayerCapabilities? playerCapabilities;
  EnsembleAction? onStart;
  EnsembleAction? onChange;
  EnsembleAction? onEnd;
  bool showControls = true;
  bool autoplay = false;
  bool? enableLoop;
  double? playbackRate;
  double? volume;
  dynamic loadingWidget;

  VideoPlayerController? _playerController;

  void updateSource(String? value) {
    // always invalidate the old controller
    _playerController?.dispose();

    if (value != null) {
      void setupPlayer() {
        if (autoplay) {
          _playerController?.play();
        }
        if (playbackRate != null) {
          _playerController?.setPlaybackSpeed(playbackRate!);
        }

        if (volume != null) {
          _playerController?.setVolume(volume!);
        }
      }

      if (value.startsWith('https://') || value.startsWith('http://')) {
        // If the asset is available locally, then use local path
        String assetName = Utils.getAssetName(value);
        if (Utils.isAssetAvailableLocally(assetName)) {
          _playerController = VideoPlayerController.asset(
              Utils.getLocalAssetFullPath(assetName))
            ..initialize().then((_) {
              VideoPlayerValue value = _playerController!.value;
              log(value.toString());
              setupPlayer();
              notifyListeners();
            });
        } else {
          _playerController = VideoPlayerController.networkUrl(Uri.parse(value))
            ..initialize().then((_) {
              VideoPlayerValue value = _playerController!.value;
              log(value.toString());
              setupPlayer();
              notifyListeners();
            });
        }
      } else if (Utils.isMemoryPath(value)) {
        _playerController = VideoPlayerController.file(File(value))
          ..initialize().then((_) {
            VideoPlayerValue value = _playerController!.value;
            log(value.toString());
            setupPlayer();
            notifyListeners();
          });
      } else {
        _playerController =
            VideoPlayerController.asset(Utils.getLocalAssetFullPath(value))
              ..initialize().then((_) {
                VideoPlayerValue value = _playerController!.value;
                log(value.toString());
                setupPlayer();
                notifyListeners();
              });
      }

      _playerController!.addListener(() {
        // finish playing, call setState() to update the status
        if (_playerController!.value.position ==
            _playerController!.value.duration) {
          notifyListeners();
        }
        playerCapabilities?.videoPlayerStateChange();
      });
    }
  }

  void setPlaybackRate(dynamic speed) {
    playbackRate = Utils.optionalDouble(speed, max: 2.0);
    if (playbackRate != null) {
      _playerController?.setPlaybackSpeed(playbackRate!);
    }
  }

  void setVolume(dynamic volume) {
    volume = Utils.optionalDouble(volume, max: 1.0);
    if (volume != null) {
      _playerController?.setVolume(volume);
    }
  }
}

mixin PlayerCapabilities on EWidgetState<Video> {
  void stop();
  void pause();
  void play();
  void mute();
  void unmute();
  void seekTo(dynamic value);
  void videoPlayerStateChange();
}

class VideoState extends EWidgetState<Video> with PlayerCapabilities {
  @override
  void didChangeDependencies() {
    widget._controller.playerCapabilities = this;
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(covariant Video oldWidget) {
    widget._controller.playerCapabilities = this;
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget buildWidget(BuildContext context) {
    if (widget._controller._playerController == null ||
        !widget._controller._playerController!.value.isInitialized) {
      return _buildLoadingWidget() ?? const SizedBox.shrink();
    }

    VideoPlayerController playerController =
        widget._controller._playerController!;
    return AspectRatio(
      aspectRatio: playerController.value.aspectRatio,
      child: Stack(alignment: Alignment.bottomCenter, children: [
        VideoPlayer(playerController),
        if (widget._controller.showControls == true)
          buildVideoControls(playerController)
      ]),
    );
  }

  Widget? _buildLoadingWidget() {
    Widget? loadingWidget = widget._controller.loadingWidget != null
        ? scopeManager
            ?.buildWidgetFromDefinition(widget._controller.loadingWidget)
        : null;
    return loadingWidget;
  }

  Widget buildVideoControls(VideoPlayerController playerController) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          CircleButton(
            icon: Icons.replay_10_outlined,
            onTap: () {
              final currentDuration =
                  widget._controller._playerController?.value.position;
              if (currentDuration != null) {
                widget._controller.playerCapabilities
                    ?.seekTo(currentDuration.inSeconds - 10);
              }
            },
          ),
          CircleButton(
            icon: getVideoIconStatus(playerController),
            onTap: () {
              setState(() {
                playerController.value.isPlaying
                    ? playerController.pause()
                    : playerController.play();
              });
            },
          ),
          CircleButton(
            icon: Icons.forward_10_outlined,
            onTap: () {
              final currentDuration =
                  widget._controller._playerController?.value.position;
              if (currentDuration != null) {
                widget._controller.playerCapabilities
                    ?.seekTo(currentDuration.inSeconds + 10);
              }
            },
          ),
        ],
      ),
    );
  }

  IconData getVideoIconStatus(VideoPlayerController playerController) {
    if (playerController.value.isPlaying) {
      return Icons.pause;
    } else if (playerController.value.duration > Duration.zero &&
        playerController.value.duration == playerController.value.position) {
      return Icons.restart_alt;
    }
    return Icons.play_arrow;
  }

  @override
  void dispose() {
    super.dispose();
    widget._controller.playerCapabilities = null;
    widget._controller._playerController?.dispose();
  }

  @override
  void mute() => widget._controller._playerController?.setVolume(0);

  @override
  void unmute() => widget._controller._playerController?.setVolume(1);

  @override
  void pause() => widget._controller._playerController?.pause();

  @override
  void play() => widget._controller._playerController?.play();

  @override
  void stop() {
    widget._controller._playerController?.pause();
    widget._controller._playerController?.seekTo(Duration.zero);
  }

  @override
  void seekTo(dynamic value) {
    final position = Utils.getDuration(value);
    if (position != null) {
      widget._controller._playerController?.seekTo(position);
    }
  }

  @override
  void videoPlayerStateChange() async {
    // onChange
    final playerController = widget._controller._playerController;
    if (playerController == null) return;

    if (widget.controller.onChange != null &&
        playerController.value.isPlaying) {
      final position = await playerController.position;
      ScreenController().executeAction(context, widget._controller.onChange!,
          event: EnsembleEvent(widget,
              data: {'position': position?.inMilliseconds ?? 0}));
    }

    // onStart
    if (widget._controller.onStart != null &&
        playerController.value.isPlaying) {
      final videoPosition = playerController.value.position;
      if (videoPosition == const Duration(seconds: 0, minutes: 0, hours: 0)) {
        ScreenController().executeAction(context, widget._controller.onStart!,
            event: EnsembleEvent(widget));
      }
    }

    // onEnd
    if (widget._controller.onEnd != null &&
        playerController.value.isCompleted) {
      final videoPosition = playerController.value.position;
      if (videoPosition ==
          widget._controller._playerController?.value.duration) {
        ScreenController().executeAction(context, widget._controller.onEnd!,
            event: EnsembleEvent(widget));
      }
    }
  }
}

class CircleButton extends StatelessWidget {
  const CircleButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: Colors.white.withValues(alpha: .5),
      radius: 17,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon),
        color: Colors.black54,
        onPressed: onTap,
      ),
    );
  }
}
