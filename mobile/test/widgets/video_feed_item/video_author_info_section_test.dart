// ABOUTME: Semantics regressions for shared author overlay metadata.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/og_viner_cache_service.dart';
import 'package:openvine/widgets/video_feed_item/video_author_info_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_provider_overrides.dart';

void main() {
  late VideoEvent video;
  late AppLocalizations enL10n;

  const testPubkey =
      'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

  setUpAll(() {
    enL10n = lookupAppLocalizations(const Locale('en'));
  });

  setUp(() {
    video = VideoEvent(
      id: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      pubkey: testPubkey,
      createdAt: 1757385263,
      content: '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
      videoUrl: 'https://example.com/video.mp4',
      authorName: 'Semantic Display Name',
      originalLoops: 0,
    );
  });

  testWidgets(
    'author row Semantics use localized avatar and author templates',
    (tester) async {
      final mockNostr = createMockNostrService();
      when(() => mockNostr.publicKey).thenReturn(testPubkey);

      await tester.pumpWidget(
        testProviderScope(
          mockNostrService: mockNostr,
          additionalOverrides: [
            userProfileReactiveProvider(testPubkey).overrideWith(
              (ref) => Stream<UserProfile?>.value(null),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoAuthorInfoSection(
                video: video,
                hasTextContent: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(
          enL10n.videoAuthorSemanticLabel(video.authorName!),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(enL10n.videoAuthorAvatarSemanticLabel),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'author row uses shared username badge rendering for OG Viners',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        ogVinerPubkeysCacheKey: jsonEncode([testPubkey]),
      });
      final prefs = await SharedPreferences.getInstance();
      final mockNostr = createMockNostrService();
      when(() => mockNostr.publicKey).thenReturn(testPubkey);

      await tester.pumpWidget(
        testProviderScope(
          mockNostrService: mockNostr,
          mockSharedPreferences: prefs,
          additionalOverrides: [
            userProfileReactiveProvider(testPubkey).overrideWith(
              (ref) => Stream<UserProfile?>.value(null),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoAuthorInfoSection(
                video: video,
                hasTextContent: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(video.authorName!), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'OG Viner',
        ),
        findsOneWidget,
      );
    },
  );
}
