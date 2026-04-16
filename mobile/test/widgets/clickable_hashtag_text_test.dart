import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/clickable_hashtag_text.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _FakeUrlLauncherPlatform extends UrlLauncherPlatform {
  String? launchedUrl;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launchedUrl = url;
    return true;
  }

  @override
  LinkDelegate? get linkDelegate => null;
}

const _testHexPubkey =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

void main() {
  group('ClickableHashtagText', () {
    late UrlLauncherPlatform originalUrlLauncherPlatform;
    late _FakeUrlLauncherPlatform fakeUrlLauncherPlatform;

    setUp(() {
      originalUrlLauncherPlatform = UrlLauncherPlatform.instance;
      fakeUrlLauncherPlatform = _FakeUrlLauncherPlatform();
      UrlLauncherPlatform.instance = fakeUrlLauncherPlatform;
    });

    tearDown(() {
      UrlLauncherPlatform.instance = originalUrlLauncherPlatform;
    });

    testWidgets('displays plain text without hashtags correctly', (
      tester,
    ) async {
      const plainText = 'This is a simple text without hashtags';

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ClickableHashtagText(text: plainText)),
        ),
      );

      expect(find.text(plainText), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('displays text with single hashtag', (tester) async {
      const textWithHashtag = 'Check out this #vine';

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ClickableHashtagText(text: textWithHashtag)),
        ),
      );

      // The Text.rich widget should contain the full text
      // Note: Text.rich with spans doesn't match find.text(), find by type instead
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('displays text with multiple hashtags', (tester) async {
      const textWithHashtags = '#trending videos on #vine are #amazing';

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ClickableHashtagText(text: textWithHashtags)),
        ),
      );

      // Text.rich with spans doesn't match find.text()
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('handles hashtags at end of text', (tester) async {
      const textWithTrailingHashtag = 'This is awesome #vine';

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ClickableHashtagText(text: textWithTrailingHashtag),
          ),
        ),
      );

      // Text.rich with spans doesn't match find.text()
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('handles hashtags with underscores and numbers', (
      tester,
    ) async {
      const textWithComplexHashtags = 'Testing #vine_2024 and #test_123';

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ClickableHashtagText(text: textWithComplexHashtags),
          ),
        ),
      );

      // Text.rich with spans doesn't match find.text()
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('respects maxLines property', (tester) async {
      const longText =
          'This is a very long text with #hashtag1 and #hashtag2 '
          'that should be truncated based on maxLines property. '
          'Here is more text with #hashtag3 and #hashtag4 '
          'that might not be visible due to line limits.';

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ClickableHashtagText(text: longText, maxLines: 2),
          ),
        ),
      );

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.maxLines, 2);
    });

    testWidgets('handles empty text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ClickableHashtagText(text: '')),
        ),
      );

      // Empty text should render as SizedBox.shrink
      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('handles text with only spaces', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ClickableHashtagText(text: '   ')),
        ),
      );

      // Text with only spaces should still render
      expect(find.text('   '), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('widget builds without errors', (tester) async {
      // Test various edge cases to ensure no crashes
      final testCases = [
        'Normal text',
        '#hashtag',
        'Text with #hashtag in middle',
        'Multiple #hashtags #here',
        '#start with hashtag',
        'End with hashtag #end',
        '##double#hashtag',
        'Special chars #test!',
        '#',
        '# space after hash',
        'URL https://example.com/#anchor should not be hashtag',
      ];

      for (final testText in testCases) {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ClickableHashtagText(text: testText)),
          ),
        );

        // Should not crash
        expect(find.byType(ClickableHashtagText), findsOneWidget);

        // Clear the widget tree before next test
        await tester.pumpWidget(Container());
      }
    });

    testWidgets('launches bare domains as external links', (tester) async {
      const textWithLink = 'Read more at example.com/docs';

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ClickableHashtagText(text: textWithLink)),
          ),
        ),
      );

      final text = tester.widget<Text>(find.byType(Text));
      final textSpan = text.textSpan! as TextSpan;
      final spans = textSpan.children!.cast<TextSpan>();
      final linkSpan = spans.firstWhere(
        (span) => span.text == 'example.com/docs',
      );

      expect(linkSpan.recognizer, isNotNull);

      final recognizer = linkSpan.recognizer! as TapGestureRecognizer;
      recognizer.onTap!();
      await tester.pump();

      expect(fakeUrlLauncherPlatform.launchedUrl, 'https://example.com/docs');
    });

    testWidgets('parses bare npub mentions as tappable profile spans', (
      tester,
    ) async {
      final npub = NostrKeyUtils.encodePubKey(_testHexPubkey);
      final textWithMention = 'Find me at $npub';

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ClickableHashtagText(text: textWithMention)),
          ),
        ),
      );

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.textSpan, isNotNull);

      final textSpan = text.textSpan! as TextSpan;
      final spans = textSpan.children!.cast<TextSpan>();
      final mentionSpan = spans.firstWhere(
        (span) => span.text != null && span.text!.startsWith('@npub1'),
      );

      expect(mentionSpan.recognizer, isA<TapGestureRecognizer>());
    });

    testWidgets('parses bare nprofile mentions as tappable profile spans', (
      tester,
    ) async {
      final nprofile = NIP19Tlv.encodeNprofile(
        Nprofile(pubkey: _testHexPubkey),
      );
      final textWithMention = 'Find me at $nprofile';

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ClickableHashtagText(text: textWithMention)),
          ),
        ),
      );

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.textSpan, isNotNull);

      final textSpan = text.textSpan! as TextSpan;
      final spans = textSpan.children!.cast<TextSpan>();
      final mentionSpan = spans.firstWhere(
        (span) => span.text != null && span.text!.startsWith('@npub1'),
      );

      expect(mentionSpan.recognizer, isA<TapGestureRecognizer>());
    });

    testWidgets('uses display nip05 when no profile name is available', (
      tester,
    ) async {
      final npub = NostrKeyUtils.encodePubKey(_testHexPubkey);
      final textWithMention = 'Find me at $npub';
      final profile = UserProfile(
        pubkey: _testHexPubkey,
        nip05: '_@alice.divine.video',
        rawData: const {},
        createdAt: DateTime.utc(2026, 4, 16),
        eventId:
            'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileReactiveProvider(_testHexPubkey).overrideWith(
              (ref) => Stream.value(profile),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ClickableHashtagText(text: textWithMention)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.textSpan, isNotNull);

      final textSpan = text.textSpan! as TextSpan;
      final spans = textSpan.children!.cast<TextSpan>();
      final mentionSpan = spans.firstWhere(
        (span) => span.text == '@alice.divine.video',
      );

      expect(mentionSpan.recognizer, isA<TapGestureRecognizer>());
    });

    // Note: Testing tap functionality and navigation requires integration testing
    // or mocking the navigation system, which is complex in this context.
    // The tap functionality would be tested in integration tests.
  });
}
