// ABOUTME: Unit tests for CuratedListService streaming operations
// ABOUTME: Tests streamPublicListsFromRelays with excludeIds and pagination

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'curated_list_service_stream_test.mocks.dart';

@GenerateMocks([NostrClient, AuthService])
void main() {
  group('CuratedListService - Stream Operations', () {
    late CuratedListService service;
    late MockNostrClient mockNostr;
    late MockAuthService mockAuth;
    late SharedPreferences prefs;
    late StreamController<Event> eventController;

    /// Creates a mock kind 30005 list event with video references
    Event createListEvent({
      required String dTag,
      required String name,
      required List<String> videoIds,
      int? createdAt,
    }) {
      final tags = <List<String>>[
        ['d', dTag],
        ['title', name],
        ...videoIds.map((id) => ['a', '34236:pubkey123:$id']),
      ];

      return Event.fromJson({
        'id': 'event_$dTag',
        'pubkey': 'author_pubkey_${dTag.hashCode.abs()}',
        'created_at':
            createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'kind': 30005,
        'tags': tags,
        'content': '',
        'sig': 'test_signature',
      });
    }

    /// Creates a mock kind 30005 list event WITHOUT video references
    Event createEmptyListEvent({required String dTag, required String name}) {
      return Event.fromJson({
        'id': 'event_$dTag',
        'pubkey': 'author_pubkey_${dTag.hashCode.abs()}',
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'kind': 30005,
        'tags': [
          ['d', dTag],
          ['title', name],
        ],
        'content': '',
        'sig': 'test_signature',
      });
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});

      mockNostr = MockNostrClient();
      mockAuth = MockAuthService();
      prefs = await SharedPreferences.getInstance();
      eventController = StreamController<Event>.broadcast();

      when(mockAuth.isAuthenticated).thenReturn(true);
      when(mockAuth.currentPublicKeyHex).thenReturn('test_pubkey');

      // Mock subscribe to return our controlled stream
      when(
        mockNostr.subscribe(any, onEose: anyNamed('onEose')),
      ).thenAnswer((_) => eventController.stream);

      service = CuratedListService(
        nostrService: mockNostr,
        authService: mockAuth,
        prefs: prefs,
      );
    });

    tearDown(() async {
      // Controller may already be closed by the test
      if (!eventController.isClosed) {
        await eventController.close();
      }
    });

    group('streamPublicListsFromRelays()', () {
      test('yields lists progressively as events arrive', () async {
        final receivedLists = <List<CuratedList>>[];

        // Start listening to the stream
        final subscription = service.streamPublicListsFromRelays().listen(
          (lists) => receivedLists.add(List.from(lists)),
        );

        // Wait for the async generator to reach the await for loop
        await Future.delayed(const Duration(milliseconds: 50));

        // Emit list events one at a time
        eventController.add(
          createListEvent(
            dTag: 'list1',
            name: 'First List',
            videoIds: ['video1'],
          ),
        );

        await Future.delayed(const Duration(milliseconds: 50));

        eventController.add(
          createListEvent(
            dTag: 'list2',
            name: 'Second List',
            videoIds: ['video2', 'video3'],
          ),
        );

        await Future.delayed(const Duration(milliseconds: 50));

        eventController.add(
          createListEvent(
            dTag: 'list3',
            name: 'Third List',
            videoIds: ['video4'],
          ),
        );

        await Future.delayed(const Duration(milliseconds: 50));

        // Close the event controller first to complete the stream
        await eventController.close();
        await subscription.cancel();

        // Should have received 3 progressive updates
        expect(receivedLists.length, 3);
        expect(receivedLists[0].length, 1); // First yield: 1 list
        expect(receivedLists[1].length, 2); // Second yield: 2 lists
        expect(receivedLists[2].length, 3); // Third yield: 3 lists
      });

      test('filters out lists without video references', () async {
        final receivedLists = <List<CuratedList>>[];

        final subscription = service.streamPublicListsFromRelays().listen(
          (lists) => receivedLists.add(List.from(lists)),
        );

        // Wait for the async generator to reach the await for loop
        await Future.delayed(const Duration(milliseconds: 50));

        // Emit a list WITH videos
        eventController.add(
          createListEvent(
            dTag: 'list_with_videos',
            name: 'List With Videos',
            videoIds: ['video1'],
          ),
        );

        await Future.delayed(const Duration(milliseconds: 50));

        // Emit a list WITHOUT videos
        eventController.add(
          createEmptyListEvent(dTag: 'list_without_videos', name: 'Empty List'),
        );

        await Future.delayed(const Duration(milliseconds: 50));

        // Emit another list WITH videos
        eventController.add(
          createListEvent(
            dTag: 'list_with_more_videos',
            name: 'Another List With Videos',
            videoIds: ['video2'],
          ),
        );

        await Future.delayed(const Duration(milliseconds: 50));

        // Close the event controller first to complete the stream
        await eventController.close();
        await subscription.cancel();

        // Should have received 2 yields (empty list was filtered)
        expect(receivedLists.length, 2);
        expect(receivedLists[0].length, 1);
        expect(receivedLists[1].length, 2);

        // Verify the empty list was not included
        final allListNames = receivedLists.last.map((l) => l.name).toSet();
        expect(allListNames, contains('List With Videos'));
        expect(allListNames, contains('Another List With Videos'));
        expect(allListNames, isNot(contains('Empty List')));
      });

      test('excludeIds parameter skips known lists', () async {
        final receivedLists = <List<CuratedList>>[];

        // Start stream with excludeIds containing 'list2'
        final subscription = service
            .streamPublicListsFromRelays(excludeIds: {'list2'})
            .listen((lists) => receivedLists.add(List.from(lists)));

        // Wait for the async generator to reach the await for loop
        await Future.delayed(const Duration(milliseconds: 50));

        // Emit list1 - should be yielded
        eventController.add(
          createListEvent(
            dTag: 'list1',
            name: 'First List',
            videoIds: ['video1'],
          ),
        );

        await Future.delayed(const Duration(milliseconds: 50));

        // Emit list2 - should be SKIPPED (in excludeIds)
        eventController.add(
          createListEvent(
            dTag: 'list2',
            name: 'Second List',
            videoIds: ['video2'],
          ),
        );

        await Future.delayed(const Duration(milliseconds: 50));

        // Emit list3 - should be yielded
        eventController.add(
          createListEvent(
            dTag: 'list3',
            name: 'Third List',
            videoIds: ['video3'],
          ),
        );

        await Future.delayed(const Duration(milliseconds: 50));

        // Close the event controller first to complete the stream
        await eventController.close();
        await subscription.cancel();

        // Should have received 2 yields (list2 was skipped)
        expect(receivedLists.length, 2);
        expect(receivedLists[0].length, 1);
        expect(receivedLists[1].length, 2);

        // Verify list2 was not included
        final allListIds = receivedLists.last.map((l) => l.id).toSet();
        expect(allListIds, contains('list1'));
        expect(allListIds, contains('list3'));
        expect(allListIds, isNot(contains('list2')));
      });

      test('deduplicates by d-tag, keeping newest version', () async {
        final receivedLists = <List<CuratedList>>[];

        final subscription = service.streamPublicListsFromRelays().listen(
          (lists) => receivedLists.add(List.from(lists)),
        );

        // Wait for the async generator to reach the await for loop
        await Future.delayed(const Duration(milliseconds: 50));

        // Emit older version of list1
        eventController.add(
          createListEvent(
            dTag: 'list1',
            name: 'Old Name',
            videoIds: ['video1'],
            createdAt: 1000,
          ),
        );

        await Future.delayed(const Duration(milliseconds: 50));

        // Emit newer version of same list1
        eventController.add(
          createListEvent(
            dTag: 'list1',
            name: 'New Name',
            videoIds: ['video1', 'video2'],
            createdAt: 2000,
          ),
        );

        await Future.delayed(const Duration(milliseconds: 50));

        // Close the event controller first to complete the stream
        await eventController.close();
        await subscription.cancel();

        // Should have received 2 yields (both versions triggered yield)
        expect(receivedLists.length, 2);

        // But final list should only have 1 unique list with newer data
        expect(receivedLists.last.length, 1);
        expect(receivedLists.last.first.name, 'New Name');
        expect(receivedLists.last.first.videoEventIds.length, 2);
      });

      test('passes limit parameter to filter', () async {
        // Capture the filter passed to subscribe
        Filter? capturedFilter;
        when(mockNostr.subscribe(any, onEose: anyNamed('onEose'))).thenAnswer((
          invocation,
        ) {
          final filters = invocation.positionalArguments[0] as List<Filter>;
          capturedFilter = filters.first;
          return eventController.stream;
        });

        // Start stream with custom limit
        final subscription = service
            .streamPublicListsFromRelays(limit: 200)
            .listen((_) {});

        await Future.delayed(const Duration(milliseconds: 50));

        // Close the event controller first to complete the stream
        await eventController.close();
        await subscription.cancel();

        expect(capturedFilter, isNotNull);
        expect(capturedFilter!.limit, 200);
        expect(capturedFilter!.kinds, contains(30005));
      });

      test('sorts lists by video count (most videos first)', () async {
        final receivedLists = <List<CuratedList>>[];

        final subscription = service.streamPublicListsFromRelays().listen(
          (lists) => receivedLists.add(List.from(lists)),
        );

        // Wait for the async generator to reach the await for loop
        await Future.delayed(const Duration(milliseconds: 50));

        // Emit list with 1 video
        eventController.add(
          createListEvent(
            dTag: 'small_list',
            name: 'Small List',
            videoIds: ['video1'],
          ),
        );

        await Future.delayed(const Duration(milliseconds: 50));

        // Emit list with 5 videos
        eventController.add(
          createListEvent(
            dTag: 'large_list',
            name: 'Large List',
            videoIds: ['v1', 'v2', 'v3', 'v4', 'v5'],
          ),
        );

        await Future.delayed(const Duration(milliseconds: 50));

        // Emit list with 3 videos
        eventController.add(
          createListEvent(
            dTag: 'medium_list',
            name: 'Medium List',
            videoIds: ['a', 'b', 'c'],
          ),
        );

        await Future.delayed(const Duration(milliseconds: 50));

        // Close the event controller first to complete the stream
        await eventController.close();
        await subscription.cancel();

        // Final list should be sorted by video count descending
        final finalList = receivedLists.last;
        expect(finalList.length, 3);
        expect(finalList[0].name, 'Large List'); // 5 videos
        expect(finalList[1].name, 'Medium List'); // 3 videos
        expect(finalList[2].name, 'Small List'); // 1 video
      });
    });
  });
}
