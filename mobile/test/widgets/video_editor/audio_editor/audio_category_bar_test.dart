// ABOUTME: Tests for AudioCategoryBar widget
// ABOUTME: Validates rendering of category chips and selection callback

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_category_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(AudioCategoryBar, () {
    Widget buildWidget({
      required AudioCategory category,
      required ValueChanged<AudioCategory> onSelect,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AudioCategoryBar(category: category, onSelect: onSelect),
        ),
      );
    }

    testWidgets('renders both category chips', (tester) async {
      await tester.pumpWidget(
        buildWidget(category: AudioCategory.diVine, onSelect: (_) {}),
      );
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.videoEditorAudioCategoryDivine), findsOneWidget);
      expect(find.text(l10n.videoEditorAudioCategoryCommunity), findsOneWidget);
    });

    testWidgets('calls onSelect with diVine when first chip is tapped', (
      tester,
    ) async {
      AudioCategory? selected;
      await tester.pumpWidget(
        buildWidget(
          category: AudioCategory.community,
          onSelect: (c) => selected = c,
        ),
      );
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(l10n.videoEditorAudioCategoryDivine));
      await tester.pumpAndSettle();

      expect(selected, equals(AudioCategory.diVine));
    });

    testWidgets('calls onSelect with community when second chip is tapped', (
      tester,
    ) async {
      AudioCategory? selected;
      await tester.pumpWidget(
        buildWidget(
          category: AudioCategory.diVine,
          onSelect: (c) => selected = c,
        ),
      );
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(l10n.videoEditorAudioCategoryCommunity));
      await tester.pumpAndSettle();

      expect(selected, equals(AudioCategory.community));
    });

    testWidgets('marks the selected chip with Semantics.selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(category: AudioCategory.diVine, onSelect: (_) {}),
      );
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      final divineSemantics = tester.widget<Semantics>(
        find.ancestor(
          of: find.text(l10n.videoEditorAudioCategoryDivine),
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.selected != null,
          ),
        ),
      );
      final communitySemantics = tester.widget<Semantics>(
        find.ancestor(
          of: find.text(l10n.videoEditorAudioCategoryCommunity),
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.selected != null,
          ),
        ),
      );

      expect(divineSemantics.properties.selected, isTrue);
      expect(communitySemantics.properties.selected, isFalse);
    });
  });
}
