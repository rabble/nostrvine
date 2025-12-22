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

@ProviderFor(commentContext)
const commentContextProvider = CommentContextProvider._();

/// Scoped provider for comment context.
///
/// Must be overridden with actual values at the CommentsScreen level.
/// Children can then read the context without needing props.

final class CommentContextProvider
    extends $FunctionalProvider<CommentContext, CommentContext, CommentContext>
    with $Provider<CommentContext> {
  /// Scoped provider for comment context.
  ///
  /// Must be overridden with actual values at the CommentsScreen level.
  /// Children can then read the context without needing props.
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

/// Derived provider for current comment input state.
///
/// Automatically uses the scoped [commentContextProvider] to get the
/// correct [CommentInputState] without needing to pass parameters.
///
/// Usage:
/// ```dart
/// // Watch state
/// final inputState = ref.watch(currentCommentInputProvider);
///
/// // Access notifier for actions
/// ref.read(currentCommentInputProvider.notifier).postMainComment();
/// ```

@ProviderFor(CurrentCommentInput)
const currentCommentInputProvider = CurrentCommentInputProvider._();

/// Derived provider for current comment input state.
///
/// Automatically uses the scoped [commentContextProvider] to get the
/// correct [CommentInputState] without needing to pass parameters.
///
/// Usage:
/// ```dart
/// // Watch state
/// final inputState = ref.watch(currentCommentInputProvider);
///
/// // Access notifier for actions
/// ref.read(currentCommentInputProvider.notifier).postMainComment();
/// ```
final class CurrentCommentInputProvider
    extends $NotifierProvider<CurrentCommentInput, CommentInputState> {
  /// Derived provider for current comment input state.
  ///
  /// Automatically uses the scoped [commentContextProvider] to get the
  /// correct [CommentInputState] without needing to pass parameters.
  ///
  /// Usage:
  /// ```dart
  /// // Watch state
  /// final inputState = ref.watch(currentCommentInputProvider);
  ///
  /// // Access notifier for actions
  /// ref.read(currentCommentInputProvider.notifier).postMainComment();
  /// ```
  const CurrentCommentInputProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentCommentInputProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentCommentInputHash();

  @$internal
  @override
  CurrentCommentInput create() => CurrentCommentInput();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CommentInputState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CommentInputState>(value),
    );
  }
}

String _$currentCommentInputHash() =>
    r'f303493cc422d06ae2bed8ef246c81e44c9ae0f2';

/// Derived provider for current comment input state.
///
/// Automatically uses the scoped [commentContextProvider] to get the
/// correct [CommentInputState] without needing to pass parameters.
///
/// Usage:
/// ```dart
/// // Watch state
/// final inputState = ref.watch(currentCommentInputProvider);
///
/// // Access notifier for actions
/// ref.read(currentCommentInputProvider.notifier).postMainComment();
/// ```

abstract class _$CurrentCommentInput extends $Notifier<CommentInputState> {
  CommentInputState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
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

/// Derived provider for current comments state.
///
/// Automatically uses the scoped [commentContextProvider] to get the
/// correct [CommentsState] without needing to pass parameters.

@ProviderFor(currentComments)
const currentCommentsProvider = CurrentCommentsProvider._();

/// Derived provider for current comments state.
///
/// Automatically uses the scoped [commentContextProvider] to get the
/// correct [CommentsState] without needing to pass parameters.

final class CurrentCommentsProvider
    extends $FunctionalProvider<CommentsState, CommentsState, CommentsState>
    with $Provider<CommentsState> {
  /// Derived provider for current comments state.
  ///
  /// Automatically uses the scoped [commentContextProvider] to get the
  /// correct [CommentsState] without needing to pass parameters.
  const CurrentCommentsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentCommentsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentCommentsHash();

  @$internal
  @override
  $ProviderElement<CommentsState> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CommentsState create(Ref ref) {
    return currentComments(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CommentsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CommentsState>(value),
    );
  }
}

String _$currentCommentsHash() => r'0206f3f2f742532386cfd752b1478145230d927e';
