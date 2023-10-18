import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class EnsemblePlayer extends StatefulWidget
    with Invokable, HasController<PlayerController, EnsemblePlayerState> {
  EnsemblePlayer({super.key});

  static const String type = "YoutubePlayer";

  final PlayerController _controller = PlayerController();

  @override
  PlayerController get controller => _controller;

  @override
  State<StatefulWidget> createState() => EnsemblePlayerState();

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
      "link": (value) =>
          _controller.link = Utils.getString(value, fallback: ""),
      "aspectRatio": (value) =>
          _controller.aspectRatio = Utils.optionalDouble(value),
      "autoStart": (value) =>
          _controller.autoStart = Utils.getBool(value, fallback: false)
    };
  }
}

class EnsemblePlayerState extends WidgetState<EnsemblePlayer> {
  @override
  void initState() {
    if (widget._controller.autoStart) {
      widget._controller.youtubePlayerController
          .loadVideo(widget._controller.link);
    } else {
      widget._controller.youtubePlayerController.cueVideoById(
        videoId: widget._controller.link.split("=").last,
      );
    }
    super.initState();
  }

  @override
  Widget buildWidget(BuildContext context) {
    return YoutubePlayerScaffold(
        aspectRatio: widget._controller.aspectRatio ?? 16 / 9,
        builder: (context, player) {
          return player;
        },
        controller: widget._controller.youtubePlayerController);
  }
}

class PlayerController extends WidgetController {
  YoutubePlayerController youtubePlayerController = YoutubePlayerController(
      params: const YoutubePlayerParams(
          showControls: true, showFullscreenButton: true));
  String link = "";
  double? aspectRatio;
  bool autoStart = false;
}
