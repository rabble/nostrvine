// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'likes_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Main likes state notifier
///
/// Manages the reactive state for likes feature, providing:
/// - Like/unlike operations
/// - Sync with relays on startup
/// - Reactive stream of liked event IDs
/// - Like count queries
///
/// Usage:
/// ```dart
/// // Watch likes state
/// final likesState = ref.watch(likesProvider);
///
/// // Check if event is liked
/// final isLiked = likesState.isLiked(eventId);
///
/// // Toggle like
/// await ref.read(likesProvider.notifier).toggleLike(
///   eventId: eventId,
///   authorPubkey: authorPubkey,
/// );
/// ```

@ProviderFor(LikesNotifier)
const likesProvider = LikesNotifierProvider._();

/// Main likes state notifier
///
/// Manages the reactive state for likes feature, providing:
/// - Like/unlike operations
/// - Sync with relays on startup
/// - Reactive stream of liked event IDs
/// - Like count queries
///
/// Usage:
/// ```dart
/// // Watch likes state
/// final likesState = ref.watch(likesProvider);
///
/// // Check if event is liked
/// final isLiked = likesState.isLiked(eventId);
///
/// // Toggle like
/// await ref.read(likesProvider.notifier).toggleLike(
///   eventId: eventId,
///   authorPubkey: authorPubkey,
/// );
/// ```
final class LikesNotifierProvider
    extends $NotifierProvider<LikesNotifier, LikesState> {
  /// Main likes state notifier
  ///
  /// Manages the reactive state for likes feature, providing:
  /// - Like/unlike operations
  /// - Sync with relays on startup
  /// - Reactive stream of liked event IDs
  /// - Like count queries
  ///
  /// Usage:
  /// ```dart
  /// // Watch likes state
  /// final likesState = ref.watch(likesProvider);
  ///
  /// // Check if event is liked
  /// final isLiked = likesState.isLiked(eventId);
  ///
  /// // Toggle like
  /// await ref.read(likesProvider.notifier).toggleLike(
  ///   eventId: eventId,
  ///   authorPubkey: authorPubkey,
  /// );
  /// ```
  const LikesNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'likesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$likesNotifierHash();

  @$internal
  @override
  LikesNotifier create() => LikesNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LikesState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LikesState>(value),
    );
  }
}

String _$likesNotifierHash() => r'b45a93a89d773a8af6761459d9f5f84ff79fb359';

/// Main likes state notifier
///
/// Manages the reactive state for likes feature, providing:
/// - Like/unlike operations
/// - Sync with relays on startup
/// - Reactive stream of liked event IDs
/// - Like count queries
///
/// Usage:
/// ```dart
/// // Watch likes state
/// final likesState = ref.watch(likesProvider);
///
/// // Check if event is liked
/// final isLiked = likesState.isLiked(eventId);
///
/// // Toggle like
/// await ref.read(likesProvider.notifier).toggleLike(
///   eventId: eventId,
///   authorPubkey: authorPubkey,
/// );
/// ```

abstract class _$LikesNotifier extends $Notifier<LikesState> {
  LikesState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<LikesState, LikesState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LikesState, LikesState>,
              LikesState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Convenience provider to check if a specific event is liked

@ProviderFor(isEventLiked)
const isEventLikedProvider = IsEventLikedFamily._();

/// Convenience provider to check if a specific event is liked

final class IsEventLikedProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Convenience provider to check if a specific event is liked
  const IsEventLikedProvider._({
    required IsEventLikedFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'isEventLikedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$isEventLikedHash();

  @override
  String toString() {
    return r'isEventLikedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    final argument = this.argument as String;
    return isEventLiked(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is IsEventLikedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$isEventLikedHash() => r'1e0e8bd04a0235604878b509dd07312ec680dfe8';

/// Convenience provider to check if a specific event is liked

final class IsEventLikedFamily extends $Family
    with $FunctionalFamilyOverride<bool, String> {
  const IsEventLikedFamily._()
    : super(
        retry: null,
        name: r'isEventLikedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Convenience provider to check if a specific event is liked

  IsEventLikedProvider call(String eventId) =>
      IsEventLikedProvider._(argument: eventId, from: this);

  @override
  String toString() => r'isEventLikedProvider';
}

/// Convenience provider to check if a like operation is in progress

@ProviderFor(isLikeInProgress)
const isLikeInProgressProvider = IsLikeInProgressFamily._();

/// Convenience provider to check if a like operation is in progress

final class IsLikeInProgressProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Convenience provider to check if a like operation is in progress
  const IsLikeInProgressProvider._({
    required IsLikeInProgressFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'isLikeInProgressProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$isLikeInProgressHash();

  @override
  String toString() {
    return r'isLikeInProgressProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    final argument = this.argument as String;
    return isLikeInProgress(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is IsLikeInProgressProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$isLikeInProgressHash() => r'3456f3be39a7eb837472d1ac11293b81fff9eec7';

/// Convenience provider to check if a like operation is in progress

final class IsLikeInProgressFamily extends $Family
    with $FunctionalFamilyOverride<bool, String> {
  const IsLikeInProgressFamily._()
    : super(
        retry: null,
        name: r'isLikeInProgressProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Convenience provider to check if a like operation is in progress

  IsLikeInProgressProvider call(String eventId) =>
      IsLikeInProgressProvider._(argument: eventId, from: this);

  @override
  String toString() => r'isLikeInProgressProvider';
}

/// Provider to get the cached like count for an event

@ProviderFor(likeCount)
const likeCountProvider = LikeCountFamily._();

/// Provider to get the cached like count for an event

final class LikeCountProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// Provider to get the cached like count for an event
  const LikeCountProvider._({
    required LikeCountFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'likeCountProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$likeCountHash();

  @override
  String toString() {
    return r'likeCountProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    final argument = this.argument as String;
    return likeCount(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LikeCountProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$likeCountHash() => r'6b6efd6d2ce0e2588c7412e82573038f19bdb896';

/// Provider to get the cached like count for an event

final class LikeCountFamily extends $Family
    with $FunctionalFamilyOverride<int, String> {
  const LikeCountFamily._()
    : super(
        retry: null,
        name: r'likeCountProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider to get the cached like count for an event

  LikeCountProvider call(String eventId) =>
      LikeCountProvider._(argument: eventId, from: this);

  @override
  String toString() => r'likeCountProvider';
}
