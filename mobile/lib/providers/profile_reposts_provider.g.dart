// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_reposts_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider that returns only the videos a user has reposted
///
/// Gets videos directly from videoEventService and filters for:
/// - isRepost == true
/// - reposterPubkey == userIdHex
///
/// This is independent from profileFeedProvider which only returns originals.

@ProviderFor(profileReposts)
const profileRepostsProvider = ProfileRepostsFamily._();

/// Provider that returns only the videos a user has reposted
///
/// Gets videos directly from videoEventService and filters for:
/// - isRepost == true
/// - reposterPubkey == userIdHex
///
/// This is independent from profileFeedProvider which only returns originals.

final class ProfileRepostsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<VideoEvent>>,
          List<VideoEvent>,
          FutureOr<List<VideoEvent>>
        >
    with $FutureModifier<List<VideoEvent>>, $FutureProvider<List<VideoEvent>> {
  /// Provider that returns only the videos a user has reposted
  ///
  /// Gets videos directly from videoEventService and filters for:
  /// - isRepost == true
  /// - reposterPubkey == userIdHex
  ///
  /// This is independent from profileFeedProvider which only returns originals.
  const ProfileRepostsProvider._({
    required ProfileRepostsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'profileRepostsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$profileRepostsHash();

  @override
  String toString() {
    return r'profileRepostsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<VideoEvent>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<VideoEvent>> create(Ref ref) {
    final argument = this.argument as String;
    return profileReposts(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ProfileRepostsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$profileRepostsHash() => r'6cd7fc7f3b63b4066befc65f6692b2ec1428d130';

/// Provider that returns only the videos a user has reposted
///
/// Gets videos directly from videoEventService and filters for:
/// - isRepost == true
/// - reposterPubkey == userIdHex
///
/// This is independent from profileFeedProvider which only returns originals.

final class ProfileRepostsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<VideoEvent>>, String> {
  const ProfileRepostsFamily._()
    : super(
        retry: null,
        name: r'profileRepostsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider that returns only the videos a user has reposted
  ///
  /// Gets videos directly from videoEventService and filters for:
  /// - isRepost == true
  /// - reposterPubkey == userIdHex
  ///
  /// This is independent from profileFeedProvider which only returns originals.

  ProfileRepostsProvider call(String userIdHex) =>
      ProfileRepostsProvider._(argument: userIdHex, from: this);

  @override
  String toString() => r'profileRepostsProvider';
}
