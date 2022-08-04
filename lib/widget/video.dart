import 'dart:developer';

import 'package:ensemble/ensemble_theme.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/form_field_builder.dart' as ensemble;
import 'package:ensemble/widget/form_helper.dart';
import 'package:ensemble/widget/widget_registry.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:ensemble/util/extensions.dart';
import 'package:video_player/video_player.dart';

class Video extends StatefulWidget with Invokable, HasController<VideoController, VideoState> {
  static const type = 'Video';
  Video({Key? key}) : super(key: key);

  final VideoController _controller = VideoController();
  @override
  VideoController get controller => _controller;

  @override
  State<StatefulWidget> createState() => VideoState();

  @override
  Map<String, Function> getters() {
    return {

    };
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

class VideoController extends WidgetController {
  VideoPlayerController? _playerController;
  Future<void>? _playerControllerFuture;

  String? _source;
  void updateSource(String? value) {
    // always invalidate the old controller
    _playerController?.dispose();

    if (value != null) {
      _playerController = VideoPlayerController.network(value);
      _playerControllerFuture = _playerController!.initialize();
    }
  }

}

class VideoState extends WidgetState<Video> {

  @override
  Widget build(BuildContext context) {
    if (widget._controller._playerController == null || widget._controller._playerControllerFuture == null) {
      return Image.asset("assets/images/img_placeholder.png");
    }

    return FutureBuilder(
      future: widget._controller._playerControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          VideoPlayerController playerController = widget._controller._playerController!;
          return AspectRatio(
              aspectRatio: playerController.value.aspectRatio,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
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
                            playerController.value.isPlaying ? playerController.pause() : playerController.play();
                          });
                        }
                      )
                    )
                  )
                ],
              )
          );


        } else {
           return const Center(
             child: CircularProgressIndicator(),
           );
        }
    });

  }

  IconData getVideoIconStatus(VideoPlayerController playerController) {
    if (playerController.value.isPlaying) {
      return Icons.pause;
    } else if (playerController.value.duration == playerController.value.position) {
      return Icons.repeat;
    }
    return Icons.play_arrow;
  }

  @override
  void dispose() {
    super.dispose();
    widget._controller._playerController?.dispose();
  }



}