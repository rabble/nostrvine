// ABOUTME: Layout tests for notification rows, covering the default and
// ABOUTME: large-text layouts that were stabilized for issues #4206 and #3387.

import 'package:clock/clock.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/notifications/widgets/actor_notification_row.dart';
import 'package:openvine/notifications/widgets/notification_video_thumbnail.dart';
import 'package:openvine/notifications/widgets/video_notification_row.dart';

const _alice = ActorInfo(
  pubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  displayName: 'Alice',
);

const _bob = ActorInfo(
  pubkey: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  displayName: 'Bob',
);

final _goldenNow = DateTime.utc(2026, 5, 15, 23);
final _notificationTimestamp = DateTime.utc(2026, 5, 15, 12);

void main() {
  group('Notification row layouts', () {
    testWidgets(
      'notification rows render default layout',
      tags: 'golden',
      (tester) async {
        await withClock(Clock(() => _goldenNow), () async {
          _setGoldenSurface(tester, const Size(420, 560));
          await tester.pumpWidget(
            _appWrapper(_scenarioColumn(textScaleFactor: 1)),
          );
          await tester.pumpAndSettle();

          expect(find.byType(ActorNotificationRow), findsOneWidget);
          expect(find.byType(VideoNotificationRow), findsOneWidget);
          expect(find.text('Follow back'), findsOneWidget);
          expect(
            find.byType(NotificationVideoThumbnail),
            findsOneWidget,
            reason: 'Default layout should keep the thumbnail inline.',
          );
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/notification_rows_default.png'),
          );
        });
      },
    );

    testWidgets(
      'notification rows render max-font layout',
      tags: 'golden',
      (tester) async {
        await withClock(Clock(() => _goldenNow), () async {
          _setGoldenSurface(tester, const Size(420, 1200));
          await tester.pumpWidget(
            _appWrapper(_scenarioColumn(textScaleFactor: 2)),
          );
          await tester.pumpAndSettle();

          expect(find.byType(ActorNotificationRow), findsOneWidget);
          expect(find.byType(VideoNotificationRow), findsOneWidget);
          expect(find.text('Follow back'), findsOneWidget);
          expect(
            find.byType(NotificationVideoThumbnail),
            findsOneWidget,
            reason: 'Large-text layout should still render the thumbnail.',
          );
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/notification_rows_max_font.png'),
          );
        });
      },
    );
  });
}

void _setGoldenSurface(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _scenarioColumn({required double textScaleFactor}) {
  final actorNotification = ActorNotification(
    id: 'follow-1',
    type: NotificationKind.follow,
    actor: _alice,
    timestamp: _notificationTimestamp,
  );
  final videoNotification = VideoNotification(
    id: 'comment-1',
    type: NotificationKind.comment,
    videoEventId:
        '1111111111111111111111111111111111111111111111111111111111111111',
    actors: const [_alice, _bob],
    totalCount: 2,
    timestamp: _notificationTimestamp,
    videoTitle: 'A longer title that exercises the responsive row layout',
    commentText:
        'This is a longer preview comment that should still render cleanly.',
  );

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _scenario(
        textScaleFactor: textScaleFactor,
        child: ActorNotificationRow(
          notification: actorNotification,
          onTap: () {},
          onProfileTap: () {},
          onFollowBack: () {},
        ),
      ),
      const SizedBox(height: 16),
      _scenario(
        textScaleFactor: textScaleFactor,
        child: VideoNotificationRow(
          notification: videoNotification,
          onTap: () {},
          onProfileTap: () {},
          onThumbnailTap: () {},
        ),
      ),
    ],
  );
}

Widget _scenario({
  required double textScaleFactor,
  required Widget child,
}) {
  return SizedBox(
    width: 320,
    child: MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(textScaleFactor),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: VineTheme.backgroundColor),
        child: child,
      ),
    ),
  );
}

Widget _appWrapper(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: VineTheme.theme,
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}
