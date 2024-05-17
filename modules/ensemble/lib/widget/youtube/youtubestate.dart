import 'package:ensemble/widget/youtube/native/unsupported_platform.dart'
    if (dart.library.html) 'package:ensemble/widget/youtube/web/youtube_platform_web.dart'
    if (dart.library.io) 'package:ensemble/widget/youtube/native/youtube_platform_native.dart';

abstract class YouTubeBase {
  factory YouTubeBase() => getInstance();
  void createWebInstance();
}
