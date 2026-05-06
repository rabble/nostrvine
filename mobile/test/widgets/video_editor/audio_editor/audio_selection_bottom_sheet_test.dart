// ABOUTME: Tests for AudioSelectionBottomSheet widget
// ABOUTME: Validates rendering of category bar, sounds, loading and
// ABOUTME: error states with mocked sound providers.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/saved_sounds_provider.dart';
import 'package:openvine/providers/sound_library_service_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/services/sound_library_service.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_category_bar.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_list_tile.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_selection_bottom_sheet.dart';

AudioEvent _createTestAudioEvent({
  String id = 'test-sound-id',
  String pubkey = 'test-pubkey',
  int createdAt = 1704067200,
  String? url,
  String? title,
  String? source,
  double? duration,
}) {
  return AudioEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    url: url ?? 'https://example.com/audio/$id.mp3',
    title: title,
    source: source,
    duration: duration ?? 5.0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(AudioSelectionBottomSheet, () {
    late ScrollController scrollController;

    setUp(() {
      scrollController = ScrollController();
    });

    tearDown(() {
      scrollController.dispose();
    });

    Widget buildWidget({
      AsyncValue<List<AudioEvent>>? trendingSoundsAsync,
      List<AudioEvent> savedSounds = const [],
    }) {
      return ProviderScope(
        overrides: [
          soundLibraryServiceProvider.overrideWith(
            (_) => SoundLibraryService(),
          ),
          savedSoundsProvider.overrideWith(
            () => _FakeSavedSoundsNotifier(savedSounds),
          ),
          if (trendingSoundsAsync != null)
            trendingSoundsProvider.overrideWith(
              () => _FakeTrendingSounds(trendingSoundsAsync),
            ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AudioSelectionBottomSheet(scrollController: scrollController),
          ),
        ),
      );
    }

    final testSounds = [
      _createTestAudioEvent(id: 'sound-1', title: 'Alpha Track'),
      _createTestAudioEvent(id: 'sound-2', title: 'Beta Song'),
      _createTestAudioEvent(id: 'sound-3', title: 'Gamma Beat'),
    ];

    group('Rendering', () {
      testWidgets('renders $AudioSelectionBottomSheet', (tester) async {
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: AsyncValue.data(testSounds)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AudioSelectionBottomSheet), findsOneWidget);
      });

      testWidgets('renders picker categories without broken community tab', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: AsyncValue.data(testSounds)),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.byType(AudioCategoryBar), findsOneWidget);
        expect(find.text(l10n.videoEditorAudioCategoryDivine), findsWidgets);
        expect(find.text(l10n.videoEditorAudioCategoryCommunity), findsNothing);
        expect(find.text(l10n.videoEditorAudioCategoryFeatured), findsWidgets);
        expect(find.text(l10n.videoEditorAudioCategoryMySounds), findsWidgets);
      });
    });

    group('Empty state', () {
      testWidgets('opens on featured sounds', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: const AsyncValue.data([])),
        );
        await tester.pumpAndSettle();

        expect(find.text('Wednesday'), findsOneWidget);
      });

      testWidgets('leaves featured list when OG Sounds tab is selected', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: AsyncValue.data(testSounds)),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.videoEditorAudioCategoryDivine));
        await tester.pumpAndSettle();

        expect(find.text('Wednesday'), findsNothing);
      });

      testWidgets('renders saved sounds empty state on My Sounds tab', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: AsyncValue.data(testSounds)),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.videoEditorAudioCategoryMySounds));
        await tester.pumpAndSettle();

        expect(find.text(l10n.soundsSavedEmptyTitle), findsOneWidget);
        expect(find.text(l10n.soundsSavedEmptyDescription), findsOneWidget);
      });
    });

    group('Initial state', () {
      testWidgets('renders featured $AudioListTile initially', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: const AsyncValue.data([])),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AudioListTile), findsOneWidget);
      });

      testWidgets('renders saved sounds on My Sounds tab', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data(testSounds),
            savedSounds: [
              _createTestAudioEvent(id: 'saved-sound', title: 'Saved Sound'),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.videoEditorAudioCategoryMySounds));
        await tester.pumpAndSettle();

        expect(find.text('Saved Sound'), findsOneWidget);
      });
    });
  });
}

/// Fake TrendingSounds notifier for testing.
class _FakeTrendingSounds extends TrendingSounds {
  _FakeTrendingSounds(this._initialValue);

  final AsyncValue<List<AudioEvent>> _initialValue;

  @override
  Future<List<AudioEvent>> build() {
    return _initialValue.when(
      data: Future.value,
      loading: () => Completer<List<AudioEvent>>().future,
      error: Future.error,
    );
  }
}

class _FakeSavedSoundsNotifier extends SavedSoundsNotifier {
  _FakeSavedSoundsNotifier(this._sounds);

  final List<AudioEvent> _sounds;

  @override
  List<AudioEvent> build() => _sounds;
}
