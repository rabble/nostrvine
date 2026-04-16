// ABOUTME: Tests for CategoriesRepository
// ABOUTME: Verifies caching, cache invalidation, and featured-first ordering

import 'package:categories_repository/categories_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show VideoCategory;
import 'package:test/test.dart';

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

void main() {
  group(CategoriesRepository, () {
    late _MockFunnelcakeApiClient apiClient;
    late CategoriesRepository repository;

    setUp(() {
      apiClient = _MockFunnelcakeApiClient();
      repository = CategoriesRepository(
        funnelcakeApiClient: apiClient,
      );
    });

    const sampleCategories = <VideoCategory>[
      VideoCategory(name: 'comedy', videoCount: 500),
      VideoCategory(name: 'animals', videoCount: 300),
      VideoCategory(name: 'music', videoCount: 200),
    ];

    group('getCategories', () {
      test('fetches categories from API', () async {
        when(
          () => apiClient.getCategories(limit: 100),
        ).thenAnswer((_) async => sampleCategories);

        final result = await repository.getCategories();

        expect(result, hasLength(3));
        verify(() => apiClient.getCategories(limit: 100)).called(1);
      });

      test('returns cached result on second call', () async {
        when(
          () => apiClient.getCategories(limit: 100),
        ).thenAnswer((_) async => sampleCategories);

        await repository.getCategories();
        await repository.getCategories();

        verify(() => apiClient.getCategories(limit: 100)).called(1);
      });

      test('bypasses cache when forceRefresh is true', () async {
        when(
          () => apiClient.getCategories(limit: 100),
        ).thenAnswer((_) async => sampleCategories);

        await repository.getCategories();
        await repository.getCategories(forceRefresh: true);

        verify(
          () => apiClient.getCategories(limit: 100),
        ).called(2);
      });

      test('filters out empty names', () async {
        when(
          () => apiClient.getCategories(limit: 100),
        ).thenAnswer(
          (_) async => const [
            VideoCategory(name: 'comedy', videoCount: 500),
            VideoCategory(name: '', videoCount: 100),
          ],
        );

        final result = await repository.getCategories();

        expect(result, hasLength(1));
        expect(result.first.name, equals('comedy'));
      });

      test('filters out zero video counts', () async {
        when(
          () => apiClient.getCategories(limit: 100),
        ).thenAnswer(
          (_) async => const [
            VideoCategory(name: 'comedy', videoCount: 500),
            VideoCategory(name: 'empty', videoCount: 0),
          ],
        );

        final result = await repository.getCategories();

        expect(result, hasLength(1));
      });

      test('sorts featured categories first', () async {
        when(
          () => apiClient.getCategories(limit: 100),
        ).thenAnswer(
          (_) async => const [
            VideoCategory(name: 'comedy', videoCount: 500),
            VideoCategory(name: 'animals', videoCount: 300),
            VideoCategory(name: 'unknown_category', videoCount: 100),
          ],
        );

        final result = await repository.getCategories();

        // 'animals' is featured, so should come first
        expect(result.first.name, equals('animals'));
      });
    });

    group('invalidateCache', () {
      test('clears cache so next call fetches fresh data', () async {
        when(
          () => apiClient.getCategories(limit: 100),
        ).thenAnswer((_) async => sampleCategories);

        await repository.getCategories();
        repository.invalidateCache();
        await repository.getCategories();

        verify(
          () => apiClient.getCategories(limit: 100),
        ).called(2);
      });
    });

    group('apiClient', () {
      test('exposes the underlying API client', () {
        expect(repository.apiClient, equals(apiClient));
      });
    });
  });
}
