import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/blurhash_display.dart';
import 'package:openvine/widgets/profile/profile_tab_thumbnail.dart';
import 'package:openvine/widgets/profile/profile_tab_thumbnail_placeholder.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

void main() {
  group(ProfileTabThumbnail, () {
    Widget buildSubject({
      String? thumbnailUrl,
      String? blurhash,
      bool isPrecached = false,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(
          body: SizedBox(
            width: 100,
            height: 100,
            child: ProfileTabThumbnail(
              thumbnailUrl: thumbnailUrl,
              blurhash: blurhash,
              isPrecached: isPrecached,
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('$ProfileTabThumbnailPlaceholder when thumbnailUrl is null', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());

        expect(find.byType(ProfileTabThumbnailPlaceholder), findsOneWidget);
        expect(find.byType(VineCachedImage), findsNothing);
      });

      testWidgets(
        '$ProfileTabThumbnailPlaceholder when thumbnailUrl is empty',
        (tester) async {
          await tester.pumpWidget(buildSubject(thumbnailUrl: ''));

          expect(find.byType(ProfileTabThumbnailPlaceholder), findsOneWidget);
          expect(find.byType(VineCachedImage), findsNothing);
        },
      );

      testWidgets('$VineCachedImage when thumbnailUrl is non-empty', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(thumbnailUrl: 'https://example.com/thumb.jpg'),
        );

        expect(find.byType(VineCachedImage), findsOneWidget);
      });

      testWidgets(
        '$VineCachedImage with default fade durations when not precached',
        (tester) async {
          await tester.pumpWidget(
            buildSubject(thumbnailUrl: 'https://example.com/thumb.jpg'),
          );

          final image = tester.widget<VineCachedImage>(
            find.byType(VineCachedImage),
          );
          expect(
            image.fadeInDuration,
            equals(const Duration(milliseconds: 500)),
          );
          expect(
            image.fadeOutDuration,
            equals(const Duration(milliseconds: 1000)),
          );
        },
      );

      testWidgets('$VineCachedImage with zero fade durations when precached', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            thumbnailUrl: 'https://example.com/thumb.jpg',
            isPrecached: true,
          ),
        );

        final image = tester.widget<VineCachedImage>(
          find.byType(VineCachedImage),
        );
        expect(image.fadeInDuration, equals(Duration.zero));
        expect(image.fadeOutDuration, equals(Duration.zero));
      });
    });

    group('blurhash fallback', () {
      const validBlurhash = 'LEHV6nWB2yk8pyo0adR*.7kCMdnj';

      testWidgets(
        '$BlurhashDisplay when thumbnailUrl is null and blurhash is provided',
        (tester) async {
          await tester.pumpWidget(buildSubject(blurhash: validBlurhash));

          expect(find.byType(BlurhashDisplay), findsOneWidget);
          expect(find.byType(ProfileTabThumbnailPlaceholder), findsNothing);
        },
      );

      testWidgets(
        '$ProfileTabThumbnailPlaceholder when thumbnailUrl and blurhash are '
        'both null',
        (tester) async {
          await tester.pumpWidget(buildSubject());

          expect(find.byType(ProfileTabThumbnailPlaceholder), findsOneWidget);
          expect(find.byType(BlurhashDisplay), findsNothing);
        },
      );

      testWidgets(
        '$ProfileTabThumbnailPlaceholder when blurhash is empty string',
        (tester) async {
          await tester.pumpWidget(buildSubject(blurhash: ''));

          expect(find.byType(ProfileTabThumbnailPlaceholder), findsOneWidget);
          expect(find.byType(BlurhashDisplay), findsNothing);
        },
      );
    });
  });
}
