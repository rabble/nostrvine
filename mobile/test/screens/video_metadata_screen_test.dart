// ABOUTME: Tests for VideoMetadataScreen gallery save and permission banner
// ABOUTME: Verifies auto-save to gallery and permission denied UX flow

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as models;
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/screens/video_metadata/video_metadata_screen.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Sets up a mock handler for the `gal` MethodChannel.
///
/// [hasAccess] controls what `Gal.hasAccess()` returns.
/// [requestAccessGranted] controls what `Gal.requestAccess()` returns.
/// [putVideoSucceeds] controls whether `Gal.putVideo()` succeeds.
void _setupGalMock({
  required TestWidgetsFlutterBinding binding,
  bool hasAccess = true,
  bool requestAccessGranted = true,
  bool putVideoSucceeds = true,
}) {
  binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('gal'),
    (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'hasAccess':
          return hasAccess;
        case 'requestAccess':
          return requestAccessGranted;
        case 'putVideo':
          if (!putVideoSucceeds) {
            throw PlatformException(code: 'ERROR', message: 'Save failed');
          }
          return null;
        default:
          return null;
      }
    },
  );
}

/// Removes the mock handler for the `gal` MethodChannel.
void _teardownGalMock(TestWidgetsFlutterBinding binding) {
  binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('gal'),
    null,
  );
}

RecordingClip _createTestClip({String id = 'test-clip'}) {
  return RecordingClip(
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
    late TestWidgetsFlutterBinding binding;
    late RecordingClip testClip;

    setUp(() {
      binding = TestWidgetsFlutterBinding.ensureInitialized();
      testClip = _createTestClip();
    });

    tearDown(() {
      _teardownGalMock(binding);
    });

    group('renders', () {
      testWidgets('renders $VideoMetadataScreen with basic structure', (
        tester,
      ) async {
        _setupGalMock(binding: binding);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              clipManagerProvider.overrideWith(
                () => _MockClipManagerNotifier([testClip]),
              ),
            ],
            child: const MaterialApp(home: VideoMetadataScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Post details'), findsOneWidget);
        expect(find.text('Post'), findsOneWidget);
      });
    });

    group('gallery save', () {
      testWidgets('saves video to gallery when finalRenderedClip exists', (
        tester,
      ) async {
        var putVideoCalled = false;

        binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('gal'),
          (MethodCall methodCall) async {
            switch (methodCall.method) {
              case 'hasAccess':
                return true;
              case 'putVideo':
                putVideoCalled = true;
                return null;
              default:
                return null;
            }
          },
        );

        final state = VideoEditorProviderState(
          title: 'Test Video',
          finalRenderedClip: testClip,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              clipManagerProvider.overrideWith(
                () => _MockClipManagerNotifier([testClip]),
              ),
              videoEditorProvider.overrideWith(
                () => _MockVideoEditorNotifier(state),
              ),
            ],
            child: const MaterialApp(home: VideoMetadataScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(putVideoCalled, isTrue);
      });

      testWidgets('does not attempt gallery save when no finalRenderedClip', (
        tester,
      ) async {
        var putVideoCalled = false;

        binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('gal'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'putVideo') {
              putVideoCalled = true;
            }
            return null;
          },
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              clipManagerProvider.overrideWith(
                () => _MockClipManagerNotifier([testClip]),
              ),
              videoEditorProvider.overrideWith(
                () => _MockVideoEditorNotifier(VideoEditorProviderState()),
              ),
            ],
            child: const MaterialApp(home: VideoMetadataScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(putVideoCalled, isFalse);
      });
    });

    group('gallery permission banner', () {
      testWidgets('shows banner when permission is denied', (tester) async {
        _setupGalMock(
          binding: binding,
          hasAccess: false,
          requestAccessGranted: false,
        );

        final state = VideoEditorProviderState(
          title: 'Test Video',
          finalRenderedClip: testClip,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              clipManagerProvider.overrideWith(
                () => _MockClipManagerNotifier([testClip]),
              ),
              videoEditorProvider.overrideWith(
                () => _MockVideoEditorNotifier(state),
              ),
            ],
            child: const MaterialApp(home: VideoMetadataScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Allow access to save a copy to your photo library.'),
          findsOneWidget,
        );
        expect(find.text('Allow'), findsOneWidget);
        expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
      });

      testWidgets('does not show banner when permission is granted', (
        tester,
      ) async {
        _setupGalMock(binding: binding);

        final state = VideoEditorProviderState(
          title: 'Test Video',
          finalRenderedClip: testClip,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              clipManagerProvider.overrideWith(
                () => _MockClipManagerNotifier([testClip]),
              ),
              videoEditorProvider.overrideWith(
                () => _MockVideoEditorNotifier(state),
              ),
            ],
            child: const MaterialApp(home: VideoMetadataScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Allow access to save a copy to your photo library.'),
          findsNothing,
        );
      });

      testWidgets('tapping Allow retries and hides banner on success', (
        tester,
      ) async {
        var hasAccessCallCount = 0;

        binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('gal'),
          (MethodCall methodCall) async {
            switch (methodCall.method) {
              case 'hasAccess':
                hasAccessCallCount++;
                // First two calls (initial check + re-check): denied
                // Third call onwards (retry after tap): granted
                return hasAccessCallCount > 2;
              case 'requestAccess':
                return null;
              case 'putVideo':
                return null;
              default:
                return null;
            }
          },
        );

        final state = VideoEditorProviderState(
          title: 'Test Video',
          finalRenderedClip: testClip,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              clipManagerProvider.overrideWith(
                () => _MockClipManagerNotifier([testClip]),
              ),
              videoEditorProvider.overrideWith(
                () => _MockVideoEditorNotifier(state),
              ),
            ],
            child: const MaterialApp(home: VideoMetadataScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Banner should be visible initially
        expect(
          find.text('Allow access to save a copy to your photo library.'),
          findsOneWidget,
        );

        // Tap the Allow button
        await tester.tap(find.text('Allow'));
        await tester.pumpAndSettle();

        // Banner should be gone after permission granted
        expect(
          find.text('Allow access to save a copy to your photo library.'),
          findsNothing,
        );
      });
    });
  });
}

/// Mock clip manager notifier for testing.
class _MockClipManagerNotifier extends ClipManagerNotifier {
  _MockClipManagerNotifier(this._clips);

  final List<RecordingClip> _clips;

  @override
  ClipManagerState build() => ClipManagerState(clips: _clips);
}

/// Mock video editor notifier for testing.
class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(this._state);

  final VideoEditorProviderState _state;

  @override
  VideoEditorProviderState build() => _state;

  @override
  Future<void> cancelRenderVideo() async {}

  @override
  void updateMetadata({
    String? title,
    String? description,
    Set<String>? tags,
  }) {}
}
