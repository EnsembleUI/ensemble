import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/widget/youtube/youtubestate.dart';

YouTubeBase getInstance() => YouTubeUnsupported();

class YouTubeUnsupported implements YouTubeBase {
  @override
  void createWebInstance() {
    throw LanguageError("Incorrect Platform for the Youtube widget");
  }
}
