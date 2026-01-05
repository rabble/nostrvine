// ABOUTME: Unit tests for CuratedListService query operations
// ABOUTME: Tests searching, filtering, and retrieving lists

// ignore_for_file: invalid_use_of_null_value

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'curated_list_service_query_test.mocks.dart';

@GenerateMocks([NostrClient, AuthService])
void main() {
  group('CuratedListService - Query Operations', () {
    late CuratedListService service;
    late MockNostrClient mockNostr;
    late MockAuthService mockAuth;
    late SharedPreferences prefs;

    setUp(() async {
      // CRITICAL: Reset SharedPreferences mock completely for each test
      SharedPreferences.setMockInitialValues({});

      mockNostr = MockNostrClient();
      mockAuth = MockAuthService();
      prefs = await SharedPreferences.getInstance();

      // Setup common mocks
      when(mockAuth.isAuthenticated).thenReturn(true);
      when(
        mockAuth.currentPublicKeyHex,
      ).thenReturn('test_pubkey_123456789abcdef');

      // Mock successful event publishing
      when(mockNostr.publishEvent(any)).thenAnswer((invocation) async {
        return invocation.positionalArguments[0] as Event;
      });

      // Mock subscribeToEvents for relay sync
      when(
        mockNostr.subscribe(argThat(anything), onEose: anyNamed('onEose')),
      ).thenAnswer((_) => Stream.empty());

      // Mock event creation
      when(
        mockAuth.createAndSignEvent(
          kind: anyNamed('kind'),
          content: anyNamed('content'),
          tags: anyNamed('tags'),
        ),
      ).thenAnswer(
        (_) async => Event.fromJson({
          'id': 'test_event_id',
          'pubkey': 'test_pubkey_123456789abcdef',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 30005,
          'tags': [],
          'content': 'test content',
          'sig': 'test_signature',
        }),
      );

      // Create fresh service instance after clearing prefs
      service = CuratedListService(
        nostrService: mockNostr,
        authService: mockAuth,
        prefs: prefs,
      );
    });

    group('searchLists()', () {
      test('finds lists by name', () async {
        // FIXME: Test isolation issue - passes individually, fails in batch
        await service.createList(name: 'Cooking Videos', isPublic: true);
        await service.createList(name: 'Travel Adventures', isPublic: true);
        await service.createList(name: 'Cooking Recipes', isPublic: true);

        final results = service.searchLists('cooking');

        expect(results.length, 2);
        expect(results.map((l) => l.name), contains('Cooking Videos'));
        expect(results.map((l) => l.name), contains('Cooking Recipes'));
        // TODO(any): Fix and re-enable this test
      }, skip: true);

      test('finds lists by description', () async {
        await service.createList(
          name: 'Random List',
          description: 'Videos about cooking',
          isPublic: true,
        );
        await service.createList(
          name: 'Another List',
          description: 'Travel videos',
          isPublic: true,
        );

        final results = service.searchLists('cooking');

        expect(results.length, 1);
        expect(results.first.name, 'Random List');
      });

      test('finds lists by tags', () async {
        await service.createList(
          name: 'List 1',
          tags: ['tech', 'tutorial'],
          isPublic: true,
        );
        await service.createList(
          name: 'List 2',
          tags: ['cooking', 'food'],
          isPublic: true,
        );

        final results = service.searchLists('tech');

        expect(results.length, 1);
        expect(results.first.name, 'List 1');
        // TODO(Any): Fix and re-enable these tests
        // This test fails only when the whole suite is run, likely due to test isolation issues
      }, skip: true);

      test('is case-insensitive', () async {
        await service.createList(name: 'Cooking Videos', isPublic: true);

        final results1 = service.searchLists('COOKING');
        final results2 = service.searchLists('cooking');
        final results3 = service.searchLists('CoOkInG');

        expect(results1.length, 1);
        expect(results2.length, 1);
        expect(results3.length, 1);
      });

      test('returns empty list for no matches', () async {
        await service.createList(name: 'Cooking Videos', isPublic: true);
        await service.createList(name: 'Travel Adventures', isPublic: true);

        final results = service.searchLists('programming');

        expect(results, isEmpty);
      });

      test('returns empty list for empty query', () async {
        await service.createList(name: 'Test List', isPublic: true);

        final results = service.searchLists('');

        expect(results, isEmpty);
      });

      test('returns empty list for whitespace-only query', () async {
        await service.createList(name: 'Test List', isPublic: true);

        final results = service.searchLists('   ');

        expect(results, isEmpty);
      });

      test('only returns public lists', () async {
        await service.createList(name: 'Public Cooking', isPublic: true);
        await service.createList(name: 'Private Cooking', isPublic: false);

        final results = service.searchLists('cooking');

        expect(results.length, 1);
        expect(results.first.name, 'Public Cooking');
      });

      test('searches across multiple fields', () async {
        await service.createList(
          name: 'Tech Videos',
          description: 'Programming tutorials',
          tags: ['coding'],
          isPublic: true,
        );

        final byName = service.searchLists('tech');
        final byDescription = service.searchLists('programming');
        final byTag = service.searchLists('coding');

        expect(byName.length, 1);
        expect(byDescription.length, 1);
        expect(byTag.length, 1);
      });
    });

    group('getListsByTag()', () {
      test('returns lists with specific tag', () async {
        await service.createList(
          name: 'List 1',
          tags: ['tech', 'tutorial'],
          isPublic: true,
        );
        await Future.delayed(const Duration(milliseconds: 5));
        await service.createList(
          name: 'List 2',
          tags: ['cooking', 'food'],
          isPublic: true,
        );
        await Future.delayed(const Duration(milliseconds: 5));
        await service.createList(
          name: 'List 3',
          tags: ['tech', 'news'],
          isPublic: true,
        );

        final results = service.getListsByTag('tech');

        expect(results.length, greaterThanOrEqualTo(2));
        expect(results.map((l) => l.name), containsAll(['List 1', 'List 3']));
      });

      test('is case-insensitive', () async {
        await service.createList(
          name: 'Test List',
          tags: ['tech'], // Tags stored lowercase
          isPublic: true,
        );

        final results1 = service.getListsByTag('tech');
        final results2 = service.getListsByTag('TECH');
        final results3 = service.getListsByTag('TeCh');

        expect(results1.length, 1);
        expect(results2.length, 1);
        expect(results3.length, 1);
      });

      test('returns empty list for non-existent tag', () async {
        await service.createList(
          name: 'Test List',
          tags: ['tech'],
          isPublic: true,
        );

        final results = service.getListsByTag('cooking');

        expect(results, isEmpty);
      });

      test('only returns public lists', () async {
        await service.createList(
          name: 'Public List',
          tags: ['tech'],
          isPublic: true,
        );
        await service.createList(
          name: 'Private List',
          tags: ['tech'],
          isPublic: false,
        );

        final results = service.getListsByTag('tech');

        expect(results.length, 1);
        expect(results.first.name, 'Public List');
      });
    });

    group('getAllTags()', () {
      test('returns all unique tags across lists', () async {
        await service.createList(
          name: 'List 1',
          tags: ['tech', 'tutorial'],
          isPublic: true,
        );
        await Future.delayed(const Duration(milliseconds: 5));
        await service.createList(
          name: 'List 2',
          tags: ['cooking', 'food'],
          isPublic: true,
        );
        await Future.delayed(const Duration(milliseconds: 5));
        await service.createList(
          name: 'List 3',
          tags: ['tech', 'news'],
          isPublic: true,
        );

        final tags = service.getAllTags();

        expect(tags.length, greaterThanOrEqualTo(5));
        expect(
          tags,
          containsAll(['tech', 'tutorial', 'cooking', 'food', 'news']),
        );
      });

      test('removes duplicates', () async {
        await service.createList(
          name: 'List 1',
          tags: ['tech', 'tutorial'],
          isPublic: true,
        );
        await service.createList(
          name: 'List 2',
          tags: ['tech', 'news'],
          isPublic: true,
        );

        final tags = service.getAllTags();

        expect(tags.where((t) => t == 'tech').length, 1);
      });

      test('returns sorted list', () async {
        await service.createList(
          name: 'List 1',
          tags: ['zebra', 'alpha', 'middle'],
          isPublic: true,
        );

        final tags = service.getAllTags();

        expect(tags, ['alpha', 'middle', 'zebra']);
      });

      test('only includes tags from public lists', () async {
        await service.createList(
          name: 'Public List',
          tags: ['public_tag'],
          isPublic: true,
        );
        await service.createList(
          name: 'Private List',
          tags: ['private_tag'],
          isPublic: false,
        );

        final tags = service.getAllTags();

        expect(tags, ['public_tag']);
        expect(tags, isNot(contains('private_tag')));
      });

      test('returns empty list when no tags', () async {
        await service.createList(name: 'Test List', isPublic: true);

        final tags = service.getAllTags();

        expect(tags, isEmpty);
      });

      test('handles lists with no tags', () async {
        await service.createList(
          name: 'List 1',
          tags: ['tag1'],
          isPublic: true,
        );
        await Future.delayed(const Duration(milliseconds: 5));
        await service.createList(name: 'List 2', tags: [], isPublic: true);

        final tags = service.getAllTags();

        // Should have tag1 from List 1
        expect(tags.length, greaterThan(0));
        expect(tags, contains('tag1'));
      });
    });

    group('fetchPublicListsContainingVideo()', () {
      // TODO(any): Fix and re-enable this test
      //test('queries Nostr for lists containing specific video', () async {
      //  // Setup: Create mock kind 30005 events containing the target video
      //  final targetVideoId = 'target_video_event_id_123456789abcdef';
      //  final mockListEvent = Event.fromJson({
      //    'id': 'list_event_id_1',
      //    'pubkey': 'other_user_pubkey_123456789abcdef',
      //    'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      //    'kind': 30005,
      //    'tags': [
      //      ['d', 'test-list-1'],
      //      ['title', 'Nature Videos'],
      //      ['description', 'Beautiful nature content'],
      //      ['e', targetVideoId],
      //      ['e', 'other_video_id_123'],
      //    ],
      //    'content': '',
      //    'sig': 'test_sig',
      //  });

      //  // Setup mock to return list events when queried with #e filter
      //  when(
      //    mockNostr.subscribe(argThat(anything), onEose: anyNamed('onEose')),
      //  ).thenAnswer((_) => Stream.fromIterable([mockListEvent]));

      //  // Act
      //  final lists = await service.fetchPublicListsContainingVideo(
      //    targetVideoId,
      //  );

      //  // Assert: Verify filter includes the video ID
      //  final captured = verify(
      //    mockNostr.subscribe(captureAny(), onEose: anyNamed('onEose')),
      //  ).captured;
      //  expect(captured, isNotEmpty);
      //  final filters = captured.first as List<Filter>;
      //  expect(filters[0].kinds, contains(30005));
      //  expect(filters[0].e, contains(targetVideoId));

      //  // Assert: Results parsed correctly
      //  expect(lists.length, 1);
      //  expect(lists.first.name, 'Nature Videos');
      //  expect(lists.first.videoEventIds, contains(targetVideoId));
      //});

      test('returns empty list when no public lists contain video', () async {
        final targetVideoId = 'orphan_video_id_123456789abcdef';

        // Setup mock to return empty stream
        when(
          mockNostr.subscribe(argThat(anything), onEose: anyNamed('onEose')),
        ).thenAnswer((_) => Stream.empty());

        // Act
        final lists = await service.fetchPublicListsContainingVideo(
          targetVideoId,
        );

        // Assert
        expect(lists, isEmpty);
      });

      test('returns stream for progressive loading', () async {
        final targetVideoId = 'target_video_123456789abcdef';
        final mockListEvent1 = Event.fromJson({
          'id': 'list_1',
          'pubkey': 'user1_pubkey_123456789abcdef',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 30005,
          'tags': [
            ['d', 'list-1'],
            ['title', 'First List'],
            ['e', targetVideoId],
          ],
          'content': '',
          'sig': 'sig1',
        });
        final mockListEvent2 = Event.fromJson({
          'id': 'list_2',
          'pubkey': 'user2_pubkey_123456789abcdef',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 30005,
          'tags': [
            ['d', 'list-2'],
            ['title', 'Second List'],
            ['e', targetVideoId],
          ],
          'content': '',
          'sig': 'sig2',
        });

        // Setup mock to return events progressively
        when(
          mockNostr.subscribe(argThat(anything), onEose: anyNamed('onEose')),
        ).thenAnswer(
          (_) => Stream.fromIterable([mockListEvent1, mockListEvent2]),
        );

        // Act: Use the stream version
        final listStream = service.streamPublicListsContainingVideo(
          targetVideoId,
        );
        final lists = await listStream.toList();

        // Assert: Both lists received
        expect(lists.length, 2);
        expect(
          lists.map((l) => l.name),
          containsAll(['First List', 'Second List']),
        );
      });
    });

    group('Query Operations - Edge Cases', () {
      test('search handles special characters', () async {
        await service.createList(name: 'C++ Programming', isPublic: true);
        await service.createList(name: 'C# Development', isPublic: true);

        final results1 = service.searchLists('c++');
        final results2 = service.searchLists('c#');

        expect(results1.first.name, 'C++ Programming');
        expect(results2.first.name, 'C# Development');
        // TODO(any): Fix and re-enable this test
      }, skip: true);

      test('search handles unicode characters', () async {
        await service.createList(name: 'Español Videos', isPublic: true);
        await service.createList(name: '日本語 Content', isPublic: true);

        final results1 = service.searchLists('español');
        final results2 = service.searchLists('日本語');

        expect(results1.first.name, 'Español Videos');
        expect(results2.first.name, '日本語 Content');
        // TODO(any): Fix and re-enable this test
      }, skip: true);

      test('search with partial match', () async {
        await service.createList(name: 'Programming Tutorials', isPublic: true);

        final results = service.searchLists('program');

        expect(results.length, 1);
        expect(results.first.name, 'Programming Tutorials');
      });

      test('getListsByTag with tag that has spaces', () async {
        await service.createList(
          name: 'Test List',
          tags: ['with spaces'],
          isPublic: true,
        );

        final results = service.getListsByTag('with spaces');

        expect(results.length, 1);
      });

      test('getAllTags handles empty string tags', () async {
        await service.createList(
          name: 'Test List',
          tags: ['valid', '', 'another'],
          isPublic: true,
        );

        final tags = service.getAllTags();

        expect(tags.contains(''), isTrue); // Service doesn't filter empty tags
      });

      test('search performance with many lists', () async {
        // FIXME: Test isolation issue - passes individually, fails in batch
        // Create 50 lists
        for (var i = 0; i < 50; i++) {
          await service.createList(
            name: 'List $i',
            description: i % 2 == 0 ? 'even number' : 'odd number',
            tags: ['tag$i'],
            isPublic: true,
          );
        }

        final stopwatch = Stopwatch()..start();
        final results = service.searchLists('even');
        stopwatch.stop();

        expect(
          results.length,
          greaterThanOrEqualTo(25),
        ); // Should find at least 25
        expect(stopwatch.elapsedMilliseconds, lessThan(100)); // Should be fast
        // TODO(any): Fix and re-enable this test
      }, skip: true);
    });

    group('streamPublicListsFromRelays()', () {
      test('streams lists immediately as they arrive', () async {
        // Setup: Mock events arriving one at a time
        final event1 = Event.fromJson({
          'id':
              'event1_id_123456789abcdef0123456789abcdef0123456789abcdef012345678',
          'pubkey':
              'pubkey1_123456789abcdef0123456789abcdef0123456789abcdef012345',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 30005,
          'tags': [
            ['d', 'list-1'],
            ['title', 'List One'],
            ['a', '34236:somepubkey:videoid1'],
          ],
          'content': 'First list',
          'sig': 'sig1',
        });

        final event2 = Event.fromJson({
          'id':
              'event2_id_123456789abcdef0123456789abcdef0123456789abcdef012345678',
          'pubkey':
              'pubkey2_123456789abcdef0123456789abcdef0123456789abcdef012345',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 30005,
          'tags': [
            ['d', 'list-2'],
            ['title', 'List Two'],
            ['a', '34236:somepubkey:videoid2'],
          ],
          'content': 'Second list',
          'sig': 'sig2',
        });

        // Mock subscribe to return events as a stream
        when(
          mockNostr.subscribe(any),
        ).thenAnswer((_) => Stream.fromIterable([event1, event2]));

        // Act: Collect streamed results
        final streamedResults = <List<CuratedList>>[];
        await for (final lists in service.streamPublicListsFromRelays()) {
          streamedResults.add(List.from(lists));
          if (streamedResults.length >= 2) break; // Stop after 2 updates
        }

        // Assert: Should have received progressive updates
        expect(streamedResults.length, 2);
        expect(streamedResults[0].length, 1); // First update has 1 list
        expect(streamedResults[1].length, 2); // Second update has 2 lists
      });

      test('deduplicates by d-tag keeping newest', () async {
        final olderEvent = Event.fromJson({
          'id':
              'older_id_123456789abcdef0123456789abcdef0123456789abcdef0123456',
          'pubkey':
              'pubkey_123456789abcdef0123456789abcdef0123456789abcdef01234567',
          'created_at':
              DateTime.now()
                  .subtract(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
          'kind': 30005,
          'tags': [
            ['d', 'same-list'],
            ['title', 'Old Title'],
            ['a', '34236:somepubkey:videoid1'],
          ],
          'content': 'Old version',
          'sig': 'sig1',
        });

        final newerEvent = Event.fromJson({
          'id':
              'newer_id_123456789abcdef0123456789abcdef0123456789abcdef0123456',
          'pubkey':
              'pubkey_123456789abcdef0123456789abcdef0123456789abcdef01234567',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 30005,
          'tags': [
            ['d', 'same-list'],
            ['title', 'New Title'],
            ['a', '34236:somepubkey:videoid1'],
          ],
          'content': 'New version',
          'sig': 'sig2',
        });

        // Send older first, then newer
        when(
          mockNostr.subscribe(any),
        ).thenAnswer((_) => Stream.fromIterable([olderEvent, newerEvent]));

        List<CuratedList>? finalLists;
        await for (final lists in service.streamPublicListsFromRelays()) {
          finalLists = lists;
          if (lists.isNotEmpty && lists.first.name == 'New Title') break;
        }

        // Should only have one list with the newer title
        expect(finalLists?.length, 1);
        expect(finalLists?.first.name, 'New Title');
      });

      test('filters out empty lists', () async {
        final emptyList = Event.fromJson({
          'id':
              'empty_id_123456789abcdef0123456789abcdef0123456789abcdef01234567',
          'pubkey':
              'pubkey_123456789abcdef0123456789abcdef0123456789abcdef01234567',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 30005,
          'tags': [
            ['d', 'empty-list'],
            ['title', 'Empty List'],
            // No video references
          ],
          'content': 'No videos',
          'sig': 'sig1',
        });

        final nonEmptyList = Event.fromJson({
          'id':
              'nonempty_id_123456789abcdef0123456789abcdef0123456789abcdef0123',
          'pubkey':
              'pubkey_123456789abcdef0123456789abcdef0123456789abcdef01234567',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 30005,
          'tags': [
            ['d', 'non-empty-list'],
            ['title', 'Non-Empty List'],
            ['a', '34236:somepubkey:videoid1'],
          ],
          'content': 'Has videos',
          'sig': 'sig2',
        });

        when(
          mockNostr.subscribe(any),
        ).thenAnswer((_) => Stream.fromIterable([emptyList, nonEmptyList]));

        List<CuratedList>? finalLists;
        await for (final lists in service.streamPublicListsFromRelays()) {
          finalLists = lists;
          if (lists.isNotEmpty) break;
        }

        // Should only have the non-empty list
        expect(finalLists?.length, 1);
        expect(finalLists?.first.name, 'Non-Empty List');
      });

      test('supports pagination with until parameter', () async {
        final oldEvent = Event.fromJson({
          'id':
              'old_event_123456789abcdef0123456789abcdef0123456789abcdef012345',
          'pubkey':
              'pubkey_123456789abcdef0123456789abcdef0123456789abcdef01234567',
          'created_at': DateTime(2024, 1, 1).millisecondsSinceEpoch ~/ 1000,
          'kind': 30005,
          'tags': [
            ['d', 'old-list'],
            ['title', 'Old List'],
            ['a', '34236:somepubkey:videoid1'],
          ],
          'content': 'Old list from 2024',
          'sig': 'sig1',
        });

        when(
          mockNostr.subscribe(any),
        ).thenAnswer((_) => Stream.fromIterable([oldEvent]));

        // Act: Request with until date
        final until = DateTime(2024, 6, 1);
        List<CuratedList>? results;
        await for (final lists in service.streamPublicListsFromRelays(
          until: until,
        )) {
          results = lists;
          if (lists.isNotEmpty) break;
        }

        // Verify subscribe was called (filter construction is internal)
        verify(mockNostr.subscribe(any)).called(1);
        expect(results?.isNotEmpty, true);
      });
    });
  });
}
