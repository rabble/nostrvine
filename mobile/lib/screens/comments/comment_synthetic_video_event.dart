import 'package:comments_repository/comments_repository.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

extension CommentSyntheticVideoEventX on Comment {
  VideoEvent toSyntheticVideoEvent() {
    final title = content.trim();
    final createdAt = this.createdAt.millisecondsSinceEpoch ~/ 1000;
    final videoKind = EventKind.videoVertical.toString();

    return VideoEvent(
      id: id,
      pubkey: authorPubkey,
      createdAt: createdAt,
      content: content,
      timestamp: this.createdAt,
      title: title.isNotEmpty ? title : null,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      duration: videoDuration,
      dimensions: videoDimensions,
      blurhash: videoBlurhash,
      // Synthetic tags for navigation only. Thread semantics still come from
      // the comment model, not from these placeholder kind values.
      rawTags: {
        'E': rootEventId,
        'K': videoKind,
        'P': rootAuthorPubkey,
        if (replyToEventId case final replyToEventId?) ...{
          'e': replyToEventId,
          'k': videoKind,
        },
        if (replyToAuthorPubkey case final replyToAuthorPubkey?) ...{
          'p': replyToAuthorPubkey,
        },
      },
    );
  }
}
