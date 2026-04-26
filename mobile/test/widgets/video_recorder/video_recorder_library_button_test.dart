import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_library_button.dart';
import 'package:pro_video_editor/core/models/video/editor_video_model.dart';

class _MockClipLibraryService extends Mock implements ClipLibraryService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoRecorderLibraryButton, () {
    late _MockClipLibraryService mockClipLibraryService;

    setUp(() {
      mockClipLibraryService = _MockClipLibraryService();

      when(
        () => mockClipLibraryService.getAllClips(),
      ).thenAnswer((_) async => []);
    });

    Widget buildWidget({List<DivineVideoClip>? clips}) {
      return ProviderScope(
        overrides: [
          clipManagerProvider.overrideWith(
            () => _TestClipManagerNotifier(clips: clips ?? []),
          ),
          clipLibraryServiceProvider.overrideWithValue(mockClipLibraryService),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: VideoRecorderLibraryButton()),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $VideoRecorderLibraryButton', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderLibraryButton), findsOneWidget);
      });

      testWidgets('renders container with rounded shape', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('renders GestureDetector for tap', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(GestureDetector), findsWidgets);
      });
    });

    group('badge count', () {
      testWidgets('does not show badge when clips is empty', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // The badge uses SizedBox.shrink when count == 0
        expect(find.text('0'), findsNothing);
      });

      testWidgets('shows badge with clip count', (tester) async {
        final clips = [
          DivineVideoClip(
            id: 'clip1',
            video: EditorVideo.file('/test/clip1.mp4'),
            duration: const Duration(seconds: 2),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
          DivineVideoClip(
            id: 'clip2',
            video: EditorVideo.file('/test/clip2.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
        ];

        await tester.pumpWidget(buildWidget(clips: clips));
        await tester.pumpAndSettle();

        expect(find.text('2'), findsOneWidget);
      });

      testWidgets('shows badge with 1 for single clip', (tester) async {
        final clips = [
          DivineVideoClip(
            id: 'clip1',
            video: EditorVideo.file('/test/clip1.mp4'),
            duration: const Duration(seconds: 2),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
        ];

        await tester.pumpWidget(buildWidget(clips: clips));
        await tester.pumpAndSettle();

        expect(find.text('1'), findsOneWidget);
      });
    });

    group('accessibility', () {
      testWidgets('has no-clips semantic label when empty', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel('Clip library, no clips'), findsOneWidget);
      });

      testWidgets('has clip count semantic label with clips', (tester) async {
        final clips = [
          DivineVideoClip(
            id: 'clip1',
            video: EditorVideo.file('/test/clip1.mp4'),
            duration: const Duration(seconds: 2),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
            thumbnailPath: '/test/thumb1.jpg',
          ),
          DivineVideoClip(
            id: 'clip2',
            video: EditorVideo.file('/test/clip2.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
            thumbnailPath: '/test/thumb2.jpg',
          ),
        ];

        await tester.pumpWidget(buildWidget(clips: clips));
        await tester.pump();

        final semantics = tester.widget<Semantics>(
          find
              .descendant(
                of: find.byType(VideoRecorderLibraryButton),
                matching: find.byType(Semantics),
              )
              .first,
        );
        expect(
          semantics.properties.label,
          equals('Open clip library, 2 clips'),
        );
      });

      testWidgets('singular label for single clip', (tester) async {
        final clips = [
          DivineVideoClip(
            id: 'clip1',
            video: EditorVideo.file('/test/clip1.mp4'),
            duration: const Duration(seconds: 2),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
            thumbnailPath: '/test/thumb1.jpg',
          ),
        ];

        await tester.pumpWidget(buildWidget(clips: clips));
        await tester.pump();

        final semantics = tester.widget<Semantics>(
          find
              .descendant(
                of: find.byType(VideoRecorderLibraryButton),
                matching: find.byType(Semantics),
              )
              .first,
        );
        expect(semantics.properties.label, equals('Open clip library, 1 clip'));
      });

      testWidgets('is marked as button in semantics', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final semantics = tester.getSemantics(
          find.bySemanticsLabel('Clip library, no clips'),
        );
        expect(semantics.flagsCollection.isButton, isTrue);
      });
    });

    group('disabled state', () {
      testWidgets('GestureDetector onTap is null when no clips', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final detector = tester
            .widgetList<GestureDetector>(
              find.descendant(
                of: find.byType(VideoRecorderLibraryButton),
                matching: find.byType(GestureDetector),
              ),
            )
            .first;
        expect(detector.onTap, isNull);
      });
    });

    group('enabled/onTap consistency', () {
      testWidgets('InkWell onTap is non-null when clips exist '
          'but thumbnailPath is null', (tester) async {
        // Session clips without thumbnails — button should still be enabled
        final clips = [
          DivineVideoClip(
            id: 'clip-no-thumb',
            video: EditorVideo.file('/test/clip.mp4'),
            duration: const Duration(seconds: 2),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
            // thumbnailPath intentionally null
          ),
        ];

        await tester.pumpWidget(buildWidget(clips: clips));
        await tester.pumpAndSettle();

        final inkWell = tester.widget<InkWell>(find.byType(InkWell));
        expect(inkWell.onTap, isNotNull);
      });

      testWidgets('InkWell onTap is non-null when no session clips '
          'but library has clips', (tester) async {
        // No session clips, but library service returns clips
        final libraryClip = DivineVideoClip(
          id: 'lib-clip',
          video: EditorVideo.file('/lib/clip.mp4'),
          duration: const Duration(seconds: 5),
          recordedAt: DateTime.now(),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
          thumbnailPath: '/lib/thumb.jpg',
        );

        when(
          () => mockClipLibraryService.getAllClips(),
        ).thenAnswer((_) async => [libraryClip]);

        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final inkWell = tester.widget<InkWell>(find.byType(InkWell));
        expect(inkWell.onTap, isNotNull);
      });

      testWidgets('Semantics.enabled matches InkWell.onTap presence', (
        tester,
      ) async {
        final clips = [
          DivineVideoClip(
            id: 'clip1',
            video: EditorVideo.file('/test/clip1.mp4'),
            duration: const Duration(seconds: 2),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
        ];

        await tester.pumpWidget(buildWidget(clips: clips));
        await tester.pumpAndSettle();

        final inkWell = tester.widget<InkWell>(find.byType(InkWell));
        final semantics = tester.widget<Semantics>(
          find
              .descendant(
                of: find.byType(VideoRecorderLibraryButton),
                matching: find.byType(Semantics),
              )
              .first,
        );

        // Both should agree: button is enabled
        expect(inkWell.onTap, isNotNull);
        expect(semantics.properties.enabled, isTrue);
      });
    });

    group('thumbnail', () {
      testWidgets('shows empty state when no clips and no library', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // No Image.file should appear
        expect(find.byType(Image), findsNothing);
      });

      testWidgets('loads library thumbnail on init', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        verify(() => mockClipLibraryService.getAllClips()).called(1);
      });
    });
  });
}

class _TestClipManagerNotifier extends ClipManagerNotifier {
  _TestClipManagerNotifier({required this.clips});

  @override
  final List<DivineVideoClip> clips;

  @override
  ClipManagerState build() {
    return ClipManagerState(clips: clips);
  }
}
