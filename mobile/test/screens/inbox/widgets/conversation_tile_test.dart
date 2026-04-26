// ABOUTME: Widget tests for ConversationTile.
// ABOUTME: Verifies avatar, display name, last message, unread dot, and tap.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
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
  });
}
