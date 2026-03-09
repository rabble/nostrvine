import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/mocks.dart';
import 'helpers/test_helpers.dart';

void main() {
  setUpTestEnvironment();

  group('SafeCacheInfoRepository', () {
    late MockCacheInfoRepository mockRepository;
    late Directory testDirectory;

    setUpAll(() async {
      await setUpTestDirectories();
    });

    tearDownAll(() async {
      await tearDownTestDirectories();
    });

    setUp(() {
      mockRepository = MockCacheInfoRepository();
      testDirectory = Directory(testSupportPath);
    });

    test('can be instantiated with default dependencies', () {
      final repo = SafeCacheInfoRepository(databaseName: 'test_db');
      expect(repo, isNotNull);
    });

    test('can be instantiated with injected dependencies', () {
      final repo = SafeCacheInfoRepository(
        databaseName: 'test_db',
        repository: mockRepository,
        directoryProvider: () async => testDirectory,
      );

      expect(repo, isNotNull);
      expect(repo.repository, same(mockRepository));
    });

    group('open', () {
      test('delegates to wrapped repository on success', () async {
        when(() => mockRepository.open()).thenAnswer((_) async => true);

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db',
          repository: mockRepository,
          directoryProvider: () async => testDirectory,
        );

        final result = await repo.open();

        expect(result, true);
        verify(() => mockRepository.open()).called(1);
      });

      test('deletes cache file and retries on FormatException', () async {
        var openCallCount = 0;
        when(() => mockRepository.open()).thenAnswer((_) async {
          openCallCount++;
          if (openCallCount == 1) {
            throw const FormatException('corrupted JSON');
          }
          return true;
        });

        // Create a corrupted cache file
        final cacheFile = File('$testSupportPath/test_db.json');
        await cacheFile.writeAsString('{ corrupted }');
        expect(cacheFile.existsSync(), true);

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db',
          repository: mockRepository,
          directoryProvider: () async => testDirectory,
        );

        final result = await repo.open();

        expect(result, true);
        expect(openCallCount, 2); // Called twice: fail then retry
        expect(cacheFile.existsSync(), false); // File was deleted
      });

      test(
        'deletes cache file and retries on Unexpected end of input',
        () async {
          var openCallCount = 0;
          when(() => mockRepository.open()).thenAnswer((_) async {
            openCallCount++;
            if (openCallCount == 1) {
              throw Exception('Unexpected end of input');
            }
            return true;
          });

          // Create a cache file
          final cacheFile = File('$testSupportPath/test_db2.json');
          await cacheFile.writeAsString('');
          expect(cacheFile.existsSync(), true);

          final repo = SafeCacheInfoRepository(
            databaseName: 'test_db2',
            repository: mockRepository,
            directoryProvider: () async => testDirectory,
          );

          final result = await repo.open();

          expect(result, true);
          expect(openCallCount, 2);
          expect(cacheFile.existsSync(), false);
        },
      );

      test('deletes cache file and retries on type Null exception', () async {
        var openCallCount = 0;
        when(() => mockRepository.open()).thenAnswer((_) async {
          openCallCount++;
          if (openCallCount == 1) {
            throw Exception("type 'Null' is not a subtype of type 'Map'");
          }
          return true;
        });

        // Create a cache file
        final cacheFile = File('$testSupportPath/test_db3.json');
        await cacheFile.writeAsString('null');
        expect(cacheFile.existsSync(), true);

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db3',
          repository: mockRepository,
          directoryProvider: () async => testDirectory,
        );

        final result = await repo.open();

        expect(result, true);
        expect(openCallCount, 2);
        expect(cacheFile.existsSync(), false);
      });

      test(
        'recovers when upstream reports via FlutterError instead of throwing',
        () async {
          // This tests the real-world scenario: JsonCacheInfoRepository
          // catches exceptions internally and reports via
          // FlutterError.reportError instead of rethrowing.
          var openCallCount = 0;
          when(() => mockRepository.open()).thenAnswer((_) async {
            openCallCount++;
            if (openCallCount == 1) {
              // Simulate upstream behavior: report via FlutterError, not throw
              FlutterError.reportError(
                FlutterErrorDetails(
                  exception: const FormatException('Unexpected end of input'),
                  library: 'flutter cache manager',
                  context: ErrorDescription('Reading cache info file'),
                ),
              );
              return true; // Upstream returns normally after reporting
            }
            return true;
          });

          final cacheFile = File('$testSupportPath/test_flutter_error.json');
          await cacheFile.writeAsString('{"truncated":');

          FlutterErrorDetails? capturedError;
          final previousHandler = FlutterError.onError;
          FlutterError.onError = (details) {
            capturedError = details;
          };

          try {
            final repo = SafeCacheInfoRepository(
              databaseName: 'test_flutter_error',
              repository: mockRepository,
              directoryProvider: () async => testDirectory,
            );

            await repo.open();

            // File should be deleted
            expect(cacheFile.existsSync(), isFalse);
            // FlutterError should NOT have leaked to outer handler
            expect(capturedError, isNull);
            // open called twice: first detects corruption, second is retry
            expect(openCallCount, equals(2));
          } finally {
            FlutterError.onError = previousHandler;
          }
        },
      );

      test(
        'forwards non-cache FlutterErrors to previous handler during open',
        () async {
          when(() => mockRepository.open()).thenAnswer((_) async {
            // Simulate a non-cache FlutterError during open
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: Exception('some rendering error'),
                library: 'rendering library',
                context: ErrorDescription('during layout'),
              ),
            );
            return true;
          });

          FlutterErrorDetails? forwardedError;
          final previousHandler = FlutterError.onError;
          FlutterError.onError = (details) {
            forwardedError = details;
          };

          try {
            final repo = SafeCacheInfoRepository(
              databaseName: 'test_forward',
              repository: mockRepository,
              directoryProvider: () async => testDirectory,
            );

            await repo.open();

            // Non-cache error should have been forwarded to previous handler
            expect(forwardedError, isNotNull);
            expect(
              forwardedError!.library,
              equals('rendering library'),
            );
          } finally {
            FlutterError.onError = previousHandler;
          }
        },
      );

      test('rethrows non-recoverable exceptions', () async {
        when(() => mockRepository.open()).thenThrow(
          Exception('Some other error'),
        );

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db',
          repository: mockRepository,
          directoryProvider: () async => testDirectory,
        );

        expect(
          repo.open,
          throwsA(isA<Exception>()),
        );
      });

      test('handles missing cache file gracefully during deletion', () async {
        var openCallCount = 0;
        when(() => mockRepository.open()).thenAnswer((_) async {
          openCallCount++;
          if (openCallCount == 1) {
            throw const FormatException('corrupted');
          }
          return true;
        });

        // Don't create a cache file - it doesn't exist
        final cacheFile = File('$testSupportPath/nonexistent.json');
        expect(cacheFile.existsSync(), false);

        final repo = SafeCacheInfoRepository(
          databaseName: 'nonexistent',
          repository: mockRepository,
          directoryProvider: () async => testDirectory,
        );

        // Should not throw even when file doesn't exist
        final result = await repo.open();
        expect(result, true);
      });
    });

    group('deleteCacheFile', () {
      test('deletes existing cache file', () async {
        final cacheFile = File('$testSupportPath/delete_test.json');
        await cacheFile.writeAsString('test content');
        expect(cacheFile.existsSync(), true);

        final repo = SafeCacheInfoRepository(
          databaseName: 'delete_test',
          repository: mockRepository,
          directoryProvider: () async => testDirectory,
        );

        await repo.deleteCacheFile();

        expect(cacheFile.existsSync(), false);
      });

      test('does nothing when cache file does not exist', () async {
        final cacheFile = File('$testSupportPath/no_file.json');
        expect(cacheFile.existsSync(), false);

        final repo = SafeCacheInfoRepository(
          databaseName: 'no_file',
          repository: mockRepository,
          directoryProvider: () async => testDirectory,
        );

        // Should not throw
        await repo.deleteCacheFile();
        expect(cacheFile.existsSync(), false);
      });
    });

    group('delegation', () {
      test('close delegates to wrapped repository', () async {
        when(() => mockRepository.close()).thenAnswer((_) async => true);

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db',
          repository: mockRepository,
        );

        final result = await repo.close();

        expect(result, true);
        verify(() => mockRepository.close()).called(1);
      });

      test('exists delegates to wrapped repository', () async {
        when(() => mockRepository.exists()).thenAnswer((_) async => true);

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db',
          repository: mockRepository,
        );

        final result = await repo.exists();

        expect(result, true);
        verify(() => mockRepository.exists()).called(1);
      });

      test('get delegates to wrapped repository', () async {
        when(() => mockRepository.get('key')).thenAnswer((_) async => null);

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db',
          repository: mockRepository,
        );

        final result = await repo.get('key');

        expect(result, isNull);
        verify(() => mockRepository.get('key')).called(1);
      });

      test('getAllObjects delegates to wrapped repository', () async {
        when(() => mockRepository.getAllObjects()).thenAnswer((_) async => []);

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db',
          repository: mockRepository,
        );

        final result = await repo.getAllObjects();

        expect(result, isEmpty);
        verify(() => mockRepository.getAllObjects()).called(1);
      });

      test('delete delegates to wrapped repository', () async {
        when(() => mockRepository.delete(1)).thenAnswer((_) async => 1);

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db',
          repository: mockRepository,
        );

        final result = await repo.delete(1);

        expect(result, 1);
        verify(() => mockRepository.delete(1)).called(1);
      });

      test('deleteAll delegates to wrapped repository', () async {
        when(() => mockRepository.deleteAll([1, 2])).thenAnswer((_) async => 2);

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db',
          repository: mockRepository,
        );

        final result = await repo.deleteAll([1, 2]);

        expect(result, 2);
        verify(() => mockRepository.deleteAll([1, 2])).called(1);
      });

      test('deleteDataFile delegates to wrapped repository', () async {
        when(() => mockRepository.deleteDataFile()).thenAnswer((_) async {});

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db',
          repository: mockRepository,
        );

        await repo.deleteDataFile();

        verify(() => mockRepository.deleteDataFile()).called(1);
      });

      test('getObjectsOverCapacity delegates to wrapped repository', () async {
        when(
          () => mockRepository.getObjectsOverCapacity(100),
        ).thenAnswer((_) async => []);

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db',
          repository: mockRepository,
        );

        final result = await repo.getObjectsOverCapacity(100);

        expect(result, isEmpty);
        verify(() => mockRepository.getObjectsOverCapacity(100)).called(1);
      });

      test('getOldObjects delegates to wrapped repository', () async {
        const maxAge = Duration(days: 7);
        when(
          () => mockRepository.getOldObjects(maxAge),
        ).thenAnswer((_) async => []);

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db',
          repository: mockRepository,
        );

        final result = await repo.getOldObjects(maxAge);

        expect(result, isEmpty);
        verify(() => mockRepository.getOldObjects(maxAge)).called(1);
      });

      test('insert delegates to wrapped repository', () async {
        final cacheObject = CacheObject(
          'test_url',
          relativePath: 'test.mp4',
          validTill: DateTime.now().add(const Duration(days: 7)),
        );
        when(
          () => mockRepository.insert(cacheObject),
        ).thenAnswer((_) async => cacheObject);

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db',
          repository: mockRepository,
        );

        final result = await repo.insert(cacheObject);

        expect(result, cacheObject);
        verify(
          () => mockRepository.insert(cacheObject),
        ).called(1);
      });

      test('update delegates to wrapped repository', () async {
        final cacheObject = CacheObject(
          'test_url',
          relativePath: 'test.mp4',
          validTill: DateTime.now().add(const Duration(days: 7)),
        );
        when(
          () => mockRepository.update(cacheObject),
        ).thenAnswer((_) async => 1);

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db',
          repository: mockRepository,
        );

        final result = await repo.update(cacheObject);

        expect(result, 1);
        verify(
          () => mockRepository.update(cacheObject),
        ).called(1);
      });

      test('updateOrInsert delegates to wrapped repository', () async {
        final cacheObject = CacheObject(
          'test_url',
          relativePath: 'test.mp4',
          validTill: DateTime.now().add(const Duration(days: 7)),
        );
        when(
          () => mockRepository.updateOrInsert(cacheObject),
        ).thenAnswer((_) async => cacheObject);

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db',
          repository: mockRepository,
        );

        final result = await repo.updateOrInsert(cacheObject);

        expect(result, cacheObject);
        verify(() => mockRepository.updateOrInsert(cacheObject)).called(1);
      });
    });
  });
}
