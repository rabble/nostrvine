// ABOUTME: Widget tests for the in-player DM reel reply/reaction bar.

import 'dart:async';

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/feed/dm_reply_context.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/video_feed_item/reel_dm_reply_bar.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockDmReactionsRepository extends Mock
    implements DmReactionsRepository {}

class _MockAuthService extends Mock implements AuthService {}

const _owner =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _peer =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _reelId =
    'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr';

DmReplyContext context({bool isOwn = false}) => DmReplyContext(
  conversationId: 'convo-id',
  participantPubkeys: const [_peer],
  isGroup: false,
  sharedReelMessageId: _reelId,
  messageAuthorPubkey: _peer,
  hintName: 'Alice',
  isOwnMessage: isOwn,
);

void main() {
  late _MockDmRepository dmRepo;
  late _MockDmReactionsRepository reactionsRepo;
  late _MockAuthService auth;
  late StreamController<List<DmReaction>> reactionStream;

  setUp(() {
    dmRepo = _MockDmRepository();
    reactionsRepo = _MockDmReactionsRepository();
    auth = _MockAuthService();
    reactionStream = StreamController<List<DmReaction>>.broadcast();

    when(() => auth.currentPublicKeyHex).thenReturn(_owner);
    when(
      () => reactionsRepo.watchForConversation(any()),
    ).thenAnswer((_) => reactionStream.stream);
    when(
      () => reactionsRepo.publish(
        conversationId: any(named: 'conversationId'),
        targetMessageId: any(named: 'targetMessageId'),
        targetMessageAuthor: any(named: 'targetMessageAuthor'),
        emoji: any(named: 'emoji'),
      ),
    ).thenAnswer(
      (_) async => const DmReactionPublishResult(success: true, rumorId: 'r'),
    );
  });

  tearDown(() => reactionStream.close());

  Widget wrap(DmReplyContext ctx) => ProviderScope(
    overrides: [
      dmRepositoryProvider.overrideWithValue(dmRepo),
      dmReactionsRepositoryProvider.overrideWithValue(reactionsRepo),
      authServiceProvider.overrideWithValue(auth),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          // Disable animations to exercise the reduced-motion path (the
          // player reaction overlay is suppressed) — these tests have no
          // ReelReplyBridge, so a reaction never triggers an overlay anyway.
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: ReelDmReplyBarHost(dmReplyContext: ctx),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('renders composer + the 6 quick emojis + picker button', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(context()));
    await tester.pump();

    for (final emoji in ReelReplyConstants.quickEmojis) {
      expect(find.text(emoji), findsOneWidget);
    }
    expect(find.byType(TextField), findsOneWidget);
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.bySemanticsLabel(l10n.dmReactionAddCustomA11yLabel), findsOne);
  });

  testWidgets('shows the contextual name hint for a peer reel', (tester) async {
    await tester.pumpWidget(wrap(context()));
    await tester.pump();
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.dmReelReplyComposerHint('Alice')), findsOneWidget);
  });

  testWidgets('shows "reply to yourself" hint on own reel', (tester) async {
    await tester.pumpWidget(wrap(context(isOwn: true)));
    await tester.pump();
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.dmReelReplyComposerHintSelf), findsOneWidget);
  });

  testWidgets('tapping a quick emoji publishes a reaction on the reel', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(context()));
    await tester.pump();

    await tester.tap(find.text('❤️'));
    await tester.pump();

    verify(
      () => reactionsRepo.publish(
        conversationId: 'convo-id',
        targetMessageId: _reelId,
        targetMessageAuthor: _peer,
        emoji: '❤️',
      ),
    ).called(1);
  });

  testWidgets('re-tapping the active emoji is a no-op', (tester) async {
    await tester.pumpWidget(wrap(context()));
    await tester.pump();

    await tester.tap(find.text('❤️'));
    await tester.pump();
    // Second tap of the same (now-active) emoji must not publish again.
    await tester.tap(find.text('❤️'));
    await tester.pump();

    verify(
      () => reactionsRepo.publish(
        conversationId: any(named: 'conversationId'),
        targetMessageId: any(named: 'targetMessageId'),
        targetMessageAuthor: any(named: 'targetMessageAuthor'),
        emoji: '❤️',
      ),
    ).called(1);
  });

  testWidgets('failed optimistic reaction can be retried with the same emoji', (
    tester,
  ) async {
    when(
      () => reactionsRepo.publish(
        conversationId: any(named: 'conversationId'),
        targetMessageId: any(named: 'targetMessageId'),
        targetMessageAuthor: any(named: 'targetMessageAuthor'),
        emoji: any(named: 'emoji'),
      ),
    ).thenAnswer(
      (_) async => const DmReactionPublishResult(
        success: false,
        rumorId: 'failed-rumor',
      ),
    );

    await tester.pumpWidget(wrap(context()));
    await tester.pump();

    await tester.tap(find.text('❤️'));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('❤️'));
    await tester.pump(ReelReplyConstants.reactionThrottle);
    await tester.pump();

    verify(
      () => reactionsRepo.publish(
        conversationId: any(named: 'conversationId'),
        targetMessageId: any(named: 'targetMessageId'),
        targetMessageAuthor: any(named: 'targetMessageAuthor'),
        emoji: '❤️',
      ),
    ).called(2);
  });

  testWidgets('submit while send is in flight preserves the draft', (
    tester,
  ) async {
    final pendingSend = Completer<NIP17SendResult>();
    when(
      () => dmRepo.sendMessage(
        recipientPubkey: any(named: 'recipientPubkey'),
        content: any(named: 'content'),
        replyToId: any(named: 'replyToId'),
      ),
    ).thenAnswer((_) => pendingSend.future);

    await tester.pumpWidget(wrap(context()));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'first reply');
    await tester.pump();
    await tester.tap(find.byType(IconButton));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'second reply');
    await tester.pump();
    await tester.tap(find.byType(IconButton));
    await tester.pump();

    expect(find.text('second reply'), findsOneWidget);
    verify(
      () => dmRepo.sendMessage(
        recipientPubkey: _peer,
        content: 'first reply',
        replyToId: _reelId,
      ),
    ).called(1);
    verifyNever(
      () => dmRepo.sendMessage(
        recipientPubkey: _peer,
        content: 'second reply',
        replyToId: _reelId,
      ),
    );

    pendingSend.complete(
      NIP17SendResult.success(
        rumorEventId: 'r',
        messageEventId: 'g',
        recipientPubkey: _peer,
      ),
    );
  });

  testWidgets('rapid different-emoji taps throttle to one immediate + one '
      'coalesced publish', (tester) async {
    await tester.pumpWidget(wrap(context()));
    await tester.pump();

    await tester.tap(find.text('❤️')); // leading edge: publishes immediately
    await tester.pump();
    await tester.tap(find.text('😂')); // within window: coalesced
    await tester.pump();

    // Only the leading ❤️ has published so far.
    verify(
      () => reactionsRepo.publish(
        conversationId: any(named: 'conversationId'),
        targetMessageId: any(named: 'targetMessageId'),
        targetMessageAuthor: any(named: 'targetMessageAuthor'),
        emoji: '❤️',
      ),
    ).called(1);

    // Advance past the throttle window; the coalesced 😂 publishes.
    await tester.pump(ReelReplyConstants.reactionThrottle);
    await tester.pump();
    verify(
      () => reactionsRepo.publish(
        conversationId: any(named: 'conversationId'),
        targetMessageId: any(named: 'targetMessageId'),
        targetMessageAuthor: any(named: 'targetMessageAuthor'),
        emoji: '😂',
      ),
    ).called(1);
  });

  testWidgets('tapping an emoji triggers the player reaction overlay', (
    tester,
  ) async {
    String? reacted;
    // Animations enabled (no disableAnimations MediaQuery) + a ReelReplyBridge
    // so the bar forwards the reaction to the player overlay.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dmRepositoryProvider.overrideWithValue(dmRepo),
          dmReactionsRepositoryProvider.overrideWithValue(reactionsRepo),
          authServiceProvider.overrideWithValue(auth),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ReelReplyBridge(
                setComposerFocused: (_) {},
                playReaction: (emoji) => reacted = emoji,
                child: ReelDmReplyBarHost(dmReplyContext: context()),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('❤️'));
    await tester.pump();

    expect(reacted, '❤️');
  });
}
