// ABOUTME: E2E regression for #7316 — tapping Retry on a failed reel DM reply
// ABOUTME: must re-drive the parked outgoing_dms row, never mint a second
// ABOUTME: rumor the recipient would render as a second message.
// ABOUTME: Drives the real ReelDmReplyBar + InlineReelReplyCubit + DmRepository
// ABOUTME: over a real socket to an in-process relay.
// ABOUTME: Requires: NO Docker stack — every dependency here is local.

@Tags(['service'])
library;

import 'package:analytics/analytics.dart';
import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/relay/relay_base.dart';
import 'package:nostr_sdk/relay/relay_status.dart';
import 'package:nostr_sdk/relay/web_socket_connection_manager.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/feed/dm_reply_context.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/video_feed_item/reel_dm_reply_bar.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../helpers/fake_relay.dart';
import '../helpers/navigation_helpers.dart';
import '../helpers/test_setup.dart';

class _MockDmReactionsRepository extends Mock
    implements DmReactionsRepository {}

class _MockAuthService extends Mock implements AuthService {}

class _MockScreenAnalyticsService extends Mock
    implements ScreenAnalyticsService {}

/// Points every dialed address at the in-process relay.
class _RedirectFactory implements WebSocketChannelFactory {
  _RedirectFactory(this.port);

  final int port;

  @override
  WebSocketChannel create(Uri uri) =>
      WebSocketChannel.connect(Uri.parse('ws://127.0.0.1:$port${uri.path}'));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const senderKey =
      '1111111111111111111111111111111111111111111111111111111111111111';
  const recipientKey =
      '2222222222222222222222222222222222222222222222222222222222222222';
  final senderPubkey = getPublicKey(senderKey);
  final recipientPubkey = getPublicKey(recipientKey);
  const reelMessageId =
      'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr';

  final replyContext = DmReplyContext(
    conversationId: DmRepository.computeConversationId(
      [senderPubkey, recipientPubkey]..sort(),
    ),
    participantPubkeys: [recipientPubkey],
    isGroup: false,
    sharedReelMessageId: reelMessageId,
    messageAuthorPubkey: recipientPubkey,
    hintName: 'Alice',
    isOwnMessage: false,
  );

  /// Real Nostr → NostrClient → NIP17MessageService → DmRepository, with a
  /// real Drift database, every socket landing on [relay].
  Future<({DmRepository repository, AppDatabase db, Nostr nostr})> buildStack(
    FakeRelay relay,
  ) async {
    final factory = _RedirectFactory(relay.port);
    final signer = LocalNostrSigner(senderKey);

    RelayBase gen(String url) =>
        RelayBase(url, RelayStatus(url), channelFactory: factory);
    final nostr = Nostr(signer, [], gen, channelFactory: factory);

    final relayManager = RelayManager(
      config: RelayManagerConfig(
        defaultRelayUrl: relay.url,
        storage: InMemoryRelayStorage(),
        autoReconnect: false,
      ),
      relayPool: nostr.relayPool,
    );
    final client = NostrClient.forTesting(
      nostr: nostr,
      relayManager: relayManager,
    );

    final db = AppDatabase.test(NativeDatabase.memory());
    addTearDown(db.close);

    final repository = DmRepository(
      nostrClient: client,
      directMessagesDao: db.directMessagesDao,
      conversationsDao: db.conversationsDao,
      outgoingDmsDao: db.outgoingDmsDao,
      userPubkey: senderPubkey,
      signer: signer,
      messageService: NIP17MessageService(
        signer: signer,
        senderPublicKey: senderPubkey,
        nostrService: client,
      ),
    );
    addTearDown(repository.stopListening);
    addTearDown(nostr.relayPool.removeAll);

    await client.initialize();

    return (repository: repository, db: db, nostr: nostr);
  }

  Widget wrap(DmRepository repository) {
    final reactionsRepo = _MockDmReactionsRepository();
    final auth = _MockAuthService();
    final analytics = _MockScreenAnalyticsService();

    when(
      () => reactionsRepo.watchForConversation(any()),
    ).thenAnswer((_) => const Stream<List<DmReaction>>.empty());
    when(() => auth.currentPublicKeyHex).thenReturn(senderPubkey);
    when(
      () => analytics.trackInteraction(
        any(),
        any(),
        params: any(named: 'params'),
      ),
    ).thenReturn(null);

    return ProviderScope(
      overrides: [
        dmRepositoryProvider.overrideWithValue(repository),
        dmReactionsRepositoryProvider.overrideWithValue(reactionsRepo),
        authServiceProvider.overrideWithValue(auth),
        screenAnalyticsServiceProvider.overrideWithValue(analytics),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ReelDmReplyBarHost(dmReplyContext: replyContext),
          ),
        ),
      ),
    );
  }

  group('#7316 reel reply Retry re-drives instead of re-sending', () {
    testWidgets(
      'soft-unconfirmed send: Retry re-drives the parked outgoing_dms row '
      'and never enqueues a second one',
      (tester) async {
        final originalOnError = suppressSetStateErrors();
        addTearDown(() => restoreErrorHandler(originalOnError));

        // A relay that accepts the frame but never sends `OK` — the exact
        // soft/unconfirmed shape the issue calls the worse case.
        final relay = await FakeRelay.start(okConfirms: false);
        addTearDown(relay.stop);
        final stack = await buildStack(relay);

        await tester.pumpWidget(wrap(stack.repository));
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));

        // ── First send ──
        logPhase('── Phase 1: first send (will go unconfirmed) ──');
        await tester.enterText(find.byType(TextField), 'reel reply probe');
        await tester.pump();
        await tester.tap(find.byType(IconButton));
        await tester.pump();

        final failed = await waitForWidget(
          tester,
          find.text(l10n.dmSendFailedRetry),
          maxSeconds: 45,
        );
        expect(failed, isTrue, reason: 'retry snackbar never appeared');

        final afterFirst = await stack.db.outgoingDmsDao.getForConversation(
          conversationId: replyContext.conversationId,
          ownerPubkey: senderPubkey,
        );
        logPhase('rows after first send: ${afterFirst.length}');
        for (final row in afterFirst) {
          logPhase('  row id=${row.id} content="${row.content}"');
        }
        expect(
          afterFirst,
          hasLength(1),
          reason: 'the first send must park exactly one durable row',
        );
        final firstRumorId = afterFirst.single.id;

        // Pump the snackbar's entrance animation to completion before tapping.
        // `waitForWidget` returns as soon as the label EXISTS, which is the
        // first frame of the slide-in — the action is still translated away
        // from where the finder reports it, and the tap misses.
        //
        // This doubles as the clock guard: `pump(duration)` advances real time
        // under the integration binding, and the wall clock must cross a full
        // second before the retry or the second rumor hashes to the same id
        // (`created_at` is seconds) and `enqueue`'s insertOrIgnore silently
        // coalesces the two rows. A human tapping a snackbar always clears
        // that bar; making it explicit keeps the test measuring the retry
        // rather than the clock.
        await pumpUntilSettled(tester, maxSeconds: 3);

        // ── Retry ──
        logPhase('── Phase 2: tap Retry ──');
        final wrapsBeforeRetry = relay.publishedEventIds.length;
        await tester.tap(
          find.widgetWithText(SnackBarAction, l10n.dmSendFailedRetry),
        );
        await tester.pump();

        // Let the second send run its full OK-confirm budget.
        await pumpUntilSettled(tester, maxSeconds: 20);

        // Positive control. Without it a tap that silently missed (the
        // snackbar hit-test trap above) would leave one row and read as
        // "no bug" — the most dangerous possible false negative for this
        // test. A retry that really ran publishes at least one more wrap.
        logPhase(
          'wraps published: $wrapsBeforeRetry before retry, '
          '${relay.publishedEventIds.length} after',
        );
        expect(
          relay.publishedEventIds.length,
          greaterThan(wrapsBeforeRetry),
          reason: 'the Retry tap never dispatched a send — test is invalid',
        );

        final afterRetry = await stack.db.outgoingDmsDao.getForConversation(
          conversationId: replyContext.conversationId,
          ownerPubkey: senderPubkey,
        );
        logPhase('rows after retry: ${afterRetry.length}');
        for (final row in afterRetry) {
          logPhase('  row id=${row.id} content="${row.content}"');
        }

        // The contract. Retry replays the SAME rumor, so the queue still holds
        // exactly one row under the original id. Before the #7316 fix this was
        // two rows under two ids, which the receiver keys `direct_messages` on
        // and therefore renders as two messages.
        expect(
          afterRetry.map((r) => r.id).toSet(),
          {firstRumorId},
          reason: 'Retry must re-drive the parked row, not mint a second rumor',
        );
        expect(
          afterRetry.single.content,
          'reel reply probe',
          reason: 'the surviving row still carries the reply text',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
