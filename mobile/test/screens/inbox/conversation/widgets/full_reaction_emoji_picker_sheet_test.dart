// ABOUTME: Widget tests for FullReactionEmojiPickerSheet.
// ABOUTME: Verifies the sheet mounts the emoji picker and resolves its result.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/inbox/conversation/widgets/full_reaction_emoji_picker_sheet.dart';
// The top-level barrel hides the picker data set; the plugin library is
// public (not src/) and carries defaultEmojiSet / EmojiPickerUtils /
// SkinTone for the reaction-content contract test.
import 'package:pro_image_editor/plugins/emoji_picker_flutter/emoji_picker_flutter.dart'
    show EmojiPickerUtils, SkinTone, defaultEmojiSet;
import 'package:pro_image_editor/pro_image_editor.dart';

import '../../../../helpers/test_provider_overrides.dart';

void main() {
  group('picker emoji reaction contract (#7784)', () {
    test('every picker-selectable emoji is a valid reaction content', () {
      // The repository validates reaction content with
      // emojiReactionContentOf before publishing, so anything this picker
      // can hand back must classify — including skin-tone variants, which
      // the picker assembles at selection time. A rejection here means an
      // ordinary picker selection would surface as a failed reaction.
      final utils = EmojiPickerUtils();
      final rejected = <String>[];
      var checked = 0;
      for (final category in defaultEmojiSet) {
        for (final emoji in category.emoji) {
          checked++;
          if (emojiReactionContentOf(emoji.emoji) == null) {
            rejected.add(emoji.emoji);
          }
          if (!emoji.hasSkinTone) continue;
          for (final tone in SkinTone.values) {
            checked++;
            final toned = utils.applySkinTone(emoji, tone).emoji;
            if (emojiReactionContentOf(toned) == null) {
              rejected.add(toned);
            }
          }
        }
      }
      expect(checked, greaterThan(1000), reason: 'picker data set loaded');
      expect(
        rejected,
        isEmpty,
        reason: 'picker-selectable but rejected by emojiReactionContentOf',
      );
    });

    test('the ranges the old classifier missed classify now (regression)', () {
      // pro_image_editor 13.3.1 exposes both of these in its Symbols
      // category; the pre-property-based classifier rejected them.
      expect(emojiReactionContentOf('™️'), equals('™️'));
      expect(emojiReactionContentOf('ℹ️'), equals('ℹ️'));
    });
  });

  group('FullReactionEmojiPickerSheet', () {
    testWidgets('mounts the emoji picker when shown', (tester) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () {
                    unawaited(
                      FullReactionEmojiPickerSheet.show(context: context),
                    );
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(EmojiEditor), findsOneWidget);
    });

    testWidgets('resolves to null when dismissed without a choice', (
      tester,
    ) async {
      String? selected;
      var completed = false;
      await tester.pumpWidget(
        testMaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () async {
                    selected = await FullReactionEmojiPickerSheet.show(
                      context: context,
                    );
                    completed = true;
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Dismiss the sheet without selecting an emoji.
      Navigator.of(tester.element(find.byType(EmojiEditor))).pop();
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(selected, isNull);
    });

    group('buildI18n', () {
      test('maps every category label to its localized value', () {
        final en = lookupAppLocalizations(const Locale('en'));
        final i18n = FullReactionEmojiPickerSheet.buildI18n(en);

        expect(i18n.search, en.emojiPickerSearchHint);
        expect(i18n.categoryRecent, en.emojiCategoryRecent);
        expect(i18n.categorySmileys, en.emojiCategorySmileys);
        expect(i18n.categoryAnimals, en.emojiCategoryAnimals);
        expect(i18n.categoryFood, en.emojiCategoryFood);
        expect(i18n.categoryActivities, en.emojiCategoryActivities);
        expect(i18n.categoryTravel, en.emojiCategoryTravel);
        expect(i18n.categoryObjects, en.emojiCategoryObjects);
        expect(i18n.categorySymbols, en.emojiCategorySymbols);
        expect(i18n.categoryFlags, en.emojiCategoryFlags);
      });

      test('follows the active locale instead of hardcoded English', () {
        final en = lookupAppLocalizations(const Locale('en'));
        final de = lookupAppLocalizations(const Locale('de'));

        // German labels differ from English, proving the picker reads from
        // l10n rather than the package's hardcoded English defaults.
        expect(de.emojiCategorySmileys, isNot(en.emojiCategorySmileys));
        expect(
          FullReactionEmojiPickerSheet.buildI18n(de).categorySmileys,
          de.emojiCategorySmileys,
        );
      });
    });
  });
}
