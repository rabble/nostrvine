// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comment_context_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(commentContext)
const commentContextProvider = CommentContextProvider._();

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

final class CommentContextProvider
    extends $FunctionalProvider<CommentContext, CommentContext, CommentContext>
    with $Provider<CommentContext> {
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
  const CommentContextProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'commentContextProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$commentContextHash();

  @$internal
  @override
  $ProviderElement<CommentContext> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CommentContext create(Ref ref) {
    return commentContext(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CommentContext value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CommentContext>(value),
    );
  }
}

String _$commentContextHash() => r'5625eb2d1bfbb6f8fc09a6b23a14826b5c4c37e5';
