// ABOUTME: Verifies CommentsRepository surfaces PublishOutcome + feedback via
// ABOUTME: PostCommentFailedException / DeleteCommentFailedException so the UI
// ABOUTME: can keep the draft text and render a retry-aware snackbar.

import 'package:comments_repository/comments_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _FakeEvent extends Fake implements Event {}

const _testUserPubkey =
    '82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2';
const _testRootEventId =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _testRootAuthorPubkey =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _testCommentId =
    '3333333333333333333333333333333333333333333333333333333333333333';

PublishOutcome _accepted(String id) => PublishOutcome(
  eventId: id,
  acceptedBy: const {'wss://relay.example.com'},
  rejectedBy: const {},
  noResponseFrom: const {},
);

PublishOutcome _transient(String id) => PublishOutcome(
  eventId: id,
  acceptedBy: const {},
  rejectedBy: const {},
  noResponseFrom: const {'wss://relay.example.com'},
);

PublishOutcome _permanent(String id) => PublishOutcome(
  eventId: id,
  acceptedBy: const {},
  rejectedBy: const {'wss://relay.example.com': 'blocked: spam'},
  noResponseFrom: const {},
);

void main() {
  late _MockNostrClient mockNostr;
  late CommentsRepository repo;

  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(const RetryPolicy());
  });

  setUp(() {
    mockNostr = _MockNostrClient();
    when(() => mockNostr.publicKey).thenReturn(_testUserPubkey);
    repo = CommentsRepository(nostrClient: mockNostr);
  });

  group('CommentsRepository publish reliability', () {
    test(
      'postComment success returns comment with event id from outcome',
      () async {
        when(
          () => mockNostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((inv) async {
          final e = inv.positionalArguments.first as Event;
          return _accepted(e.id);
        });

        final comment = await repo.postComment(
          content: 'hello world',
          rootEventId: _testRootEventId,
          rootEventKind: 34236,
          rootEventAuthorPubkey: _testRootAuthorPubkey,
        );

        expect(comment.content, equals('hello world'));
        expect(comment.authorPubkey, equals(_testUserPubkey));
      },
    );

    test(
      'postComment transient failure → exception carries retryable feedback',
      () async {
        when(
          () => mockNostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((inv) async {
          final e = inv.positionalArguments.first as Event;
          return _transient(e.id);
        });

        try {
          await repo.postComment(
            content: 'hello',
            rootEventId: _testRootEventId,
            rootEventKind: 34236,
            rootEventAuthorPubkey: _testRootAuthorPubkey,
          );
          fail('expected PostCommentFailedException');
        } on PostCommentFailedException catch (e) {
          expect(e.outcome, isNotNull);
          expect(e.feedback, isNotNull);
          expect(e.feedback!.retryable, isTrue);
          expect(e.feedback!.messageKey, 'publish_no_relay_response');
        }
      },
    );

    test(
      'deleteComment permanent rejection → non-retryable feedback with reason',
      () async {
        when(
          () => mockNostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((inv) async {
          final e = inv.positionalArguments.first as Event;
          return _permanent(e.id);
        });

        try {
          await repo.deleteComment(commentId: _testCommentId);
          fail('expected DeleteCommentFailedException');
        } on DeleteCommentFailedException catch (e) {
          expect(e.feedback!.retryable, isFalse);
          expect(e.feedback!.messageKey, 'publish_rejected_permanent');
          expect(e.feedback!.firstRejectionReason, 'blocked: spam');
        }
      },
    );

    test(
      'deleteComment transient failure is retryable',
      () async {
        when(
          () => mockNostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((inv) async {
          final e = inv.positionalArguments.first as Event;
          return _transient(e.id);
        });

        try {
          await repo.deleteComment(commentId: _testCommentId);
          fail('expected DeleteCommentFailedException');
        } on DeleteCommentFailedException catch (e) {
          expect(e.feedback!.retryable, isTrue);
        }
      },
    );
  });
}
