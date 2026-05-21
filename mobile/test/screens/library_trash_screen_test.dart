// ABOUTME: Tests for LibraryTrashScreen destructive actions and countdown copy
// ABOUTME: Verifies restore/hard-delete/empty-trash wiring and empty state UI

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/screens/library_trash_screen.dart';
import 'package:openvine/widgets/library/empty_library_state.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockClipsLibraryBloc
    extends MockBloc<ClipsLibraryEvent, ClipsLibraryState>
    implements ClipsLibraryBloc {}

void main() {
  final en = AppLocalizationsEn();

  group(LibraryTrashScreen, () {
    late _MockClipsLibraryBloc mockBloc;

    final trashedClip = DivineVideoClip(
      id: 'trashed-clip',
      video: EditorVideo.file('/tmp/trashed.mp4'),
      thumbnailPath: '/tmp/trashed.jpg',
      duration: const Duration(seconds: 5),
      recordedAt: DateTime(2026, 5),
      targetAspectRatio: .vertical,
      originalAspectRatio: 9 / 16,
      deletedAt: DateTime.now().subtract(const Duration(days: 28)),
    );

    setUp(() {
      mockBloc = _MockClipsLibraryBloc();
    });

    Widget buildWidget(ClipsLibraryState state) {
      when(() => mockBloc.state).thenReturn(state);
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: BlocProvider<ClipsLibraryBloc>.value(
          value: mockBloc,
          child: const LibraryTrashScreen(),
        ),
      );
    }

    testWidgets('loads trash, shows countdown, and restores a clip', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(
          ClipsLibraryState(
            status: ClipsLibraryStatus.trashLoaded,
            trashedClips: [trashedClip],
          ),
        ),
      );
      await tester.pump();

      verify(
        () => mockBloc.add(const ClipsLibraryTrashLoadRequested()),
      ).called(1);
      expect(find.text(en.libraryTrashAutoDeletes(2)), findsOneWidget);

      await tester.tap(find.text(en.libraryTrashRestoreLabel));
      await tester.pump();

      verify(
        () => mockBloc.add(const ClipsLibraryRestoreClips({'trashed-clip'})),
      ).called(1);
    });

    testWidgets('confirms hard delete and empty trash before dispatching', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(
          ClipsLibraryState(
            status: ClipsLibraryStatus.trashLoaded,
            trashedClips: [trashedClip],
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text(en.libraryTrashDeleteNowLabel));
      await tester.pumpAndSettle();

      expect(find.text(en.libraryTrashDeleteConfirmTitle), findsOneWidget);
      verifyNever(() => mockBloc.add(ClipsLibraryHardDeleteClip(trashedClip)));

      await tester.tap(find.text(en.libraryDeleteConfirm));
      await tester.pumpAndSettle();

      verify(
        () => mockBloc.add(ClipsLibraryHardDeleteClip(trashedClip)),
      ).called(1);

      await tester.tap(find.text(en.libraryTrashEmptyAllLabel));
      await tester.pumpAndSettle();

      expect(find.text(en.libraryTrashEmptyConfirmTitle), findsOneWidget);
      verifyNever(() => mockBloc.add(const ClipsLibraryEmptyTrash()));

      await tester.tap(find.text(en.libraryDeleteConfirm));
      await tester.pumpAndSettle();

      verify(() => mockBloc.add(const ClipsLibraryEmptyTrash())).called(1);
    });

    testWidgets('shows empty state and hides empty-trash action', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(
          const ClipsLibraryState(status: ClipsLibraryStatus.trashLoaded),
        ),
      );
      await tester.pump();

      expect(find.byType(EmptyLibraryState), findsOneWidget);
      expect(find.text(en.libraryTrashEmptyTitle), findsOneWidget);
      expect(find.text(en.libraryTrashEmptyAllLabel), findsNothing);
    });
  });
}
