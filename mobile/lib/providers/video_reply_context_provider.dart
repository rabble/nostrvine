// ABOUTME: Holds the active video-reply publish target while camera/editor flow runs.
// ABOUTME: Cleared after publish or when the flow is abandoned.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_reply_context.dart';

final videoReplyContextProvider =
    NotifierProvider<VideoReplyContextNotifier, VideoReplyContext?>(
      VideoReplyContextNotifier.new,
    );

class VideoReplyContextNotifier extends Notifier<VideoReplyContext?> {
  @override
  VideoReplyContext? build() => null;

  void set(VideoReplyContext context) => state = context;

  void clear() => state = null;
}
