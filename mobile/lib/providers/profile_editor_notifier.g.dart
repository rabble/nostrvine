// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_editor_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the Profile Repository

@ProviderFor(profileRepository)
const profileRepositoryProvider = ProfileRepositoryProvider._();

/// Provides the Profile Repository

final class ProfileRepositoryProvider
    extends
        $FunctionalProvider<
          ProfileRepository,
          ProfileRepository,
          ProfileRepository
        >
    with $Provider<ProfileRepository> {
  /// Provides the Profile Repository
  const ProfileRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProfileRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProfileRepository create(Ref ref) {
    return profileRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProfileRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProfileRepository>(value),
    );
  }
}

String _$profileRepositoryHash() => r'7fda36d4a1658f0b742c4b176e1af9aee88fb8eb';

/// Notifier for orchestrating profile publishing and username claiming.
///
/// Handles the complete profile save flow:
/// 1. Publishes profile metadata (Kind 0) to Nostr relays
/// 2. Claims username via NIP-05 if provided
/// 3. Rolls back profile if username claim fails

@ProviderFor(ProfileEditorNotifier)
const profileEditorProvider = ProfileEditorNotifierProvider._();

/// Notifier for orchestrating profile publishing and username claiming.
///
/// Handles the complete profile save flow:
/// 1. Publishes profile metadata (Kind 0) to Nostr relays
/// 2. Claims username via NIP-05 if provided
/// 3. Rolls back profile if username claim fails
final class ProfileEditorNotifierProvider
    extends $AsyncNotifierProvider<ProfileEditorNotifier, ProfileSaveResult?> {
  /// Notifier for orchestrating profile publishing and username claiming.
  ///
  /// Handles the complete profile save flow:
  /// 1. Publishes profile metadata (Kind 0) to Nostr relays
  /// 2. Claims username via NIP-05 if provided
  /// 3. Rolls back profile if username claim fails
  const ProfileEditorNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileEditorProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileEditorNotifierHash();

  @$internal
  @override
  ProfileEditorNotifier create() => ProfileEditorNotifier();
}

String _$profileEditorNotifierHash() =>
    r'2ca0ab25c41abaf55817b214a459222531f2357b';

/// Notifier for orchestrating profile publishing and username claiming.
///
/// Handles the complete profile save flow:
/// 1. Publishes profile metadata (Kind 0) to Nostr relays
/// 2. Claims username via NIP-05 if provided
/// 3. Rolls back profile if username claim fails

abstract class _$ProfileEditorNotifier
    extends $AsyncNotifier<ProfileSaveResult?> {
  FutureOr<ProfileSaveResult?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<ProfileSaveResult?>, ProfileSaveResult?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ProfileSaveResult?>, ProfileSaveResult?>,
              AsyncValue<ProfileSaveResult?>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
