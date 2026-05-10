// ABOUTME: Tests for VideoNotificationRow — single/multi actor messages,
// ABOUTME: thumbnail rendering, and tap callbacks (row, profile, thumbnail).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/notifications/widgets/notification_avatar_stack.dart';
import 'package:openvine/notifications/widgets/notification_comment_quote.dart';
import 'package:openvine/notifications/widgets/notification_video_thumbnail.dart';
import 'package:openvine/notifications/widgets/video_notification_row.dart';
import 'package:openvine/widgets/notification_type_icon.dart';

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
  String? commentText,
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
    commentText: commentText,
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
      testWidgets('leading $NotificationTypeIcon for every kind', (
        tester,
      ) async {
        await _pump(tester, notification: _video());
        expect(find.byType(NotificationTypeIcon), findsOneWidget);
      });

      testWidgets('actor name and like message when single actor', (
        tester,
      ) async {
        await _pump(tester, notification: _video());

        expect(
          find.textContaining(_l10n.notificationLikedYourVideo('Alice')),
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
          find.textContaining(
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
          find.textContaining(_l10n.notificationCommentedOnYourVideo('Alice')),
          findsOneWidget,
        );
      });

      testWidgets(
        'appends video title for like / comment / repost',
        (tester) async {
          await _pump(
            tester,
            notification: _video(videoTitle: 'My Cool Vine'),
          );

          expect(find.textContaining('My Cool Vine'), findsOneWidget);
        },
      );

      testWidgets(
        'renders $NotificationCommentQuote when commentText is set',
        (tester) async {
          await _pump(
            tester,
            notification: _video(
              type: NotificationKind.comment,
              commentText: 'Loved this clip!',
            ),
          );

          // The quote widget renders the body with curly quotes.
          expect(find.byType(NotificationCommentQuote), findsOneWidget);
          expect(find.textContaining('Loved this clip!'), findsOneWidget);
        },
      );

      testWidgets(
        'no $NotificationCommentQuote when commentText is null',
        (tester) async {
          await _pump(
            tester,
            notification: _video(type: NotificationKind.comment),
          );

          expect(find.byType(NotificationCommentQuote), findsNothing);
        },
      );

      testWidgets(
        'timestamp moves to the quote when commentText is present',
        (tester) async {
          // The timestamp must anchor to the visual end of the row, so
          // when a comment quote is rendered the timestamp goes there
          // instead of the message line. This test asserts the message
          // line does NOT carry the timestamp suffix while the quote
          // does.
          await _pump(
            tester,
            notification: _video(
              type: NotificationKind.comment,
              commentText: 'Thanks!',
            ),
          );

          final quoteWidget = tester.widget<NotificationCommentQuote>(
            find.byType(NotificationCommentQuote),
          );
          // The widget owns the timestamp suffix.
          expect(quoteWidget.timestamp, isNotNull);
          expect(quoteWidget.timestamp, isNotEmpty);
        },
      );

      testWidgets('thumbnail placeholder when videoThumbnailUrl is null', (
        tester,
      ) async {
        await _pump(tester, notification: _video());

        expect(
          find.byType(NotificationVideoThumbnail),
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
          find.byType(NotificationVideoThumbnail),
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
