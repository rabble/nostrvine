// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clip_count_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider that returns the current number of clips in the library.
/// Only counts clips where the video file still exists on disk.

@ProviderFor(clipCount)
const clipCountProvider = ClipCountProvider._();

/// Provider that returns the current number of clips in the library.
/// Only counts clips where the video file still exists on disk.

final class ClipCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// Provider that returns the current number of clips in the library.
  /// Only counts clips where the video file still exists on disk.
  const ClipCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clipCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clipCountHash();

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    return clipCount(ref);
  }
}

String _$clipCountHash() => r'f7f39a4a7d24bdbb6d08ea92d79f69fc92898f68';
