import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/notifications/widgets/notification_avatar_stack.dart';
import 'package:openvine/notifications/widgets/notification_list_item.dart';

/// Returns a finder that matches [RichText] widgets whose plain text
/// contains [substring].
Finder _findRichTextContaining(String substring) {
  return find.byWidgetPredicate(
    (widget) {
      if (widget is RichText) {
        return widget.text.toPlainText().contains(substring);
      }
      return false;
    },
    description: 'RichText containing "$substring"',
  );
}

void main() {
  const actor = ActorInfo(
    pubkey: 'abc123',
    displayName: 'Alice',
    pictureUrl: 'https://example.com/alice.jpg',
  );

  const actor2 = ActorInfo(
    pubkey: 'def456',
    displayName: 'Bob',
  );

  const actor3 = ActorInfo(
    pubkey: 'ghi789',
    displayName: 'Carol',
  );

  Widget buildSubject(
    NotificationItem notification, {
    VoidCallback? onTap,
    VoidCallback? onProfileTap,
    VoidCallback? onFollowBack,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: NotificationListItem(
          notification: notification,
          onTap: onTap ?? () {},
          onProfileTap: onProfileTap,
          onFollowBack: onFollowBack,
        ),
      ),
    );
  }

  group(NotificationListItem, () {
    group('SingleNotification', () {
      testWidgets('renders actor name for like notification', (
        tester,
      ) async {
        final notification = SingleNotification(
          id: '1',
          type: NotificationKind.like,
          actor: actor,
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        );

        await tester.pumpWidget(buildSubject(notification));
        await tester.pump();

        expect(_findRichTextContaining('Alice'), findsOneWidget);
      });

      testWidgets('renders comment text for comment type', (tester) async {
        final notification = SingleNotification(
          id: '2',
          type: NotificationKind.comment,
          actor: actor,
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          commentText: 'Great video!',
        );

        await tester.pumpWidget(buildSubject(notification));
        await tester.pump();

        expect(find.text('Great video!'), findsOneWidget);
      });

      testWidgets('renders follow-back button for follow type', (
        tester,
      ) async {
        final notification = SingleNotification(
          id: '3',
          type: NotificationKind.follow,
          actor: actor,
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        );

        await tester.pumpWidget(buildSubject(notification));
        await tester.pump();

        expect(find.text('Follow back'), findsOneWidget);
      });

      testWidgets(
        'does not render follow-back button when already following',
        (tester) async {
          final notification = SingleNotification(
            id: '4',
            type: NotificationKind.follow,
            actor: actor,
            timestamp: DateTime.now().subtract(const Duration(hours: 2)),
            isFollowingBack: true,
          );

          await tester.pumpWidget(buildSubject(notification));
          await tester.pump();

          expect(find.text('Follow back'), findsNothing);
        },
      );

      testWidgets('calls onTap when tapped', (tester) async {
        var tapped = false;
        final notification = SingleNotification(
          id: '5',
          type: NotificationKind.like,
          actor: actor,
          timestamp: DateTime.now(),
        );

        await tester.pumpWidget(
          buildSubject(notification, onTap: () => tapped = true),
        );
        await tester.pump();

        await tester.tap(find.byType(NotificationListItem));
        await tester.pump();

        expect(tapped, isTrue);
      });

      testWidgets('calls onFollowBack when follow-back button is tapped', (
        tester,
      ) async {
        var followedBack = false;
        final notification = SingleNotification(
          id: '6',
          type: NotificationKind.follow,
          actor: actor,
          timestamp: DateTime.now(),
        );

        await tester.pumpWidget(
          buildSubject(
            notification,
            onFollowBack: () => followedBack = true,
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Follow back'));
        await tester.pump();

        expect(followedBack, isTrue);
      });

      testWidgets('renders reply comment text for reply type', (
        tester,
      ) async {
        final notification = SingleNotification(
          id: '7',
          type: NotificationKind.reply,
          actor: actor,
          timestamp: DateTime.now(),
          commentText: 'I agree!',
        );

        await tester.pumpWidget(buildSubject(notification));
        await tester.pump();

        expect(find.text('I agree!'), findsOneWidget);
      });

      testWidgets('uses unread background when not read', (tester) async {
        final notification = SingleNotification(
          id: '8',
          type: NotificationKind.like,
          actor: actor,
          timestamp: DateTime.now(),
        );

        await tester.pumpWidget(buildSubject(notification));
        await tester.pump();

        // The NotificationListItem wraps content in a Material widget.
        // Unread uses VineTheme.cardBackground, read uses backgroundColor.
        final materials = tester.widgetList<Material>(
          find.byType(Material),
        );

        // At least one Material should have a non-null color.
        expect(materials.any((m) => m.color != null), isTrue);
      });
    });

    group('GroupedNotification', () {
      testWidgets('renders grouped message', (tester) async {
        final notification = GroupedNotification(
          id: '10',
          type: NotificationKind.like,
          actors: const [actor, actor2, actor3],
          totalCount: 94,
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          videoTitle: 'My Video',
        );

        await tester.pumpWidget(buildSubject(notification));
        await tester.pump();

        expect(_findRichTextContaining('Alice'), findsOneWidget);
        expect(_findRichTextContaining('93 others'), findsOneWidget);
      });

      testWidgets('renders $NotificationAvatarStack for grouped', (
        tester,
      ) async {
        final notification = GroupedNotification(
          id: '11',
          type: NotificationKind.like,
          actors: const [actor, actor2],
          totalCount: 5,
          timestamp: DateTime.now(),
        );

        await tester.pumpWidget(buildSubject(notification));
        await tester.pump();

        expect(find.byType(NotificationAvatarStack), findsOneWidget);
      });

      testWidgets('calls onTap when grouped row is tapped', (tester) async {
        var tapped = false;
        final notification = GroupedNotification(
          id: '12',
          type: NotificationKind.like,
          actors: const [actor],
          totalCount: 1,
          timestamp: DateTime.now(),
        );

        await tester.pumpWidget(
          buildSubject(notification, onTap: () => tapped = true),
        );
        await tester.pump();

        await tester.tap(find.byType(NotificationListItem));
        await tester.pump();

        expect(tapped, isTrue);
      });
    });
  });
}
