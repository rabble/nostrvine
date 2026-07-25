// ABOUTME: Widget tests for ConversationTile.
// ABOUTME: Verifies avatar, display name, last message, unread dot, and tap.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/widgets/conversation_tile.dart';
import 'package:openvine/widgets/user_avatar.dart';

import '../../../helpers/test_provider_overrides.dart';

void main() {
  const currentPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const otherPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  final now = DateTime.now();
  final nowUnix = now.millisecondsSinceEpoch ~/ 1000;

  UserProfile createTestProfile({String? displayName, String? name}) {
    return UserProfile(
      pubkey: otherPubkey,
      displayName: displayName,
      name: name,
      rawData: const {},
      createdAt: now,
      eventId:
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
    );
  }

  DmConversation createTestConversation({
    String? lastMessageContent,
    int? lastMessageTimestamp,
    bool isRead = true,
  }) {
    return DmConversation(
      id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
      participantPubkeys: const [currentPubkey, otherPubkey],
      isGroup: false,
      createdAt: nowUnix,
      lastMessageContent: lastMessageContent,
      lastMessageTimestamp: lastMessageTimestamp,
      isRead: isRead,
    );
  }

  /// The [SemanticsProperties] of the tile's own outermost Semantics wrapper.
  ///
  /// `onLongPressHint` lands in `SemanticsHintOverrides`, which `SemanticsData`
  /// does not expose, so the widget's declared properties are the accessible
  /// assertion point.
  SemanticsProperties tileSemantics(WidgetTester tester) {
    return tester
        .widget<Semantics>(
          find
              .descendant(
                of: find.byType(ConversationTile),
                matching: find.byType(Semantics),
              )
              .first,
        )
        .properties;
  }

  group(ConversationTile, () {
    group('renders', () {
      testWidgets('renders $UserAvatar', (tester) async {
        final testProfile = createTestProfile(displayName: 'Alice');
        final testConversation = createTestConversation();

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => testProfile),
            ],
            home: Scaffold(
              body: ConversationTile(
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
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => testProfile),
            ],
            home: Scaffold(
              body: ConversationTile(
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

      testWidgets('renders last message content', (tester) async {
        final testProfile = createTestProfile(displayName: 'Alice');
        final testConversation = createTestConversation(
          lastMessageContent: 'Hey, how are you?',
          lastMessageTimestamp: nowUnix,
        );

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => testProfile),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Hey, how are you?'), findsOneWidget);
      });

      testWidgets(
        'last message preview uses VineTheme.onSurfaceVariant',
        (tester) async {
          // PR #3548 picked onSurfaceVariant for the preview; a later
          // drift slid it back to onSurfaceMuted (one shade darker) and
          // shipped without anyone catching it. Pin the color so the
          // same drift can't recur silently.
          final testProfile = createTestProfile(displayName: 'Alice');
          final testConversation = createTestConversation(
            lastMessageContent: 'Hey, how are you?',
            lastMessageTimestamp: nowUnix,
          );

          await tester.pumpWidget(
            testMaterialApp(
              additionalOverrides: [
                fetchUserProfileProvider(
                  otherPubkey,
                ).overrideWith((ref) async => testProfile),
              ],
              home: Scaffold(
                body: ConversationTile(
                  conversation: testConversation,
                  currentUserPubkey: currentPubkey,
                  onTap: () {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final preview = tester.widget<Text>(find.text('Hey, how are you?'));
          expect(preview.style?.color, equals(VineTheme.onSurfaceVariant));
        },
      );

      // #3662 — the structured collab invite carries a deterministic
      // plaintext fallback ('...Open diVine to review and accept.') so
      // legacy clients can still see something. Inside diVine that copy
      // is misleading; the conversation list should show a localized
      // label instead.
      testWidgets(
        'replaces legacy collab invite plaintext with localized preview',
        (tester) async {
          final testProfile = createTestProfile(displayName: 'Alice');
          final testConversation = createTestConversation(
            lastMessageContent:
                'You were invited to collaborate on Skate loop. '
                'Open diVine to review and accept.',
            lastMessageTimestamp: nowUnix,
          );

          await tester.pumpWidget(
            testMaterialApp(
              additionalOverrides: [
                fetchUserProfileProvider(
                  otherPubkey,
                ).overrideWith((ref) async => testProfile),
              ],
              home: Scaffold(
                body: ConversationTile(
                  conversation: testConversation,
                  currentUserPubkey: currentPubkey,
                  onTap: () {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final l10n = lookupAppLocalizations(const Locale('en'));
          expect(
            find.text(l10n.inboxConversationCollabInvitePreview),
            findsOneWidget,
          );
          expect(
            find.textContaining('Open diVine to review and accept'),
            findsNothing,
          );
        },
      );

      testWidgets(
        'strips divine.video URL and prefixes a camera icon for shared-video DMs',
        (tester) async {
          // VideoSharingService composes a share DM as
          //   [personal message?]
          //   "title"
          //   <blank>
          //   https://divine.video/video/<id>
          // The conversation preview shouldn't surface the URL; it should
          // render an inline cameraRetro icon (the same glyph as the
          // bottom-nav camera button) followed by the title.
          final testProfile = createTestProfile(displayName: 'Alice');
          final testConversation = createTestConversation(
            lastMessageContent:
                '"#DIVINE #TEAMFB @shutupphia"\n\n'
                'https://divine.video/video/abc123',
            lastMessageTimestamp: nowUnix,
          );

          await tester.pumpWidget(
            testMaterialApp(
              additionalOverrides: [
                fetchUserProfileProvider(
                  otherPubkey,
                ).overrideWith((ref) async => testProfile),
              ],
              home: Scaffold(
                body: ConversationTile(
                  conversation: testConversation,
                  currentUserPubkey: currentPubkey,
                  onTap: () {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.textContaining('"#DIVINE #TEAMFB @shutupphia"'),
            findsOneWidget,
          );
          expect(
            find.textContaining('https://divine.video'),
            findsNothing,
          );
          final cameraIcon = find.byWidgetPredicate(
            (widget) =>
                widget is DivineIcon &&
                widget.icon == DivineIconName.cameraRetro &&
                widget.color == VineTheme.whiteText,
          );
          expect(cameraIcon, findsOneWidget);
        },
      );

      testWidgets(
        'plain-text preview does not include the camera icon',
        (tester) async {
          final testProfile = createTestProfile(displayName: 'Alice');
          final testConversation = createTestConversation(
            lastMessageContent: 'Hey, how are you?',
            lastMessageTimestamp: nowUnix,
          );

          await tester.pumpWidget(
            testMaterialApp(
              additionalOverrides: [
                fetchUserProfileProvider(
                  otherPubkey,
                ).overrideWith((ref) async => testProfile),
              ],
              home: Scaffold(
                body: ConversationTile(
                  conversation: testConversation,
                  currentUserPubkey: currentPubkey,
                  onTap: () {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is DivineIcon &&
                  widget.icon == DivineIconName.cameraRetro,
            ),
            findsNothing,
          );
        },
      );

      testWidgets('renders unread indicator when conversation is unread', (
        tester,
      ) async {
        final testProfile = createTestProfile(displayName: 'Alice');
        final testConversation = createTestConversation(isRead: false);

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => testProfile),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The unread dot is an 8x8 Container with BoxShape.circle
        final dotFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.constraints?.maxWidth == 8 &&
              widget.constraints?.maxHeight == 8,
        );
        expect(dotFinder, findsOneWidget);
      });

      testWidgets(
        'does not render unread indicator when conversation is read',
        (tester) async {
          final testProfile = createTestProfile(displayName: 'Alice');
          final testConversation = createTestConversation();

          await tester.pumpWidget(
            testMaterialApp(
              additionalOverrides: [
                fetchUserProfileProvider(
                  otherPubkey,
                ).overrideWith((ref) async => testProfile),
              ],
              home: Scaffold(
                body: ConversationTile(
                  conversation: testConversation,
                  currentUserPubkey: currentPubkey,
                  onTap: () {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // No 8x8 circle Container should exist
          final dotFinder = find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.constraints?.maxWidth == 8 &&
                widget.constraints?.maxHeight == 8,
          );
          expect(dotFinder, findsNothing);
        },
      );

      testWidgets('renders emphasized preview when conversation is unread', (
        tester,
      ) async {
        final testProfile = createTestProfile(displayName: 'Alice');
        final testConversation = createTestConversation(
          lastMessageContent: 'Hey, how are you?',
          lastMessageTimestamp: nowUnix,
          isRead: false,
        );

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => testProfile),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final preview = tester.widget<Text>(find.text('Hey, how are you?'));
        expect(preview.style?.fontWeight, equals(FontWeight.w600));
        expect(preview.style?.color, equals(VineTheme.whiteText));
      });

      testWidgets('renders muted preview when conversation is read', (
        tester,
      ) async {
        final testProfile = createTestProfile(displayName: 'Alice');
        final testConversation = createTestConversation(
          lastMessageContent: 'Hey, how are you?',
          lastMessageTimestamp: nowUnix,
        );

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => testProfile),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final preview = tester.widget<Text>(find.text('Hey, how are you?'));
        expect(preview.style?.fontWeight, equals(FontWeight.w400));
        expect(preview.style?.color, equals(VineTheme.onSurfaceVariant));
      });

      testWidgets('announces unread status in the semantic label', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final testProfile = createTestProfile(displayName: 'Alice');
        final testConversation = createTestConversation(
          lastMessageContent: 'Hey, how are you?',
          lastMessageTimestamp: nowUnix,
          isRead: false,
        );

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => testProfile),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final semantics = tester.getSemantics(find.byType(ConversationTile));
        expect(
          semantics.label,
          contains(l10n.inboxConversationTileLabelUnread('Alice')),
        );
      });

      testWidgets('omits the unread prefix from the label when read', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final testProfile = createTestProfile(displayName: 'Alice');
        final testConversation = createTestConversation(
          lastMessageContent: 'Hey, how are you?',
          lastMessageTimestamp: nowUnix,
        );

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => testProfile),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final semantics = tester.getSemantics(find.byType(ConversationTile));
        expect(
          semantics.label,
          contains(l10n.inboxConversationTileLabel('Alice')),
        );
        expect(
          semantics.label,
          isNot(contains(l10n.inboxConversationTileLabelUnread('Alice'))),
        );
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
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => testProfile),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () => tapped = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(ConversationTile));
        await tester.pumpAndSettle();

        expect(tapped, isTrue);
      });

      testWidgets('calls onLongPress when long-pressed', (tester) async {
        var longPressed = false;
        final testProfile = createTestProfile(displayName: 'Alice');
        final testConversation = createTestConversation();

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => testProfile),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () {},
                onLongPress: () => longPressed = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.longPress(find.byType(ConversationTile));
        await tester.pumpAndSettle();

        expect(longPressed, isTrue);
      });
    });

    group('highlight', () {
      testWidgets(
        'applies $VineTheme.containerLow background when highlighted',
        (tester) async {
          final testProfile = createTestProfile(displayName: 'Alice');
          final testConversation = createTestConversation();

          await tester.pumpWidget(
            testMaterialApp(
              additionalOverrides: [
                fetchUserProfileProvider(
                  otherPubkey,
                ).overrideWith((ref) async => testProfile),
              ],
              home: Scaffold(
                body: ConversationTile(
                  conversation: testConversation,
                  currentUserPubkey: currentPubkey,
                  highlighted: true,
                  onTap: () {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final decoratedBox = tester.widget<DecoratedBox>(
            find
                .descendant(
                  of: find.byType(ConversationTile),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          );
          final decoration = decoratedBox.decoration as BoxDecoration;
          expect(decoration.color, equals(VineTheme.containerLow));
        },
      );

      testWidgets('has no background color when not highlighted', (
        tester,
      ) async {
        final testProfile = createTestProfile(displayName: 'Alice');
        final testConversation = createTestConversation();

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => testProfile),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final decoratedBox = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(ConversationTile),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final decoration = decoratedBox.decoration as BoxDecoration;
        expect(decoration.color, isNull);
      });
    });

    group('fixed-identity overrides (#6283)', () {
      testWidgets('displayNameOverride wins over the resolved profile', (
        tester,
      ) async {
        final testProfile = createTestProfile(displayName: 'Alice');

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => testProfile),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: createTestConversation(),
                currentUserPubkey: currentPubkey,
                onTap: () {},
                displayNameOverride: 'Divine Moderation',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Divine Moderation'), findsOneWidget);
        expect(find.text('Alice'), findsNothing);
      });

      testWidgets('displayNameOverride also wins before the profile '
          'repository is ready', (tester) async {
        // profileRepositoryProvider is null until the relay client is ready,
        // so the tile's fallback is a generated "Adjective Animal N" name.
        // A pinned, known account must never render that.
        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => null),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: createTestConversation(),
                currentUserPubkey: currentPubkey,
                onTap: () {},
                displayNameOverride: 'Divine Moderation',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Divine Moderation'), findsOneWidget);
        expect(
          find.text(UserProfile.defaultDisplayNameFor(otherPubkey)),
          findsNothing,
        );
      });

      testWidgets('subtitleOverride replaces the message preview', (
        tester,
      ) async {
        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => null),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: createTestConversation(
                  lastMessageContent: 'Hello',
                ),
                currentUserPubkey: currentPubkey,
                onTap: () {},
                subtitleOverride: 'Bugs, moderation, account stuff.',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Bugs, moderation, account stuff.'), findsOneWidget);
        expect(find.text('Hello'), findsNothing);
      });

      testWidgets('advertises no long-press hint when no handler is given', (
        tester,
      ) async {
        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => null),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: createTestConversation(),
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The hint is a promise to assistive tech; without onLongPress there
        // is no action sheet to open, so promising one is a lie.
        expect(tileSemantics(tester).hintOverrides?.onLongPressHint, isNull);
      });

      testWidgets('keeps the long-press hint when a handler IS given', (
        tester,
      ) async {
        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => null),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: createTestConversation(),
                currentUserPubkey: currentPubkey,
                onTap: () {},
                onLongPress: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tileSemantics(tester).hintOverrides?.onLongPressHint,
          isNotNull,
        );
      });
    });
  });
}
