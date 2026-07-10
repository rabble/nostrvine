import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/blocs/storage/storage_cubit.dart';
import 'package:openvine/constants/storage_cache_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/storage_management_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as editor;

class _MockService extends Mock implements StorageManagementService {}

DivineVideoClip _clip(String id) => DivineVideoClip(
  id: id,
  video: editor.EditorVideo.file(File('/tmp/$id.mp4')),
  duration: const Duration(seconds: 3),
  recordedAt: DateTime(2024),
  targetAspectRatio: model.AspectRatio.square,
  originalAspectRatio: 1,
);

void main() {
  setUpAll(() => registerFallbackValue(<DivineVideoClip>[]));

  group(StorageCubit, () {
    late _MockService service;

    setUp(() => service = _MockService());

    StorageCubit build() => StorageCubit(service: service);

    group('loadCacheSize', () {
      // A non-default saved budget so the failure test proves the limit
      // survives a size-measurement failure rather than resetting to default.
      const savedLimit = 3 * 1024 * 1024 * 1024;

      blocTest<StorageCubit, StorageState>(
        'emits loading then ready with the size',
        setUp: () {
          when(service.cacheSizeBytes).thenAnswer((_) async => 2048);
          when(service.cacheLimitBytes).thenReturn(kCacheLimitDefaultBytes);
        },
        build: build,
        act: (cubit) => cubit.loadCacheSize(),
        expect: () => const [
          StorageState(cacheStatus: StorageCacheStatus.loading),
          StorageState(
            cacheStatus: StorageCacheStatus.ready,
            cacheSizeBytes: 2048,
          ),
        ],
      );

      blocTest<StorageCubit, StorageState>(
        'keeps the saved limit and emits failure when sizing throws',
        setUp: () {
          when(service.cacheLimitBytes).thenReturn(savedLimit);
          when(service.cacheSizeBytes).thenThrow(Exception('boom'));
        },
        build: build,
        act: (cubit) => cubit.loadCacheSize(),
        expect: () => const [
          StorageState(
            cacheStatus: StorageCacheStatus.loading,
            cacheLimitBytes: savedLimit,
          ),
          StorageState(
            cacheStatus: StorageCacheStatus.failure,
            cacheLimitBytes: savedLimit,
          ),
        ],
        errors: () => [isA<Exception>()],
      );
    });

    group('clearCaches', () {
      blocTest<StorageCubit, StorageState>(
        'emits clearing then ready with the refreshed size',
        setUp: () {
          when(service.clearCaches).thenAnswer((_) async {});
          when(service.cacheSizeBytes).thenAnswer((_) async => 0);
        },
        build: build,
        seed: () => const StorageState(cacheSizeBytes: 4096),
        act: (cubit) => cubit.clearCaches(),
        expect: () => const [
          StorageState(
            cacheStatus: StorageCacheStatus.clearing,
            cacheSizeBytes: 4096,
          ),
          StorageState(cacheStatus: StorageCacheStatus.cleared),
        ],
      );
    });

    group('scanLibrary', () {
      blocTest<StorageCubit, StorageState>(
        'emits scanning then scanned with the broken clips',
        setUp: () =>
            when(service.findBrokenClips).thenAnswer((_) async => [_clip('a')]),
        build: build,
        act: (cubit) => cubit.scanLibrary(),
        expect: () => [
          const StorageState(libraryStatus: StorageLibraryStatus.scanning),
          isA<StorageState>()
              .having(
                (s) => s.libraryStatus,
                'libraryStatus',
                StorageLibraryStatus.scanned,
              )
              .having((s) => s.brokenClips.map((c) => c.id), 'ids', ['a']),
        ],
      );
    });

    group('removeBrokenClips', () {
      blocTest<StorageCubit, StorageState>(
        'emits cleaning then cleaned and empties the list',
        setUp: () => when(
          () => service.removeBrokenClips(any()),
        ).thenAnswer((_) async {}),
        build: build,
        seed: () => StorageState(
          libraryStatus: StorageLibraryStatus.scanned,
          brokenClips: [_clip('a')],
        ),
        act: (cubit) => cubit.removeBrokenClips(),
        expect: () => [
          isA<StorageState>().having(
            (s) => s.libraryStatus,
            'status',
            StorageLibraryStatus.cleaning,
          ),
          const StorageState(libraryStatus: StorageLibraryStatus.cleaned),
        ],
      );

      blocTest<StorageCubit, StorageState>(
        'does nothing when there are no broken clips',
        build: build,
        act: (cubit) => cubit.removeBrokenClips(),
        expect: () => const <StorageState>[],
      );
    });

    group('cache limit', () {
      const oneGb = 1024 * 1024 * 1024;

      blocTest<StorageCubit, StorageState>(
        'previewCacheLimit updates the limit without persisting',
        build: build,
        act: (cubit) => cubit.previewCacheLimit(oneGb),
        expect: () => const [StorageState(cacheLimitBytes: oneGb)],
        verify: (_) => verifyNever(() => service.setCacheLimit(any())),
      );

      blocTest<StorageCubit, StorageState>(
        'commitCacheLimit persists the limit and refreshes the size',
        setUp: () {
          when(() => service.setCacheLimit(any())).thenAnswer((_) async {});
          when(service.cacheSizeBytes).thenAnswer((_) async => 512);
          when(service.cacheLimitBytes).thenReturn(oneGb);
        },
        build: build,
        act: (cubit) => cubit.commitCacheLimit(oneGb),
        expect: () => const [
          StorageState(
            cacheStatus: StorageCacheStatus.loading,
            cacheLimitBytes: oneGb,
          ),
          StorageState(
            cacheStatus: StorageCacheStatus.ready,
            cacheLimitBytes: oneGb,
            cacheSizeBytes: 512,
          ),
        ],
        verify: (_) => verify(() => service.setCacheLimit(oneGb)).called(1),
      );
    });
  });
}
