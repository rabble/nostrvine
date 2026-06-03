// ABOUTME: Comprehensive TDD tests for SoundsScreen - sounds browser for audio reuse
// ABOUTME: Tests trending sounds, search, loading states, error handling, and sound selection

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/saved_sounds_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/sound_library_service_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/screens/sound_detail_screen.dart';
import 'package:openvine/screens/sounds_screen.dart';
import 'package:openvine/services/sound_library_service.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/sound_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sound_service/sound_service.dart';

import '../helpers/go_router.dart';

class _MockAudioPlaybackService extends Mock implements AudioPlaybackService {}

/// Creates a test AudioEvent with the given parameters.
AudioEvent createTestAudioEvent({
  required String id,
  String? title,
  double? duration,
  String pubkey =
      'test_pubkey_0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
  int createdAt = 1700000000,
}) {
  return AudioEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    title: title ?? 'Test Sound $id',
    duration: duration ?? 6.0,
    url: 'https://example.com/audio/$id.m4a',
    mimeType: 'audio/mp4',
  );
}

/// Mock TrendingSounds notifier that returns test data.
class MockTrendingSoundsNotifier extends TrendingSounds {
  MockTrendingSoundsNotifier({this.sounds});

  final List<AudioEvent>? sounds;

  @override
  Future<List<AudioEvent>> build() async {
    return sounds ?? [];
  }
}

/// Mock TrendingSounds notifier that never completes (for loading state).
class MockTrendingSoundsLoadingNotifier extends TrendingSounds {
  @override
  Future<List<AudioEvent>> build() {
    // Return a future that never completes
    return Completer<List<AudioEvent>>().future;
  }
}

/// Mock TrendingSounds notifier that throws an error.
class MockTrendingSoundsErrorNotifier extends TrendingSounds {
  MockTrendingSoundsErrorNotifier(this.error);

  final Object error;

  @override
  Future<List<AudioEvent>> build() async {
    throw error;
  }
}

/// Test wrapper widget that provides necessary context.
Widget createTestWidget({required Widget child, List<dynamic>? overrides}) {
  return ProviderScope(
    overrides: [...?overrides],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: VineTheme.theme,
      home: child,
    ),
  );
}

void main() {
  group('SoundsScreen', () {
    group('Widget Structure', () {
      testWidgets('renders with correct title', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: const SoundsScreen(),
            overrides: [
              trendingSoundsProvider.overrideWith(
                () => MockTrendingSoundsNotifier(sounds: []),
              ),
            ],
          ),
        );

        await tester.pump();

        expect(find.text('Sounds'), findsOneWidget);
      });

      testWidgets('has back button in AppBar', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: const SoundsScreen(),
            overrides: [
              trendingSoundsProvider.overrideWith(
                () => MockTrendingSoundsNotifier(sounds: []),
              ),
            ],
          ),
        );

        await tester.pump();

        expect(find.byType(DiVineAppBarIconButton), findsOneWidget);
      });

      testWidgets('has search text field', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: const SoundsScreen(),
            overrides: [
              trendingSoundsProvider.overrideWith(
                () => MockTrendingSoundsNotifier(sounds: []),
              ),
            ],
          ),
        );

        await tester.pump();

        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Search sounds...'), findsOneWidget);
      });

      testWidgets('has dark background', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: const SoundsScreen(),
            overrides: [
              trendingSoundsProvider.overrideWith(
                () => MockTrendingSoundsNotifier(sounds: []),
              ),
            ],
          ),
        );

        await tester.pump();

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, equals(Colors.black));
      });
    });

    group('Trending Sounds Section', () {
      testWidgets('shows trending sounds header', (tester) async {
        final testSounds = [
          createTestAudioEvent(id: 'sound1', title: 'Trending Sound 1'),
          createTestAudioEvent(id: 'sound2', title: 'Trending Sound 2'),
        ];

        await tester.pumpWidget(
          createTestWidget(
            child: const SoundsScreen(),
            overrides: [
              trendingSoundsProvider.overrideWith(
                () => MockTrendingSoundsNotifier(sounds: testSounds),
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Trending Sounds'), findsOneWidget);
      });

      testWidgets('displays trending sounds in horizontal scroll', (
        tester,
      ) async {
        final testSounds = [
          createTestAudioEvent(id: 'sound1', title: 'Trending Sound 1'),
          createTestAudioEvent(id: 'sound2', title: 'Trending Sound 2'),
          createTestAudioEvent(id: 'sound3', title: 'Trending Sound 3'),
        ];

        await tester.pumpWidget(
          createTestWidget(
            child: const SoundsScreen(),
            overrides: [
              trendingSoundsProvider.overrideWith(
                () => MockTrendingSoundsNotifier(sounds: testSounds),
              ),
              // Force empty bundled sounds so only the Trending Sounds
              // horizontal list renders; otherwise rootBundle loads the
              // bundled manifest and the Featured Sounds section adds a
              // second horizontal ListView.
              soundLibraryServiceProvider.overrideWith(
                (_) async => SoundLibraryService(),
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // Should have horizontal scroll view for trending sounds
        final listViews = find.byWidgetPredicate(
          (widget) =>
              widget is ListView && widget.scrollDirection == Axis.horizontal,
        );
        expect(listViews, findsOneWidget);
      });

      testWidgets('uses compact SoundTile for trending section', (
        tester,
      ) async {
        final testSounds = [
          createTestAudioEvent(id: 'sound1', title: 'Trending Sound 1'),
        ];

        await tester.pumpWidget(
          createTestWidget(
            child: const SoundsScreen(),
            overrides: [
              trendingSoundsProvider.overrideWith(
                () => MockTrendingSoundsNotifier(sounds: testSounds),
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // Find SoundTile widget and verify compact mode
        final soundTiles = find.byType(SoundTile);
        expect(soundTiles, findsWidgets);
      });
    });

    group('All Sounds List', () {
      testWidgets('shows all sounds header', (tester) async {
        final testSounds = [
          createTestAudioEvent(id: 'sound1', title: 'Sound 1'),
        ];

        await tester.pumpWidget(
          createTestWidget(
            child: const SoundsScreen(),
            overrides: [
              trendingSoundsProvider.overrideWith(
                () => MockTrendingSoundsNotifier(sounds: testSounds),
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('All Sounds'), findsOneWidget);
      });

      testWidgets('displays sounds in vertical list', (tester) async {
        final testSounds = [
          createTestAudioEvent(id: 'sound1', title: 'Sound 1'),
          createTestAudioEvent(id: 'sound2', title: 'Sound 2'),
        ];

        await tester.pumpWidget(
          createTestWidget(
            child: const SoundsScreen(),
            overrides: [
              trendingSoundsProvider.overrideWith(
                () => MockTrendingSoundsNotifier(sounds: testSounds),
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // Should find normal SoundTile widgets for all sounds
        expect(find.byType(SoundTile), findsAtLeast(2));
      });
    });

    group('Loading State', () {
      testWidgets('shows loading indicator when loading', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: const SoundsScreen(),
            overrides: [
              trendingSoundsProvider.overrideWith(
                MockTrendingSoundsLoadingNotifier.new,
              ),
              soundLibraryServiceProvider.overrideWith(
                (_) => Completer<SoundLibraryService>().future,
              ),
            ],
          ),
        );

        await tester.pump();

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
      });
    });

    group('Error State', () {
      // The error branch only renders _ErrorState when bundled sounds are
      // also empty; otherwise it falls back to the bundled list. Each test
      // forces an empty bundled library so the trending error surfaces.
      testWidgets('shows error message on failure', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: const SoundsScreen(),
            overrides: [
              trendingSoundsProvider.overrideWith(
                () =>
                    MockTrendingSoundsErrorNotifier(Exception('Network error')),
              ),
              soundLibraryServiceProvider.overrideWith(
                (_) async => SoundLibraryService(),
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Failed to load sounds'), findsOneWidget);
      });

      testWidgets('shows retry button on error', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: const SoundsScreen(),
            overrides: [
              trendingSoundsProvider.overrideWith(
                () =>
                    MockTrendingSoundsErrorNotifier(Exception('Network error')),
              ),
              soundLibraryServiceProvider.overrideWith(
                (_) async => SoundLibraryService(),
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Retry'), findsOneWidget);
      });
    });

    group('Empty State', () {
      testWidgets('shows empty message when no sounds', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: const SoundsScreen(),
            overrides: [
              trendingSoundsProvider.overrideWith(
                () => MockTrendingSoundsNotifier(sounds: []),
              ),
              soundLibraryServiceProvider.overrideWith(
                (_) async => SoundLibraryService(),
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('No sounds available'), findsOneWidget);
      });
    });

    group('Search Functionality', () {
      testWidgets('filters sounds by search query', (tester) async {
        final testSounds = [
          createTestAudioEvent(id: 'sound1', title: 'Cool Beat'),
          createTestAudioEvent(id: 'sound2', title: 'Awesome Melody'),
          createTestAudioEvent(id: 'sound3', title: 'Cool Rhythm'),
        ];

        await tester.pumpWidget(
          createTestWidget(
            child: const SoundsScreen(),
            overrides: [
              trendingSoundsProvider.overrideWith(
                () => MockTrendingSoundsNotifier(sounds: testSounds),
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // Enter search query
        await tester.enterText(find.byType(TextField), 'Cool');
        await tester.pumpAndSettle();

        // Should only show sounds with "Cool" in title
        expect(find.text('Cool Beat'), findsOneWidget);
        expect(find.text('Cool Rhythm'), findsOneWidget);
        expect(find.text('Awesome Melody'), findsNothing);
      });

      testWidgets('search is case insensitive', (tester) async {
        final testSounds = [
          createTestAudioEvent(id: 'sound1', title: 'Cool Beat'),
        ];

        await tester.pumpWidget(
          createTestWidget(
            child: const SoundsScreen(),
            overrides: [
              trendingSoundsProvider.overrideWith(
                () => MockTrendingSoundsNotifier(sounds: testSounds),
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // Enter lowercase search
        await tester.enterText(find.byType(TextField), 'cool');
        await tester.pumpAndSettle();

        expect(find.text('Cool Beat'), findsOneWidget);
      });

      testWidgets('shows no results message when search has no matches', (
        tester,
      ) async {
        final testSounds = [
          createTestAudioEvent(id: 'sound1', title: 'Cool Beat'),
        ];

        await tester.pumpWidget(
          createTestWidget(
            child: const SoundsScreen(),
            overrides: [
              trendingSoundsProvider.overrideWith(
                () => MockTrendingSoundsNotifier(sounds: testSounds),
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // Enter search that matches nothing
        await tester.enterText(find.byType(TextField), 'zzzzz');
        await tester.pumpAndSettle();

        expect(find.text('No sounds found'), findsOneWidget);
      });
    });

    group('Sound Selection', () {
      testWidgets('tapping sound without callback saves it to library', (
        tester,
      ) async {
        final testSounds = [
          createTestAudioEvent(id: 'sound1', title: 'Cool Beat'),
        ];
        SharedPreferences.setMockInitialValues({});
        final sharedPreferences = await SharedPreferences.getInstance();
        final mockGoRouter = MockGoRouter();
        when(() => mockGoRouter.pop<Object?>()).thenAnswer((_) {});
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            trendingSoundsProvider.overrideWith(
              () => MockTrendingSoundsNotifier(sounds: testSounds),
            ),
            soundLibraryServiceProvider.overrideWith(
              (_) async => SoundLibraryService(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MockGoRouterProvider(
              goRouter: mockGoRouter,
              child: const MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: SoundsScreen(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final soundTiles = find.byType(SoundTile);
        expect(soundTiles, findsWidgets);

        await tester.tap(soundTiles.last);
        await tester.pumpAndSettle();

        verifyNever(() => mockGoRouter.pop<Object?>());
        expect(find.text('Saved to Sounds'), findsOneWidget);
        expect(container.read(savedSoundsProvider).map((sound) => sound.id), [
          'sound1',
        ]);
        expect(container.read(selectedSoundProvider), isNull);
      });
      testWidgets('tapping sound selects it and navigates back', (
        tester,
      ) async {
        final testSounds = [
          createTestAudioEvent(id: 'sound1', title: 'Cool Beat'),
        ];

        AudioEvent? selectedSound;

        await tester.pumpWidget(
          createTestWidget(
            child: SoundsScreen(
              onSoundSelected: (sound) {
                selectedSound = sound;
              },
            ),
            overrides: [
              trendingSoundsProvider.overrideWith(
                () => MockTrendingSoundsNotifier(sounds: testSounds),
              ),
              // Force empty bundled sounds so the All Sounds list contains
              // exactly one tile (`sound1`) and `soundTiles.last` stays in
              // the viewport regardless of rootBundle timing across isolates.
              soundLibraryServiceProvider.overrideWith(
                (_) async => SoundLibraryService(),
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // Tap on a sound tile (in All Sounds section, non-compact)
        final soundTiles = find.byType(SoundTile);
        expect(soundTiles, findsWidgets);

        // Find and tap the non-compact tile
        await tester.tap(soundTiles.last);
        await tester.pumpAndSettle();

        expect(selectedSound, isNotNull);
        expect(selectedSound!.id, equals('sound1'));
      });
    });

    group('Accessibility', () {
      testWidgets('has semantic labels', (tester) async {
        final testSounds = [
          createTestAudioEvent(id: 'sound1', title: 'Cool Beat'),
        ];

        await tester.pumpWidget(
          createTestWidget(
            child: const SoundsScreen(),
            overrides: [
              trendingSoundsProvider.overrideWith(
                () => MockTrendingSoundsNotifier(sounds: testSounds),
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // Verify Semantics widget exists with correct label
        final semanticsWidget = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Sounds screen',
        );
        expect(semanticsWidget, findsOneWidget);
      });
    });

    group('Theme Compliance', () {
      testWidgets('uses VineTheme colors for accents', (tester) async {
        final testSounds = [
          createTestAudioEvent(id: 'sound1', title: 'Cool Beat'),
        ];

        await tester.pumpWidget(
          createTestWidget(
            child: const SoundsScreen(),
            overrides: [
              trendingSoundsProvider.overrideWith(
                () => MockTrendingSoundsNotifier(sounds: testSounds),
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // Find trending icon and verify color
        final trendingIcon = find.byIcon(Icons.local_fire_department);
        expect(trendingIcon, findsOneWidget);

        final iconWidget = tester.widget<Icon>(trendingIcon);
        expect(iconWidget.color, equals(VineTheme.vineGreen));
      });
    });

    group('Preview Playback', () {
      late _MockAudioPlaybackService mockAudioService;

      setUp(() {
        mockAudioService = _MockAudioPlaybackService();

        // Set up default mock behavior
        when(
          () => mockAudioService.loadAudio(any()),
        ).thenAnswer((_) async => const Duration(seconds: 6));
        when(() => mockAudioService.play()).thenAnswer((_) async {});
        when(() => mockAudioService.stop()).thenAnswer((_) async {});
        when(() => mockAudioService.isPlaying).thenReturn(false);
      });

      testWidgets('play button shows play icon initially', (tester) async {
        final testSounds = [
          createTestAudioEvent(id: 'sound1', title: 'Cool Beat'),
        ];

        await tester.pumpWidget(
          createTestWidget(
            child: const SoundsScreen(),
            overrides: [
              trendingSoundsProvider.overrideWith(
                () => MockTrendingSoundsNotifier(sounds: testSounds),
              ),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // Find play icon (not stop icon)
        expect(find.byIcon(Icons.play_arrow), findsWidgets);
        expect(find.byIcon(Icons.stop), findsNothing);
      });

      testWidgets('tapping preview button loads and plays audio', (
        tester,
      ) async {
        final testSounds = [
          createTestAudioEvent(id: 'sound1', title: 'Cool Beat'),
        ];

        await tester.pumpWidget(
          createTestWidget(
            child: const SoundsScreen(),
            overrides: [
              trendingSoundsProvider.overrideWith(
                () => MockTrendingSoundsNotifier(sounds: testSounds),
              ),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // Find and tap the preview button (play_arrow icon in normal tile)
        final playButtons = find.byIcon(Icons.play_arrow);
        expect(playButtons, findsWidgets);

        // Tap the first play button we find
        await tester.tap(playButtons.first);
        await tester.pumpAndSettle();

        // Verify loadAudio and play were called
        verify(() => mockAudioService.loadAudio(any())).called(1);
        verify(() => mockAudioService.play()).called(1);
      });

      testWidgets('tapping same sound again stops playback', (tester) async {
        final testSounds = [
          createTestAudioEvent(id: 'sound1', title: 'Cool Beat'),
        ];

        // Use completer to keep play() running so finally block doesn't reset state
        final playCompleter = Completer<void>();
        when(
          () => mockAudioService.play(),
        ).thenAnswer((_) => playCompleter.future);

        await tester.pumpWidget(
          createTestWidget(
            child: const SoundsScreen(),
            overrides: [
              trendingSoundsProvider.overrideWith(
                () => MockTrendingSoundsNotifier(sounds: testSounds),
              ),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // First tap to start playing
        final playButtons = find.byIcon(Icons.play_arrow);
        await tester.tap(playButtons.first);
        // Pump to update UI while play() is still "running"
        await tester.pump();

        // Now there should be a stop icon (play is in progress)
        final stopButtons = find.byIcon(Icons.stop);
        expect(stopButtons, findsWidgets);

        // Second tap to stop
        await tester.tap(stopButtons.first);

        // Complete play() to avoid hanging
        playCompleter.complete();
        await tester.pumpAndSettle();

        // Verify stop was called
        verify(() => mockAudioService.stop()).called(greaterThanOrEqualTo(1));
      });

      testWidgets('tapping different sound stops current and plays new', (
        tester,
      ) async {
        final testSounds = [
          createTestAudioEvent(id: 'sound1', title: 'Cool Beat'),
          createTestAudioEvent(id: 'sound2', title: 'Awesome Melody'),
        ];

        await tester.pumpWidget(
          createTestWidget(
            child: const SoundsScreen(),
            overrides: [
              trendingSoundsProvider.overrideWith(
                () => MockTrendingSoundsNotifier(sounds: testSounds),
              ),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // Get all play buttons
        final playButtons = find.byIcon(Icons.play_arrow);
        expect(playButtons, findsWidgets);

        // Tap first sound's preview
        await tester.tap(playButtons.first);
        await tester.pumpAndSettle();

        // Clear previous interactions
        clearInteractions(mockAudioService);

        // Now find and tap a different play button (second sound)
        // The first sound now shows stop, second shows play
        final newPlayButtons = find.byIcon(Icons.play_arrow);
        expect(newPlayButtons, findsWidgets);
        await tester.tap(newPlayButtons.first);
        await tester.pumpAndSettle();

        // Verify stop was called for previous sound and new one was loaded
        verify(() => mockAudioService.stop()).called(greaterThanOrEqualTo(1));
        verify(() => mockAudioService.loadAudio(any())).called(1);
      });

      testWidgets('disposing the screen while previewing stops the audio '
          '(navigate-away cleanup contract)', (tester) async {
        final testSounds = [
          createTestAudioEvent(id: 'sound1', title: 'Cool Beat'),
        ];

        // Keep play() pending so the preview rests in the playing state
        // (previewingSoundId set) when we tear the screen down.
        final playCompleter = Completer<void>();
        when(
          () => mockAudioService.play(),
        ).thenAnswer((_) => playCompleter.future);

        await tester.pumpWidget(
          createTestWidget(
            child: const SoundsScreen(),
            overrides: [
              trendingSoundsProvider.overrideWith(
                () => MockTrendingSoundsNotifier(sounds: testSounds),
              ),
              // Empty bundled sounds → exactly one preview button.
              soundLibraryServiceProvider.overrideWith(
                (_) async => SoundLibraryService(),
              ),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.play_arrow).first);
        // Drain stop()/loadAudio microtasks so previewingSoundId is set.
        await tester.pump();
        await tester.pump();
        expect(find.byIcon(Icons.stop), findsWidgets);

        clearInteractions(mockAudioService);

        // Navigate away: tearing the whole tree down unmounts the
        // ProviderScope and the BlocProvider, which closes the SoundsCubit.
        // close() must stop the in-flight preview — SoundsView.dispose()
        // only disposes the text controller.
        await tester.pumpWidget(const SizedBox.shrink());

        verify(() => mockAudioService.stop()).called(1);

        playCompleter.complete();
        await tester.pumpAndSettle();
      });

      testWidgets('shows snackbar when sound has no URL', (tester) async {
        final testSounds = [
          const AudioEvent(
            id: 'sound1',
            pubkey:
                'test_pubkey_0123456789abcdef0123456789abcdef'
                '0123456789abcdef0123456789abcdef',
            createdAt: 1700000000,
            title: 'Sound Without URL',
            duration: 6.0,
            mimeType: 'audio/mp4',
          ),
        ];

        await tester.pumpWidget(
          createTestWidget(
            child: const SoundsScreen(),
            overrides: [
              trendingSoundsProvider.overrideWith(
                () => MockTrendingSoundsNotifier(sounds: testSounds),
              ),
              // Force empty bundled sounds so only the Trending Sounds
              // horizontal list renders; otherwise rootBundle loads the
              // bundled manifest and the Featured Sounds section adds a
              // second horizontal ListView.
              soundLibraryServiceProvider.overrideWith(
                (_) async => SoundLibraryService(),
              ),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // Tap the preview button
        final playButtons = find.byIcon(Icons.play_arrow);
        await tester.tap(playButtons.first);
        await tester.pumpAndSettle();

        // Should show snackbar with error message
        expect(
          find.text('Unable to preview sound - no audio available'),
          findsOneWidget,
        );

        // loadAudio should NOT have been called
        verifyNever(() => mockAudioService.loadAudio(any()));
      });

      testWidgets('shows generic snackbar when preview playback fails', (
        tester,
      ) async {
        final testSounds = [
          createTestAudioEvent(id: 'sound1', title: 'Cool Beat'),
        ];
        when(
          () => mockAudioService.play(),
        ).thenThrow(StateError('audio bus locked'));

        await tester.pumpWidget(
          createTestWidget(
            child: const SoundsScreen(),
            overrides: [
              trendingSoundsProvider.overrideWith(
                () => MockTrendingSoundsNotifier(sounds: testSounds),
              ),
              soundLibraryServiceProvider.overrideWith(
                (_) async => SoundLibraryService(),
              ),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.play_arrow).first);
        await tester.pumpAndSettle();

        expect(find.text('Failed to play preview'), findsOneWidget);
        expect(find.text('Failed to play preview: '), findsNothing);
      });
    });

    group('Detail Navigation', () {
      late _MockAudioPlaybackService mockAudioService;

      setUp(() {
        mockAudioService = _MockAudioPlaybackService();
        when(() => mockAudioService.stop()).thenAnswer((_) async {});
      });

      testWidgets('chevron button navigates to SoundDetailScreen', (
        tester,
      ) async {
        final testSounds = [
          createTestAudioEvent(id: 'sound1', title: 'Cool Beat'),
        ];

        var pushedPath = '';
        AudioEvent? pushedExtra;
        final mockGoRouter = MockGoRouter();
        when(
          () => mockGoRouter.push(
            captureAny(),
            extra: captureAny(named: 'extra'),
          ),
        ).thenAnswer((invocation) async {
          pushedPath = invocation.positionalArguments.first as String;
          pushedExtra = invocation.namedArguments[#extra] as AudioEvent?;
          return null;
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              trendingSoundsProvider.overrideWith(
                () => MockTrendingSoundsNotifier(sounds: testSounds),
              ),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
            child: MockGoRouterProvider(
              goRouter: mockGoRouter,
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: VineTheme.theme,
                home: const SoundsScreen(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Focus the all-sounds list so the expected sound row is definitely in
        // view before tapping its chevron. The old test grabbed the first
        // chevron icon in the tree, which became order-dependent under CI.
        await tester.enterText(find.byType(TextField), 'Cool Beat');
        await tester.pumpAndSettle();

        final detailButtons = find.bySemanticsLabel(
          'View details for Cool Beat',
        );
        expect(detailButtons, findsOneWidget);

        await tester.tap(detailButtons);
        await tester.pump();

        expect(pushedPath, equals('/sound/sound1'));
        expect(pushedExtra?.id, equals('sound1'));
      });

      testWidgets('navigating to detail stops current preview', (tester) async {
        final testSounds = [
          createTestAudioEvent(id: 'sound1', title: 'Cool Beat'),
        ];

        // Use completer to keep play() running so finally block doesn't reset state
        final playCompleter = Completer<void>();
        when(
          () => mockAudioService.loadAudio(any()),
        ).thenAnswer((_) async => const Duration(seconds: 6));
        when(
          () => mockAudioService.play(),
        ).thenAnswer((_) => playCompleter.future);
        when(() => mockAudioService.isPlaying).thenReturn(true);

        final mockGoRouter = MockGoRouter();
        when(
          () => mockGoRouter.push(any(), extra: any(named: 'extra')),
        ).thenAnswer((_) async => null);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              trendingSoundsProvider.overrideWith(
                () => MockTrendingSoundsNotifier(sounds: testSounds),
              ),
              // Force empty bundled sounds so the all-sounds section contains
              // exactly one tile (`sound1`); otherwise rootBundle pulls in
              // bundled sounds and the play / chevron icon order becomes
              // dependent on whatever the merged VGV runner cached for
              // `assets/`. Sibling tests above use the same override.
              soundLibraryServiceProvider.overrideWith(
                (_) async => SoundLibraryService(),
              ),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
            child: MockGoRouterProvider(
              goRouter: mockGoRouter,
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: VineTheme.theme,
                home: const SoundsScreen(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Address the preview / chevron buttons by their per-sound semantic
        // identifiers so the test no longer depends on icon order in the tree.
        final previewButton = find.bySemanticsLabel(
          RegExp('^Preview Cool Beat'),
        );
        expect(previewButton, findsOneWidget);

        await tester.tap(previewButton);
        // Drain microtasks for stop()/loadAudio so _previewingSoundId is set
        // before we tap the chevron — otherwise _stopPreview short-circuits.
        await tester.pump();
        await tester.pump();

        clearInteractions(mockAudioService);
        when(() => mockAudioService.stop()).thenAnswer((_) async {});

        final detailButton = find.bySemanticsLabel(
          'View details for Cool Beat',
        );
        expect(detailButton, findsOneWidget);
        await tester.tap(detailButton);

        // Complete play() to avoid hanging
        playCompleter.complete();
        await tester.pumpAndSettle();

        verify(() => mockAudioService.stop()).called(greaterThanOrEqualTo(1));
      });

      testWidgets('SoundDetailScreen displays sound information', (
        tester,
      ) async {
        final testSound = createTestAudioEvent(
          id: 'sound1',
          title: 'Cool Beat',
        );

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              // Mock the videos + usage providers so the un-mocked
              // soundsRepository fetch can't race into the error state and
              // tip the framework with a RenderFlex overflow under shuffled
              // VGV-optimized seeds.
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
              audioPlaybackServiceProvider.overrideWithValue(mockAudioService),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // Verify screen elements
        expect(find.text('Sound'), findsOneWidget);
        expect(find.text('Cool Beat'), findsOneWidget);
        // Duration is combined with video count: "6.0s · No videos yet"
        expect(find.textContaining('6.0s'), findsOneWidget);
      });

      testWidgets('SoundDetailScreen empty state fits short viewports', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(400, 520);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final testSound = createTestAudioEvent(
          id: 'sound1',
          title: 'Cool Beat',
        );

        await tester.pumpWidget(
          createTestWidget(
            child: SoundDetailScreen(sound: testSound),
            overrides: [
              soundUsageCountProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(0)),
              videosUsingSoundProvider(
                testSound.id,
              ).overrideWith((ref) => Future.value(<String>[])),
            ],
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('No videos yet'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  });
}
