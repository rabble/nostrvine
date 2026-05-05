// ABOUTME: Tests for ActorNotificationRow — follow / mention / system
// ABOUTME: rendering, follow-back button visibility, and tap callbacks.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/notifications/widgets/actor_notification_row.dart';

const _alice = ActorInfo(
  pubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  displayName: 'Alice',
);

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

ActorNotification _actor({
  String id = 'n1',
  NotificationKind type = NotificationKind.follow,
  String? commentText,
  bool isFollowingBack = false,
  bool isRead = false,
}) {
  return ActorNotification(
    id: id,
    type: type,
    actor: _alice,
    timestamp: DateTime.utc(2026, 5, 4, 12),
    commentText: commentText,
    isFollowingBack: isFollowingBack,
    isRead: isRead,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required ActorNotification notification,
  VoidCallback? onTap,
  VoidCallback? onProfileTap,
  VoidCallback? onFollowBack,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ActorNotificationRow(
          notification: notification,
          onTap: onTap ?? () {},
          onProfileTap: onProfileTap ?? () {},
          onFollowBack: onFollowBack,
        ),
      ),
    ),
  );
}

void main() {
  group(ActorNotificationRow, () {
    group('renders', () {
      testWidgets('"{actor} started following you" for follow', (
        tester,
      ) async {
        await _pump(tester, notification: _actor());

        expect(
          find.text(_l10n.notificationStartedFollowing('Alice')),
          findsOneWidget,
        );
      });

      testWidgets('"{actor} mentioned you" for mention', (tester) async {
        await _pump(
          tester,
          notification: _actor(type: NotificationKind.mention),
        );

        expect(
          find.text(_l10n.notificationMentionedYou('Alice')),
          findsOneWidget,
        );
      });

      testWidgets('system message for system kind', (tester) async {
        await _pump(
          tester,
          notification: _actor(type: NotificationKind.system),
        );

        expect(find.text(_l10n.notificationSystemUpdate), findsOneWidget);
      });

      testWidgets('"{actor} liked your comment" for likeComment', (
        tester,
      ) async {
        await _pump(
          tester,
          notification: _actor(type: NotificationKind.likeComment),
        );

        expect(
          find.text(_l10n.notificationLikedYourComment('Alice')),
          findsOneWidget,
        );
      });

      testWidgets('Follow back button when not yet following', (tester) async {
        await _pump(tester, notification: _actor());

        expect(find.text('Follow back'), findsOneWidget);
      });

      testWidgets('no Follow back button when already following back', (
        tester,
      ) async {
        await _pump(
          tester,
          notification: _actor(isFollowingBack: true),
        );

        expect(find.text('Follow back'), findsNothing);
      });

      testWidgets('comment text for mention with commentText', (tester) async {
        await _pump(
          tester,
          notification: _actor(
            type: NotificationKind.mention,
            commentText: 'Hey check this out',
          ),
        );

        expect(find.text('Hey check this out'), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('tap on row fires onTap', (tester) async {
        var tapped = false;

        await _pump(
          tester,
          notification: _actor(),
          onTap: () => tapped = true,
        );

        await tester.tap(find.byType(ActorNotificationRow));
        await tester.pump();

        expect(tapped, isTrue);
      });

      testWidgets('tap on Follow back fires onFollowBack', (tester) async {
        var tapped = false;

        await _pump(
          tester,
          notification: _actor(),
          onFollowBack: () => tapped = true,
        );

        await tester.tap(find.text('Follow back'));
        await tester.pump();

        expect(tapped, isTrue);
      });
    });
  });
}
