import 'package:ensemble/widget/youtube/native/youtube_platform_native.dart'
    if (dart.library.html) './web/youtube_platform_web.dart';

abstract class YoutubeWeb {
  factory YoutubeWeb() => getInstance();
  void createWebInstance();
}
