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

    testWidgets('renders picker category chips in product order', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(category: AudioCategory.featured, onSelect: (_) {}),
      );
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.videoEditorAudioCategoryFeatured), findsOneWidget);
      expect(find.text(l10n.videoEditorAudioCategoryDivine), findsOneWidget);
      expect(find.text(l10n.videoEditorAudioCategoryMySounds), findsOneWidget);
      expect(find.text(l10n.videoEditorAudioCategoryCommunity), findsNothing);

      final featuredLeft = tester.getTopLeft(
        find.text(l10n.videoEditorAudioCategoryFeatured),
      );
      final ogLeft = tester.getTopLeft(
        find.text(l10n.videoEditorAudioCategoryDivine),
      );
      final mySoundsLeft = tester.getTopLeft(
        find.text(l10n.videoEditorAudioCategoryMySounds),
      );
      expect(featuredLeft.dx, lessThan(ogLeft.dx));
      expect(ogLeft.dx, lessThan(mySoundsLeft.dx));
    });

    testWidgets('calls onSelect with featured when first chip is tapped', (
      tester,
    ) async {
      AudioCategory? selected;
      await tester.pumpWidget(
        buildWidget(
          category: AudioCategory.divine,
          onSelect: (c) => selected = c,
        ),
      );
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(l10n.videoEditorAudioCategoryFeatured));
      await tester.pumpAndSettle();

      expect(selected, equals(AudioCategory.featured));
    });

    testWidgets('calls onSelect with divine when second chip is tapped', (
      tester,
    ) async {
      AudioCategory? selected;
      await tester.pumpWidget(
        buildWidget(
          category: AudioCategory.featured,
          onSelect: (c) => selected = c,
        ),
      );
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(l10n.videoEditorAudioCategoryDivine));
      await tester.pumpAndSettle();

      expect(selected, equals(AudioCategory.divine));
    });

    testWidgets('calls onSelect with mySounds when third chip is tapped', (
      tester,
    ) async {
      AudioCategory? selected;
      await tester.pumpWidget(
        buildWidget(
          category: AudioCategory.featured,
          onSelect: (c) => selected = c,
        ),
      );
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(l10n.videoEditorAudioCategoryMySounds));
      await tester.pumpAndSettle();

      expect(selected, equals(AudioCategory.mySounds));
    });

    testWidgets('marks the selected chip with Semantics.selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(category: AudioCategory.featured, onSelect: (_) {}),
      );
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      final featuredSemantics = tester.widget<Semantics>(
        find.ancestor(
          of: find.text(l10n.videoEditorAudioCategoryFeatured),
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.selected != null,
          ),
        ),
      );
      final ogSemantics = tester.widget<Semantics>(
        find.ancestor(
          of: find.text(l10n.videoEditorAudioCategoryDivine),
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.selected != null,
          ),
        ),
      );

      expect(featuredSemantics.properties.selected, isTrue);
      expect(ogSemantics.properties.selected, isFalse);
    });
  });
}
