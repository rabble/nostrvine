@Tags(['skip_very_good_optimization'])
import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_saved_videos/profile_saved_videos_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/profile/profile_saved_grid.dart';

import '../../helpers/go_router.dart';

class _MockProfileSavedVideosBloc
    extends MockBloc<ProfileSavedVideosEvent, ProfileSavedVideosState>
    implements ProfileSavedVideosBloc {}

List<VideoEvent> _createTestVideos({int count = 2}) {
  final now = DateTime.now();
  final nowUnix = now.millisecondsSinceEpoch ~/ 1000;
  return List.generate(
    count,
    (i) => VideoEvent(
      id: 'video-$i',
      pubkey: 'aaa${'a' * 60}',
      createdAt: nowUnix - i,
      content: 'Video $i',
      timestamp: now.subtract(Duration(seconds: i)),
      title: 'Video $i',
      videoUrl: 'https://example.com/v$i.mp4',
      thumbnailUrl: 'https://example.com/thumb$i.jpg',
    ),
  );
}

void main() {
  group(ProfileSavedGrid, () {
    late _MockProfileSavedVideosBloc mockBloc;
    late MockGoRouter mockGoRouter;

    setUp(() {
      mockBloc = _MockProfileSavedVideosBloc();
      mockGoRouter = MockGoRouter();
      when(
        () => mockGoRouter.push<Object?>(any(), extra: any(named: 'extra')),
      ).thenAnswer((_) async => null);
    });

    Widget buildSubject({MockGoRouter? goRouter}) {
      final app = MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(
          body: BlocProvider<ProfileSavedVideosBloc>.value(
            value: mockBloc,
            child: const ProfileSavedGrid(),
          ),
        ),
      );
      if (goRouter != null) {
        return MockGoRouterProvider(goRouter: goRouter, child: app);
      }
      return app;
    }

    group('renders', () {
      testWidgets('loading indicator when status is initial', (tester) async {
        when(() => mockBloc.state).thenReturn(const ProfileSavedVideosState());

        await tester.pumpWidget(buildSubject());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('loading indicator when status is syncing', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileSavedVideosState(
            status: ProfileSavedVideosStatus.syncing,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('loading indicator when status is loading', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileSavedVideosState(
            status: ProfileSavedVideosStatus.loading,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('error message when status is failure', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileSavedVideosState(
            status: ProfileSavedVideosStatus.failure,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('Error loading saved videos'), findsOneWidget);
      });

      testWidgets('empty state when no saved videos', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileSavedVideosState(
            status: ProfileSavedVideosStatus.success,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('Nothing saved yet'), findsOneWidget);
        expect(
          find.text(
            "Bookmark videos from the share sheet and they'll show up here.",
          ),
          findsOneWidget,
        );
      });

      testWidgets('grid of saved videos when videos exist', (tester) async {
        final videos = _createTestVideos(count: 3);
        when(() => mockBloc.state).thenReturn(
          ProfileSavedVideosState(
            status: ProfileSavedVideosStatus.success,
            videos: videos,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(SliverGrid), findsOneWidget);
      });

      testWidgets('bottom loading indicator when loading more', (tester) async {
        final videos = _createTestVideos(count: 3);
        when(() => mockBloc.state).thenReturn(
          ProfileSavedVideosState(
            status: ProfileSavedVideosStatus.success,
            videos: videos,
            isLoadingMore: true,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('dispatches load more when scrolled near bottom', (
        tester,
      ) async {
        final manyVideos = _createTestVideos(count: 30);
        when(() => mockBloc.state).thenReturn(
          ProfileSavedVideosState(
            status: ProfileSavedVideosStatus.success,
            videos: manyVideos,
          ),
        );

        await tester.pumpWidget(buildSubject());

        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -5000),
        );
        await tester.pumpAndSettle();

        verify(
          () => mockBloc.add(const ProfileSavedVideosLoadMoreRequested()),
        ).called(greaterThanOrEqualTo(1));
      });

      testWidgets('navigates to fullscreen feed when tile is tapped', (
        tester,
      ) async {
        final videos = _createTestVideos(count: 3);
        when(() => mockBloc.state).thenReturn(
          ProfileSavedVideosState(
            status: ProfileSavedVideosStatus.success,
            videos: videos,
          ),
        );

        await tester.pumpWidget(buildSubject(goRouter: mockGoRouter));

        await tester.tap(find.byType(GestureDetector).first);
        await tester.pumpAndSettle();

        verify(
          () => mockGoRouter.push<Object?>(any(), extra: any(named: 'extra')),
        ).called(1);
      });
    });

    group('scroll coordination with NestedScrollView', () {
      testWidgets(
        'uses PrimaryScrollController from NestedScrollView ancestor',
        (tester) async {
          final videos = _createTestVideos(count: 6);
          when(() => mockBloc.state).thenReturn(
            ProfileSavedVideosState(
              status: ProfileSavedVideosStatus.success,
              videos: videos,
            ),
          );

          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: VineTheme.theme,
              home: Scaffold(
                body: NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) => [
                    const SliverToBoxAdapter(child: SizedBox(height: 200)),
                  ],
                  body: BlocProvider<ProfileSavedVideosBloc>.value(
                    value: mockBloc,
                    child: const ProfileSavedGrid(),
                  ),
                ),
              ),
            ),
          );

          expect(find.byType(ProfileSavedGrid), findsOneWidget);
          expect(find.byType(SliverGrid), findsOneWidget);

          final customScrollView = tester.widget<CustomScrollView>(
            find.byType(CustomScrollView).last,
          );
          expect(customScrollView.controller, isNull);
        },
      );
    });
  });
}
