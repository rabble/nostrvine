// ABOUTME: Widget tests for VideoEditorScaffold.
// ABOUTME: Verifies loading UI and FAB visibility rules.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/widgets/branded_loading_scaffold.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_scaffold.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(VideoEditorScaffold, () {
    late VideoEditorMainBloc mainBloc;
    late TimelineOverlayBloc overlayBloc;
    late ClipEditorBloc clipBloc;
    late VideoEditorFilterBloc filterBloc;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      mainBloc = VideoEditorMainBloc();
      overlayBloc = TimelineOverlayBloc();
      clipBloc = ClipEditorBloc(onFinalClipInvalidated: () {});
      filterBloc = VideoEditorFilterBloc();
    });

    tearDown(() async {
      await mainBloc.close();
      await overlayBloc.close();
      await clipBloc.close();
      await filterBloc.close();
    });

    Widget buildWidget({required bool isLoading}) {
      final editorKey = GlobalKey<ProImageEditorState>();
      final removeAreaKey = GlobalKey();

      return ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: VideoEditorScope(
          editorKey: editorKey,
          removeAreaKey: removeAreaKey,
          onOpenCamera: () {},
          onAddStickers: () {},
          onAdjustVolume: () {},
          onOpenClipsEditor: () {},
          onAddEditTextLayer: ([layer]) async => null,
          onOpenMusicLibrary: () {},
          originalClipAspectRatio: 9 / 16,
          bodySizeNotifier: ValueNotifier(const Size(400, 800)),
          fromLibrary: false,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<VideoEditorMainBloc>.value(value: mainBloc),
              BlocProvider<TimelineOverlayBloc>.value(value: overlayBloc),
              BlocProvider<ClipEditorBloc>.value(value: clipBloc),
              BlocProvider<VideoEditorFilterBloc>.value(value: filterBloc),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: VideoEditorScaffold(isLoading: isLoading),
            ),
          ),
        ),
      );
    }

    testWidgets('shows loading scaffold when isLoading is true', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget(isLoading: true));

      expect(find.byType(BrandedLoadingScaffold), findsOneWidget);
      expect(find.bySemanticsLabel('Add element'), findsOneWidget);
    });

    testWidgets('hides FAB while a sub-editor is open', (tester) async {
      mainBloc.add(const VideoEditorMainOpenSubEditor(SubEditorType.text));

      await tester.pumpWidget(buildWidget(isLoading: true));
      await tester.pump();

      expect(find.bySemanticsLabel('Add element'), findsNothing);
    });

    testWidgets('hides FAB when an overlay item is selected', (tester) async {
      overlayBloc.add(const TimelineOverlayItemSelected('overlay-1'));

      await tester.pumpWidget(buildWidget(isLoading: true));
      await tester.pump();

      expect(find.bySemanticsLabel('Add element'), findsNothing);
    });
  });
}
