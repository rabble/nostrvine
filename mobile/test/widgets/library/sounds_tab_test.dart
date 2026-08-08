// ABOUTME: Widget tests for the Library Sounds tab.
// ABOUTME: Verifies the tab shows user-saved reusable sounds, not asset sounds.

import 'dart:async';

import 'package:creator_sync/creator_sync.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:openvine/blocs/saved_sounds/saved_sound_media_probe.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_scope.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/saved_sound.dart';
import 'package:openvine/providers/creator_sync_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:openvine/widgets/library/sounds_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSoundSyncRepository extends Mock implements SoundSyncRepository {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockNostrSigner extends Mock implements NostrSigner {}

class _TestNostrSession extends NostrSession {
  _TestNostrSession(this._readiness);

  final NostrSessionReadiness _readiness;

  @override
  NostrSessionReadiness build() => _readiness;
}

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
          child: SavedSoundsScope(
            service: SavedSoundsService(sharedPreferences),
            mediaProbe: const _NoopSavedSoundMediaProbe(),
            child: MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: VineTheme.theme,
              routerConfig: GoRouter(
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (context, state) => Scaffold(
                      body: SoundsTab(showAudioPicker: showAudioPicker),
                    ),
                  ),
                  GoRoute(
                    path: '/sound/:id',
                    builder: (context, state) => Text(
                      'sound detail ${state.pathParameters['id']}',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows saved sounds without featured or trending sections', (
      tester,
    ) async {
      await SavedSoundsService(
        sharedPreferences,
      ).saveSound(_sound(id: 'sound1', title: 'Original sound - rabble'));

      await pumpSoundsTab(tester);

      expect(find.text('Original sound - rabble'), findsOneWidget);
      expect(find.text('Featured Sounds'), findsNothing);
      expect(find.text('Trending Sounds'), findsNothing);
    });

    testWidgets('opens saved sound details from the card', (tester) async {
      await SavedSoundsService(
        sharedPreferences,
      ).saveSound(_sound(id: 'sound1', title: 'Original sound - rabble'));

      await pumpSoundsTab(tester);
      await tester.tap(find.text('Original sound - rabble'));
      await tester.pumpAndSettle();

      expect(find.text('sound detail sound1'), findsOneWidget);
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
      expect(find.byKey(const Key('saved_sound_label_field')), findsOneWidget);

      final savedSounds = SavedSoundsService(
        sharedPreferences,
      ).loadSavedSounds();
      expect(
        savedSounds.map((sound) => sound.audio.title),
        contains('Wednesday My Dudes'),
      );
    });

    testWidgets('filters rich cards by personal hashtag', (tester) async {
      final service = SavedSoundsService(sharedPreferences);
      await service.saveSavedSound(
        SavedSound(
          audio: _sound(id: 'sound1', title: 'Drum Loop'),
          personalHashtags: const ['practice'],
          catalogTags: const [],
          waveformSamples: const [],
        ),
      );
      await service.saveSavedSound(
        SavedSound(
          audio: _sound(id: 'sound2', title: 'Piano Loop'),
          personalHashtags: const ['favorite'],
          catalogTags: const [],
          waveformSamples: const [],
        ),
      );

      await pumpSoundsTab(tester);
      await tester.tap(find.byKey(const Key('saved_sound_filter_practice')));
      await tester.pumpAndSettle();

      expect(find.text('Drum Loop'), findsOneWidget);
      expect(find.text('Piano Loop'), findsNothing);
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
      await SavedSoundsService(
        sharedPreferences,
      ).saveSound(_sound(id: 'sound1', title: 'Original sound - rabble'));

      await pumpSoundsTab(tester);
      await tester.tap(find.byKey(const Key('saved_sound_remove')));
      await tester.pumpAndSettle();

      expect(find.text('Original sound - rabble'), findsNothing);
      expect(find.text('No saved sounds yet'), findsOneWidget);
    });

    group('sync trigger', () {
      late _MockSoundSyncRepository syncRepository;

      Future<void> pumpSyncedSoundsTab(WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(sharedPreferences),
              soundSyncAvailabilityProvider.overrideWith(
                (ref) async => SoundSyncAvailable(syncRepository),
              ),
            ],
            child: SavedSoundsScope(
              service: SavedSoundsService(sharedPreferences),
              mediaProbe: const _NoopSavedSoundMediaProbe(),
              child: MaterialApp.router(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: VineTheme.theme,
                routerConfig: GoRouter(
                  routes: [
                    GoRoute(
                      path: '/',
                      builder: (context, state) =>
                          const Scaffold(body: SoundsTab()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        // Lets soundSyncAvailabilityProvider's FutureProvider resolve so
        // SoundsTab rebuilds with the now-available repository and mounts
        // BlocProvider<SoundSyncCubit>, whose create: fires syncNow().
        await tester.pump();
        await tester.pump();
      }

      setUp(() {
        syncRepository = _MockSoundSyncRepository();
      });

      testWidgets('reconciles once when the tab opens', (tester) async {
        final completer = Completer<SoundSyncOutcome>();
        when(syncRepository.reconcile).thenAnswer((_) => completer.future);

        await pumpSyncedSoundsTab(tester);

        verify(syncRepository.reconcile).called(1);

        completer.complete(
          const SoundSyncOutcome(
            pulled: 0,
            pushed: 0,
            deleted: 0,
            deletionsRetried: 0,
          ),
        );
        await tester.pumpAndSettle();
      });

      testWidgets('shows syncing then synced status', (tester) async {
        final completer = Completer<SoundSyncOutcome>();
        when(syncRepository.reconcile).thenAnswer((_) => completer.future);
        final l10n = lookupAppLocalizations(const Locale('en'));

        await pumpSyncedSoundsTab(tester);

        expect(find.text(l10n.soundSyncStatusSyncing), findsOneWidget);
        expect(find.text(l10n.soundSyncStatusSynced), findsNothing);

        completer.complete(
          const SoundSyncOutcome(
            pulled: 1,
            pushed: 0,
            deleted: 0,
            deletionsRetried: 0,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.soundSyncStatusSyncing), findsNothing);
        expect(find.text(l10n.soundSyncStatusSynced), findsOneWidget);
      });

      testWidgets('shows locked status when the vault key is unavailable', (
        tester,
      ) async {
        when(
          syncRepository.reconcile,
        ).thenThrow(VaultKeyUnavailableException('locked'));
        final l10n = lookupAppLocalizations(const Locale('en'));

        await pumpSyncedSoundsTab(tester);
        await tester.pumpAndSettle();

        expect(find.text(l10n.soundSyncStatusLocked), findsOneWidget);
      });
    });

    group('vault key locked at the provider', () {
      const testPubkey =
          'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';

      testWidgets(
        'shows the locked banner when the vault key cannot be unlocked',
        (tester) async {
          final mockClient = _MockNostrClient();
          final mockSigner = _MockNostrSigner();
          when(() => mockClient.signer).thenReturn(mockSigner);
          when(() => mockClient.hasKeys).thenReturn(true);
          when(() => mockClient.publicKey).thenReturn(testPubkey);
          // No signed-in account from the signer's perspective —
          // VaultKeyService throws VaultKeyUnavailableException before ever
          // touching secure storage or a relay. Unlike the mocked-cubit
          // "shows locked status" case above, this drives the real
          // soundSyncAvailabilityProvider failure path end to end.
          when(mockSigner.getPublicKey).thenAnswer((_) async => null);
          final l10n = lookupAppLocalizations(const Locale('en'));

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                sharedPreferencesProvider.overrideWithValue(
                  sharedPreferences,
                ),
                nostrSessionProvider.overrideWith(
                  () => _TestNostrSession(
                    NostrSessionReadiness.nostrReady(
                      pubkey: testPubkey,
                      client: mockClient,
                    ),
                  ),
                ),
              ],
              child: SavedSoundsScope(
                service: SavedSoundsService(sharedPreferences),
                mediaProbe: const _NoopSavedSoundMediaProbe(),
                child: MaterialApp.router(
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  theme: VineTheme.theme,
                  routerConfig: GoRouter(
                    routes: [
                      GoRoute(
                        path: '/',
                        builder: (context, state) =>
                            const Scaffold(body: SoundsTab()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text(l10n.soundSyncStatusLocked), findsOneWidget);
          expect(find.text(l10n.soundSyncStatusSyncing), findsNothing);
          expect(find.text(l10n.soundSyncStatusSynced), findsNothing);
        },
      );
    });
  });
}

class _NoopSavedSoundMediaProbe implements SavedSoundMediaProbe {
  const _NoopSavedSoundMediaProbe();

  @override
  Future<SavedSoundMediaResult?> probe(AudioEvent sound) async => null;
}
