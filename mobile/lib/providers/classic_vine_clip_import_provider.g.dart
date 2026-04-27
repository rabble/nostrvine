// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'classic_vine_clip_import_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(classicVineClipImportService)
const classicVineClipImportServiceProvider =
    ClassicVineClipImportServiceProvider._();

final class ClassicVineClipImportServiceProvider
    extends
        $FunctionalProvider<
          ClassicVineClipImportService,
          ClassicVineClipImportService,
          ClassicVineClipImportService
        >
    with $Provider<ClassicVineClipImportService> {
  const ClassicVineClipImportServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'classicVineClipImportServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$classicVineClipImportServiceHash();

  @$internal
  @override
  $ProviderElement<ClassicVineClipImportService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ClassicVineClipImportService create(Ref ref) {
    return classicVineClipImportService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ClassicVineClipImportService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ClassicVineClipImportService>(value),
    );
  }
}

String _$classicVineClipImportServiceHash() =>
    r'64250ea18488f7c7fcb48794b38ec7d167ec439a';
