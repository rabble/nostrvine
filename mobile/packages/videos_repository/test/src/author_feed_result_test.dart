// ABOUTME: Unit tests for the AuthorFeedResult value type.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:videos_repository/videos_repository.dart';

VideoEvent _video(String id) => VideoEvent(
  id: id,
  pubkey: 'author',
  createdAt: 1000,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1000 * 1000),
);

void main() {
  group('AuthorFeedResult', () {
    test('defaults videos to empty and envelope fields to null', () {
      const result = AuthorFeedResult(authorPubkey: 'pub');

      expect(result.authorPubkey, equals('pub'));
      expect(result.videos, isEmpty);
      expect(result.nextOffset, isNull);
      expect(result.totalCount, isNull);
      expect(result.hasMore, isNull);
      expect(result.isFromCache, isFalse);
    });

    test('value equality is based on all fields', () {
      final a = AuthorFeedResult(
        authorPubkey: 'pub',
        videos: [_video('a')],
        nextOffset: 50,
        totalCount: 120,
        hasMore: true,
        isFromCache: true,
      );
      final b = AuthorFeedResult(
        authorPubkey: 'pub',
        videos: [_video('a')],
        nextOffset: 50,
        totalCount: 120,
        hasMore: true,
        isFromCache: true,
      );

      expect(a, equals(b));
    });

    test('differs when any field differs', () {
      const base = AuthorFeedResult(authorPubkey: 'pub', totalCount: 1);
      expect(base, isNot(equals(const AuthorFeedResult(authorPubkey: 'pub'))));
      expect(
        base,
        isNot(equals(const AuthorFeedResult(authorPubkey: 'other'))),
      );
      expect(
        base,
        isNot(
          equals(
            const AuthorFeedResult(authorPubkey: 'pub', isFromCache: true),
          ),
        ),
      );
    });

    test('copyWith replaces only the provided fields', () {
      const original = AuthorFeedResult(
        authorPubkey: 'pub',
        nextOffset: 50,
        totalCount: 120,
        hasMore: true,
        isFromCache: true,
      );

      final updated = original.copyWith(
        nextOffset: 100,
        hasMore: false,
        isFromCache: false,
      );

      expect(updated.authorPubkey, equals('pub'));
      expect(updated.nextOffset, equals(100));
      expect(updated.totalCount, equals(120));
      expect(updated.hasMore, isFalse);
      expect(updated.isFromCache, isFalse);
    });

    test('copyWith keeps fields that are not passed', () {
      const original = AuthorFeedResult(
        authorPubkey: 'pub',
        nextOffset: 50,
        totalCount: 120,
        hasMore: true,
      );

      final updated = original.copyWith(totalCount: 99);

      expect(updated.nextOffset, equals(50)); // kept
      expect(updated.hasMore, isTrue); // kept
      expect(updated.totalCount, equals(99));
      expect(updated.isFromCache, isFalse);
    });

    test('copyWith can clear nullable envelope fields', () {
      const original = AuthorFeedResult(
        authorPubkey: 'pub',
        nextOffset: 50,
        totalCount: 120,
        hasMore: true,
      );

      final updated = original.copyWith(
        nextOffset: null,
        totalCount: null,
        hasMore: null,
      );

      expect(updated.nextOffset, isNull);
      expect(updated.totalCount, isNull);
      expect(updated.hasMore, isNull);
    });
  });
}
