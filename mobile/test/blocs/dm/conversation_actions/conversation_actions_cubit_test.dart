// ABOUTME: Tests for ConversationActionsCubit — report, block, remove.
// ABOUTME: Verifies service delegation, return values, and error handling.

import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_service/content_blocklist_service.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/dm/conversation_actions/conversation_actions_cubit.dart';
import 'package:openvine/services/content_moderation_service.dart';
import 'package:openvine/services/content_reporting_service.dart';

class _MockContentReportingService extends Mock
    implements ContentReportingService {}

class _MockContentBlocklistService extends Mock
    implements ContentBlocklistService {}

class _MockDmRepository extends Mock implements DmRepository {}

void main() {
  const pubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const currentUserPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const conversationId =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

  group(ConversationActionsCubit, () {
    late _MockContentReportingService mockReportingService;
    late _MockContentBlocklistService mockBlocklistService;
    late _MockDmRepository mockDmRepo;

    setUp(() {
      mockReportingService = _MockContentReportingService();
      mockBlocklistService = _MockContentBlocklistService();
      mockDmRepo = _MockDmRepository();
    });

    ConversationActionsCubit createCubit({
      ContentReportingService? reportingService,
    }) => ConversationActionsCubit(
      contentReportingService: reportingService ?? mockReportingService,
      contentBlocklistService: mockBlocklistService,
      dmRepository: mockDmRepo,
      currentUserPubkey: currentUserPubkey,
    );

    test('initial state is idle', () {
      final cubit = createCubit();
      expect(cubit.state.status, ConversationActionsStatus.idle);
      cubit.close();
    });

    group('isBlocked', () {
      test('delegates to ContentBlocklistService', () {
        when(() => mockBlocklistService.isBlocked(pubkey)).thenReturn(true);

        final cubit = createCubit();
        expect(cubit.isBlocked(pubkey), isTrue);

        verify(() => mockBlocklistService.isBlocked(pubkey)).called(1);
        cubit.close();
      });
    });

    group('reportUser', () {
      blocTest<ConversationActionsCubit, ConversationActionsState>(
        'returns true when report succeeds',
        setUp: () {
          when(
            () => mockReportingService.reportUser(
              userPubkey: pubkey,
              reason: ContentFilterReason.other,
              details: 'Reported from DM conversation',
            ),
          ).thenAnswer(
            (_) async => ReportResult.createSuccess('report-id'),
          );
        },
        build: createCubit,
        act: (cubit) async {
          final result = await cubit.reportUser(pubkey);
          expect(result, isTrue);
        },
        expect: () => [
          const ConversationActionsState(
            status: ConversationActionsStatus.processing,
          ),
          const ConversationActionsState(),
        ],
        verify: (_) {
          verify(
            () => mockReportingService.reportUser(
              userPubkey: pubkey,
              reason: ContentFilterReason.other,
              details: 'Reported from DM conversation',
            ),
          ).called(1);
        },
      );

      blocTest<ConversationActionsCubit, ConversationActionsState>(
        'returns false when reporting service is null',
        build: () => ConversationActionsCubit(
          contentReportingService: null,
          contentBlocklistService: mockBlocklistService,
          dmRepository: mockDmRepo,
          currentUserPubkey: currentUserPubkey,
        ),
        act: (cubit) async {
          final result = await cubit.reportUser(pubkey);
          expect(result, isFalse);
        },
        expect: () => <ConversationActionsState>[],
      );

      blocTest<ConversationActionsCubit, ConversationActionsState>(
        'returns false and calls addError on failure',
        setUp: () {
          when(
            () => mockReportingService.reportUser(
              userPubkey: pubkey,
              reason: ContentFilterReason.other,
              details: 'Reported from DM conversation',
            ),
          ).thenThrow(Exception('Network error'));
        },
        build: createCubit,
        act: (cubit) async {
          final result = await cubit.reportUser(pubkey);
          expect(result, isFalse);
        },
        expect: () => [
          const ConversationActionsState(
            status: ConversationActionsStatus.processing,
          ),
          const ConversationActionsState(),
        ],
        errors: () => [isA<Exception>()],
      );
    });

    group('blockUser', () {
      blocTest<ConversationActionsCubit, ConversationActionsState>(
        'emits processing then success and calls blocklistService',
        setUp: () {
          when(
            () => mockBlocklistService.blockUser(
              pubkey,
              ourPubkey: currentUserPubkey,
            ),
          ).thenAnswer((_) async {});
        },
        build: createCubit,
        act: (cubit) => cubit.blockUser(pubkey),
        expect: () => [
          const ConversationActionsState(
            status: ConversationActionsStatus.processing,
          ),
          const ConversationActionsState(
            status: ConversationActionsStatus.success,
          ),
        ],
        verify: (_) {
          verify(
            () => mockBlocklistService.blockUser(
              pubkey,
              ourPubkey: currentUserPubkey,
            ),
          ).called(1);
        },
      );

      blocTest<ConversationActionsCubit, ConversationActionsState>(
        'emits failure and calls addError when blocklistService throws',
        setUp: () {
          when(
            () => mockBlocklistService.blockUser(
              pubkey,
              ourPubkey: currentUserPubkey,
            ),
          ).thenAnswer((_) async => throw Exception('block failed'));
        },
        build: createCubit,
        act: (cubit) => cubit.blockUser(pubkey),
        expect: () => [
          const ConversationActionsState(
            status: ConversationActionsStatus.processing,
          ),
          const ConversationActionsState(
            status: ConversationActionsStatus.failure,
          ),
        ],
        errors: () => [isA<Exception>()],
      );
    });

    group('unblockUser', () {
      blocTest<ConversationActionsCubit, ConversationActionsState>(
        'emits processing then success and calls unblockUser',
        setUp: () {
          when(
            () => mockBlocklistService.unblockUser(pubkey),
          ).thenAnswer((_) async {});
        },
        build: createCubit,
        act: (cubit) => cubit.unblockUser(pubkey),
        expect: () => [
          const ConversationActionsState(
            status: ConversationActionsStatus.processing,
          ),
          const ConversationActionsState(
            status: ConversationActionsStatus.success,
          ),
        ],
        verify: (_) {
          verify(
            () => mockBlocklistService.unblockUser(pubkey),
          ).called(1);
        },
      );

      blocTest<ConversationActionsCubit, ConversationActionsState>(
        'emits failure and calls addError when unblockUser throws',
        setUp: () {
          when(
            () => mockBlocklistService.unblockUser(pubkey),
          ).thenAnswer((_) async => throw Exception('unblock failed'));
        },
        build: createCubit,
        act: (cubit) => cubit.unblockUser(pubkey),
        expect: () => [
          const ConversationActionsState(
            status: ConversationActionsStatus.processing,
          ),
          const ConversationActionsState(
            status: ConversationActionsStatus.failure,
          ),
        ],
        errors: () => [isA<Exception>()],
      );
    });

    group('removeConversation', () {
      blocTest<ConversationActionsCubit, ConversationActionsState>(
        'returns true on success',
        setUp: () {
          when(
            () => mockDmRepo.removeConversation(any()),
          ).thenAnswer((_) async {});
        },
        build: createCubit,
        act: (cubit) async {
          final result = await cubit.removeConversation(conversationId);
          expect(result, isTrue);
        },
        expect: () => [
          const ConversationActionsState(
            status: ConversationActionsStatus.processing,
          ),
          const ConversationActionsState(
            status: ConversationActionsStatus.success,
          ),
        ],
        verify: (_) {
          verify(
            () => mockDmRepo.removeConversation(conversationId),
          ).called(1);
        },
      );

      blocTest<ConversationActionsCubit, ConversationActionsState>(
        'returns false and calls addError on failure',
        setUp: () {
          when(
            () => mockDmRepo.removeConversation(any()),
          ).thenThrow(Exception('DB error'));
        },
        build: createCubit,
        act: (cubit) async {
          final result = await cubit.removeConversation(conversationId);
          expect(result, isFalse);
        },
        expect: () => [
          const ConversationActionsState(
            status: ConversationActionsStatus.processing,
          ),
          const ConversationActionsState(
            status: ConversationActionsStatus.failure,
          ),
        ],
        errors: () => [isA<Exception>()],
      );
    });
  });
}
