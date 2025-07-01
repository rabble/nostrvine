// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_manager_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$videoManagerConfigHash() =>
    r'd933b857778eacc30b1e1154f769fd006fe4aba5';

/// Configuration provider for video manager settings
///
/// Copied from [videoManagerConfig].
@ProviderFor(videoManagerConfig)
final videoManagerConfigProvider =
    AutoDisposeProvider<VideoManagerConfig>.internal(
  videoManagerConfig,
  name: r'videoManagerConfigProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$videoManagerConfigHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef VideoManagerConfigRef = AutoDisposeProviderRef<VideoManagerConfig>;
String _$videoPlayerControllerHash() =>
    r'e3114ca84f715c1cde9bd9f55ffc4185efbc1b77';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Helper provider to get video player controller by ID
///
/// Copied from [videoPlayerController].
@ProviderFor(videoPlayerController)
const videoPlayerControllerProvider = VideoPlayerControllerFamily();

/// Helper provider to get video player controller by ID
///
/// Copied from [videoPlayerController].
class VideoPlayerControllerFamily extends Family<VideoPlayerController?> {
  /// Helper provider to get video player controller by ID
  ///
  /// Copied from [videoPlayerController].
  const VideoPlayerControllerFamily();

  /// Helper provider to get video player controller by ID
  ///
  /// Copied from [videoPlayerController].
  VideoPlayerControllerProvider call(
    String videoId,
  ) {
    return VideoPlayerControllerProvider(
      videoId,
    );
  }

  @override
  VideoPlayerControllerProvider getProviderOverride(
    covariant VideoPlayerControllerProvider provider,
  ) {
    return call(
      provider.videoId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'videoPlayerControllerProvider';
}

/// Helper provider to get video player controller by ID
///
/// Copied from [videoPlayerController].
class VideoPlayerControllerProvider
    extends AutoDisposeProvider<VideoPlayerController?> {
  /// Helper provider to get video player controller by ID
  ///
  /// Copied from [videoPlayerController].
  VideoPlayerControllerProvider(
    String videoId,
  ) : this._internal(
          (ref) => videoPlayerController(
            ref as VideoPlayerControllerRef,
            videoId,
          ),
          from: videoPlayerControllerProvider,
          name: r'videoPlayerControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$videoPlayerControllerHash,
          dependencies: VideoPlayerControllerFamily._dependencies,
          allTransitiveDependencies:
              VideoPlayerControllerFamily._allTransitiveDependencies,
          videoId: videoId,
        );

  VideoPlayerControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.videoId,
  }) : super.internal();

  final String videoId;

  @override
  Override overrideWith(
    VideoPlayerController? Function(VideoPlayerControllerRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: VideoPlayerControllerProvider._internal(
        (ref) => create(ref as VideoPlayerControllerRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        videoId: videoId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<VideoPlayerController?> createElement() {
    return _VideoPlayerControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is VideoPlayerControllerProvider && other.videoId == videoId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, videoId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin VideoPlayerControllerRef
    on AutoDisposeProviderRef<VideoPlayerController?> {
  /// The parameter `videoId` of this provider.
  String get videoId;
}

class _VideoPlayerControllerProviderElement
    extends AutoDisposeProviderElement<VideoPlayerController?>
    with VideoPlayerControllerRef {
  _VideoPlayerControllerProviderElement(super.provider);

  @override
  String get videoId => (origin as VideoPlayerControllerProvider).videoId;
}

String _$videoStateByIdHash() => r'bb38c37a823ea88dec58319572f4b77716cef2a6';

/// Helper provider to get video state by ID
///
/// Copied from [videoStateById].
@ProviderFor(videoStateById)
const videoStateByIdProvider = VideoStateByIdFamily();

/// Helper provider to get video state by ID
///
/// Copied from [videoStateById].
class VideoStateByIdFamily extends Family<VideoState?> {
  /// Helper provider to get video state by ID
  ///
  /// Copied from [videoStateById].
  const VideoStateByIdFamily();

  /// Helper provider to get video state by ID
  ///
  /// Copied from [videoStateById].
  VideoStateByIdProvider call(
    String videoId,
  ) {
    return VideoStateByIdProvider(
      videoId,
    );
  }

  @override
  VideoStateByIdProvider getProviderOverride(
    covariant VideoStateByIdProvider provider,
  ) {
    return call(
      provider.videoId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'videoStateByIdProvider';
}

/// Helper provider to get video state by ID
///
/// Copied from [videoStateById].
class VideoStateByIdProvider extends AutoDisposeProvider<VideoState?> {
  /// Helper provider to get video state by ID
  ///
  /// Copied from [videoStateById].
  VideoStateByIdProvider(
    String videoId,
  ) : this._internal(
          (ref) => videoStateById(
            ref as VideoStateByIdRef,
            videoId,
          ),
          from: videoStateByIdProvider,
          name: r'videoStateByIdProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$videoStateByIdHash,
          dependencies: VideoStateByIdFamily._dependencies,
          allTransitiveDependencies:
              VideoStateByIdFamily._allTransitiveDependencies,
          videoId: videoId,
        );

  VideoStateByIdProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.videoId,
  }) : super.internal();

  final String videoId;

  @override
  Override overrideWith(
    VideoState? Function(VideoStateByIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: VideoStateByIdProvider._internal(
        (ref) => create(ref as VideoStateByIdRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        videoId: videoId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<VideoState?> createElement() {
    return _VideoStateByIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is VideoStateByIdProvider && other.videoId == videoId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, videoId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin VideoStateByIdRef on AutoDisposeProviderRef<VideoState?> {
  /// The parameter `videoId` of this provider.
  String get videoId;
}

class _VideoStateByIdProviderElement
    extends AutoDisposeProviderElement<VideoState?> with VideoStateByIdRef {
  _VideoStateByIdProviderElement(super.provider);

  @override
  String get videoId => (origin as VideoStateByIdProvider).videoId;
}

String _$isVideoReadyHash() => r'21fd2124143539c90065cf3955fa32813d252601';

/// Helper provider to check if video is ready
///
/// Copied from [isVideoReady].
@ProviderFor(isVideoReady)
const isVideoReadyProvider = IsVideoReadyFamily();

/// Helper provider to check if video is ready
///
/// Copied from [isVideoReady].
class IsVideoReadyFamily extends Family<bool> {
  /// Helper provider to check if video is ready
  ///
  /// Copied from [isVideoReady].
  const IsVideoReadyFamily();

  /// Helper provider to check if video is ready
  ///
  /// Copied from [isVideoReady].
  IsVideoReadyProvider call(
    String videoId,
  ) {
    return IsVideoReadyProvider(
      videoId,
    );
  }

  @override
  IsVideoReadyProvider getProviderOverride(
    covariant IsVideoReadyProvider provider,
  ) {
    return call(
      provider.videoId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'isVideoReadyProvider';
}

/// Helper provider to check if video is ready
///
/// Copied from [isVideoReady].
class IsVideoReadyProvider extends AutoDisposeProvider<bool> {
  /// Helper provider to check if video is ready
  ///
  /// Copied from [isVideoReady].
  IsVideoReadyProvider(
    String videoId,
  ) : this._internal(
          (ref) => isVideoReady(
            ref as IsVideoReadyRef,
            videoId,
          ),
          from: isVideoReadyProvider,
          name: r'isVideoReadyProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$isVideoReadyHash,
          dependencies: IsVideoReadyFamily._dependencies,
          allTransitiveDependencies:
              IsVideoReadyFamily._allTransitiveDependencies,
          videoId: videoId,
        );

  IsVideoReadyProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.videoId,
  }) : super.internal();

  final String videoId;

  @override
  Override overrideWith(
    bool Function(IsVideoReadyRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: IsVideoReadyProvider._internal(
        (ref) => create(ref as IsVideoReadyRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        videoId: videoId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<bool> createElement() {
    return _IsVideoReadyProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is IsVideoReadyProvider && other.videoId == videoId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, videoId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin IsVideoReadyRef on AutoDisposeProviderRef<bool> {
  /// The parameter `videoId` of this provider.
  String get videoId;
}

class _IsVideoReadyProviderElement extends AutoDisposeProviderElement<bool>
    with IsVideoReadyRef {
  _IsVideoReadyProviderElement(super.provider);

  @override
  String get videoId => (origin as IsVideoReadyProvider).videoId;
}

String _$videoMemoryStatsHash() => r'c095e323920409b650c92f103f4d1307da644409';

/// Helper provider for memory statistics
///
/// Copied from [videoMemoryStats].
@ProviderFor(videoMemoryStats)
final videoMemoryStatsProvider = AutoDisposeProvider<VideoMemoryStats>.internal(
  videoMemoryStats,
  name: r'videoMemoryStatsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$videoMemoryStatsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef VideoMemoryStatsRef = AutoDisposeProviderRef<VideoMemoryStats>;
String _$videoManagerDebugInfoHash() =>
    r'4dcc8b772e6521f86da842365c228fc7b571d617';

/// Helper provider for debug information
///
/// Copied from [videoManagerDebugInfo].
@ProviderFor(videoManagerDebugInfo)
final videoManagerDebugInfoProvider =
    AutoDisposeProvider<Map<String, dynamic>>.internal(
  videoManagerDebugInfo,
  name: r'videoManagerDebugInfoProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$videoManagerDebugInfoHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef VideoManagerDebugInfoRef = AutoDisposeProviderRef<Map<String, dynamic>>;
String _$videoManagerHash() => r'1edbfe4dbd2edce4374912d757fcc2dd58a303a6';

/// Main Riverpod video manager provider
///
/// Copied from [VideoManager].
@ProviderFor(VideoManager)
final videoManagerProvider =
    AutoDisposeNotifierProvider<VideoManager, VideoManagerState>.internal(
  VideoManager.new,
  name: r'videoManagerProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$videoManagerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$VideoManager = AutoDisposeNotifier<VideoManagerState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
