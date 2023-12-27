import 'dart:developer';
import 'dart:io';

import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/input/form_helper.dart';
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
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'source': (value) => _controller.updateSource(Utils.getUrl(value)),
    };
  }
}

class MyController extends WidgetController {
  VideoPlayerController? _playerController;

  void updateSource(String? value) {
    // always invalidate the old controller
    _playerController?.dispose();

    if (value != null) {
      if (value.startsWith('https://') || value.startsWith('http://')) {
        _playerController = VideoPlayerController.networkUrl(Uri.parse(value))
          ..initialize().then((_) {
            VideoPlayerValue value = _playerController!.value;
            log(value.toString());
            notifyListeners();
          });
      } else if (Utils.isMemoryPath(value)) {
        _playerController = VideoPlayerController.file(File(value))
          ..initialize().then((_) {
            VideoPlayerValue value = _playerController!.value;
            log(value.toString());
            notifyListeners();
          });
      } else {
        _playerController =
            VideoPlayerController.asset(Utils.getLocalAssetFullPath(value))
              ..initialize().then((_) {
                VideoPlayerValue value = _playerController!.value;
                log(value.toString());
                notifyListeners();
              });
      }

      _playerController!.addListener(() {
        // finish playing, call setState() to update the status
        if (_playerController!.value.position ==
            _playerController!.value.duration) {
          notifyListeners();
        }
      });
    }
  }
}

class VideoState extends WidgetState<Video> {
  @override
  Widget buildWidget(BuildContext context) {
    if (widget._controller._playerController == null ||
        !widget._controller._playerController!.value.isInitialized) {
      return const SizedBox.shrink();
    }

    VideoPlayerController playerController =
        widget._controller._playerController!;
    return AspectRatio(
        aspectRatio: playerController.value.aspectRatio,
        child: Stack(alignment: Alignment.bottomCenter, children: [
          VideoPlayer(playerController),
          Center(
              child: CircleAvatar(
                  backgroundColor: Colors.white.withOpacity(.5),
                  radius: 17,
                  child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(getVideoIconStatus(playerController)),
                      color: Colors.black54,
                      onPressed: () {
                        setState(() {
                          playerController.value.isPlaying
                              ? playerController.pause()
                              : playerController.play();
                        });
                      })))
        ]));
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
    widget._controller._playerController?.dispose();
  }
}
