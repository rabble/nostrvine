import 'package:comments_repository/comments_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class _FakeEvent extends Fake implements Event {}

const int _commentKind = EventKind.comment;
const int _rootEventKind = EventKind.videoVertical;

void main() {
  // Self-heal merge: a just-posted comment publishes to relays instantly, but
  // loadComments reads the Funnelcake REST index first and only falls back to
  // relays when REST is unavailable. While the REST index lags, the repository
  // keeps the user's own comment visible on a sheet reopen. See issue #5598
  // (recurrence of #211).
  group('CommentsRepository recently-posted self-heal (#5598)', () {
    late _MockNostrClient nostrClient;
    late _MockFunnelcakeApiClient funnelcakeClient;
    late DateTime now;
    late CommentsRepository repository;

    const rootEventId =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const rootAuthorPubkey =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const userPubkey =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

    setUpAll(() {
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(_FakeEvent());
    });

    setUp(() {
      nostrClient = _MockNostrClient();
      funnelcakeClient = _MockFunnelcakeApiClient();
      now = DateTime.utc(2026, 6, 27, 13, 35, 38);
      when(() => nostrClient.publicKey).thenReturn(userPubkey);
      when(() => nostrClient.publishEvent(any())).thenAnswer((inv) async {
        final event = inv.positionalArguments.first as Event;
        return PublishSuccess(event: event);
      });
      when(
        () => nostrClient.queryEvents(any()),
      ).thenAnswer((_) async => <Event>[]);
      repository = CommentsRepository(
        nostrClient: nostrClient,
        funnelcakeApiClient: funnelcakeClient,
        clock: () => now,
      );
    });

    void stubRest(List<VideoComment> comments, {required int total}) {
      when(() => funnelcakeClient.isAvailable).thenReturn(true);
      when(
        () => funnelcakeClient.getVideoComments(
          videoId: any(named: 'videoId'),
          sort: any(named: 'sort'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          cacheBustToken: any(named: 'cacheBustToken'),
        ),
      ).thenAnswer(
        (_) async => VideoCommentsResponse(comments: comments, total: total),
      );
    }

    VideoComment restComment(String id, {String content = 'rest'}) =>
        VideoComment(
          id: id,
          pubkey: userPubkey,
          createdAt: 1000,
          kind: _commentKind,
          content: content,
          sig: 'sig',
          tags: [
            ['E', rootEventId],
            ['K', _rootEventKind.toString()],
            ['P', rootAuthorPubkey],
            ['e', rootEventId],
            ['k', _rootEventKind.toString()],
            ['p', rootAuthorPubkey],
          ],
        );

    Future<Comment> postOne({String content = 'my new comment'}) {
      return repository.postComment(
        content: content,
        rootEventId: rootEventId,
        rootEventKind: _rootEventKind,
        rootEventAuthorPubkey: rootAuthorPubkey,
      );
    }

    Future<CommentThread> load({DateTime? before}) {
      return repository.loadComments(
        rootEventId: rootEventId,
        rootEventKind: _rootEventKind,
        before: before,
      );
    }

    test(
      'merges the just-posted comment into a REST load that omits it',
      () async {
        final posted = await postOne();
        stubRest([restComment('other_comment')], total: 1);

        final thread = await load();

        expect(thread.commentCache.containsKey(posted.id), isTrue);
        expect(thread.comments, hasLength(2));
        // Just-posted comment is newest, so it sorts first.
        expect(thread.comments.first.id, equals(posted.id));
        // Count badge reflects the injected comment beyond the server total.
        expect(thread.totalCount, equals(2));
      },
    );

    test('does not duplicate once REST returns the posted comment', () async {
      final posted = await postOne();
      stubRest([restComment(posted.id)], total: 1);

      final first = await load();
      expect(first.comments, hasLength(1));
      expect(first.totalCount, equals(1));

      // The pending entry was pruned (backend caught up); a later read that
      // momentarily omits it again does not resurrect a stale copy.
      stubRest(<VideoComment>[], total: 0);
      final second = await load();
      expect(second.comments, isEmpty);
    });

    test('drops the pending comment after the retention window', () async {
      await postOne();
      now = now.add(const Duration(minutes: 11));
      stubRest(<VideoComment>[], total: 0);

      final thread = await load();

      expect(thread.comments, isEmpty);
      expect(thread.totalCount, equals(0));
    });

    test('merges into a relay-path load when REST is unavailable', () async {
      when(() => funnelcakeClient.isAvailable).thenReturn(false);
      final posted = await postOne();

      final thread = await load();

      expect(thread.comments.map((c) => c.id), contains(posted.id));
      expect(thread.totalCount, equals(1));
    });

    test('does not merge into paginated (before != null) loads', () async {
      when(() => funnelcakeClient.isAvailable).thenReturn(false);
      await postOne();

      final thread = await load(before: DateTime.utc(2030));

      expect(thread.comments, isEmpty);
    });

    test('clearCommentCountCache drops the pending buffer', () async {
      await postOne();
      repository.clearCommentCountCache();
      stubRest(<VideoComment>[], total: 0);

      final thread = await load();

      expect(thread.comments, isEmpty);
    });

    // #5854: the comments REST response is edge-cached and not purged on
    // comment ingest, so a post-action reload can serve a stale list. The
    // repository busts the cache while it holds a just-posted comment.
    group('cache-bust token (#5854)', () {
      List<Object?> capturedCacheBustTokens() {
        return verify(
          () => funnelcakeClient.getVideoComments(
            videoId: any(named: 'videoId'),
            sort: any(named: 'sort'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            cacheBustToken: captureAny(named: 'cacheBustToken'),
          ),
        ).captured;
      }

      test('passes a cacheBustToken after a local post', () async {
        await postOne();
        stubRest(<VideoComment>[], total: 0);

        await load();

        expect(capturedCacheBustTokens().single, isNotNull);
      });

      test('passes no cacheBustToken on a cold load', () async {
        stubRest(<VideoComment>[], total: 0);

        await load();

        expect(capturedCacheBustTokens().single, isNull);
      });
    });
  });
}
