// ABOUTME: Riverpod provider for VideoReplyContext.
// ABOUTME: State is set before entering recorder and cleared after publish.

import 'package:openvine/models/video_reply_context.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'video_reply_context_provider.g.dart';

/// Provider holding the active video reply context.
///
/// When non-null, the video editor flow should skip the metadata
/// screen and publish as a comment via [VideoCommentPublishService].
@Riverpod(keepAlive: true)
class VideoReplyContextNotifier extends _$VideoReplyContextNotifier {
  @override
  VideoReplyContext? build() => null;

  /// Set the reply context before navigating to the recorder.
  void setContext(VideoReplyContext context) {
    state = context;
  }

  /// Clear the reply context after publishing or cancelling.
  void clear() {
    state = null;
  }
}
