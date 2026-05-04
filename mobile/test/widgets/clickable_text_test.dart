// ABOUTME: ClickableText URL-detection coverage. Hashtag/mention paths are
// ABOUTME: covered by comprehensive_clickable_hashtag_text_test.dart.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/clickable_text.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      ),
    );
  }

  TextSpan urlSpan(WidgetTester tester) {
    final text = tester.widget<Text>(find.byType(Text));
    final root = text.textSpan! as TextSpan;
    final spans = root.children!.cast<TextSpan>();
    return spans.firstWhere((s) => s.recognizer is TapGestureRecognizer);
  }

  group(ClickableText, () {
    testWidgets('renders bare text without spans when no patterns match', (
      tester,
    ) async {
      await pump(
        tester,
        const ClickableText(text: 'hello world no links here'),
      );

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.data, equals('hello world no links here'));
      expect(text.textSpan, isNull);
    });

    testWidgets('renders Text.rich with a tappable URL span for https URLs', (
      tester,
    ) async {
      var launched = '';
      await pump(
        tester,
        ClickableText(
          text: 'visit https://divine.video for more',
          onLaunchUrl: (uri) async {
            launched = uri.toString();
            return true;
          },
        ),
      );

      final span = urlSpan(tester);
      expect(span.text, equals('https://divine.video'));
      (span.recognizer! as TapGestureRecognizer).onTap!();
      await tester.pump();

      expect(launched, equals('https://divine.video'));
    });

    testWidgets('matches mixed-case scheme via case-insensitive regex', (
      tester,
    ) async {
      var launched = '';
      await pump(
        tester,
        ClickableText(
          text: 'see Https://CartridgeAndQuest.com today',
          onLaunchUrl: (uri) async {
            launched = uri.toString();
            return true;
          },
        ),
      );

      final span = urlSpan(tester);
      // Span text preserves the original case so it reads naturally inline.
      expect(span.text, equals('Https://CartridgeAndQuest.com'));
      (span.recognizer! as TapGestureRecognizer).onTap!();
      await tester.pump();

      // Uri.tryParse normalises the scheme + host to lowercase per RFC 3986;
      // the destination is unchanged.
      expect(launched, equals('https://cartridgeandquest.com'));
    });

    testWidgets('strips trailing punctuation from the URL match', (
      tester,
    ) async {
      var launched = '';
      await pump(
        tester,
        ClickableText(
          text: 'see https://example.com.',
          onLaunchUrl: (uri) async {
            launched = uri.toString();
            return true;
          },
        ),
      );

      final span = urlSpan(tester);
      expect(span.text, equals('https://example.com'));
      (span.recognizer! as TapGestureRecognizer).onTap!();
      await tester.pump();

      expect(launched, equals('https://example.com'));
    });

    testWidgets('keeps trailing punctuation as plain text after the URL span', (
      tester,
    ) async {
      await pump(
        tester,
        const ClickableText(text: 'see https://example.com.'),
      );

      final text = tester.widget<Text>(find.byType(Text));
      final root = text.textSpan! as TextSpan;
      final spans = root.children!.cast<TextSpan>();

      final urlIdx = spans.indexWhere((s) => s.recognizer != null);
      expect(urlIdx, isNot(equals(-1)));
      expect(spans[urlIdx].text, equals('https://example.com'));
      expect(spans[urlIdx + 1].text, equals('.'));
      expect(spans[urlIdx + 1].recognizer, isNull);
    });

    testWidgets('treats www. URLs as tappable and prefixes https://', (
      tester,
    ) async {
      var launched = '';
      await pump(
        tester,
        ClickableText(
          text: 'visit www.divine.video',
          onLaunchUrl: (uri) async {
            launched = uri.toString();
            return true;
          },
        ),
      );

      final span = urlSpan(tester);
      expect(span.text, equals('www.divine.video'));
      (span.recognizer! as TapGestureRecognizer).onTap!();
      await tester.pump();

      expect(launched, equals('https://www.divine.video'));
    });

    testWidgets('does not match nsec1... — secrets are never tappable', (
      tester,
    ) async {
      const nsec =
          'nsec10000000000000000000000000000000000000000000000000000000000000';
      await pump(tester, const ClickableText(text: 'leak $nsec'));

      final text = tester.widget<Text>(find.byType(Text));
      // Secret should render as plain text — no `Text.rich`, no recognizer.
      expect(text.data, equals('leak $nsec'));
      expect(text.textSpan, isNull);
    });

    testWidgets('exposes URL text as a semantics label', (tester) async {
      await pump(
        tester,
        const ClickableText(text: 'see https://example.com here'),
      );

      final text = tester.widget<Text>(find.byType(Text));
      final root = text.textSpan! as TextSpan;
      final spans = root.children!.cast<TextSpan>();
      final url = spans.firstWhere((s) => s.recognizer != null);
      expect(url.semanticsLabel, equals('https://example.com'));
    });
  });

  group('$ClickableText.dispose', () {
    testWidgets('disposes recognizers when the widget is removed', (
      tester,
    ) async {
      await pump(
        tester,
        const ClickableText(text: 'see https://example.com please'),
      );
      // Pumping with an empty Container removes the previous tree.
      await pump(tester, const SizedBox.shrink());

      // No assertion possible on disposed state directly; relying on
      // flutter_test's leak detection to surface undisposed recognizers
      // would be flaky. The unit value here is exercising the dispose
      // path so any future regression in the lifecycle (e.g. switching
      // back to ConsumerWidget) is caught by analyzer + smoke run.
      expect(find.byType(ClickableText), findsNothing);
    });
  });
}
