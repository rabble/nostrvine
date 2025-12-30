// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'social_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Social state notifier with reactive state management
/// keepAlive: true prevents disposal during async initialization and keeps following list cached
/// Note: Likes are now managed by LikesProvider (see likes_providers.dart)

@ProviderFor(SocialNotifier)
const socialProvider = SocialNotifierProvider._();

/// Social state notifier with reactive state management
/// keepAlive: true prevents disposal during async initialization and keeps following list cached
/// Note: Likes are now managed by LikesProvider (see likes_providers.dart)
final class SocialNotifierProvider
    extends $NotifierProvider<SocialNotifier, SocialState> {
  /// Social state notifier with reactive state management
  /// keepAlive: true prevents disposal during async initialization and keeps following list cached
  /// Note: Likes are now managed by LikesProvider (see likes_providers.dart)
  const SocialNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'socialProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$socialNotifierHash();

  @$internal
  @override
  SocialNotifier create() => SocialNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SocialState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SocialState>(value),
    );
  }
}

String _$socialNotifierHash() => r'c07dc6fe0826b103053eee453df9e91fab99e9a0';

/// Social state notifier with reactive state management
/// keepAlive: true prevents disposal during async initialization and keeps following list cached
/// Note: Likes are now managed by LikesProvider (see likes_providers.dart)

abstract class _$SocialNotifier extends $Notifier<SocialState> {
  SocialState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<SocialState, SocialState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SocialState, SocialState>,
              SocialState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
