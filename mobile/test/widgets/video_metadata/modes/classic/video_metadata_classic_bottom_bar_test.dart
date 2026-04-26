import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as models;
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_metadata/modes/classic/video_metadata_classic_bottom_bar.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(VideoMetadataClassicBottomBar, () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders Post button labeled "Done"', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataClassicBottomBar()),
          ),
        ),
      );
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('button is disabled when metadata is invalid', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataClassicBottomBar()),
          ),
        ),
      );

      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity).first,
      );
      expect(animatedOpacity.opacity, lessThan(1));
    });

    testWidgets('button is enabled when metadata is valid', (tester) async {
      final validState = VideoEditorProviderState(
        title: 'Test Video',
        finalRenderedClip: DivineVideoClip(
          id: 'test-clip',
          video: EditorVideo.file('test.mp4'),
          duration: const Duration(seconds: 10),
          recordedAt: DateTime.now(),
          targetAspectRatio: models.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(validState),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataClassicBottomBar()),
          ),
        ),
      );

      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity).first,
      );
      expect(animatedOpacity.opacity, equals(1.0));
    });

    testWidgets('tapping Done calls postVideo when valid', (tester) async {
      var postVideoCalled = false;
      final mockNotifier = _MockVideoEditorNotifier(
        VideoEditorProviderState(
          title: 'Test',
          finalRenderedClip: DivineVideoClip(
            id: 'test',
            video: EditorVideo.file('test.mp4'),
            duration: const Duration(seconds: 5),
            recordedAt: DateTime.now(),
            targetAspectRatio: models.AspectRatio.square,
            originalAspectRatio: 9 / 16,
          ),
        ),
        onPostVideo: () => postVideoCalled = true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [videoEditorProvider.overrideWith(() => mockNotifier)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataClassicBottomBar()),
          ),
        ),
      );

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(postVideoCalled, isTrue);
    });

    testWidgets('button has correct semantics identifier', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataClassicBottomBar()),
          ),
        ),
      );

      final semantics = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.identifier == 'post_button',
        ),
      );
      expect(semantics.properties.label, equals('Open post preview screen'));
    });
  });
}

class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(this._state, {this.onPostVideo});

  final VideoEditorProviderState _state;
  final VoidCallback? onPostVideo;

  @override
  VideoEditorProviderState build() => _state;

  @override
  Future<void> postVideo(BuildContext context) async {
    onPostVideo?.call();
  }
}
