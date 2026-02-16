// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'watermark_download_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides a [WatermarkDownloadService] with injected dependencies.

@ProviderFor(watermarkDownloadService)
const watermarkDownloadServiceProvider = WatermarkDownloadServiceProvider._();

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
  const WatermarkDownloadServiceProvider._()
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
    r'90e0376eb0765575ba8d07e98c4a1aa550174df2';
