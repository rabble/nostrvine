// ABOUTME: Scoped provider holding the current comment context (video ID and author pubkey)
// ABOUTME: Override at CommentsScreen level so children can access without prop drilling

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'comment_context_provider.g.dart';

/// Record type for comment context
typedef CommentContext = ({String eventId, String pubkey});

/// Scoped provider for comment context.
///
/// Must be overridden with actual values at the CommentsScreen level.
/// Children can then read the context without needing props.
///
/// Usage in widgets:
/// ```dart
/// final ctx = ref.watch(commentContextProvider);
/// final inputState = ref.watch(commentInputProvider(ctx.eventId, ctx.pubkey));
/// final notifier = ref.read(commentInputProvider(ctx.eventId, ctx.pubkey).notifier);
/// ```
@Riverpod(keepAlive: true)
CommentContext commentContext(Ref ref) {
  throw UnimplementedError(
    'commentContextProvider must be overridden with actual values',
  );
}
