// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'watermark_download_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides a [WatermarkDownloadService] with injected dependencies.

@ProviderFor(watermarkDownloadService)
final watermarkDownloadServiceProvider = WatermarkDownloadServiceProvider._();

/// Provides a [WatermarkDownloadService] with injected dependencies.

final class WatermarkDownloadServiceProvider
    extends
        $FunctionalProvider<
          WatermarkDownloadService,
          WatermarkDownloadService,
          WatermarkDownloadService
        >
    with $Provider<WatermarkDownloadService> {
  /// Provides a [WatermarkDownloadService] with injected dependencies.
  WatermarkDownloadServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'watermarkDownloadServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$watermarkDownloadServiceHash();

  @$internal
  @override
  $ProviderElement<WatermarkDownloadService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WatermarkDownloadService create(Ref ref) {
    return watermarkDownloadService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WatermarkDownloadService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WatermarkDownloadService>(value),
    );
  }
}

String _$watermarkDownloadServiceHash() =>
    r'7b6bfd4ec13343e0d7305340455dc2c41b6768ef';
