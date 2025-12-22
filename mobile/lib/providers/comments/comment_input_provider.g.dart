// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comment_input_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for managing comment input state for a specific video
///
/// Parameterized by (rootEventId, rootAuthorPubkey) to match CommentsNotifier.
/// Manages:
/// - Main comment text input
/// - Reply text inputs (per comment ID)
/// - Active reply state (which comment is being replied to)
/// - Posting states (main and per-reply)
///
/// Usage:
/// ```dart
/// // Watch input state
/// final inputState = ref.watch(commentInputProvider(videoId, authorPubkey));
///
/// // Update main text
/// ref.read(commentInputProvider(videoId, authorPubkey).notifier)
///     .updateMainText(newText);
///
/// // Post comment
/// await ref.read(commentInputProvider(videoId, authorPubkey).notifier)
///     .postMainComment();
/// ```

@ProviderFor(CommentInputNotifier)
const commentInputProvider = CommentInputNotifierFamily._();

/// Provider for managing comment input state for a specific video
///
/// Parameterized by (rootEventId, rootAuthorPubkey) to match CommentsNotifier.
/// Manages:
/// - Main comment text input
/// - Reply text inputs (per comment ID)
/// - Active reply state (which comment is being replied to)
/// - Posting states (main and per-reply)
///
/// Usage:
/// ```dart
/// // Watch input state
/// final inputState = ref.watch(commentInputProvider(videoId, authorPubkey));
///
/// // Update main text
/// ref.read(commentInputProvider(videoId, authorPubkey).notifier)
///     .updateMainText(newText);
///
/// // Post comment
/// await ref.read(commentInputProvider(videoId, authorPubkey).notifier)
///     .postMainComment();
/// ```
final class CommentInputNotifierProvider
    extends $NotifierProvider<CommentInputNotifier, CommentInputState> {
  /// Provider for managing comment input state for a specific video
  ///
  /// Parameterized by (rootEventId, rootAuthorPubkey) to match CommentsNotifier.
  /// Manages:
  /// - Main comment text input
  /// - Reply text inputs (per comment ID)
  /// - Active reply state (which comment is being replied to)
  /// - Posting states (main and per-reply)
  ///
  /// Usage:
  /// ```dart
  /// // Watch input state
  /// final inputState = ref.watch(commentInputProvider(videoId, authorPubkey));
  ///
  /// // Update main text
  /// ref.read(commentInputProvider(videoId, authorPubkey).notifier)
  ///     .updateMainText(newText);
  ///
  /// // Post comment
  /// await ref.read(commentInputProvider(videoId, authorPubkey).notifier)
  ///     .postMainComment();
  /// ```
  const CommentInputNotifierProvider._({
    required CommentInputNotifierFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'commentInputProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$commentInputNotifierHash();

  @override
  String toString() {
    return r'commentInputProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  CommentInputNotifier create() => CommentInputNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CommentInputState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CommentInputState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CommentInputNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$commentInputNotifierHash() =>
    r'e0efb09eb1e1ffb93243a559965c4f08313cf595';

/// Provider for managing comment input state for a specific video
///
/// Parameterized by (rootEventId, rootAuthorPubkey) to match CommentsNotifier.
/// Manages:
/// - Main comment text input
/// - Reply text inputs (per comment ID)
/// - Active reply state (which comment is being replied to)
/// - Posting states (main and per-reply)
///
/// Usage:
/// ```dart
/// // Watch input state
/// final inputState = ref.watch(commentInputProvider(videoId, authorPubkey));
///
/// // Update main text
/// ref.read(commentInputProvider(videoId, authorPubkey).notifier)
///     .updateMainText(newText);
///
/// // Post comment
/// await ref.read(commentInputProvider(videoId, authorPubkey).notifier)
///     .postMainComment();
/// ```

final class CommentInputNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          CommentInputNotifier,
          CommentInputState,
          CommentInputState,
          CommentInputState,
          (String, String)
        > {
  const CommentInputNotifierFamily._()
    : super(
        retry: null,
        name: r'commentInputProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for managing comment input state for a specific video
  ///
  /// Parameterized by (rootEventId, rootAuthorPubkey) to match CommentsNotifier.
  /// Manages:
  /// - Main comment text input
  /// - Reply text inputs (per comment ID)
  /// - Active reply state (which comment is being replied to)
  /// - Posting states (main and per-reply)
  ///
  /// Usage:
  /// ```dart
  /// // Watch input state
  /// final inputState = ref.watch(commentInputProvider(videoId, authorPubkey));
  ///
  /// // Update main text
  /// ref.read(commentInputProvider(videoId, authorPubkey).notifier)
  ///     .updateMainText(newText);
  ///
  /// // Post comment
  /// await ref.read(commentInputProvider(videoId, authorPubkey).notifier)
  ///     .postMainComment();
  /// ```

  CommentInputNotifierProvider call(
    String rootEventId,
    String rootAuthorPubkey,
  ) => CommentInputNotifierProvider._(
    argument: (rootEventId, rootAuthorPubkey),
    from: this,
  );

  @override
  String toString() => r'commentInputProvider';
}

/// Provider for managing comment input state for a specific video
///
/// Parameterized by (rootEventId, rootAuthorPubkey) to match CommentsNotifier.
/// Manages:
/// - Main comment text input
/// - Reply text inputs (per comment ID)
/// - Active reply state (which comment is being replied to)
/// - Posting states (main and per-reply)
///
/// Usage:
/// ```dart
/// // Watch input state
/// final inputState = ref.watch(commentInputProvider(videoId, authorPubkey));
///
/// // Update main text
/// ref.read(commentInputProvider(videoId, authorPubkey).notifier)
///     .updateMainText(newText);
///
/// // Post comment
/// await ref.read(commentInputProvider(videoId, authorPubkey).notifier)
///     .postMainComment();
/// ```

abstract class _$CommentInputNotifier extends $Notifier<CommentInputState> {
  late final _$args = ref.$arg as (String, String);
  String get rootEventId => _$args.$1;
  String get rootAuthorPubkey => _$args.$2;

  CommentInputState build(String rootEventId, String rootAuthorPubkey);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args.$1, _$args.$2);
    final ref = this.ref as $Ref<CommentInputState, CommentInputState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CommentInputState, CommentInputState>,
              CommentInputState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
