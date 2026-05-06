// ABOUTME: Tests for VideoNotificationRow — single/multi actor messages,
// ABOUTME: thumbnail rendering, and tap callbacks (row, profile, thumbnail).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/notifications/widgets/notification_avatar_stack.dart';
import 'package:openvine/notifications/widgets/video_notification_row.dart';

const _alice = ActorInfo(
  pubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  displayName: 'Alice',
);

const _bob = ActorInfo(
  pubkey: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  displayName: 'Bob',
);

const _carol = ActorInfo(
  pubkey: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
  displayName: 'Carol',
);

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

VideoNotification _video({
  String id = 'n1',
  NotificationKind type = NotificationKind.like,
  List<ActorInfo> actors = const [_alice],
  int totalCount = 1,
  String? videoThumbnailUrl,
  String? videoTitle,
  bool isRead = false,
}) {
  return VideoNotification(
    id: id,
    type: type,
    videoEventId:
        '1111111111111111111111111111111111111111111111111111111111111111',
    actors: actors,
    totalCount: totalCount,
    timestamp: DateTime.utc(2026, 5, 4, 12),
    videoThumbnailUrl: videoThumbnailUrl,
    videoTitle: videoTitle,
    isRead: isRead,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required VideoNotification notification,
  VoidCallback? onTap,
  VoidCallback? onProfileTap,
  VoidCallback? onThumbnailTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: VideoNotificationRow(
          notification: notification,
          onTap: onTap ?? () {},
          onProfileTap: onProfileTap ?? () {},
          onThumbnailTap: onThumbnailTap ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  group(VideoNotificationRow, () {
    group('renders', () {
      testWidgets('actor name and like message when single actor', (
        tester,
      ) async {
        await _pump(tester, notification: _video());

        expect(
          find.text(_l10n.notificationLikedYourVideo('Alice')),
          findsOneWidget,
        );
      });

      testWidgets('"{first} and N others" when multi actor', (tester) async {
        await _pump(
          tester,
          notification: _video(
            actors: const [_alice, _bob, _carol],
            totalCount: 50,
          ),
        );

        final verb = _l10n.notificationLikedYourVideo('').trimLeft();
        expect(
          find.text(
            'Alice ${_l10n.notificationAndConnector} '
            '${_l10n.notificationOthersCount(49)} $verb',
          ),
          findsOneWidget,
        );
      });

      testWidgets('comment message for comment kind', (tester) async {
        await _pump(
          tester,
          notification: _video(type: NotificationKind.comment),
        );

        expect(
          find.text(_l10n.notificationCommentedOnYourVideo('Alice')),
          findsOneWidget,
        );
      });

      testWidgets('thumbnail placeholder when videoThumbnailUrl is null', (
        tester,
      ) async {
        await _pump(tester, notification: _video());

        expect(
          find.byKey(const Key('video_notification_thumbnail')),
          findsOneWidget,
        );
      });

      testWidgets('avatar stack for the actors', (tester) async {
        await _pump(
          tester,
          notification: _video(
            actors: const [_alice, _bob],
            totalCount: 2,
          ),
        );

        expect(find.byType(NotificationAvatarStack), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('tap on row fires onTap', (tester) async {
        var tapped = false;

        await _pump(
          tester,
          notification: _video(),
          onTap: () => tapped = true,
        );

        await tester.tap(find.byType(VideoNotificationRow));
        await tester.pump();

        expect(tapped, isTrue);
      });

      testWidgets('tap on thumbnail fires onThumbnailTap', (tester) async {
        var tapped = false;

        await _pump(
          tester,
          notification: _video(),
          onThumbnailTap: () => tapped = true,
        );

        await tester.tap(
          find.byKey(const Key('video_notification_thumbnail')),
        );
        await tester.pump();

        expect(tapped, isTrue);
      });

      testWidgets('tap on avatar stack fires onProfileTap', (tester) async {
        var tapped = false;

        await _pump(
          tester,
          notification: _video(),
          onProfileTap: () => tapped = true,
        );

        await tester.tap(find.byType(NotificationAvatarStack));
        await tester.pump();

        expect(tapped, isTrue);
      });
    });
  });
}
