import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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

      when(() => mockClipLibraryService.getAllClips()).thenAnswer(
        (_) async => [],
      );
    });

    Widget buildWidget({
      List<DivineVideoClip>? clips,
    }) {
      return ProviderScope(
        overrides: [
          clipManagerProvider.overrideWith(
            () => _TestClipManagerNotifier(clips: clips ?? []),
          ),
          clipLibraryServiceProvider.overrideWithValue(
            mockClipLibraryService,
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: VideoRecorderLibraryButton(),
          ),
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

      testWidgets('renders InkWell for tap', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(InkWell), findsOneWidget);
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
      testWidgets('has semantic label', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsLabel('Open the clip library'),
          findsOneWidget,
        );
      });

      testWidgets('is marked as button in semantics', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final semantics = tester.getSemantics(
          find.bySemanticsLabel('Open the clip library'),
        );
        expect(semantics.flagsCollection.isButton, isTrue);
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
