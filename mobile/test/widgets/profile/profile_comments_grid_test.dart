import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/profile_comments/profile_comments_bloc.dart';
import 'package:openvine/widgets/profile/profile_comments_grid.dart';

import '../../helpers/go_router.dart';

class _MockProfileCommentsBloc
    extends MockBloc<ProfileCommentsEvent, ProfileCommentsState>
    implements ProfileCommentsBloc {}

const _testAuthorPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _testRootEventId =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _testRootAuthorPubkey =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

Comment _createTextComment({
  required String id,
  int createdAtSeconds = 1700000000,
}) => Comment(
  id: id,
  content: 'Text comment $id',
  authorPubkey: _testAuthorPubkey,
  createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtSeconds * 1000),
  rootEventId: _testRootEventId,
  rootAuthorPubkey: _testRootAuthorPubkey,
);

Comment _createVideoComment({
  required String id,
  int createdAtSeconds = 1700000000,
}) => Comment(
  id: id,
  content: 'Video reply $id',
  authorPubkey: _testAuthorPubkey,
  createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtSeconds * 1000),
  rootEventId: _testRootEventId,
  rootAuthorPubkey: _testRootAuthorPubkey,
  videoUrl: 'https://example.com/$id.mp4',
  thumbnailUrl: 'https://example.com/$id-thumb.jpg',
);

void main() {
  group(ProfileCommentsGrid, () {
    late _MockProfileCommentsBloc mockBloc;
    late MockGoRouter mockGoRouter;

    setUp(() {
      mockBloc = _MockProfileCommentsBloc();
      mockGoRouter = MockGoRouter();
      when(
        () => mockGoRouter.push<Object?>(any()),
      ).thenAnswer((_) async => null);
    });

    Widget buildSubject({bool isOwnProfile = true, MockGoRouter? goRouter}) {
      final app = MaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(
          body: BlocProvider<ProfileCommentsBloc>.value(
            value: mockBloc,
            child: ProfileCommentsGrid(isOwnProfile: isOwnProfile),
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
        when(() => mockBloc.state).thenReturn(const ProfileCommentsState());

        await tester.pumpWidget(buildSubject());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('loading indicator when status is loading', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileCommentsState(status: ProfileCommentsStatus.loading),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('error message when status is failure', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileCommentsState(
            status: ProfileCommentsStatus.failure,
            error: 'Failed to load comments',
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('Error loading comments'), findsOneWidget);
      });

      testWidgets('own profile empty state when no comments', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileCommentsState(status: ProfileCommentsStatus.success),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('No Comments Yet'), findsOneWidget);
        expect(
          find.text('Your comments and replies will appear here'),
          findsOneWidget,
        );
      });

      testWidgets('other profile empty state when no comments', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const ProfileCommentsState(status: ProfileCommentsStatus.success),
        );

        await tester.pumpWidget(buildSubject(isOwnProfile: false));

        expect(find.text('No Comments'), findsOneWidget);
        expect(
          find.text('Their comments and replies will appear here'),
          findsOneWidget,
        );
      });

      testWidgets('video replies section when video comments exist', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          ProfileCommentsState(
            status: ProfileCommentsStatus.success,
            videoReplies: [
              _createVideoComment(id: 'v1'),
              _createVideoComment(id: 'v2'),
            ],
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('Video Replies'), findsOneWidget);
      });

      testWidgets('text comments section when text comments exist', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          ProfileCommentsState(
            status: ProfileCommentsStatus.success,
            textComments: [
              _createTextComment(id: 't1'),
              _createTextComment(id: 't2'),
            ],
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('Comments'), findsOneWidget);
        expect(find.text('Text comment t1'), findsOneWidget);
        expect(find.text('Text comment t2'), findsOneWidget);
      });

      testWidgets('both sections when both types exist', (tester) async {
        when(() => mockBloc.state).thenReturn(
          ProfileCommentsState(
            status: ProfileCommentsStatus.success,
            videoReplies: [_createVideoComment(id: 'v1')],
            textComments: [_createTextComment(id: 't1')],
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('Video Replies'), findsOneWidget);
        expect(find.text('Comments'), findsOneWidget);
      });

      testWidgets('bottom loading indicator when loading more', (tester) async {
        when(() => mockBloc.state).thenReturn(
          ProfileCommentsState(
            status: ProfileCommentsStatus.success,
            textComments: [_createTextComment(id: 't1')],
            isLoadingMore: true,
          ),
        );

        await tester.pumpWidget(buildSubject());

        // One for the bottom loading indicator
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('dispatches load more when scrolled near bottom', (
        tester,
      ) async {
        // Create enough items to make the list scrollable
        final manyComments = List.generate(
          20,
          (i) =>
              _createTextComment(id: 't$i', createdAtSeconds: 1700000000 - i),
        );

        when(() => mockBloc.state).thenReturn(
          ProfileCommentsState(
            status: ProfileCommentsStatus.success,
            textComments: manyComments,
          ),
        );

        await tester.pumpWidget(buildSubject());

        // Scroll to the bottom
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -5000),
        );
        await tester.pumpAndSettle();

        verify(
          () => mockBloc.add(const ProfileCommentsLoadMoreRequested()),
        ).called(greaterThanOrEqualTo(1));
      });

      testWidgets('navigates to video when text comment is tapped', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          ProfileCommentsState(
            status: ProfileCommentsStatus.success,
            textComments: [_createTextComment(id: 't1')],
          ),
        );

        await tester.pumpWidget(buildSubject(goRouter: mockGoRouter));

        await tester.tap(find.text('Text comment t1'));
        await tester.pumpAndSettle();

        verify(
          () => mockGoRouter.push<Object?>('/video/$_testRootEventId'),
        ).called(1);
      });

      testWidgets('navigates to video when video reply tile is tapped', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          ProfileCommentsState(
            status: ProfileCommentsStatus.success,
            videoReplies: [_createVideoComment(id: 'v1')],
          ),
        );

        await tester.pumpWidget(buildSubject(goRouter: mockGoRouter));

        await tester.tap(find.byType(GestureDetector).first);
        await tester.pumpAndSettle();

        verify(
          () => mockGoRouter.push<Object?>('/video/$_testRootEventId'),
        ).called(1);
      });
    });

    group('scroll coordination with NestedScrollView', () {
      testWidgets(
        'uses PrimaryScrollController from NestedScrollView ancestor',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            ProfileCommentsState(
              status: ProfileCommentsStatus.success,
              textComments: [
                _createTextComment(id: 't1'),
                _createTextComment(id: 't2'),
              ],
            ),
          );

          await tester.pumpWidget(
            MaterialApp(
              theme: VineTheme.theme,
              home: Scaffold(
                body: NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) => [
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 200),
                    ),
                  ],
                  body: BlocProvider<ProfileCommentsBloc>.value(
                    value: mockBloc,
                    child: const ProfileCommentsGrid(isOwnProfile: true),
                  ),
                ),
              ),
            ),
          );

          expect(find.byType(ProfileCommentsGrid), findsOneWidget);

          final customScrollView = tester.widget<CustomScrollView>(
            find.byType(CustomScrollView).last,
          );
          expect(customScrollView.controller, isNull);
        },
      );

      testWidgets(
        'header scrolls away when scrolling inside the grid',
        (tester) async {
          final manyComments = List.generate(
            30,
            (i) => _createTextComment(
              id: 't$i',
              createdAtSeconds: 1700000000 - i,
            ),
          );

          when(() => mockBloc.state).thenReturn(
            ProfileCommentsState(
              status: ProfileCommentsStatus.success,
              textComments: manyComments,
            ),
          );

          await tester.pumpWidget(
            MaterialApp(
              theme: VineTheme.theme,
              home: Scaffold(
                body: NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) => [
                    const SliverToBoxAdapter(
                      child: SizedBox(
                        height: 200,
                        child: ColoredBox(
                          color: Colors.red,
                          child: Center(child: Text('Header')),
                        ),
                      ),
                    ),
                  ],
                  body: BlocProvider<ProfileCommentsBloc>.value(
                    value: mockBloc,
                    child: const ProfileCommentsGrid(isOwnProfile: true),
                  ),
                ),
              ),
            ),
          );

          expect(find.text('Header'), findsOneWidget);

          await tester.drag(
            find.byType(CustomScrollView).last,
            const Offset(0, -300),
          );
          await tester.pumpAndSettle();

          // Header should have scrolled off screen (clipped from tree)
          expect(find.text('Header'), findsNothing);
        },
      );
    });
  });
}
