// ABOUTME: Unit tests for DbRepostsLocalStorage implementation.
// ABOUTME: Tests the db_client-backed local storage for repost records.

// Not needed rules for test code.
// ignore_for_file: prefer_const_constructors

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:test/test.dart';

class MockPersonalRepostsDao extends Mock implements PersonalRepostsDao {}

void main() {
  group('DbRepostsLocalStorage', () {
    late MockPersonalRepostsDao mockDao;
    late DbRepostsLocalStorage storage;

    /// Valid 64-char hex pubkey for testing
    const testUserPubkey =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    const testOriginalAuthorPubkey =
        '1111111111111111111111111111111111111111111111111111111111111111';

    /// Valid addressable IDs for testing (format: 34236:pubkey:d-tag)
    const testAddressableId = '34236:$testOriginalAuthorPubkey:video1';
    const testAddressableId2 = '34236:$testOriginalAuthorPubkey:video2';

    /// Valid 64-char hex event IDs for testing
    const testRepostEventId =
        'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
    const testRepostEventId2 =
        'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

    setUpAll(() {
      registerFallbackValue(
        PersonalRepostRow(
          addressableId: '',
          repostEventId: '',
          originalAuthorPubkey: '',
          userPubkey: '',
          createdAt: 0,
        ),
      );
      registerFallbackValue(<PersonalRepostRow>[]);
    });

    setUp(() {
      mockDao = MockPersonalRepostsDao();
      storage = DbRepostsLocalStorage(
        dao: mockDao,
        userPubkey: testUserPubkey,
      );
    });

    group('constructor', () {
      test('creates storage with dao and userPubkey', () {
        final storage = DbRepostsLocalStorage(
          dao: mockDao,
          userPubkey: testUserPubkey,
        );
        expect(storage, isNotNull);
      });
    });

    group('saveRepostRecord', () {
      test('calls dao.upsertRepost with correct parameters', () async {
        when(
          () => mockDao.upsertRepost(
            addressableId: any(named: 'addressableId'),
            repostEventId: any(named: 'repostEventId'),
            originalAuthorPubkey: any(named: 'originalAuthorPubkey'),
            userPubkey: any(named: 'userPubkey'),
            createdAt: any(named: 'createdAt'),
          ),
        ).thenAnswer((_) async {});

        final now = DateTime.now();
        final record = RepostRecord(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          createdAt: now,
        );

        await storage.saveRepostRecord(record);

        verify(
          () => mockDao.upsertRepost(
            addressableId: testAddressableId,
            repostEventId: testRepostEventId,
            originalAuthorPubkey: testOriginalAuthorPubkey,
            userPubkey: testUserPubkey,
            createdAt: now.millisecondsSinceEpoch ~/ 1000,
          ),
        ).called(1);
      });
    });

    group('saveRepostRecordsBatch', () {
      test('calls dao.upsertRepostsBatch with converted rows', () async {
        when(
          () => mockDao.upsertRepostsBatch(any()),
        ).thenAnswer((_) async {});

        final now = DateTime.now();
        final records = [
          RepostRecord(
            addressableId: testAddressableId,
            repostEventId: testRepostEventId,
            originalAuthorPubkey: testOriginalAuthorPubkey,
            createdAt: now,
          ),
          RepostRecord(
            addressableId: testAddressableId2,
            repostEventId: testRepostEventId2,
            originalAuthorPubkey: testOriginalAuthorPubkey,
            createdAt: now,
          ),
        ];

        await storage.saveRepostRecordsBatch(records);

        final captured = verify(
          () => mockDao.upsertRepostsBatch(captureAny()),
        ).captured;
        expect(captured.length, equals(1));

        final rows = captured.first as List<PersonalRepostRow>;
        expect(rows.length, equals(2));
        expect(rows[0].addressableId, equals(testAddressableId));
        expect(rows[0].repostEventId, equals(testRepostEventId));
        expect(rows[0].userPubkey, equals(testUserPubkey));
        expect(rows[1].addressableId, equals(testAddressableId2));
        expect(rows[1].repostEventId, equals(testRepostEventId2));
      });

      test('does not call dao when records list is empty', () async {
        await storage.saveRepostRecordsBatch([]);

        verifyNever(() => mockDao.upsertRepostsBatch(any()));
      });
    });

    group('deleteRepostRecord', () {
      test('returns true when deletion succeeds', () async {
        when(
          () => mockDao.deleteRepost(
            addressableId: any(named: 'addressableId'),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async => 1);

        final result = await storage.deleteRepostRecord(testAddressableId);

        expect(result, isTrue);
        verify(
          () => mockDao.deleteRepost(
            addressableId: testAddressableId,
            userPubkey: testUserPubkey,
          ),
        ).called(1);
      });

      test('returns false when no record exists', () async {
        when(
          () => mockDao.deleteRepost(
            addressableId: any(named: 'addressableId'),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async => 0);

        final result = await storage.deleteRepostRecord(testAddressableId);

        expect(result, isFalse);
      });
    });

    group('getRepostRecord', () {
      test('returns RepostRecord when found', () async {
        final row = PersonalRepostRow(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );

        when(
          () => mockDao.getRepost(
            addressableId: any(named: 'addressableId'),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async => row);

        final result = await storage.getRepostRecord(testAddressableId);

        expect(result, isNotNull);
        expect(result!.addressableId, equals(testAddressableId));
        expect(result.repostEventId, equals(testRepostEventId));
        expect(result.originalAuthorPubkey, equals(testOriginalAuthorPubkey));
        expect(
          result.createdAt,
          equals(DateTime.fromMillisecondsSinceEpoch(1000 * 1000)),
        );
      });

      test('returns null when not found', () async {
        when(
          () => mockDao.getRepost(
            addressableId: any(named: 'addressableId'),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async => null);

        final result = await storage.getRepostRecord(testAddressableId);

        expect(result, isNull);
      });
    });

    group('getRepostEventId', () {
      test('returns repost event ID when reposted', () async {
        when(
          () => mockDao.getRepostEventId(
            addressableId: any(named: 'addressableId'),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async => testRepostEventId);

        final result = await storage.getRepostEventId(testAddressableId);

        expect(result, equals(testRepostEventId));
        verify(
          () => mockDao.getRepostEventId(
            addressableId: testAddressableId,
            userPubkey: testUserPubkey,
          ),
        ).called(1);
      });

      test('returns null when not reposted', () async {
        when(
          () => mockDao.getRepostEventId(
            addressableId: any(named: 'addressableId'),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async => null);

        final result = await storage.getRepostEventId(testAddressableId);

        expect(result, isNull);
      });
    });

    group('getAllRepostRecords', () {
      test('returns converted RepostRecords', () async {
        final rows = [
          PersonalRepostRow(
            addressableId: testAddressableId,
            repostEventId: testRepostEventId,
            originalAuthorPubkey: testOriginalAuthorPubkey,
            userPubkey: testUserPubkey,
            createdAt: 1000,
          ),
          PersonalRepostRow(
            addressableId: testAddressableId2,
            repostEventId: testRepostEventId2,
            originalAuthorPubkey: testOriginalAuthorPubkey,
            userPubkey: testUserPubkey,
            createdAt: 2000,
          ),
        ];

        when(
          () => mockDao.getAllReposts(any()),
        ).thenAnswer((_) async => rows);

        final result = await storage.getAllRepostRecords();

        expect(result.length, equals(2));
        expect(result[0].addressableId, equals(testAddressableId));
        expect(result[0].repostEventId, equals(testRepostEventId));
        expect(
          result[0].createdAt,
          equals(DateTime.fromMillisecondsSinceEpoch(1000 * 1000)),
        );
        expect(result[1].addressableId, equals(testAddressableId2));
        expect(result[1].repostEventId, equals(testRepostEventId2));
        expect(
          result[1].createdAt,
          equals(DateTime.fromMillisecondsSinceEpoch(2000 * 1000)),
        );

        verify(() => mockDao.getAllReposts(testUserPubkey)).called(1);
      });

      test('returns empty list when no records', () async {
        when(() => mockDao.getAllReposts(any())).thenAnswer((_) async => []);

        final result = await storage.getAllRepostRecords();

        expect(result, isEmpty);
      });
    });

    group('getRepostedAddressableIds', () {
      test('returns set of reposted addressable IDs', () async {
        when(() => mockDao.getRepostedAddressableIds(any())).thenAnswer(
          (_) async => {testAddressableId, testAddressableId2},
        );

        final result = await storage.getRepostedAddressableIds();

        expect(result.length, equals(2));
        expect(result, containsAll([testAddressableId, testAddressableId2]));
        verify(
          () => mockDao.getRepostedAddressableIds(testUserPubkey),
        ).called(1);
      });

      test('returns empty set when no reposts', () async {
        when(() => mockDao.getRepostedAddressableIds(any())).thenAnswer(
          (_) async => <String>{},
        );

        final result = await storage.getRepostedAddressableIds();

        expect(result, isEmpty);
      });
    });

    group('isReposted', () {
      test('returns true when event is reposted', () async {
        when(
          () => mockDao.isReposted(
            addressableId: any(named: 'addressableId'),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async => true);

        final result = await storage.isReposted(testAddressableId);

        expect(result, isTrue);
        verify(
          () => mockDao.isReposted(
            addressableId: testAddressableId,
            userPubkey: testUserPubkey,
          ),
        ).called(1);
      });

      test('returns false when event is not reposted', () async {
        when(
          () => mockDao.isReposted(
            addressableId: any(named: 'addressableId'),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async => false);

        final result = await storage.isReposted(testAddressableId);

        expect(result, isFalse);
      });
    });

    group('watchRepostedAddressableIds', () {
      test('returns stream from dao', () async {
        final controller = StreamController<Set<String>>();
        when(
          () => mockDao.watchRepostedAddressableIds(any()),
        ).thenAnswer((_) => controller.stream);

        final stream = storage.watchRepostedAddressableIds();

        // Add values to controller
        controller
          ..add({testAddressableId})
          ..add({testAddressableId, testAddressableId2});

        final emissions = await stream.take(2).toList();

        expect(emissions[0], equals({testAddressableId}));
        expect(
          emissions[1],
          equals({testAddressableId, testAddressableId2}),
        );

        verify(
          () => mockDao.watchRepostedAddressableIds(testUserPubkey),
        ).called(1);

        await controller.close();
      });
    });

    group('clearAll', () {
      test('calls dao.deleteAllForUser', () async {
        when(() => mockDao.deleteAllForUser(any())).thenAnswer((_) async => 5);

        await storage.clearAll();

        verify(() => mockDao.deleteAllForUser(testUserPubkey)).called(1);
      });
    });

    group('timestamp conversion', () {
      test('converts DateTime to Unix timestamp correctly', () async {
        when(
          () => mockDao.upsertRepost(
            addressableId: any(named: 'addressableId'),
            repostEventId: any(named: 'repostEventId'),
            originalAuthorPubkey: any(named: 'originalAuthorPubkey'),
            userPubkey: any(named: 'userPubkey'),
            createdAt: any(named: 'createdAt'),
          ),
        ).thenAnswer((_) async {});

        // Use a specific timestamp to verify conversion
        final dateTime = DateTime.utc(2024, 1, 15, 12, 30, 45);
        final expectedUnix = dateTime.millisecondsSinceEpoch ~/ 1000;

        final record = RepostRecord(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          createdAt: dateTime,
        );

        await storage.saveRepostRecord(record);

        verify(
          () => mockDao.upsertRepost(
            addressableId: testAddressableId,
            repostEventId: testRepostEventId,
            originalAuthorPubkey: testOriginalAuthorPubkey,
            userPubkey: testUserPubkey,
            createdAt: expectedUnix,
          ),
        ).called(1);
      });

      test('converts Unix timestamp to DateTime correctly', () async {
        const unixTimestamp = 1705322445; // 2024-01-15 12:00:45 UTC
        final expectedDateTime = DateTime.fromMillisecondsSinceEpoch(
          unixTimestamp * 1000,
        );

        final row = PersonalRepostRow(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: unixTimestamp,
        );

        when(
          () => mockDao.getRepost(
            addressableId: any(named: 'addressableId'),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async => row);

        final result = await storage.getRepostRecord(testAddressableId);

        expect(result, isNotNull);
        expect(result!.createdAt, equals(expectedDateTime));
      });
    });
  });
}
