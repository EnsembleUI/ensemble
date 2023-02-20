import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerFile extends StatefulWidget {
  VideoPlayerFile({super.key, required this.videoPath});
  dynamic videoPath;

  @override
  State<VideoPlayerFile> createState() => _VideoPlayerFileState();
}

class _VideoPlayerFileState extends State<VideoPlayerFile> {
  VideoPlayerController? controller;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      controller = VideoPlayerController.network(widget.videoPath!)
        ..initialize().then((_) {
          controller!.play();
          setState(() {});
        });
    } else {
      controller = VideoPlayerController.file(widget.videoPath!)
        ..initialize().then((_) {
          controller!.play();
          setState(() {});
        });
    }
  }

  @override
  void dispose() {
    super.dispose();
    controller!.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
          child: controller!.value.isInitialized
              ? SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height / 1.4,
                  child: Stack(
                    children: [
                      Center(
                        child: AspectRatio(
                          aspectRatio: controller!.value.aspectRatio,
                          child: VideoPlayer(controller!),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox()),
    );
  }

  playPause() {
    if (controller!.value.isPlaying) {
      controller!.pause();
    } else {
      controller!.play();
    }
  }
}
