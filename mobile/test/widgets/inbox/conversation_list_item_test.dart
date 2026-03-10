// ABOUTME: Widget tests for ConversationListItem
// ABOUTME: Tests rendering of single/group avatars, unread indicators,
// ABOUTME: content layout, and tap callbacks

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/inbox/conversation_list_item.dart';

void main() {
  group(ConversationListItem, () {
    group('renders', () {
      testWidgets('renders display name', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ConversationListItem(
                displayName: 'Alice',
                lastMessage: 'Hey!',
                timestamp: '14h',
              ),
            ),
          ),
        );

        expect(find.text('Alice'), findsOneWidget);
      });

      testWidgets('renders last message preview', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ConversationListItem(
                displayName: 'Alice',
                lastMessage: 'Hey there!',
                timestamp: '14h',
              ),
            ),
          ),
        );

        expect(find.text('Hey there!'), findsOneWidget);
      });

      testWidgets('renders timestamp', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ConversationListItem(
                displayName: 'Alice',
                lastMessage: 'Hey!',
                timestamp: '2d',
              ),
            ),
          ),
        );

        expect(find.text('2d'), findsOneWidget);
      });

      testWidgets('renders bottom divider', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ConversationListItem(
                displayName: 'Alice',
                lastMessage: 'Hey!',
                timestamp: '14h',
              ),
            ),
          ),
        );

        expect(find.byType(Divider), findsOneWidget);
      });

      testWidgets('renders fallback avatar when avatarUrl is null', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ConversationListItem(
                displayName: 'Alice',
                lastMessage: 'Hey!',
                timestamp: '14h',
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.person), findsOneWidget);
        expect(find.byType(CachedNetworkImage), findsNothing);
      });

      testWidgets('renders $CachedNetworkImage when avatarUrl is provided', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ConversationListItem(
                displayName: 'Alice',
                lastMessage: 'Hey!',
                timestamp: '14h',
                avatarUrl: 'https://example.com/avatar.jpg',
              ),
            ),
          ),
        );

        expect(find.byType(CachedNetworkImage), findsOneWidget);
      });

      testWidgets('renders unread dot when isUnread is true', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ConversationListItem(
                displayName: 'Alice',
                lastMessage: 'Hey!',
                timestamp: '14h',
                isUnread: true,
              ),
            ),
          ),
        );

        // The unread dot is inside a Positioned > DecoratedBox > SizedBox
        // with 8x8 size. Find via the Positioned widget.
        expect(find.byType(Positioned), findsOneWidget);
      });

      testWidgets('does not render unread dot when isUnread is false', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ConversationListItem(
                displayName: 'Alice',
                lastMessage: 'Hey!',
                timestamp: '14h',
              ),
            ),
          ),
        );

        // No Positioned widget should exist when not unread
        expect(find.byType(Positioned), findsNothing);
      });

      testWidgets('truncates display name with ellipsis', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ConversationListItem(
                displayName: 'A Very Long Name',
                lastMessage: 'Hey!',
                timestamp: '14h',
              ),
            ),
          ),
        );

        final nameText = tester.widget<Text>(find.text('A Very Long Name'));
        expect(nameText.maxLines, equals(1));
        expect(nameText.overflow, equals(TextOverflow.ellipsis));
      });

      testWidgets('truncates last message with ellipsis', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ConversationListItem(
                displayName: 'Alice',
                lastMessage:
                    'A very long message that '
                    'should be truncated in the preview',
                timestamp: '14h',
              ),
            ),
          ),
        );

        final messageText = tester.widget<Text>(
          find.text(
            'A very long message that '
            'should be truncated in the preview',
          ),
        );
        expect(messageText.maxLines, equals(1));
        expect(messageText.overflow, equals(TextOverflow.ellipsis));
      });
    });

    group('interactions', () {
      testWidgets('calls onTap when tapped', (tester) async {
        var wasTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConversationListItem(
                displayName: 'Alice',
                lastMessage: 'Hey!',
                timestamp: '14h',
                onTap: () => wasTapped = true,
              ),
            ),
          ),
        );

        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();

        expect(wasTapped, isTrue);
      });
    });

    group('group chat avatars', () {
      testWidgets('renders two-person group avatar for 2 participants', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ConversationListItem(
                displayName: 'Group Chat',
                lastMessage: 'Hey everyone!',
                timestamp: '1h',
                isGroupChat: true,
                participantCount: 2,
                participantAvatars: [
                  'https://example.com/a.jpg',
                  'https://example.com/b.jpg',
                ],
              ),
            ),
          ),
        );

        // Two-person group should have a Stack with two
        // positioned fallback avatars
        expect(find.byType(Stack), findsWidgets);
        expect(find.text('Group Chat'), findsOneWidget);
      });

      testWidgets('renders grid group avatar for 4+ participants', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ConversationListItem(
                displayName: 'Large Group',
                lastMessage: 'Welcome!',
                timestamp: '5m',
                isGroupChat: true,
                participantCount: 6,
                participantAvatars: [
                  'https://example.com/a.jpg',
                  'https://example.com/b.jpg',
                  'https://example.com/c.jpg',
                  'https://example.com/d.jpg',
                ],
              ),
            ),
          ),
        );

        // Grid avatar shows +count badge
        expect(find.text('+6'), findsOneWidget);
        expect(find.text('Large Group'), findsOneWidget);
      });
    });
  });
}
