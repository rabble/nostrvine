// ABOUTME: Tests for ClipsTab widget
// ABOUTME: Verifies clips grid, selection, loading, and empty states

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/library/clips_tab.dart';
import 'package:openvine/widgets/library/empty_library_state.dart';
import 'package:openvine/widgets/video_clip/video_clip_preview.dart';
import 'package:openvine/widgets/video_clip/video_clip_thumbnail_card.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../../helpers/go_router.dart';

class _MockClipsLibraryBloc
    extends MockBloc<ClipsLibraryEvent, ClipsLibraryState>
    implements ClipsLibraryBloc {}

void main() {
  final en = AppLocalizationsEn();

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
      bool isSelectionMode = false,
      bool selectionEnabled = true,
      double? targetAspectRatio,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(
          body: BlocProvider<ClipsLibraryBloc>.value(
            value: mockBloc,
            child: ClipsTab(
              showRecordButton: isSelectionMode,
              selectionEnabled: selectionEnabled,
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

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
      });

      testWidgets('friendly error and retry when error state', (tester) async {
        when(
          () => mockBloc.state,
        ).thenReturn(const ClipsLibraryState(status: ClipsLibraryStatus.error));

        await tester.pumpWidget(buildWidget());

        expect(find.text(en.libraryCouldNotLoadClips), findsOneWidget);
        expect(find.text(en.searchTryAgain), findsOneWidget);
      });

      testWidgets('$EmptyLibraryState when no clips', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const ClipsLibraryState(status: ClipsLibraryStatus.loaded),
        );

        await tester.pumpWidget(buildWidget());

        expect(find.byType(EmptyLibraryState), findsOneWidget);
        expect(find.text(en.libraryNoClipsYetTitle), findsOneWidget);
      });

      testWidgets(
        '$EmptyLibraryState without record button in selection mode',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            const ClipsLibraryState(status: ClipsLibraryStatus.loaded),
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

      testWidgets(
        'omits the selection position when the badge is not shown',
        (tester) async {
          // Reachable on the ordinary library route: entering the library with
          // clips already in the editor pre-selects them
          // (ClipsLibraryLoadRequested.preSelectedIds) while selection mode is
          // still off, so selectionEnabled is false and no badge is rendered.
          when(() => mockBloc.state).thenReturn(
            ClipsLibraryState(
              status: ClipsLibraryStatus.loaded,
              clips: [clip1, clip2],
              selectedClipIds: const {'clip1'},
            ),
          );

          await tester.pumpWidget(buildWidget(selectionEnabled: false));

          final semantics = tester.getSemantics(
            find.byType(VideoClipThumbnailCard).first,
          );
          // No badge on screen, so the ordinal would name a position the user
          // cannot see.
          expect(find.text('1'), findsNothing);
          expect(semantics.value, equals(en.videoClipSemanticValueSelected));
        },
      );
    });

    group('interactions', () {
      testWidgets('toggles selection when clip is tapped', (tester) async {
        when(() => mockBloc.state).thenReturn(
          ClipsLibraryState(status: ClipsLibraryStatus.loaded, clips: [clip1]),
        );

        await tester.pumpWidget(buildWidget());

        await tester.tap(find.byType(VideoClipThumbnailCard).first);

        verify(
          () => mockBloc.add(ClipsLibraryToggleSelection(clip1)),
        ).called(1);
      });

      testWidgets(
        'long-press → trash closes preview and soft-deletes the clip',
        (tester) async {
          DivineVideoPlayerController.resetIdCounterForTesting();
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(
            const MethodChannel('divine_video_player'),
            (call) async {
              if (call.method == 'create') {
                return <String, Object?>{'textureId': 1};
              }
              return null;
            },
          );
          messenger.setMockMethodCallHandler(
            const MethodChannel('divine_video_player/player_0'),
            (call) async => null,
          );
          addTearDown(() {
            messenger
              ..setMockMethodCallHandler(
                const MethodChannel('divine_video_player'),
                null,
              )
              ..setMockMethodCallHandler(
                const MethodChannel('divine_video_player/player_0'),
                null,
              );
          });

          final mockGoRouter = MockGoRouter();
          when(() => mockGoRouter.pop<Object?>(any())).thenReturn(null);
          when(mockGoRouter.canPop).thenReturn(true);

          when(() => mockBloc.state).thenReturn(
            ClipsLibraryState(
              status: ClipsLibraryStatus.loaded,
              clips: [clip1],
            ),
          );

          await tester.pumpWidget(
            ProviderScope(
              child: MockGoRouterProvider(
                goRouter: mockGoRouter,
                child: buildWidget(),
              ),
            ),
          );

          // Long-press opens the VideoClipPreview overlay; tapping
          // (default selectionEnabled=true) would only toggle selection.
          // pumpAndSettle never settles here because the preview shows a
          // CircularProgressIndicator while the player initializes.
          await tester.longPress(find.byType(VideoClipThumbnailCard).first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(VideoClipPreview), findsOneWidget);

          await tester.tap(
            find.byWidgetPredicate(
              (w) => w is DivineIcon && w.icon == DivineIconName.trash,
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text(en.libraryDeleteClipTitle), findsOneWidget);

          final confirmButton = find.text(en.libraryDeleteConfirm).last;
          await tester.ensureVisible(confirmButton);
          await tester.tap(confirmButton, warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(VideoClipPreview), findsNothing);
          verify(() => mockBloc.add(ClipsLibraryDeleteClip(clip1))).called(1);
        },
      );
    });
  });

  group(ClipSelectionFooter, () {
    late _MockClipsLibraryBloc mockBloc;

    setUp(() {
      mockBloc = _MockClipsLibraryBloc();
    });

    Widget buildWidget({VoidCallback? onCreate}) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(
          body: BlocProvider<ClipsLibraryBloc>.value(
            value: mockBloc,
            child: ClipSelectionFooter(onCreate: onCreate ?? () {}),
          ),
        ),
      );
    }

    testWidgets('calls onCreate when the select button is tapped', (
      tester,
    ) async {
      when(() => mockBloc.state).thenReturn(
        const ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          selectedClipIds: {'clip1'},
        ),
      );

      var created = false;
      await tester.pumpWidget(buildWidget(onCreate: () => created = true));

      await tester.tap(find.text(en.librarySelect));

      expect(created, isTrue);
    });

    testWidgets('disables the select button without a selection', (
      tester,
    ) async {
      when(() => mockBloc.state).thenReturn(
        const ClipsLibraryState(status: ClipsLibraryStatus.loaded),
      );

      var created = false;
      await tester.pumpWidget(buildWidget(onCreate: () => created = true));

      await tester.tap(find.text(en.librarySelect));

      expect(created, isFalse);
    });
  });
}
