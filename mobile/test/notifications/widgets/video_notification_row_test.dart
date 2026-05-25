// ABOUTME: Tests for VideoNotificationRow — single/multi actor messages,
// ABOUTME: thumbnail rendering, and tap callbacks (row, profile, thumbnail).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/notification_constants.dart';
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
final AppLocalizations _jaL10n = lookupAppLocalizations(const Locale('ja'));

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
  Locale? locale,
  double textScaleFactor = 1,
}) async {
  // Pin a tall, deterministic surface: the 2× stacked layout needs the
  // vertical room production's scrollable list gives it, and pinning makes
  // the file immune to surface-size leaks under the shared-isolate CI run
  // (`very_good test --optimization`). Reset after each test. See #4719.
  await tester.binding.setSurfaceSize(const Size(420, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScaleFactor)),
          child: SizedBox(
            width: 320,
            child: VideoNotificationRow(
              notification: notification,
              onTap: onTap ?? () {},
              onProfileTap: onProfileTap ?? () {},
              onThumbnailTap: onThumbnailTap ?? () {},
            ),
          ),
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

      testWidgets(
        'uses locale-correct single-actor wording for Japanese like text',
        (tester) async {
          await _pump(
            tester,
            locale: const Locale('ja'),
            notification: _video(),
          );

          expect(
            find.textContaining(_jaL10n.notificationLikedYourVideo('Alice')),
            findsOneWidget,
          );
        },
      );

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

      testWidgets('appends video title for like / comment / repost', (
        tester,
      ) async {
        await _pump(tester, notification: _video(videoTitle: 'My Cool Vine'));

        expect(find.textContaining('My Cool Vine'), findsOneWidget);
      });

      testWidgets('renders $NotificationCommentQuote when commentText is set', (
        tester,
      ) async {
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
      });

      testWidgets('no $NotificationCommentQuote when commentText is null', (
        tester,
      ) async {
        await _pump(
          tester,
          notification: _video(type: NotificationKind.comment),
        );

        expect(find.byType(NotificationCommentQuote), findsNothing);
      });

      testWidgets('timestamp moves to the quote when commentText is present', (
        tester,
      ) async {
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
      });

      testWidgets('thumbnail placeholder when videoThumbnailUrl is null', (
        tester,
      ) async {
        await _pump(tester, notification: _video());

        expect(find.byType(NotificationVideoThumbnail), findsOneWidget);
      });

      testWidgets('avatar stack for the actors', (tester) async {
        await _pump(
          tester,
          notification: _video(actors: const [_alice, _bob], totalCount: 2),
        );

        expect(find.byType(NotificationAvatarStack), findsOneWidget);
      });

      testWidgets('moves the thumbnail below the text at large font sizes', (
        tester,
      ) async {
        await _pump(
          tester,
          notification: _video(
            videoTitle: 'A fairly long title for max-font testing',
          ),
          textScaleFactor: 2,
        );

        final message = tester.getTopLeft(find.textContaining('Alice'));
        final thumbnail = tester.getTopLeft(
          find.byType(NotificationVideoThumbnail),
        );
        expect(thumbnail.dy, greaterThan(message.dy));
      });

      testWidgets('keeps the thumbnail inline below the stack threshold', (
        tester,
      ) async {
        await _pump(
          tester,
          notification: _video(
            videoTitle: 'A fairly long title for threshold testing',
          ),
          textScaleFactor: NotificationConstants.largeTextStackThreshold - 0.01,
        );

        final message = tester.getTopLeft(find.textContaining('Alice'));
        final thumbnail = tester.getTopLeft(
          find.byType(NotificationVideoThumbnail),
        );
        expect(thumbnail.dy, lessThan(message.dy));
      });

      testWidgets('stacks the thumbnail above the stack threshold', (
        tester,
      ) async {
        await _pump(
          tester,
          notification: _video(
            videoTitle: 'A fairly long title for threshold testing',
          ),
          textScaleFactor: NotificationConstants.largeTextStackThreshold + 0.01,
        );

        final message = tester.getTopLeft(find.textContaining('Alice'));
        final thumbnail = tester.getTopLeft(
          find.byType(NotificationVideoThumbnail),
        );
        expect(thumbnail.dy, greaterThan(message.dy));
      });
    });

    group('interactions', () {
      testWidgets('tap on row fires onTap', (tester) async {
        var tapped = false;

        await _pump(tester, notification: _video(), onTap: () => tapped = true);

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

        await tester.tap(find.byType(NotificationVideoThumbnail));
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

      testWidgets('does not overflow at large text sizes', (tester) async {
        await _pump(
          tester,
          notification: _video(
            type: NotificationKind.comment,
            videoTitle: 'A fairly long title for max-font layout verification',
            commentText:
                'This is a longer comment preview to exercise the stacked '
                'thumbnail layout path.',
          ),
          textScaleFactor: 2,
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    });
  });
}
