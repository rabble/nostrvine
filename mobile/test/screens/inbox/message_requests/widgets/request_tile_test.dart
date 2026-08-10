// ABOUTME: Widget tests for RequestTile.
// ABOUTME: Verifies avatar, display name, "Sent a message request" subtitle,
// ABOUTME: unread dot, and tap callback.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/message_requests/widgets/request_tile.dart';
import 'package:openvine/widgets/user_avatar.dart';

import '../../../../helpers/test_provider_overrides.dart';

void main() {
  const currentPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const otherPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  final now = DateTime.now();
  final nowUnix = now.millisecondsSinceEpoch ~/ 1000;

  UserProfile createTestProfile({String? displayName}) {
    return UserProfile(
      pubkey: otherPubkey,
      displayName: displayName,
      rawData: const {},
      createdAt: now,
      eventId:
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
    );
  }

  DmConversation createTestConversation({bool isRead = true}) {
    return DmConversation(
      id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
      participantPubkeys: const [currentPubkey, otherPubkey],
      isGroup: false,
      createdAt: nowUnix,
      lastMessageContent: 'Hello',
      lastMessageTimestamp: nowUnix,
      isRead: isRead,
    );
  }

  group(RequestTile, () {
    group('renders', () {
      testWidgets('renders $UserAvatar', (tester) async {
        final testProfile = createTestProfile(displayName: 'Alice');
        final testConversation = createTestConversation();

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              userProfileReactiveProvider(
                otherPubkey,
              ).overrideWith((ref) => Stream.value(testProfile)),
            ],
            home: Scaffold(
              body: RequestTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(UserAvatar), findsOneWidget);
      });

      testWidgets('renders display name from profile', (tester) async {
        final testProfile = createTestProfile(displayName: 'Alice');
        final testConversation = createTestConversation();

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              userProfileReactiveProvider(
                otherPubkey,
              ).overrideWith((ref) => Stream.value(testProfile)),
            ],
            home: Scaffold(
              body: RequestTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Alice'), findsOneWidget);
      });

      testWidgets('always renders "Sent a message request" subtitle', (
        tester,
      ) async {
        final testProfile = createTestProfile(displayName: 'Alice');
        final testConversation = createTestConversation();

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              userProfileReactiveProvider(
                otherPubkey,
              ).overrideWith((ref) => Stream.value(testProfile)),
            ],
            home: Scaffold(
              body: RequestTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sent a message request'), findsOneWidget);
        // Should NOT show the actual message content
        expect(find.text('Hello'), findsNothing);
      });

      testWidgets('renders unread dot when conversation is unread', (
        tester,
      ) async {
        final testProfile = createTestProfile(displayName: 'Alice');
        final testConversation = createTestConversation(isRead: false);

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              userProfileReactiveProvider(
                otherPubkey,
              ).overrideWith((ref) => Stream.value(testProfile)),
            ],
            home: Scaffold(
              body: RequestTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find 8x8 red circle (unread dot)
        final dotFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.constraints?.maxWidth == 8 &&
              widget.constraints?.maxHeight == 8,
        );
        expect(dotFinder, findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('calls onTap when tapped', (tester) async {
        var tapped = false;
        final testProfile = createTestProfile(displayName: 'Alice');
        final testConversation = createTestConversation();

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              userProfileReactiveProvider(
                otherPubkey,
              ).overrideWith((ref) => Stream.value(testProfile)),
            ],
            home: Scaffold(
              body: RequestTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () => tapped = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(RequestTile));

        expect(tapped, isTrue);
      });
    });

    // #6416. Moderation recognition reached only the inbox list, so an
    // enforcement notice that arrived inbound-first — the normal shape for an
    // automated notice — rendered here as an unidentified stranger with
    // "Decline and remove" beside it. Neither key has a kind-0 the app can
    // read, so the profile is always null and the name was always generated.
    group('moderation identity', () {
      final l10n = lookupAppLocalizations(const Locale('en'));

      Future<void> pumpTileFor(
        WidgetTester tester,
        String counterparty,
      ) async {
        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              userProfileReactiveProvider(
                counterparty,
              ).overrideWith((ref) => Stream.value(null)),
            ],
            home: Scaffold(
              body: RequestTile(
                conversation: DmConversation(
                  id:
                      'dddddddddddddddddddddddddddddddddddddddddddddddddd'
                      'dddddddddddddd',
                  participantPubkeys: [currentPubkey, counterparty],
                  isGroup: false,
                  createdAt: nowUnix,
                ),
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      Finder wordmarkFinder() => find.byWidgetPredicate(
        (widget) => widget is DivineIcon && widget.icon == DivineIconName.logo,
        description: 'bundled Divine wordmark',
      );

      testWidgets('a retired moderation request is named and badged', (
        tester,
      ) async {
        final retired = kLegacyModerationPubkeys.first;

        await pumpTileFor(tester, retired);

        expect(find.text(l10n.inboxSupportRowTitle), findsOneWidget);
        expect(find.text(l10n.dmRetiredThreadClosedTitle), findsOneWidget);
        expect(find.text(l10n.inboxRequestTileSubtitle), findsNothing);
        expect(
          find.text(UserProfile.defaultDisplayNameFor(retired)),
          findsNothing,
        );
        expect(wordmarkFinder(), findsOneWidget);
      });

      testWidgets('the current moderation key is named and badged too', (
        tester,
      ) async {
        await pumpTileFor(tester, kModerationPubkeyHex);

        expect(find.text(l10n.inboxSupportRowTitle), findsOneWidget);
        expect(wordmarkFinder(), findsOneWidget);
      });

      testWidgets('an ordinary request is untouched', (tester) async {
        await pumpTileFor(tester, otherPubkey);

        expect(
          find.text(UserProfile.defaultDisplayNameFor(otherPubkey)),
          findsOneWidget,
        );
        expect(wordmarkFinder(), findsNothing);
      });
    });
  });
}
