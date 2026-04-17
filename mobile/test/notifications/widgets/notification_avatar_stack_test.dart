@Tags(['skip_very_good_optimization'])
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/notifications/widgets/notification_avatar_stack.dart';

void main() {
  const actor1 = ActorInfo(
    pubkey: 'abc123',
    displayName: 'Alice',
    pictureUrl: 'https://example.com/alice.jpg',
  );

  const actor2 = ActorInfo(
    pubkey: 'def456',
    displayName: 'Bob',
    pictureUrl: 'https://example.com/bob.jpg',
  );

  const actorNoPhoto = ActorInfo(
    pubkey: 'ghi789',
    displayName: 'Carol',
  );

  Widget buildSubject({
    required List<ActorInfo> actors,
    int? overflowCount,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: NotificationAvatarStack(
          actors: actors,
          overflowCount: overflowCount,
        ),
      ),
    );
  }

  group(NotificationAvatarStack, () {
    testWidgets('renders single avatar for one actor', (tester) async {
      await tester.pumpWidget(buildSubject(actors: const [actor1]));
      await tester.pump();

      expect(find.byType(CachedNetworkImage), findsOneWidget);
    });

    testWidgets('renders two avatars for two actors', (tester) async {
      await tester.pumpWidget(
        buildSubject(actors: const [actor1, actor2]),
      );
      await tester.pump();

      expect(find.byType(CachedNetworkImage), findsNWidgets(2));
    });

    testWidgets('renders three positioned items for three actors', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(actors: const [actor1, actor2, actorNoPhoto]),
      );
      await tester.pump();

      // actor1 and actor2 have URLs => CachedNetworkImage
      expect(find.byType(CachedNetworkImage), findsNWidgets(2));
      // 3 Positioned widgets for the 3 avatars
      expect(find.byType(Positioned), findsNWidgets(3));
    });

    testWidgets('renders overflow circle when overflowCount > 0', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(actors: const [actor1], overflowCount: 42),
      );
      await tester.pump();

      expect(find.text('+42'), findsOneWidget);
    });

    testWidgets('does not render overflow circle when overflowCount is null', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(actors: const [actor1]));
      await tester.pump();

      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('caps displayed avatars at 3', (tester) async {
      const actor4 = ActorInfo(
        pubkey: 'jkl012',
        displayName: 'Dave',
        pictureUrl: 'https://example.com/dave.jpg',
      );

      await tester.pumpWidget(
        buildSubject(
          actors: const [actor1, actor2, actorNoPhoto, actor4],
        ),
      );
      await tester.pump();

      // Only first 3 actors shown; actor1 and actor2 have URLs
      expect(find.byType(CachedNetworkImage), findsNWidgets(2));
      // 3 Positioned widgets (not 4)
      expect(find.byType(Positioned), findsNWidgets(3));
    });
  });
}
