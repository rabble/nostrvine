// ABOUTME: Widget tests for the account deletion orchestration helpers.
// ABOUTME: Verifies local auth cleanup does not run before retryable kind-5
// ABOUTME: deletion failures are handled.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/delete_account_dialog.dart';

class _MockAccountDeletionService extends Mock
    implements AccountDeletionService {}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pubkey =
      '1111111111111111111111111111111111111111111111111111111111111111';
  const nip62EventId =
      '2222222222222222222222222222222222222222222222222222222222222222';
  const failedEventId =
      '3333333333333333333333333333333333333333333333333333333333333333';
  const succeededEventId =
      '4444444444444444444444444444444444444444444444444444444444444444';

  testWidgets(
    'partial kind-5 failure keeps auth cleanup pending so retry can sign',
    (tester) async {
      final deletionService = _MockAccountDeletionService();
      final authService = _MockAuthService();
      final failedEvent = Event(pubkey, 34236, const [], 'video')
        ..id = failedEventId
        ..sig = 'sig';
      final nip62Outcome = PublishOutcome(
        eventId: nip62EventId,
        acceptedBy: const {'wss://relay.divine.video'},
        rejectedBy: const {},
        noResponseFrom: const {},
      );
      final batch = BatchDeletionResult(
        succeededEventIds: const {succeededEventId},
        failedEventIds: const {failedEventId},
        feedbacks: {
          failedEventId: const PublishUserFeedback(
            severity: PublishSeverity.error,
            messageKey: 'publish_no_relay_response',
            retryable: true,
          ),
          succeededEventId: PublishResultMapper.map(nip62Outcome),
        },
      );

      when(
        () => deletionService.deleteAccount(
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer(
        (_) async => DeleteAccountResult.nip62Success(
          deleteEventId: nip62EventId,
          outcome: nip62Outcome,
          feedback: PublishResultMapper.map(nip62Outcome),
          batch: batch,
          fetchedEvents: [failedEvent],
        ),
      );
      when(
        () => deletionService.retryFailedDeletions(
          originalEvents: any(named: 'originalEvents'),
          failedEventIds: any(named: 'failedEventIds'),
        ),
      ).thenAnswer(
        (_) async => const BatchDeletionResult(
          succeededEventIds: {failedEventId},
          failedEventIds: {},
          feedbacks: {},
        ),
      );
      when(authService.deleteKeycastAccount).thenAnswer((_) async {
        return (true, null);
      });
      when(
        () => authService.signOut(deleteKeys: true),
      ).thenAnswer((_) async {});

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => executeAccountDeletion(
                    context: context,
                    deletionService: deletionService,
                    authService: authService,
                  ),
                  child: const Text('Delete'),
                ),
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.textContaining('can be retried'), findsOneWidget);
      verifyNever(authService.deleteKeycastAccount);
      verifyNever(() => authService.signOut(deleteKeys: true));
    },
  );
}
