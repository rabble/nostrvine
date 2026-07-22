// ABOUTME: App-side VideoEvent helper for the blurhash content-type fallback.
// ABOUTME: Shared by the feed thumbnail and the pooled error overlay so the two
// ABOUTME: call sites can't drift apart.

import 'package:blurhash_service/blurhash_service.dart';
import 'package:models/models.dart';

/// Derives the [VineContentType] used to pick a generic blurhash gradient when
/// a video carries no event-level [VideoEvent.blurhash].
extension VideoEventContentType on VideoEvent {
  /// Content-type inferred from the event's hashtags, group, title, and
  /// content. `null` when nothing maps to a known category, in which case
  /// [BlurhashDisplay] falls back to the default Vine gradient.
  VineContentType? get blurhashContentType => BlurhashService.deriveContentType(
    hashtags: hashtags,
    group: group,
    title: title,
    content: content,
  );
}
