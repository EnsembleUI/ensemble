import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/youtube/youtubestate.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class Youtube extends StatefulWidget
    with Invokable, HasController<PlayerController, YoutubeState> {
  Youtube({super.key});

  static const String type = "YouTube";

  final PlayerController _controller = PlayerController();

  @override
  PlayerController get controller => _controller;

  @override
  State<StatefulWidget> createState() => YoutubeState();

  @override
  Map<String, Function> getters() => {};

  @override
  Map<String, Function> methods() => {
        'nextVideo': () => _controller.youtubeMethods!.nextVideo(),
        'previousVideo': () => _controller.youtubeMethods?.previousVideo(),
        'stopVideo': () => _controller.youtubeMethods?.stopVideo(),
        'pauseVideo': () => _controller.youtubeMethods?.pauseVideo(),
        'playVideo': () => _controller.youtubeMethods?.playVideo(),
        'mute': () => _controller.youtubeMethods?.mute(),
        'unMute': () => _controller.youtubeMethods?.unMute()
      };

  @override
  Map<String, Function> setters() => {
        "url": (value) =>
            _controller.getVideoId(Utils.getString(value, fallback: "")),
        "aspectRatio": (value) =>
            _controller.aspectRatio = Utils.optionalDouble(value),
        "autoplay": (value) =>
            _controller.autoplay = Utils.getBool(value, fallback: false),
        "showControls": (value) =>
            _controller.showControls = Utils.getBool(value, fallback: true),
        "endSeconds": (value) =>
            _controller.endSeconds = Utils.optionalDouble(value),
        "startSeconds": (value) =>
            _controller.startSeconds = Utils.optionalDouble(value),
        "showAnnotations": (value) => _controller.showVideoAnnotation =
            Utils.getBool(value, fallback: true),
        "videoList": (value) =>
            _controller.getVideoIdList(Utils.getListOfStrings(value)!),
        "playbackRate": (value) {
          _controller.youtubeMethods
              ?.setPlaybackRate(Utils.getDouble(value, fallback: 1.0));
          _controller.playbackRate = Utils.optionalDouble(value);
        },
        "showFullScreenButton": (value) => _controller.showFullScreenButton =
            Utils.getBool(value, fallback: false),
        "enableCaptions": (value) =>
            _controller.enableCaptions = Utils.getBool(value, fallback: true),
        "volume": (value) {
          _controller.youtubeMethods
              ?.setVolume(Utils.getInt(value, fallback: 100, max: 100, min: 0));
          _controller.volume = Utils.optionalInt(value, max: 100, min: 0);
        },
        'videoPosition': (value) =>
            _controller.videoPosition = Utils.getBool(value, fallback: false)
      };
}

mixin YoutubeMethods on WidgetState<Youtube> {
  void nextVideo();
  void previousVideo();
  void stopVideo();
  void pauseVideo();
  void playVideo();
  void mute();
  void unMute();
  void setPlaybackRate(double rate);
  void setVolume(int volume);
}

class YoutubeState extends WidgetState<Youtube> with YoutubeMethods {
  late YoutubePlayerController player;
  @override
  void initState() {
    YoutubeWeb().createWebInstance();
    PlayerController playerController = widget._controller;
    player = YoutubePlayerController(
        params: YoutubePlayerParams(
            enableCaption: playerController.enableCaptions,
            showControls: playerController.showControls,
            showFullscreenButton: playerController.showFullScreenButton,
            showVideoAnnotations: playerController.showVideoAnnotation));
    List<String> list = playerController.videoList;

    if (!playerController.autoplay) {
      (list.isEmpty)
          ? player.cueVideoById(
              videoId: playerController.url,
              startSeconds: playerController.startSeconds,
              endSeconds: playerController.endSeconds)
          : player.cuePlaylist(
              list: playerController.videoList,
              startSeconds: playerController.startSeconds,
              listType: ListType.playlist);
    } else {
      (list.isEmpty)
          ? player.loadVideoById(
              videoId: playerController.url,
              startSeconds: playerController.startSeconds,
              endSeconds: playerController.endSeconds)
          : player.loadPlaylist(
              list: playerController.videoList,
              startSeconds: playerController.startSeconds,
              listType: ListType.playlist);
    }
    super.initState();
  }

  @override
  void didChangeDependencies() {
    widget._controller.youtubeMethods = this;
    widget._controller.youtubeMethods!
        .setPlaybackRate(widget.controller.playbackRate ?? 1);
    widget._controller.youtubeMethods!
        .setVolume(widget.controller.volume ?? 100);
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(covariant Youtube oldWidget) {
    widget._controller.youtubeMethods = this;
    widget._controller.youtubeMethods!
        .setPlaybackRate(oldWidget.controller.playbackRate ?? 1);
    widget._controller.youtubeMethods!
        .setVolume(oldWidget.controller.volume ?? 100);
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget buildWidget(BuildContext context) {
    PlayerController playerController = widget._controller;

    if (widget._controller.broken) {
      return const SizedBox.shrink();
    }
    return YoutubePlayerScaffold(
      gestureRecognizers: <Factory<EagerGestureRecognizer>>{}..add(
          Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
        ),
      enableFullScreenOnVerticalDrag: false,
      autoFullScreen: false,
      aspectRatio: playerController.aspectRatio ?? 16 / 9,
      controller: player
        ..setFullScreenListener((value) async {
          final videoData = await player.videoData;
          final startSeconds = await player.currentTime;
          if (!context.mounted) return;
          final currentTime = await FullscreenYoutubePlayer.launch(
            context,
            videoId: videoData.videoId,
            startSeconds: startSeconds,
          );
          if (currentTime != null) {
            player.seekTo(seconds: currentTime, allowSeekAhead: true);
          }
        }),
      builder: (context, youtube) {
        if (playerController.videoPosition) {
          return YoutubeValueBuilder(
              builder: (context, youtubeValue) => Column(
                    children: [
                      youtube,
                      StreamBuilder<YoutubeVideoState>(
                          stream: player.videoStateStream,
                          builder: (context, snapshot) {
                            final int position =
                                snapshot.data?.position.inMilliseconds ?? 0;
                            final int duration =
                                youtubeValue.metaData.duration.inMilliseconds;
                            return LinearProgressIndicator(
                              value: duration == 0 ? 0 : position / duration,
                              minHeight: 3,
                            );
                          })
                    ],
                  ));
        } else {
          return youtube;
        }
      },
    );
  }

  @override
  void mute() => player.mute();

  @override
  void nextVideo() => player.nextVideo();

  @override
  void pauseVideo() => player.pauseVideo();

  @override
  void playVideo() => player.playVideo();

  @override
  void previousVideo() => player.previousVideo();

  @override
  void stopVideo() => player.stopVideo();

  @override
  void unMute() => player.unMute();

  @override
  void setPlaybackRate(double rate) => player.setPlaybackRate(rate);

  @override
  void setVolume(int volume) => player.setVolume(volume);
}

class PlayerController extends WidgetController {
  YoutubeMethods? youtubeMethods;
  String url = "";
  double? aspectRatio;
  bool autoplay = false;
  bool broken = false;
  bool showControls = true;
  bool showFullScreenButton = false;
  bool showVideoAnnotation = true;
  double? startSeconds;
  double? endSeconds;
  bool enableCaptions = true;
  double? playbackRate;
  int? volume;
  bool videoPosition = false;

  List<String> videoList = [];

  void getVideoIdList(List<String> list) {
    if (list.length > 1) {
      if (url.isNotEmpty) {
        String? x = YoutubePlayerController.convertUrlToId(url);
        (x != null) ? videoList.add(x) : broken = true;
      }
      for (var i in list) {
        String? x = YoutubePlayerController.convertUrlToId(i);
        (x == null) ? broken = true : videoList.add(x);
      }
    } else if (list.length == 1) {
      if (url.isEmpty) {
        String? x = YoutubePlayerController.convertUrlToId(list.first);
        (x != null) ? url = x : broken = true;
      } else {
        String? x = YoutubePlayerController.convertUrlToId(list.first);
        String? x1 = YoutubePlayerController.convertUrlToId(url);
        (x != null) ? videoList.add(x) : broken = true;
        (x1 != null) ? videoList.add(x1) : broken = true;
      }
    }
  }

  void getVideoId(String value) {
    String? x = YoutubePlayerController.convertUrlToId(value);
    if (x != null) {
      url = x;
    }
  }
}
