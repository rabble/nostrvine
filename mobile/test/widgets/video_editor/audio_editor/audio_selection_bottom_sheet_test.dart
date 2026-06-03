// ABOUTME: Tests for AudioSelectionBottomSheet widget
// ABOUTME: Validates rendering of category bar, sounds, loading and
// ABOUTME: error states with mocked sound providers.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/saved_sounds_provider.dart';
import 'package:openvine/providers/sound_library_service_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/services/sound_library_service.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
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

Finder _divineIcon(DivineIconName name) =>
    find.byWidgetPredicate((w) => w is DivineIcon && w.icon == name);

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
      List<VineSound> bundledSounds = const [],
    }) {
      return ProviderScope(
        overrides: [
          soundLibraryServiceProvider.overrideWith(
            (_) async => _FakeSoundLibraryService(bundledSounds),
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

      testWidgets('shows import action in the audio picker', (tester) async {
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: const AsyncValue.data([])),
        );
        await tester.pumpAndSettle();

        expect(find.text('Import audio'), findsOneWidget);
        expect(find.byIcon(Icons.upload_file), findsOneWidget);
      });

      testWidgets('renders $AudioCategoryBar with all category chips', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: AsyncValue.data(testSounds)),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.byType(AudioCategoryBar), findsOneWidget);
        expect(find.text(l10n.videoEditorAudioCategoryDivine), findsWidgets);
        expect(find.text(l10n.videoEditorAudioCategoryCommunity), findsWidgets);
        expect(find.text(l10n.videoEditorAudioCategoryFeatured), findsWidgets);
        expect(find.text(l10n.videoEditorAudioCategoryMySounds), findsWidgets);
      });
    });

    group('Search', () {
      testWidgets('filters featured sounds on featured tab', (tester) async {
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: AsyncValue.data(testSounds)),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.enterText(find.byType(TextField).first, 'wednes');
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.videoEditorAudioCategoryFeatured));
        await tester.pumpAndSettle();

        expect(find.text('Wednesday My Dudes'), findsOneWidget);
      });

      testWidgets('filters community sounds on community tab', (tester) async {
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: AsyncValue.data(testSounds)),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.enterText(find.byType(TextField).first, 'beta');
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.videoEditorAudioCategoryCommunity));
        await tester.pumpAndSettle();

        expect(find.text('Beta Song'), findsOneWidget);
        expect(find.text('Alpha Track'), findsNothing);
      });

      testWidgets('filters saved sounds on My Sounds tab', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data(testSounds),
            savedSounds: [
              _createTestAudioEvent(id: 'saved-1', title: 'Uh Oh'),
              _createTestAudioEvent(id: 'saved-2', title: 'Victory Lap'),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.enterText(find.byType(TextField).first, 'uh oh');
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.videoEditorAudioCategoryMySounds));
        await tester.pumpAndSettle();

        expect(find.text('Uh Oh'), findsOneWidget);
        expect(find.text('Victory Lap'), findsNothing);
      });

      testWidgets('renders search empty state when no tab matches', (
        tester,
      ) async {
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
        await tester.enterText(find.byType(TextField).first, 'not a match');
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.videoEditorAudioCategoryMySounds));
        await tester.pumpAndSettle();

        expect(find.text(l10n.soundsNoSoundsFound), findsOneWidget);
        expect(find.text(l10n.soundsNoSoundsFoundDescription), findsOneWidget);
      });
    });

    group('Loading state', () {
      testWidgets('renders $BrandedLoadingIndicator on community tab', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: const AsyncValue.loading()),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.videoEditorAudioCategoryCommunity));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
      });
    });

    group('Empty state', () {
      testWidgets('renders empty state when no bundled sounds available', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: const AsyncValue.data([])),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.text(l10n.videoEditorAudioNoSoundsAvailableTitle),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.music_off), findsOneWidget);
      });

      testWidgets('renders featured sounds on featured tab', (tester) async {
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: AsyncValue.data(testSounds)),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.videoEditorAudioCategoryFeatured));
        await tester.pumpAndSettle();

        expect(find.text('Wednesday My Dudes'), findsOneWidget);
      });

      testWidgets('renders bundled Wednesday clip on Divine tab', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data(testSounds),
            bundledSounds: [
              VineSound(
                id: 'wednesday',
                title: 'Wednesday My Dudes',
                assetPath: 'assets/sounds/wednesday.mp3',
                duration: const Duration(milliseconds: 6269),
                tags: ['meme', 'classic', 'frog'],
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Wednesday My Dudes'), findsOneWidget);
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

    group('Error state', () {
      testWidgets('renders error state when community fails', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.error(
              Exception('network error'),
              StackTrace.current,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.videoEditorAudioCategoryCommunity));
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.videoEditorAudioFailedToLoadTitle),
          findsOneWidget,
        );
        expect(_divineIcon(DivineIconName.warningCircle), findsOneWidget);
      });

      testWidgets('renders retry button on error state', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.error(
              Exception('network error'),
              StackTrace.current,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.videoEditorAudioCategoryCommunity));
        await tester.pumpAndSettle();

        expect(find.text(l10n.commonRetry), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
      });
    });

    group('Initial state', () {
      testWidgets('renders no $AudioListTile while no sounds are loaded', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: const AsyncValue.data([])),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AudioListTile), findsNothing);
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

class _FakeSoundLibraryService extends SoundLibraryService {
  _FakeSoundLibraryService(this._bundledSounds);

  final List<VineSound> _bundledSounds;

  @override
  List<VineSound> get sounds => List.unmodifiable(_bundledSounds);

  @override
  List<VineSound> get customSounds => const [];

  @override
  bool get isLoaded => true;

  @override
  Future<void> loadSounds() async {}

  @override
  Future<void> loadCustomSounds() async {}
}
