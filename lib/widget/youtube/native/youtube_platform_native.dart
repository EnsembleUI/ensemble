import 'package:ensemble/widget/youtube/youtubestate.dart';

YoutubeWeb getInstance() => YoutubeNativeInstance();

class YoutubeNativeInstance implements YoutubeWeb {
  @override
  void createWebInstance() {}
}
