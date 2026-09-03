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

    Widget buildWidget({
      TextScaler textScaler = TextScaler.noScaling,
      EdgeInsets viewInsets = EdgeInsets.zero,
    }) {
      return ProviderScope(
        overrides: [
          clipManagerProvider.overrideWith(
            () => _MockClipManagerNotifier([testClip]),
          ),
          videoEditorProvider.overrideWith(
            () => _MockVideoEditorNotifier(VideoEditorProviderState()),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(platform: TargetPlatform.iOS),
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: textScaler,
                viewInsets: viewInsets,
              ),
              child: child!,
            );
          },
          home: const VideoMetadataCaptureStack(),
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

    testWidgets('body scroll dismisses the keyboard', (tester) async {
      await tester.pumpWidget(buildWidget());

      final scrollView = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(
        scrollView.keyboardDismissBehavior,
        ScrollViewKeyboardDismissBehavior.onDrag,
      );
    });

    testWidgets('dragging a long description scrolls toward metadata options', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(402, 874));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        buildWidget(
          textScaler: const TextScaler.linear(1.35),
          viewInsets: const EdgeInsets.only(bottom: 336),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final description = find.byWidgetPredicate(
        (widget) =>
            widget is DivineTextField && widget.labelText == 'Description',
      );
      await tester.enterText(description, List.filled(260, 'a').join());
      await tester.pump();

      final bottomBar = find.byType(VideoMetadataCaptureBottomBar);
      final descriptionRect = tester.getRect(description);
      final dragStart = Offset(
        descriptionRect.center.dx,
        tester.getTopLeft(bottomBar).dy - 1,
      );
      expect(descriptionRect.contains(dragStart), isTrue);

      final outerScrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      final initialOffset = outerScrollable.position.pixels;

      await tester.dragFrom(dragStart, const Offset(0, -300));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(outerScrollable.position.pixels, greaterThan(initialOffset));
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
