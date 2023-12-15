import 'package:ensemble/widget/youtube/youtubestate.dart';

YouTubeBase getInstance() => YouTubeNativeInstance();

class YouTubeNativeInstance implements YouTubeBase {
  @override
  void createWebInstance() {}
}
