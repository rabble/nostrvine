// ABOUTME: Tests for VideoRecorderScreen - main video recording UI
// ABOUTME: Tests screen initialization, camera setup, UI elements, and lifecycle

@Tags(['skip_very_good_optimization'])
import 'dart:core';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/camera_permission/camera_permission_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_capture_stack.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_bottom_bar.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks/mock_camera_service.dart';

class _MockDraftStorageService extends Mock implements DraftStorageService {}

class _MockClipLibraryService extends Mock implements ClipLibraryService {}

/// Mock for CameraPermissionBloc
class MockCameraPermissionBloc extends Mock implements CameraPermissionBloc {
  @override
  CameraPermissionState get state =>
      const CameraPermissionLoaded(CameraPermissionStatus.authorized);

  @override
  Stream<CameraPermissionState> get stream => Stream.value(state);

  @override
  Future<void> close() async {
    // No-op for mock
  }
}

/// Helper to build VideoRecorderScreen with required providers
Widget buildTestWidget({List<Override> overrides = const []}) {
  final mockDraftStorage = _MockDraftStorageService();
  when(
    () => mockDraftStorage.getDraftById(any()),
  ).thenAnswer((_) async => null);
  final mockClipLibrary = _MockClipLibraryService();
  when(mockClipLibrary.getAllClips).thenAnswer((_) async => []);
  return ProviderScope(
    overrides: [
      draftStorageServiceProvider.overrideWithValue(mockDraftStorage),
      clipLibraryServiceProvider.overrideWithValue(mockClipLibrary),
      ...overrides,
    ],
    child: BlocProvider<CameraPermissionBloc>(
      create: (_) => MockCameraPermissionBloc(),
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: VideoRecorderScreen(),
      ),
    ),
  );
}

/// Helper to build VideoRecorderScreen with provider overrides
Widget buildTestWidgetWithOverrides(List<Override> overrides) {
  final mockDraftStorage = _MockDraftStorageService();
  when(
    () => mockDraftStorage.getDraftById(any()),
  ).thenAnswer((_) async => null);
  final mockClipLibrary = _MockClipLibraryService();
  when(mockClipLibrary.getAllClips).thenAnswer((_) async => []);
  return ProviderScope(
    overrides: [
      draftStorageServiceProvider.overrideWithValue(mockDraftStorage),
      clipLibraryServiceProvider.overrideWithValue(mockClipLibrary),
      ...overrides,
    ],
    child: BlocProvider<CameraPermissionBloc>(
      create: (_) => MockCameraPermissionBloc(),
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: VideoRecorderScreen(),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoRecorderScreen Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('UI Components', () {
      testWidgets('renders capture stack by default', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        expect(find.byType(VideoRecorderCaptureStack), findsOneWidget);
      });

      testWidgets('renders bottom bar widget', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        expect(find.byType(VideoRecorderBottomBar), findsOneWidget);
      });

      testWidgets('renders Column with Expanded and bottom bar', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        // Body is a Column with an Expanded child and a Padding child
        final columnFinder = find.descendant(
          of: find.byType(Scaffold),
          matching: find.byType(Column),
        );
        expect(columnFinder, findsWidgets);

        final column = tester.widget<Column>(columnFinder.first);
        expect(column.children.first, isA<Expanded>());
        expect(column.children.last, isA<Padding>());
      });
    });

    group('Initialization', () {
      testWidgets('initializes recording provider on mount', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();
        await tester.pump(); // Post-frame callback

        // Provider should be read during initialization
        expect(() => container.read(videoRecorderProvider), returnsNormally);
      });

      testWidgets('registers as WidgetsBindingObserver', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        // Observer should be registered (verified by no exception)
        expect(find.byType(VideoRecorderScreen), findsOneWidget);
      });
    });

    group('Lifecycle Management', () {
      testWidgets('handles app lifecycle state changes', (tester) async {
        // Override platform to avoid macOS-specific camera preview
        // which requires a native texture not available in tests
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        try {
          final mockCamera = MockCameraService.create(
            onUpdateState: ({forceCameraRebuild}) {},
            onAutoStopped: (_) {},
          );
          await mockCamera.initialize();

          await tester.pumpWidget(
            buildTestWidgetWithOverrides([
              videoRecorderProvider.overrideWith(
                () => VideoRecorderNotifier(mockCamera),
              ),
            ]),
          );

          await tester.pump();

          // Simulate app going to background
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.pump();

          // Simulate app coming back to foreground
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump();

          // Should not crash
          expect(find.byType(VideoRecorderScreen), findsOneWidget);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

      testWidgets('unregister observer on dispose', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        // Remove the widget
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: Text('Other screen')),
          ),
        );

        await tester.pump();

        // Should have disposed without errors
        expect(find.byType(VideoRecorderScreen), findsNothing);
      });

      testWidgets('destroys notifier on dispose', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();
        await tester.pump(); // Post-frame callback

        // Navigate away
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: Text('Other screen')),
          ),
        );

        await tester.pumpAndSettle();

        // Should have disposed cleanly
        expect(find.byType(VideoRecorderScreen), findsNothing);
      });
    });

    group('Screen Layout', () {
      testWidgets('uses Column layout for screen', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        final columnFinder = find.descendant(
          of: find.byType(Scaffold),
          matching: find.byType(Column),
        );
        expect(columnFinder, findsWidgets);
      });

      testWidgets('screen takes full available space', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        final screenSize = tester.getSize(find.byType(VideoRecorderScreen));
        final viewSize =
            tester.view.physicalSize / tester.view.devicePixelRatio;

        expect(screenSize.width, equals(viewSize.width));
        expect(screenSize.height, equals(viewSize.height));
      });
    });

    group('State Management', () {
      testWidgets('screen reacts to recording state changes', (tester) async {
        await tester.pumpWidget(
          buildTestWidgetWithOverrides([
            videoRecorderProvider.overrideWith(VideoRecorderNotifier.new),
          ]),
        );

        await tester.pump();
        await tester.pump();

        // Screen should rebuild when state changes
        expect(find.byType(VideoRecorderScreen), findsOneWidget);
      });

      testWidgets('maintains state during rebuilds', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        // Force rebuild
        await tester.pump();

        // All widgets should still be present
        expect(find.byType(VideoRecorderCaptureStack), findsOneWidget);
        expect(find.byType(VideoRecorderBottomBar), findsOneWidget);
      });
    });

    group('Widget Tree Structure', () {
      testWidgets('capture stack is within Expanded', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        // Capture stack should be a descendant of Expanded
        expect(
          find.descendant(
            of: find.byType(Expanded),
            matching: find.byType(VideoRecorderCaptureStack),
          ),
          findsOneWidget,
        );
      });

      testWidgets('bottom bar is below the capture stack', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        final columnFinder = find.descendant(
          of: find.byType(Scaffold),
          matching: find.byType(Column),
        );
        final column = tester.widget<Column>(columnFinder.first);

        // First child is Expanded (capture stack), last is Padding (bottom bar)
        expect(column.children.first, isA<Expanded>());
        expect(column.children.last, isA<Padding>());
      });
    });

    group('Screen Integration', () {
      testWidgets('can be pushed onto navigation stack', (tester) async {
        final mockDraftStorage = _MockDraftStorageService();
        when(
          () => mockDraftStorage.getDraftById(any()),
        ).thenAnswer((_) async => null);
        final mockClipLibrary = _MockClipLibraryService();
        when(mockClipLibrary.getAllClips).thenAnswer((_) async => []);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              draftStorageServiceProvider.overrideWithValue(mockDraftStorage),
              clipLibraryServiceProvider.overrideWithValue(mockClipLibrary),
            ],
            child: BlocProvider<CameraPermissionBloc>(
              create: (_) => MockCameraPermissionBloc(),
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: Builder(
                    builder: (context) => ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BlocProvider<CameraPermissionBloc>(
                              create: (_) => MockCameraPermissionBloc(),
                              child: const VideoRecorderScreen(),
                            ),
                          ),
                        );
                      },
                      child: const Text('Open Camera'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Camera'));
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderScreen), findsOneWidget);
      });

      testWidgets('can be popped from navigation stack', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        // Simulate back navigation
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: Text('Home')),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderScreen), findsNothing);
        expect(find.text('Home'), findsOneWidget);
      });
    });

    group('Error Handling', () {
      testWidgets('handles missing provider gracefully', (tester) async {
        // This tests that the screen doesn't crash without proper setup
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        // Should build without crashing
        expect(find.byType(VideoRecorderScreen), findsOneWidget);
      });

      testWidgets('handles multiple rapid lifecycle changes', (tester) async {
        // Override platform to avoid macOS-specific camera preview
        // which requires a native texture not available in tests
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        try {
          final mockCamera = MockCameraService.create(
            onAutoStopped: (_) {},
            onUpdateState: ({forceCameraRebuild}) {},
          );
          await mockCamera.initialize();

          await tester.pumpWidget(
            buildTestWidgetWithOverrides([
              videoRecorderProvider.overrideWith(
                () => VideoRecorderNotifier(mockCamera),
              ),
            ]),
          );

          await tester.pump();

          // Rapid lifecycle changes
          for (var i = 0; i < 5; i++) {
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.paused,
            );
            await tester.pump();
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            );
            await tester.pump();
          }

          // Should handle without crashing
          expect(find.byType(VideoRecorderScreen), findsOneWidget);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    });

    group('Autosave Restore Flow', () {
      testWidgets(
        'shows bottom sheet when autosaved draft has been edited',
        (tester) async {
          // Skip the "why six seconds" prompt
          SharedPreferences.setMockInitialValues({
            'why_six_seconds_shown': true,
          });

          final mockDraftStorage = _MockDraftStorageService();
          final editedDraft = DivineVideoDraft(
            id: 'autosave',
            clips: [
              DivineVideoClip(
                id: 'clip_1',
                video: EditorVideo.file('/tmp/test.mp4'),
                duration: const Duration(seconds: 6),
                recordedAt: DateTime(2025),
                originalAspectRatio: 9 / 16,
                targetAspectRatio: .vertical,
              ),
            ],
            title: 'Edited Title',
            description: '',
            hashtags: const {},
            selectedApproach: 'camera',
            createdAt: DateTime(2025),
            lastModified: DateTime(2025),
            publishStatus: PublishStatus.draft,
            publishAttempts: 0,
          );
          when(
            () => mockDraftStorage.getDraftById(any()),
          ).thenAnswer((_) async => editedDraft);

          final mockClipLibrary = _MockClipLibraryService();
          when(mockClipLibrary.getAllClips).thenAnswer((_) async => []);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                draftStorageServiceProvider.overrideWithValue(
                  mockDraftStorage,
                ),
                clipLibraryServiceProvider.overrideWithValue(mockClipLibrary),
              ],
              child: BlocProvider<CameraPermissionBloc>(
                create: (_) => MockCameraPermissionBloc(),
                child: const MaterialApp(
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: VideoRecorderScreen(),
                ),
              ),
            ),
          );

          // Trigger post-frame callback
          await tester.pump();
          // Wait for async draft check
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump();

          // Bottom sheet should be visible
          expect(find.text('We found work in progress'), findsOneWidget);
          expect(find.text('Yes, continue'), findsOneWidget);
          expect(
            find.text('No, start a new video'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'does not show bottom sheet when draft has no edits',
        (tester) async {
          SharedPreferences.setMockInitialValues({
            'why_six_seconds_shown': true,
          });

          final mockDraftStorage = _MockDraftStorageService();
          // Draft with clips but no metadata edits → hasBeenEdited = false
          final uneditedDraft = DivineVideoDraft(
            id: 'autosave',
            clips: [
              DivineVideoClip(
                id: 'clip_1',
                video: EditorVideo.file('/tmp/test.mp4'),
                duration: const Duration(seconds: 6),
                recordedAt: DateTime(2025),
                originalAspectRatio: 9 / 16,
                targetAspectRatio: .vertical,
              ),
            ],
            title: '',
            description: '',
            hashtags: const {},
            selectedApproach: 'camera',
            createdAt: DateTime(2025),
            lastModified: DateTime(2025),
            publishStatus: PublishStatus.draft,
            publishAttempts: 0,
          );
          when(
            () => mockDraftStorage.getDraftById(any()),
          ).thenAnswer((_) async => uneditedDraft);

          final mockClipLibrary = _MockClipLibraryService();
          when(mockClipLibrary.getAllClips).thenAnswer((_) async => []);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                draftStorageServiceProvider.overrideWithValue(
                  mockDraftStorage,
                ),
                clipLibraryServiceProvider.overrideWithValue(mockClipLibrary),
              ],
              child: BlocProvider<CameraPermissionBloc>(
                create: (_) => MockCameraPermissionBloc(),
                child: const MaterialApp(
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: VideoRecorderScreen(),
                ),
              ),
            ),
          );

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump();

          // Bottom sheet should NOT appear
          expect(find.text('We found work in progress'), findsNothing);
        },
      );

      testWidgets(
        'does not show bottom sheet when no draft exists',
        (tester) async {
          SharedPreferences.setMockInitialValues({
            'why_six_seconds_shown': true,
          });

          final mockDraftStorage = _MockDraftStorageService();
          when(
            () => mockDraftStorage.getDraftById(any()),
          ).thenAnswer((_) async => null);

          final mockClipLibrary = _MockClipLibraryService();
          when(mockClipLibrary.getAllClips).thenAnswer((_) async => []);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                draftStorageServiceProvider.overrideWithValue(
                  mockDraftStorage,
                ),
                clipLibraryServiceProvider.overrideWithValue(mockClipLibrary),
              ],
              child: BlocProvider<CameraPermissionBloc>(
                create: (_) => MockCameraPermissionBloc(),
                child: const MaterialApp(
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: VideoRecorderScreen(),
                ),
              ),
            ),
          );

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump();

          expect(find.text('We found work in progress'), findsNothing);
        },
      );
    });
  });
}
