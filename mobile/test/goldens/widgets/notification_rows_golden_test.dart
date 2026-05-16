// ABOUTME: Layout tests for notification rows, covering the default and
// ABOUTME: large-text layouts that were stabilized for issues #4206 and #3387.
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
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
const _notificationGoldenTolerance = 0.03;
final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

void main() {
  final previousGoldenFileComparator = goldenFileComparator;
  goldenFileComparator = _TolerantGoldenFileComparator(
    Uri.parse('test/goldens/widgets/notification_rows_golden_test.dart'),
    precisionTolerance: _notificationGoldenTolerance,
  );
  tearDownAll(() => goldenFileComparator = previousGoldenFileComparator);

  group('Notification row layouts', () {
    testGoldens('notification rows render default layout', (tester) async {
      await withClock(Clock(() => _goldenNow), () async {
        await tester.pumpWidgetBuilder(
          _scenarioColumn(textScaleFactor: 1),
          wrapper: materialAppWrapper(
            theme: VineTheme.theme,
            localizations: AppLocalizations.localizationsDelegates,
            localeOverrides: AppLocalizations.supportedLocales,
          ),
          surfaceSize: const Size(420, 560),
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpAndSettle();

        expect(find.byType(ActorNotificationRow), findsOneWidget);
        expect(find.byType(VideoNotificationRow), findsOneWidget);
        expect(find.text(_l10n.notificationFollowBack), findsOneWidget);
        expect(
          find.byType(NotificationVideoThumbnail),
          findsOneWidget,
          reason: 'Default layout should keep the thumbnail inline.',
        );
        expect(tester.takeException(), isNull);
        await screenMatchesGolden(tester, 'notification_rows_default');
      });
    }, tags: 'golden');

    testGoldens('notification rows render max-font layout', (tester) async {
      await withClock(Clock(() => _goldenNow), () async {
        await tester.pumpWidgetBuilder(
          _scenarioColumn(textScaleFactor: 2),
          wrapper: materialAppWrapper(
            theme: VineTheme.theme,
            localizations: AppLocalizations.localizationsDelegates,
            localeOverrides: AppLocalizations.supportedLocales,
          ),
          surfaceSize: const Size(420, 1200),
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpAndSettle();

        expect(find.byType(ActorNotificationRow), findsOneWidget);
        expect(find.byType(VideoNotificationRow), findsOneWidget);
        expect(find.text(_l10n.notificationFollowBack), findsOneWidget);
        expect(
          find.byType(NotificationVideoThumbnail),
          findsOneWidget,
          reason: 'Large-text layout should still render the thumbnail.',
        );
        expect(tester.takeException(), isNull);
        await screenMatchesGolden(tester, 'notification_rows_max_font');
      });
    }, tags: 'golden');
  });
}

class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(
    super.testFile, {
    required double precisionTolerance,
  }) : assert(
         0 <= precisionTolerance && precisionTolerance <= 1,
         'precisionTolerance must be between 0 and 1',
       ),
       _precisionTolerance = precisionTolerance;

  final double _precisionTolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    // Linux CI shows a small amount of text antialiasing drift versus macOS.
    // Keep the threshold tight so real layout regressions still fail.
    final passed = result.passed || result.diffPercent <= _precisionTolerance;
    if (passed) {
      result.dispose();
      return true;
    }

    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
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

Widget _scenario({required double textScaleFactor, required Widget child}) {
  return SizedBox(
    width: 320,
    child: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScaleFactor)),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: VineTheme.backgroundColor),
        child: child,
      ),
    ),
  );
}
