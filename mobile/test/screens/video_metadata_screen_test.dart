// ABOUTME: Tests for VideoMetadataScreen basic rendering and structure
// ABOUTME: Verifies screen renders with expected UI elements

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as models;
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_publish/video_publish_provider_state.dart';
import 'package:openvine/models/video_publish/video_publish_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/screens/video_metadata/video_metadata_screen.dart';
import 'package:openvine/services/native_proofmode_service.dart';
import 'package:openvine/widgets/video_metadata/modes/capture/video_metadata_capture_stack.dart';
import 'package:openvine/widgets/video_metadata/modes/classic/video_metadata_classic_stack.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

DivineVideoClip _createTestClip({String id = 'test-clip'}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.file('test.mp4'),
    duration: const Duration(seconds: 10),
    recordedAt: DateTime.now(),
    targetAspectRatio: models.AspectRatio.square,
    originalAspectRatio: 9 / 16,
  );
}

void main() {
  group(VideoMetadataScreen, () {
    late DivineVideoClip testClip;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      testClip = _createTestClip();
    });

    // VideoMetadataScreen is pushed as a top-level route, OUTSIDE the recorder's
    // BlocProvider, so it must NOT depend on VideoRecorderBloc — it reads the
    // persisted recorder mode from SharedPreferences instead. These tests pump
    // it without any BlocProvider on purpose: a regression to reading the bloc
    // would throw a ProviderNotFoundException and fail here (the crash hm21
    // hit in classic mode).
    Widget buildScreen() {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          clipManagerProvider.overrideWith(
            () => _MockClipManagerNotifier([testClip]),
          ),
          videoEditorProvider.overrideWith(
            () => _MockVideoEditorNotifier(
              VideoEditorProviderState(finalRenderedClip: testClip),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: VideoMetadataScreen(),
        ),
      );
    }

    group('initState', () {
      testWidgets('clears stale publish error state on screen init', (
        tester,
      ) async {
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            clipManagerProvider.overrideWith(
              () => _MockClipManagerNotifier([testClip]),
            ),
            videoPublishProvider.overrideWith(
              () => _MockVideoPublishNotifier(
                const VideoPublishProviderState(
                  publishState: VideoPublishState.error,
                  errorMessage: 'Previous error',
                ),
              ),
            ),
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(
                VideoEditorProviderState(finalRenderedClip: testClip),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: VideoMetadataScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final state = container.read(videoPublishProvider);
        expect(state.publishState, VideoPublishState.idle);
        expect(state.errorMessage, isNull);
      });
    });

    group('renders', () {
      testWidgets('renders $VideoMetadataScreen with basic structure', (
        tester,
      ) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        expect(find.text('Post details'), findsOneWidget);
        expect(find.text('Post'), findsOneWidget);
      });

      testWidgets('renders audio reuse opt-in and updates editor state', (
        tester,
      ) async {
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            clipManagerProvider.overrideWith(
              () => _MockClipManagerNotifier([testClip]),
            ),
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(
                VideoEditorProviderState(finalRenderedClip: testClip),
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: VideoMetadataScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.videoMetadataAudioReuseTitle), findsOneWidget);
        expect(find.text(l10n.videoMetadataAudioReuseSubtitle), findsOneWidget);
        expect(container.read(videoEditorProvider).allowAudioReuse, isFalse);

        await tester.ensureVisible(
          find.text(l10n.videoMetadataAudioReuseTitle),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.videoMetadataAudioReuseTitle));
        await tester.pumpAndSettle();

        expect(container.read(videoEditorProvider).allowAudioReuse, isTrue);

        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
    });

    group('C2PA signing prompt (#6058)', () {
      testWidgets(
        'prompts to regenerate or post anyway when signing fails, and '
        '"Post anyway" clears the flag',
        (tester) async {
          final container = ProviderContainer(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              clipManagerProvider.overrideWith(
                () => _MockClipManagerNotifier([testClip]),
              ),
              videoEditorProvider.overrideWith(
                () => _MockVideoEditorNotifier(
                  VideoEditorProviderState(finalRenderedClip: testClip),
                ),
              ),
            ],
          );
          addTearDown(container.dispose);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: VideoMetadataScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final l10n = lookupAppLocalizations(const Locale('en'));
          // Nothing while signing hasn't failed.
          expect(find.text(l10n.videoMetadataC2paMissingTitle), findsNothing);

          // The render finishes without a C2PA content credential.
          final notifier = container.read(videoEditorProvider.notifier);
          notifier.state = notifier.state.copyWith(c2paSigningFailed: true);
          await tester.pumpAndSettle();

          expect(find.text(l10n.videoMetadataC2paMissingTitle), findsOneWidget);
          expect(
            find.text(l10n.videoMetadataC2paMissingRegenerate),
            findsOneWidget,
          );

          await tester.tap(
            find.text(l10n.videoMetadataC2paMissingPostAnyway),
          );
          await tester.pumpAndSettle();

          expect(
            container.read(videoEditorProvider).c2paSigningFailed,
            isFalse,
            reason: 'posting anyway clears the pending prompt',
          );
          expect(find.text(l10n.videoMetadataC2paMissingTitle), findsNothing);
        },
      );

      testWidgets(
        '"Regenerate" re-signs (isProcessing) rather than posting without '
        'provenance',
        (tester) async {
          // A re-sign that never resolves keeps isProcessing observably true,
          // which distinguishes retryC2paSigning (sets it) from a mis-wire to
          // acknowledgeC2paSigningFailure (which would not).
          NativeProofModeService.proofFileOverride =
              (
                file, {
                required enableAdvancedCawgEmbedding,
                creatorBindingAssertion,
                cawgIdentityAssertion,
                verifiedIdentityBundle,
                clips,
                editorStateHistory,
              }) => Completer<models.NativeProofData?>().future;
          addTearDown(() => NativeProofModeService.proofFileOverride = null);

          final container = ProviderContainer(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              clipManagerProvider.overrideWith(
                () => _MockClipManagerNotifier([testClip]),
              ),
              videoEditorProvider.overrideWith(
                () => _MockVideoEditorNotifier(
                  VideoEditorProviderState(finalRenderedClip: testClip),
                ),
              ),
            ],
          );
          addTearDown(container.dispose);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: VideoMetadataScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final l10n = lookupAppLocalizations(const Locale('en'));
          final notifier = container.read(videoEditorProvider.notifier);
          notifier.state = notifier.state.copyWith(c2paSigningFailed: true);
          await tester.pumpAndSettle();

          await tester.tap(find.text(l10n.videoMetadataC2paMissingRegenerate));
          // The re-sign turns on the processing spinner, which animates
          // forever — pumpAndSettle would time out. Pump fixed frames to run
          // the sheet-dismiss animation and the retry microtask instead.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump();

          final state = container.read(videoEditorProvider);
          expect(
            find.text(l10n.videoMetadataC2paMissingTitle),
            findsNothing,
            reason: 'the prompt is dismissed once a choice is made',
          );
          expect(
            state.c2paSigningFailed,
            isFalse,
            reason: 'the retry clears the prompt while it re-signs',
          );
          expect(
            state.isProcessing,
            isTrue,
            reason:
                'Regenerate re-signs the existing render, so it enters the '
                'processing state — it does not silently post without '
                'provenance',
          );
        },
      );

      testWidgets(
        'a system-back (null pop) re-signs rather than posting without '
        'provenance (#6058)',
        (tester) async {
          // A re-sign that never resolves keeps isProcessing observably true,
          // distinguishing retryC2paSigning from a silent postAnyway.
          NativeProofModeService.proofFileOverride =
              (
                file, {
                required enableAdvancedCawgEmbedding,
                creatorBindingAssertion,
                cawgIdentityAssertion,
                verifiedIdentityBundle,
                clips,
                editorStateHistory,
              }) => Completer<models.NativeProofData?>().future;
          addTearDown(() => NativeProofModeService.proofFileOverride = null);

          final container = ProviderContainer(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              clipManagerProvider.overrideWith(
                () => _MockClipManagerNotifier([testClip]),
              ),
              videoEditorProvider.overrideWith(
                () => _MockVideoEditorNotifier(
                  VideoEditorProviderState(finalRenderedClip: testClip),
                ),
              ),
            ],
          );
          addTearDown(container.dispose);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: VideoMetadataScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final l10n = lookupAppLocalizations(const Locale('en'));
          final notifier = container.read(videoEditorProvider.notifier);
          notifier.state = notifier.state.copyWith(c2paSigningFailed: true);
          await tester.pumpAndSettle();
          expect(find.text(l10n.videoMetadataC2paMissingTitle), findsOneWidget);

          // Dismiss the non-dismissible sheet with a system back (no button
          // choice) — the pop resolves the prompt future with null.
          await tester.binding.handlePopRoute();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump();

          final state = container.read(videoEditorProvider);
          expect(
            find.text(l10n.videoMetadataC2paMissingTitle),
            findsNothing,
            reason: 'the prompt is dismissed by the system back',
          );
          expect(
            state.c2paSigningFailed,
            isFalse,
            reason: 'the null pop re-signs, which clears the prompt flag',
          );
          expect(
            state.isProcessing,
            isTrue,
            reason:
                'a system back re-signs the existing render (retryC2paSigning) '
                'instead of silently posting without provenance',
          );
        },
      );

      testWidgets(
        'prompts on mount when signing already failed before the screen '
        'mounted (#6058)',
        (tester) async {
          final container = ProviderContainer(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              clipManagerProvider.overrideWith(
                () => _MockClipManagerNotifier([testClip]),
              ),
              videoEditorProvider.overrideWith(
                () => _MockVideoEditorNotifier(
                  VideoEditorProviderState(
                    finalRenderedClip: testClip,
                    c2paSigningFailed: true,
                  ),
                ),
              ),
            ],
          );
          addTearDown(container.dispose);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: VideoMetadataScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final l10n = lookupAppLocalizations(const Locale('en'));
          expect(
            find.text(l10n.videoMetadataC2paMissingTitle),
            findsOneWidget,
            reason:
                'ref.listen misses a value already true at mount, so the '
                'post-frame check must surface the prompt',
          );
        },
      );
    });

    group('recorder mode switch', () {
      testWidgets('renders $VideoMetadataCaptureStack when mode is capture', (
        tester,
      ) async {
        await prefs.setString(
          VideoRecorderMode.persistenceKey,
          VideoRecorderMode.capture.name,
        );

        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        expect(find.byType(VideoMetadataCaptureStack), findsOneWidget);
        expect(find.byType(VideoMetadataClassicStack), findsNothing);
      });

      testWidgets('renders $VideoMetadataClassicStack when mode is classic', (
        tester,
      ) async {
        await prefs.setString(
          VideoRecorderMode.persistenceKey,
          VideoRecorderMode.classic.name,
        );

        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        expect(find.byType(VideoMetadataClassicStack), findsOneWidget);
        expect(find.byType(VideoMetadataCaptureStack), findsNothing);
      });
    });
  });
}

/// Mock clip manager notifier for testing.
class _MockClipManagerNotifier extends ClipManagerNotifier {
  _MockClipManagerNotifier(this._clips);

  final List<DivineVideoClip> _clips;

  @override
  ClipManagerState build() => ClipManagerState(clips: _clips);
}

/// Mock publish notifier that starts with a given state.
class _MockVideoPublishNotifier extends VideoPublishNotifier {
  _MockVideoPublishNotifier(this._initialState);

  final VideoPublishProviderState _initialState;

  @override
  VideoPublishProviderState build() => _initialState;
}

/// Mock video editor notifier that returns a fixed state.
class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(this._initialState);

  final VideoEditorProviderState _initialState;

  @override
  VideoEditorProviderState build() => _initialState;
}
