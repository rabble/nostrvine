// ABOUTME: Unit tests for ReportSubmissionCubit, the report sheet's
// ABOUTME: submission state machine across the kind-1984 and DM channels.

import 'package:bloc_test/bloc_test.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/report/report_submission_cubit.dart';
import 'package:openvine/services/content_moderation_types.dart';
import 'package:openvine/services/content_reporting_service.dart';

class _MockContentReportingService extends Mock
    implements ContentReportingService {}

class _MockDmRepository extends Mock implements DmRepository {}

const _moderationPubkey =
    '8fd5eb6d8f362163bc00a5ab6b4a3167dbf32d00ec4efdbcf43b3c9514433b7e';

/// A 64-hex blob hash, so `moderationDmTags` resolves it rather than dropping
/// it as malformed.
const _blobHash =
    'b1b2c3d4e5f6b1b2c3d4e5f6b1b2c3d4e5f6b1b2c3d4e5f6b1b2c3d4e5f6b1b2';

void main() {
  setUpAll(() {
    registerFallbackValue(ContentFilterReason.spam);
  });

  group(ReportTarget, () {
    ReportTarget targetWith({String? userPubkey}) => ReportTarget(
      eventId: 'event_id',
      authorPubkey: 'author_pubkey',
      userPubkey: userPubkey,
      sha256: _blobHash,
      videoUrl: 'https://blossom.example/$_blobHash',
      moderationKindLabel: 'Content Report',
      moderationEventLabel: 'Event',
    );

    test('carries a video blob hash on a content report', () {
      final target = targetWith();

      expect(target.moderationSha256, equals(_blobHash));
      expect(target.moderationVideoUrl, isNotNull);
    });

    test('withholds the blob hash from a user report', () {
      // The constructor allows a video and a userPubkey together, and
      // userPubkey is what routes to reportUser. Passing the hash regardless
      // would have the backend file an account-level report against that one
      // video.
      final target = targetWith(userPubkey: 'reported_user_pubkey');

      expect(target.moderationSha256, isNull);
      expect(target.moderationVideoUrl, isNull);
    });
  });

  group(ReportSubmissionCubit, () {
    late _MockContentReportingService reportingService;
    late _MockDmRepository dmRepository;

    setUp(() {
      reportingService = _MockContentReportingService();
      dmRepository = _MockDmRepository();

      when(
        () => reportingService.reportContent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          reason: any(named: 'reason'),
          details: any(named: 'details'),
          sourceRelay: any(named: 'sourceRelay'),
          additionalContext: any(named: 'additionalContext'),
          hashtags: any(named: 'hashtags'),
        ),
      ).thenAnswer(
        (_) async =>
            ReportResult.createSuccess('id', delivery: ReportDelivery.reached),
      );

      when(
        () => dmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
          additionalTags: any(named: 'additionalTags'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'rumor_id',
          messageEventId: 'dm_event_id',
          recipientPubkey: _moderationPubkey,
        ),
      );
    });

    ReportSubmissionCubit buildCubit({
      ModerationDmTransportResolver? resolveTransport,
    }) => ReportSubmissionCubit(
      contentReportingServiceFuture: Future.value(reportingService),
      resolveModerationDmTransport:
          resolveTransport ??
          () => (repository: dmRepository, pubkey: _moderationPubkey),
      target: const ReportTarget(
        eventId: 'event_id',
        authorPubkey: 'author_pubkey',
        moderationKindLabel: 'Content Report',
        moderationEventLabel: 'Event',
      ),
    );

    Future<String?> submit(ReportSubmissionCubit cubit) => cubit.submit(
      reason: ContentFilterReason.spam,
      reasonTitle: 'Spam',
      details: 'Spam',
    );

    blocTest<ReportSubmissionCubit, ReportSubmissionState>(
      'reaches submitted with no caveat when both channels land',
      build: buildCubit,
      act: submit,
      verify: (cubit) {
        expect(cubit.state.status, ReportSubmissionStatus.submitted);
        expect(cubit.state.moderationDmFailed, isFalse);
        expect(
          cubit.state.moderationDm.outcome,
          ModerationDmOutcome.delivered,
        );
      },
    );

    blocTest<ReportSubmissionCubit, ReportSubmissionState>(
      'stays resubmittable when the report reached no channel',
      build: () {
        when(
          () => reportingService.reportContent(
            eventId: any(named: 'eventId'),
            authorPubkey: any(named: 'authorPubkey'),
            reason: any(named: 'reason'),
            details: any(named: 'details'),
            sourceRelay: any(named: 'sourceRelay'),
            additionalContext: any(named: 'additionalContext'),
            hashtags: any(named: 'hashtags'),
          ),
        ).thenAnswer(
          (_) async => ReportResult.createSuccess(
            'id',
            delivery: ReportDelivery.localOnly,
          ),
        );
        return buildCubit();
      },
      act: submit,
      verify: (cubit) {
        // Not `submitted`: the confirmation screen would be false in four
        // places at once, so the form stays live for a one-tap retry.
        expect(cubit.state.status, ReportSubmissionStatus.notSent);
      },
    );

    test('hands back the rejection detail for the inline error', () async {
      when(
        () => reportingService.reportContent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          reason: any(named: 'reason'),
          details: any(named: 'details'),
          sourceRelay: any(named: 'sourceRelay'),
          additionalContext: any(named: 'additionalContext'),
          hashtags: any(named: 'hashtags'),
        ),
      ).thenAnswer((_) async => ReportResult.failure('Not authenticated'));
      final cubit = buildCubit();
      addTearDown(cubit.close);

      // The detail is returned, never emitted: state carries no error strings.
      expect(await submit(cubit), equals('Not authenticated'));
      expect(cubit.state.status, ReportSubmissionStatus.failure);
    });

    test('a moderation-side failure does not sink the report', () async {
      // The transport is resolved inside the dispatch precisely so this stays
      // a DM-only failure. Resolving it when the sheet opened would let the
      // moderation label service take down a report the kind-1984 channel
      // carried fine.
      final cubit = buildCubit(
        resolveTransport: () => throw StateError('moderation unavailable'),
      );
      addTearDown(cubit.close);

      await submit(cubit);

      expect(cubit.state.status, ReportSubmissionStatus.submitted);
      expect(cubit.state.moderationDmFailed, isTrue);
      verifyNever(
        () => dmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
          additionalTags: any(named: 'additionalTags'),
        ),
      );
    });

    test('re-drives the parked row rather than minting a second DM', () async {
      when(
        () => dmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
          additionalTags: any(named: 'additionalTags'),
        ),
      ).thenAnswer(
        (_) async => const NIP17SendResult.failure(
          'no relays',
          queuedRumorId: 'parked_rumor_id',
        ),
      );
      when(
        () => dmRepository.recoverFullSend(
          rumorId: any(named: 'rumorId'),
          resetRetryBudget: any(named: 'resetRetryBudget'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'parked_rumor_id',
          messageEventId: 'dm_event_id',
          recipientPubkey: _moderationPubkey,
        ),
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await submit(cubit);
      expect(
        cubit.state.moderationDm.queuedRumorId,
        equals('parked_rumor_id'),
      );

      // The same reason again: coalesce onto the row rather than stack a
      // second one for the sweep to deliver (#6610).
      await submit(cubit);

      verify(
        () => dmRepository.recoverFullSend(
          rumorId: 'parked_rumor_id',
          resetRetryBudget: true,
        ),
      ).called(1);
      verify(
        () => dmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
          additionalTags: any(named: 'additionalTags'),
        ),
      ).called(1);
      expect(cubit.state.moderationDm.queuedRumorId, isNull);
    });

    test('replaces the parked row when the reason moved', () async {
      when(
        () => dmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
          additionalTags: any(named: 'additionalTags'),
        ),
      ).thenAnswer(
        (_) async => const NIP17SendResult.failure(
          'no relays',
          queuedRumorId: 'parked_rumor_id',
        ),
      );
      when(
        () => dmRepository.cancelOutgoingSend(rumorId: any(named: 'rumorId')),
      ).thenAnswer((_) async => true);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await submit(cubit);

      // A parked rumor's tags are frozen at build time and replayed verbatim,
      // so re-driving after the user changed their mind would ship the
      // superseded NIP-32 label while the kind-1984 republish carries the new
      // one. Cancel and mint a correct one instead.
      await cubit.submit(
        reason: ContentFilterReason.harassment,
        reasonTitle: 'Harassment',
        details: 'Harassment',
      );

      verify(
        () => dmRepository.cancelOutgoingSend(rumorId: 'parked_rumor_id'),
      ).called(1);
      verifyNever(
        () => dmRepository.recoverFullSend(
          rumorId: any(named: 'rumorId'),
          resetRetryBudget: any(named: 'resetRetryBudget'),
        ),
      );
    });

    test('stops sending once a parked row becomes unreachable', () async {
      when(
        () => dmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
          additionalTags: any(named: 'additionalTags'),
        ),
      ).thenAnswer(
        (_) async => const NIP17SendResult.failure(
          'no relays',
          queuedRumorId: 'parked_rumor_id',
        ),
      );
      when(
        () => dmRepository.recoverFullSend(
          rumorId: any(named: 'rumorId'),
          resetRetryBudget: any(named: 'resetRetryBudget'),
        ),
      ).thenThrow(ArgumentError('no such outgoing send'));
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await submit(cubit);
      await submit(cubit);
      // Delivery can be neither confirmed nor retried, so a third submit must
      // not mint the #6610 duplicate — and must keep the caveat.
      await submit(cubit);

      expect(
        cubit.state.moderationDm.outcome,
        ModerationDmOutcome.unverifiable,
      );
      expect(cubit.state.moderationDmFailed, isTrue);
      verify(
        () => dmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
          additionalTags: any(named: 'additionalTags'),
        ),
      ).called(1);
    });

    test('does not DM the team twice for an unchanged resubmit', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await submit(cubit);
      await submit(cubit);

      // The kind-1984 republishes deliberately; the DM is the report itself,
      // so a second copy is a second ticket to triage.
      verify(
        () => reportingService.reportContent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          reason: any(named: 'reason'),
          details: any(named: 'details'),
          sourceRelay: any(named: 'sourceRelay'),
          additionalContext: any(named: 'additionalContext'),
          hashtags: any(named: 'hashtags'),
        ),
      ).called(2);
      verify(
        () => dmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
          additionalTags: any(named: 'additionalTags'),
        ),
      ).called(1);
    });
  });
}
