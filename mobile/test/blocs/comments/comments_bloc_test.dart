// ABOUTME: Tests for CommentsBloc - loading comments, posting, and tree building
// ABOUTME: Tests comment stream handling, optimistic updates, and error cases

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/blocs/comments/comments_bloc.dart';
import 'package:openvine/models/comment.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/social_service.dart';

class _MockSocialService extends Mock implements SocialService {}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group('CommentsBloc', () {
    late _MockSocialService mockSocialService;
    late _MockAuthService mockAuthService;
    late StreamController<Event> commentsStreamController;

    // Helper to create valid hex IDs (64 hex characters)
    String validId(String suffix) {
      final hexSuffix = suffix.codeUnits
          .map((c) => c.toRadixString(16).padLeft(2, '0'))
          .join();
      return hexSuffix.padLeft(64, '0');
    }

    setUp(() {
      mockSocialService = _MockSocialService();
      mockAuthService = _MockAuthService();
      commentsStreamController = StreamController<Event>.broadcast();

      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockAuthService.currentPublicKeyHex,
      ).thenReturn(validId('currentuser'));
    });

    tearDown(() {
      commentsStreamController.close();
    });

    CommentsBloc createBloc({String? rootEventId, String? rootAuthorPubkey}) =>
        CommentsBloc(
          socialService: mockSocialService,
          authService: mockAuthService,
          rootEventId: rootEventId ?? validId('root'),
          rootAuthorPubkey: rootAuthorPubkey ?? validId('author'),
        );

    test('initial state has correct rootEventId and rootAuthorPubkey', () {
      final bloc = createBloc(
        rootEventId: validId('testevent'),
        rootAuthorPubkey: validId('testauthor'),
      );

      expect(bloc.state.rootEventId, validId('testevent'));
      expect(bloc.state.rootAuthorPubkey, validId('testauthor'));
      expect(bloc.state.status, CommentsStatus.initial);

      bloc.close();
    });

    group('CommentsLoadRequested', () {
      blocTest<CommentsBloc, CommentsState>(
        'emits [loading, success] when comments arrive from stream',
        setUp: () {
          when(() => mockSocialService.fetchCommentsForEvent(any())).thenAnswer(
            (_) => Stream.value(
              Event(
                validId('commenter'),
                1,
                [
                  ['e', validId('root'), '', 'root'],
                  ['p', validId('author')],
                ],
                'Test comment',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              ),
            ),
          );
        },
        build: () => createBloc(),
        act: (bloc) => bloc.add(const CommentsLoadRequested()),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<CommentsState>().having(
            (s) => s.status,
            'status',
            CommentsStatus.loading,
          ),
          isA<CommentsState>()
              .having((s) => s.status, 'status', CommentsStatus.success)
              .having((s) => s.topLevelComments.length, 'comments count', 1)
              .having((s) => s.totalCommentCount, 'total count', 1),
        ],
      );

      blocTest<CommentsBloc, CommentsState>(
        'emits [loading, success] with empty list after timeout when no comments',
        setUp: () {
          when(
            () => mockSocialService.fetchCommentsForEvent(any()),
          ).thenAnswer((_) => const Stream.empty());
        },
        build: () => createBloc(),
        act: (bloc) => bloc.add(const CommentsLoadRequested()),
        wait: const Duration(seconds: 4),
        expect: () => [
          isA<CommentsState>().having(
            (s) => s.status,
            'status',
            CommentsStatus.loading,
          ),
          isA<CommentsState>()
              .having((s) => s.status, 'status', CommentsStatus.success)
              .having((s) => s.topLevelComments, 'comments', isEmpty)
              .having((s) => s.totalCommentCount, 'total count', 0),
        ],
      );

      blocTest<CommentsBloc, CommentsState>(
        'builds correct comment tree with replies',
        setUp: () {
          // Create events - note: id is calculated automatically from content
          final parentEvent = Event(
            validId('commenter1'),
            1,
            [
              ['e', validId('root'), '', 'root'],
              ['p', validId('author')],
            ],
            'Parent comment',
            createdAt: 1000000,
          );

          final replyEvent = Event(
            validId('commenter2'),
            1,
            [
              ['e', validId('root'), '', 'root'],
              ['e', parentEvent.id, '', 'reply'],
              ['p', validId('author')],
              ['p', validId('commenter1')],
            ],
            'Reply comment',
            createdAt: 1000001,
          );

          when(
            () => mockSocialService.fetchCommentsForEvent(any()),
          ).thenAnswer((_) => Stream.fromIterable([parentEvent, replyEvent]));
        },
        build: () => createBloc(),
        act: (bloc) => bloc.add(const CommentsLoadRequested()),
        wait: const Duration(milliseconds: 100),
        verify: (bloc) {
          expect(bloc.state.topLevelComments.length, 1);
          expect(bloc.state.topLevelComments.first.replies.length, 1);
          expect(bloc.state.totalCommentCount, 2);
        },
      );
    });

    group('CommentPostRequested', () {
      blocTest<CommentsBloc, CommentsState>(
        'posts comment and reloads when authenticated',
        setUp: () {
          when(() => mockAuthService.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthService.currentPublicKeyHex,
          ).thenReturn(validId('currentuser'));
          when(
            () => mockSocialService.postComment(
              content: any(named: 'content'),
              rootEventId: any(named: 'rootEventId'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              replyToEventId: any(named: 'replyToEventId'),
              replyToAuthorPubkey: any(named: 'replyToAuthorPubkey'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => mockSocialService.fetchCommentsForEvent(any()),
          ).thenAnswer((_) => const Stream.empty());
        },
        build: () => createBloc(),
        act: (bloc) => bloc.add(const CommentPostRequested(content: 'Test')),
        wait: const Duration(seconds: 4),
        verify: (_) {
          verify(
            () => mockSocialService.postComment(
              content: 'Test',
              rootEventId: any(named: 'rootEventId'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              replyToEventId: null,
              replyToAuthorPubkey: null,
            ),
          ).called(1);
        },
      );

      blocTest<CommentsBloc, CommentsState>(
        'emits error when not authenticated',
        setUp: () {
          when(() => mockAuthService.isAuthenticated).thenReturn(false);
        },
        build: () => createBloc(),
        act: (bloc) => bloc.add(const CommentPostRequested(content: 'Test')),
        expect: () => [
          isA<CommentsState>().having(
            (s) => s.error,
            'error',
            'Please sign in to comment',
          ),
        ],
      );

      blocTest<CommentsBloc, CommentsState>(
        'emits error when content is empty',
        setUp: () {
          when(() => mockAuthService.isAuthenticated).thenReturn(true);
        },
        build: () => createBloc(),
        act: (bloc) => bloc.add(const CommentPostRequested(content: '   ')),
        expect: () => [
          isA<CommentsState>().having(
            (s) => s.error,
            'error',
            'Comment cannot be empty',
          ),
        ],
      );
    });

    group('CommentExpansionToggled', () {
      blocTest<CommentsBloc, CommentsState>(
        'toggles expansion state of a comment',
        seed: () => CommentsState(
          status: CommentsStatus.success,
          rootEventId: validId('root'),
          rootAuthorPubkey: validId('author'),
          topLevelComments: [
            CommentNode(
              comment: Comment(
                id: validId('comment1'),
                content: 'Test',
                authorPubkey: validId('commenter'),
                createdAt: DateTime.now(),
                rootEventId: validId('root'),
                rootAuthorPubkey: validId('author'),
              ),
              isExpanded: true,
            ),
          ],
          totalCommentCount: 1,
        ),
        build: () => createBloc(),
        act: (bloc) => bloc.add(CommentExpansionToggled(validId('comment1'))),
        expect: () => [
          isA<CommentsState>().having(
            (s) => s.topLevelComments.first.isExpanded,
            'isExpanded',
            false,
          ),
        ],
      );
    });
  });

  group('CommentsState', () {
    test('supports value equality', () {
      final state1 = CommentsState(
        status: CommentsStatus.success,
        rootEventId: 'event1',
        rootAuthorPubkey: 'author1',
        topLevelComments: const [],
        totalCommentCount: 0,
      );
      final state2 = CommentsState(
        status: CommentsStatus.success,
        rootEventId: 'event1',
        rootAuthorPubkey: 'author1',
        topLevelComments: const [],
        totalCommentCount: 0,
      );

      expect(state1, equals(state2));
    });

    test('copyWith creates copy with updated values', () {
      const state = CommentsState(
        status: CommentsStatus.initial,
        rootEventId: 'event1',
        rootAuthorPubkey: 'author1',
      );

      final updated = state.copyWith(
        status: CommentsStatus.loading,
        error: 'Test error',
      );

      expect(updated.status, CommentsStatus.loading);
      expect(updated.error, 'Test error');
      expect(updated.rootEventId, 'event1');
    });

    test('copyWith preserves values when not specified', () {
      const state = CommentsState(
        status: CommentsStatus.success,
        rootEventId: 'event1',
        rootAuthorPubkey: 'author1',
        totalCommentCount: 5,
      );

      final updated = state.copyWith();

      expect(updated.status, CommentsStatus.success);
      expect(updated.rootEventId, 'event1');
      expect(updated.totalCommentCount, 5);
    });
  });

  group('CommentNode', () {
    test('totalReplyCount returns correct count including nested replies', () {
      final node = CommentNode(
        comment: Comment(
          id: 'comment1',
          content: 'Parent',
          authorPubkey: 'author1',
          createdAt: DateTime.now(),
          rootEventId: 'root',
          rootAuthorPubkey: 'author',
        ),
        replies: [
          CommentNode(
            comment: Comment(
              id: 'reply1',
              content: 'Reply 1',
              authorPubkey: 'author2',
              createdAt: DateTime.now(),
              rootEventId: 'root',
              rootAuthorPubkey: 'author',
            ),
            replies: [
              CommentNode(
                comment: Comment(
                  id: 'nested1',
                  content: 'Nested reply',
                  authorPubkey: 'author3',
                  createdAt: DateTime.now(),
                  rootEventId: 'root',
                  rootAuthorPubkey: 'author',
                ),
              ),
            ],
          ),
          CommentNode(
            comment: Comment(
              id: 'reply2',
              content: 'Reply 2',
              authorPubkey: 'author4',
              createdAt: DateTime.now(),
              rootEventId: 'root',
              rootAuthorPubkey: 'author',
            ),
          ),
        ],
      );

      expect(node.totalReplyCount, 3);
    });

    test('supports value equality', () {
      final comment = Comment(
        id: 'comment1',
        content: 'Test',
        authorPubkey: 'author1',
        createdAt: DateTime(2024),
        rootEventId: 'root',
        rootAuthorPubkey: 'author',
      );

      final node1 = CommentNode(comment: comment);
      final node2 = CommentNode(comment: comment);

      expect(node1, equals(node2));
    });
  });
}
