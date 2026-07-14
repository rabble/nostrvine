// ABOUTME: Unit tests for CuratedListService.fetchPublicList
// ABOUTME: Covers relay fetch by author + d-tag for list deep links

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

const _authorPubkey =
    'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';
const _videoEventId =
    '1111111111111111111111111111111111111111111111111111111111111111';

Event _listEvent({
  required String id,
  required String dTag,
  required int createdAt,
  String title = 'My Vines',
  String pubkey = _authorPubkey,
}) {
  return Event.fromJson({
    'id': id,
    'pubkey': pubkey,
    'created_at': createdAt,
    'kind': 30005,
    'tags': [
      ['d', dTag],
      ['title', title],
      ['e', _videoEventId],
    ],
    'content': '',
    'sig': 'test_signature',
  });
}

void main() {
  group('CuratedListService.fetchPublicList', () {
    late CuratedListService service;
    late _MockNostrClient mockNostr;
    late _MockAuthService mockAuth;
    late SharedPreferences prefs;

    setUpAll(() {
      registerFallbackValue(<Filter>[]);
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});

      mockNostr = _MockNostrClient();
      mockAuth = _MockAuthService();
      prefs = await SharedPreferences.getInstance();

      when(() => mockAuth.isAuthenticated).thenReturn(true);
      when(
        () => mockAuth.currentPublicKeyHex,
      ).thenReturn('test_pubkey_123456789abcdef');

      service = CuratedListService(
        nostrService: mockNostr,
        authService: mockAuth,
        prefs: prefs,
      );
    });

    test('returns the parsed list when a matching event is found', () async {
      when(() => mockNostr.queryEvents(any())).thenAnswer(
        (_) async => [
          _listEvent(id: 'event_1', dTag: 'my-vines', createdAt: 1000),
        ],
      );

      final list = await service.fetchPublicList(
        authorPubkey: _authorPubkey,
        listId: 'my-vines',
      );

      expect(list, isNotNull);
      expect(list!.id, equals('my-vines'));
      expect(list.name, equals('My Vines'));
      expect(list.pubkey, equals(_authorPubkey));
      expect(list.videoEventIds, equals([_videoEventId]));
    });

    test('queries kind 30005 by author and d-tag', () async {
      when(
        () => mockNostr.queryEvents(any()),
      ).thenAnswer((_) async => <Event>[]);

      await service.fetchPublicList(
        authorPubkey: _authorPubkey,
        listId: 'my-vines',
      );

      final captured =
          verify(() => mockNostr.queryEvents(captureAny())).captured.single
              as List<Filter>;
      expect(captured, hasLength(1));
      final filter = captured.single;
      expect(filter.kinds, equals([30005]));
      expect(filter.authors, equals([_authorPubkey]));
      expect(filter.d, equals(['my-vines']));
    });

    test('returns null when no event matches', () async {
      when(
        () => mockNostr.queryEvents(any()),
      ).thenAnswer((_) async => <Event>[]);

      final list = await service.fetchPublicList(
        authorPubkey: _authorPubkey,
        listId: 'my-vines',
      );

      expect(list, isNull);
    });

    test('picks the newest version of a replaceable event', () async {
      when(() => mockNostr.queryEvents(any())).thenAnswer(
        (_) async => [
          _listEvent(
            id: 'event_old',
            dTag: 'my-vines',
            createdAt: 1000,
            title: 'Old Title',
          ),
          _listEvent(
            id: 'event_new',
            dTag: 'my-vines',
            createdAt: 2000,
            title: 'New Title',
          ),
        ],
      );

      final list = await service.fetchPublicList(
        authorPubkey: _authorPubkey,
        listId: 'my-vines',
      );

      expect(list, isNotNull);
      expect(list!.name, equals('New Title'));
    });

    test('ignores events whose d-tag does not match', () async {
      when(() => mockNostr.queryEvents(any())).thenAnswer(
        (_) async => [
          _listEvent(id: 'event_other', dTag: 'other-list', createdAt: 1000),
        ],
      );

      final list = await service.fetchPublicList(
        authorPubkey: _authorPubkey,
        listId: 'my-vines',
      );

      expect(list, isNull);
    });
  });
}
