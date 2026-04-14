import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as models;
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_metadata/modes/capture/video_metadata_capture_app_bar.dart';
import 'package:openvine/widgets/video_metadata/modes/capture/video_metadata_capture_bottom_bar.dart';
import 'package:openvine/widgets/video_metadata/modes/capture/video_metadata_capture_clip_preview.dart';
import 'package:openvine/widgets/video_metadata/modes/capture/video_metadata_capture_stack.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_form_fields.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group(VideoMetadataCaptureStack, () {
    late DivineVideoClip testClip;

    setUp(() {
      testClip = DivineVideoClip(
        id: 'test-clip',
        video: EditorVideo.file('test.mp4'),
        duration: const Duration(seconds: 10),
        recordedAt: DateTime.now(),
        thumbnailPath: 'test_thumbnail.jpg',
        targetAspectRatio: models.AspectRatio.square,
        originalAspectRatio: 9 / 16,
      );
    });

    Widget buildWidget() {
      return ProviderScope(
        overrides: [
          clipManagerProvider.overrideWith(
            () => _MockClipManagerNotifier([testClip]),
          ),
          videoEditorProvider.overrideWith(
            () => _MockVideoEditorNotifier(VideoEditorProviderState()),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: VideoMetadataCaptureStack(),
        ),
      );
    }

    testWidgets('renders $VideoMetadataCaptureStack', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byType(VideoMetadataCaptureStack), findsOneWidget);
    });

    testWidgets('renders $VideoMetadataCaptureAppBar', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byType(VideoMetadataCaptureAppBar), findsOneWidget);
    });

    testWidgets('renders $VideoMetadataCaptureClipPreview', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byType(VideoMetadataCaptureClipPreview), findsOneWidget);
    });

    testWidgets('renders $VideoMetadataFormFields', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byType(VideoMetadataFormFields), findsOneWidget);
    });

    testWidgets('renders $VideoMetadataCaptureBottomBar', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byType(VideoMetadataCaptureBottomBar), findsOneWidget);
    });

    testWidgets('uses correct background color', (tester) async {
      await tester.pumpWidget(buildWidget());

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(VineTheme.surfaceContainerHigh));
    });

    testWidgets('body is scrollable', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });
}

class _MockClipManagerNotifier extends ClipManagerNotifier {
  _MockClipManagerNotifier(this._clips);

  final List<DivineVideoClip> _clips;

  @override
  ClipManagerState build() => ClipManagerState(clips: _clips);
}

class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(this._state);

  final VideoEditorProviderState _state;

  @override
  VideoEditorProviderState build() => _state;
}
