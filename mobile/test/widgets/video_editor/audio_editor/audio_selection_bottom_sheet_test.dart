// ABOUTME: Tests for AudioSelectionBottomSheet widget
// ABOUTME: Validates rendering states, sorting, empty/error states,
// ABOUTME: and sound selection behavior with mocked providers.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/models/vine_sound.dart';
import 'package:openvine/providers/sound_library_service_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/services/sound_library_service.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_list_tile.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_selection_bottom_sheet.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_sort_dropdown.dart';

/// Helper to create test AudioEvent instances.
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

/// Creates a SoundLibraryService with pre-loaded sounds for testing.
SoundLibraryService _createLoadedService(List<VineSound> sounds) {
  final service = SoundLibraryService();
  // SoundLibraryService uses internal lists; for testing we rely on the
  // provider override to deliver sounds via AsyncValue.data directly.
  return service;
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

    /// Builds the widget wrapped in ProviderScope with configurable overrides.
    Widget buildWidget({
      AsyncValue<SoundLibraryService>? soundLibraryAsync,
      AsyncValue<List<AudioEvent>>? trendingSoundsAsync,
      Completer<SoundLibraryService>? soundLibraryCompleter,
    }) {
      return ProviderScope(
        overrides: [
          if (soundLibraryAsync != null)
            soundLibraryServiceProvider.overrideWith(
              (_) => soundLibraryAsync.when(
                data: Future.value,
                loading: () =>
                    (soundLibraryCompleter ?? Completer<SoundLibraryService>())
                        .future,
                error: Future.error,
              ),
            ),
          if (trendingSoundsAsync != null)
            trendingSoundsProvider.overrideWith(
              () => _FakeTrendingSounds(trendingSoundsAsync),
            ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AudioSelectionBottomSheet(
              scrollController: scrollController,
            ),
          ),
        ),
      );
    }

    final testSounds = [
      _createTestAudioEvent(
        id: 'sound-1',
        title: 'Alpha Track',
        duration: 3.0,
      ),
      _createTestAudioEvent(
        id: 'sound-2',
        title: 'Beta Song',
        createdAt: 1704153600,
        duration: 6.0,
      ),
      _createTestAudioEvent(
        id: 'sound-3',
        title: 'Gamma Beat',
        createdAt: 1704240000,
        duration: 1.5,
      ),
    ];

    group('Rendering', () {
      testWidgets('renders $AudioSelectionBottomSheet', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            soundLibraryAsync: AsyncValue.data(_createLoadedService([])),
            trendingSoundsAsync: AsyncValue.data(testSounds),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byType(AudioSelectionBottomSheet),
          findsOneWidget,
        );
      });

      testWidgets('renders $AudioListTile for each sound', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            soundLibraryAsync: AsyncValue.data(_createLoadedService([])),
            trendingSoundsAsync: AsyncValue.data(testSounds),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AudioListTile), findsNWidgets(3));
      });

      testWidgets('renders sound titles', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            soundLibraryAsync: AsyncValue.data(_createLoadedService([])),
            trendingSoundsAsync: AsyncValue.data(testSounds),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Alpha Track'), findsOneWidget);
        expect(find.text('Beta Song'), findsOneWidget);
        expect(find.text('Gamma Beat'), findsOneWidget);
      });

      testWidgets('renders $AudioSortDropdown', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            soundLibraryAsync: AsyncValue.data(_createLoadedService([])),
            trendingSoundsAsync: AsyncValue.data(testSounds),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AudioSortDropdown), findsOneWidget);
      });
    });

    group('Loading state', () {
      testWidgets(
        'renders $BrandedLoadingIndicator when loading with no bundled sounds',
        (tester) async {
          await tester.pumpWidget(
            buildWidget(
              soundLibraryAsync: AsyncValue.data(_createLoadedService([])),
              trendingSoundsAsync: const AsyncValue.loading(),
            ),
          );
          await tester.pump();

          expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
        },
      );
    });

    group('Empty state', () {
      testWidgets('renders empty state when no sounds available', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            soundLibraryAsync: AsyncValue.data(_createLoadedService([])),
            trendingSoundsAsync: const AsyncValue.data([]),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('No sounds available'), findsOneWidget);
        expect(find.byIcon(Icons.music_off), findsOneWidget);
      });
    });

    group('Error state', () {
      testWidgets(
        'renders error state when loading fails with no bundled sounds',
        (tester) async {
          await tester.pumpWidget(
            buildWidget(
              soundLibraryAsync: AsyncValue.data(_createLoadedService([])),
              trendingSoundsAsync: AsyncValue.error(
                Exception('network error'),
                StackTrace.current,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Failed to load sounds'), findsOneWidget);
          expect(find.byIcon(Icons.error_outline), findsOneWidget);
        },
      );

      testWidgets('renders retry button on error state', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            soundLibraryAsync: AsyncValue.data(_createLoadedService([])),
            trendingSoundsAsync: AsyncValue.error(
              Exception('network error'),
              StackTrace.current,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Retry'), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
      });
    });

    group('Sorting', () {
      testWidgets('default sort is newest first', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            soundLibraryAsync: AsyncValue.data(_createLoadedService([])),
            trendingSoundsAsync: AsyncValue.data(testSounds),
          ),
        );
        await tester.pumpAndSettle();

        // Find all AudioListTile widgets and check their order
        final tiles = tester.widgetList<AudioListTile>(
          find.byType(AudioListTile),
        );
        final titles = tiles.map((t) => t.audio.title).toList();

        // Newest first: Gamma (1704240000) > Beta (1704153600) > Alpha
        expect(titles, equals(['Gamma Beat', 'Beta Song', 'Alpha Track']));
      });
    });
  });
}

/// Fake TrendingSounds notifier for testing.
class _FakeTrendingSounds extends TrendingSounds {
  _FakeTrendingSounds(this._initialValue);

  final AsyncValue<List<AudioEvent>> _initialValue;

  @override
  Future<List<AudioEvent>> build() async {
    return _initialValue.when(
      data: (data) => data,
      loading: () => Completer<List<AudioEvent>>().future,
      error: Future.error,
    );
  }
}
