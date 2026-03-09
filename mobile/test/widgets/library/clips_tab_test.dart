// ABOUTME: Tests for ClipsTab widget
// ABOUTME: Verifies clips grid, selection, loading, and empty states

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/library/clips_tab.dart';
import 'package:openvine/widgets/library/empty_library_state.dart';
import 'package:openvine/widgets/video_clip/video_clip_thumbnail_card.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockClipsLibraryBloc
    extends MockBloc<ClipsLibraryEvent, ClipsLibraryState>
    implements ClipsLibraryBloc {}

void main() {
  group(ClipsTab, () {
    late _MockClipsLibraryBloc mockBloc;

    final clip1 = DivineVideoClip(
      id: 'clip1',
      video: EditorVideo.file('/path/to/clip1.mp4'),
      duration: const Duration(seconds: 5),
      recordedAt: DateTime(2026),
      targetAspectRatio: .vertical,
      originalAspectRatio: 9 / 16,
    );

    final clip2 = DivineVideoClip(
      id: 'clip2',
      video: EditorVideo.file('/path/to/clip2.mp4'),
      duration: const Duration(seconds: 3),
      recordedAt: DateTime(2026),
      targetAspectRatio: .vertical,
      originalAspectRatio: 9 / 16,
    );

    setUp(() {
      mockBloc = _MockClipsLibraryBloc();
    });

    Widget buildWidget({
      Duration remainingDuration = const Duration(seconds: 30),
      bool isSelectionMode = false,
      double? targetAspectRatio,
    }) {
      return MaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(
          body: BlocProvider<ClipsLibraryBloc>.value(
            value: mockBloc,
            child: ClipsTab(
              remainingDuration: remainingDuration,
              isSelectionMode: isSelectionMode,
              targetAspectRatio: targetAspectRatio,
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('loading indicator when loading', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const ClipsLibraryState(status: ClipsLibraryStatus.loading),
        );

        await tester.pumpWidget(buildWidget());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('$EmptyLibraryState when no clips', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const ClipsLibraryState(
            status: ClipsLibraryStatus.loaded,
          ),
        );

        await tester.pumpWidget(buildWidget());

        expect(find.byType(EmptyLibraryState), findsOneWidget);
        expect(find.text('No Clips Yet'), findsOneWidget);
      });

      testWidgets(
        '$EmptyLibraryState without record button in selection mode',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            const ClipsLibraryState(
              status: ClipsLibraryStatus.loaded,
            ),
          );

          await tester.pumpWidget(buildWidget(isSelectionMode: true));

          expect(find.byType(EmptyLibraryState), findsOneWidget);
          expect(find.byType(ElevatedButton), findsNothing);
        },
      );

      testWidgets('clip thumbnails when clips are loaded', (tester) async {
        when(() => mockBloc.state).thenReturn(
          ClipsLibraryState(
            status: ClipsLibraryStatus.loaded,
            clips: [clip1, clip2],
          ),
        );

        await tester.pumpWidget(buildWidget());

        expect(find.byType(VideoClipThumbnailCard), findsNWidgets(2));
      });
    });

    group('interactions', () {
      testWidgets('toggles selection when clip is tapped', (tester) async {
        when(() => mockBloc.state).thenReturn(
          ClipsLibraryState(
            status: ClipsLibraryStatus.loaded,
            clips: [clip1],
          ),
        );

        await tester.pumpWidget(buildWidget());

        await tester.tap(find.byType(VideoClipThumbnailCard).first);

        verify(
          () => mockBloc.add(ClipsLibraryToggleSelection(clip1)),
        ).called(1);
      });
    });
  });

  group(ClipSelectionHeader, () {
    late _MockClipsLibraryBloc mockBloc;

    setUp(() {
      mockBloc = _MockClipsLibraryBloc();
    });

    Widget buildWidget({
      Duration remainingDuration = const Duration(seconds: 30),
      VoidCallback? onCreate,
    }) {
      return MaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(
          body: BlocProvider<ClipsLibraryBloc>.value(
            value: mockBloc,
            child: ClipSelectionHeader(
              remainingDuration: remainingDuration,
              onCreate: onCreate ?? () {},
            ),
          ),
        ),
      );
    }

    testWidgets('displays remaining duration', (tester) async {
      when(() => mockBloc.state).thenReturn(
        const ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          selectedClipIds: {'clip1', 'clip2'},
        ),
      );

      await tester.pumpWidget(buildWidget());

      // Format is "30.00s remaining" (2 decimal places)
      expect(find.text('30.00s remaining'), findsOneWidget);
    });

    testWidgets('calls onCreate when Add button is tapped', (tester) async {
      when(() => mockBloc.state).thenReturn(
        const ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          selectedClipIds: {'clip1'},
        ),
      );

      var created = false;
      await tester.pumpWidget(buildWidget(onCreate: () => created = true));

      // Find and tap the Add button (text button, not icon)
      final addButton = find.text('Add');
      expect(addButton, findsOneWidget);
      await tester.tap(addButton);
      expect(created, isTrue);
    });
  });
}
