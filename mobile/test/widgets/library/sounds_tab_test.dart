// ABOUTME: Widget tests for the Library Sounds tab.
// ABOUTME: Verifies the tab shows user-saved reusable sounds, not asset sounds.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:openvine/widgets/library/sounds_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

AudioEvent _sound({
  required String id,
  required String title,
  int createdAt = 1700000000,
}) {
  return AudioEvent(
    id: id,
    pubkey:
        'test_pubkey_0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    createdAt: createdAt,
    title: title,
    duration: 6,
    url: 'https://example.com/audio/$id.m4a',
    mimeType: 'audio/mp4',
    source: 'Original Sound',
  );
}

void main() {
  group(SoundsTab, () {
    late SharedPreferences sharedPreferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
    });

    Future<void> pumpSoundsTab(
      WidgetTester tester, {
      Future<AudioEvent?> Function(BuildContext)? showAudioPicker,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            home: Scaffold(
              body: SoundsTab(showAudioPicker: showAudioPicker),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows saved sounds without featured or trending sections', (
      tester,
    ) async {
      await SavedSoundsService(sharedPreferences).saveSound(
        _sound(id: 'sound1', title: 'Original sound - rabble'),
      );

      await pumpSoundsTab(tester);

      expect(find.text('Original sound - rabble'), findsOneWidget);
      expect(find.text('Featured Sounds'), findsNothing);
      expect(find.text('Trending Sounds'), findsNothing);
    });

    testWidgets('filters saved sounds by search query', (tester) async {
      final service = SavedSoundsService(sharedPreferences);
      await service.saveSound(_sound(id: 'sound1', title: 'Drum Loop'));
      await service.saveSound(_sound(id: 'sound2', title: 'Piano Loop'));

      await pumpSoundsTab(tester);
      await tester.enterText(find.byType(TextField), 'drum');
      await tester.pumpAndSettle();

      expect(find.text('Drum Loop'), findsOneWidget);
      expect(find.text('Piano Loop'), findsNothing);
    });

    testWidgets('saves sound selected from Add audio picker', (tester) async {
      await pumpSoundsTab(
        tester,
        showAudioPicker: (_) async =>
            _sound(id: 'wednesday', title: 'Wednesday My Dudes'),
      );

      await tester.tap(find.text('Add audio'));
      await tester.pumpAndSettle();

      expect(find.text('Wednesday My Dudes'), findsOneWidget);

      final savedSounds = SavedSoundsService(sharedPreferences).loadSounds();
      expect(
        savedSounds.map((sound) => sound.title),
        contains('Wednesday My Dudes'),
      );
    });

    testWidgets('shows empty state when no sounds have been saved', (
      tester,
    ) async {
      await pumpSoundsTab(tester);

      expect(find.text('No saved sounds yet'), findsOneWidget);
      expect(
        find.text('Tap Use Sound on a video to save it here.'),
        findsOneWidget,
      );
    });

    testWidgets('removes a saved sound from the library', (tester) async {
      await SavedSoundsService(sharedPreferences).saveSound(
        _sound(id: 'sound1', title: 'Original sound - rabble'),
      );

      await pumpSoundsTab(tester);
      await tester.tap(find.byTooltip('Remove sound'));
      await tester.pumpAndSettle();

      expect(find.text('Original sound - rabble'), findsNothing);
      expect(find.text('No saved sounds yet'), findsOneWidget);
    });
  });
}
