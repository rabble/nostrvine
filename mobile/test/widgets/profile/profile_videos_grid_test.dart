import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';
import 'package:openvine/widgets/profile/profile_videos_grid.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockBackgroundPublishBloc
    extends MockBloc<BackgroundPublishEvent, BackgroundPublishState>
    implements BackgroundPublishBloc {}

const _ownPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _otherPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

DivineVideoDraft _createTestDraft({String title = 'Test Draft'}) {
  return DivineVideoDraft.create(
    clips: [
      DivineVideoClip(
        id: 'clip-1',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 3),
        recordedAt: DateTime(2025, 12, 13),
        targetAspectRatio: model.AspectRatio.vertical,
        originalAspectRatio: 9 / 16,
      ),
    ],
    title: title,
    description: 'Test description',
    hashtags: {},
    selectedApproach: 'camera',
  );
}

List<model.VideoEvent> _createTestVideos({
  required String pubkey,
  int count = 2,
}) {
  final now = DateTime.now();
  final nowUnix = now.millisecondsSinceEpoch ~/ 1000;
  return List.generate(
    count,
    (i) => model.VideoEvent(
      id: 'video-$i',
      pubkey: pubkey,
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
  group(ProfileVideosGrid, () {
    late _MockAuthService mockAuth;
    late _MockBackgroundPublishBloc mockBloc;

    setUp(() {
      mockAuth = _MockAuthService();
      mockBloc = _MockBackgroundPublishBloc();
      when(() => mockBloc.state).thenReturn(const BackgroundPublishState());
    });

    Widget buildSubject({
      required String userIdHex,
      List<model.VideoEvent> videos = const [],
      bool isLoading = false,
      String? errorMessage,
    }) {
      return testProviderScope(
        mockAuthService: mockAuth,
        child: BlocProvider<BackgroundPublishBloc>.value(
          value: mockBloc,
          child: MaterialApp(
            home: Scaffold(
              body: ProfileVideosGrid(
                videos: videos,
                userIdHex: userIdHex,
                isLoading: isLoading,
                errorMessage: errorMessage,
              ),
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('empty state when no videos and not own profile', (
        tester,
      ) async {
        when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);

        await tester.pumpWidget(buildSubject(userIdHex: _otherPubkey));

        expect(find.text('No Videos Yet'), findsOneWidget);
        expect(
          find.text("This user hasn't shared any videos yet"),
          findsOneWidget,
        );
      });

      testWidgets('empty state with own profile message when own profile', (
        tester,
      ) async {
        when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);

        await tester.pumpWidget(buildSubject(userIdHex: _ownPubkey));

        expect(find.text('No Videos Yet'), findsOneWidget);
        expect(
          find.text('Share your first video to see it here'),
          findsOneWidget,
        );
      });

      testWidgets('loading state when isLoading is true and no videos', (
        tester,
      ) async {
        when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);

        await tester.pumpWidget(
          buildSubject(userIdHex: _ownPubkey, isLoading: true),
        );

        expect(find.text('Loading videos...'), findsOneWidget);
      });

      testWidgets('error state when errorMessage is provided and no videos', (
        tester,
      ) async {
        when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);

        await tester.pumpWidget(
          buildSubject(
            userIdHex: _ownPubkey,
            errorMessage: 'Connection failed',
          ),
        );

        expect(find.text('Connection failed'), findsOneWidget);
      });

      testWidgets('video grid when videos are provided', (tester) async {
        when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);
        final videos = _createTestVideos(pubkey: _otherPubkey);

        await tester.pumpWidget(
          buildSubject(userIdHex: _otherPubkey, videos: videos),
        );

        expect(find.byType(SliverGrid), findsOneWidget);
      });
    });

    group('background uploads', () {
      testWidgets('shows uploading tile when viewing own profile '
          'with active background upload', (tester) async {
        when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);

        final draft = _createTestDraft();
        when(() => mockBloc.state).thenReturn(
          BackgroundPublishState(
            uploads: [
              BackgroundUpload(draft: draft, result: null, progress: 0.5),
            ],
          ),
        );

        final videos = _createTestVideos(pubkey: _ownPubkey);

        await tester.pumpWidget(
          buildSubject(userIdHex: _ownPubkey, videos: videos),
        );

        expect(find.byType(SliverGrid), findsOneWidget);
        expect(find.byType(PartialCircleSpinner), findsOneWidget);
      });

      testWidgets('does not show uploading tile when viewing '
          "another user's profile with active background upload", (
        tester,
      ) async {
        when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);

        final draft = _createTestDraft();
        when(() => mockBloc.state).thenReturn(
          BackgroundPublishState(
            uploads: [
              BackgroundUpload(draft: draft, result: null, progress: 0.5),
            ],
          ),
        );

        final videos = _createTestVideos(pubkey: _otherPubkey);

        await tester.pumpWidget(
          buildSubject(userIdHex: _otherPubkey, videos: videos),
        );

        expect(find.byType(SliverGrid), findsOneWidget);
        expect(find.byType(PartialCircleSpinner), findsNothing);
      });

      testWidgets('does not show completed uploads on own profile', (
        tester,
      ) async {
        when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);

        final draft = _createTestDraft();
        when(() => mockBloc.state).thenReturn(
          BackgroundPublishState(
            uploads: [
              BackgroundUpload(
                draft: draft,
                result: const PublishSuccess(),
                progress: 1,
              ),
            ],
          ),
        );

        final videos = _createTestVideos(pubkey: _ownPubkey);

        await tester.pumpWidget(
          buildSubject(userIdHex: _ownPubkey, videos: videos),
        );

        expect(find.byType(PartialCircleSpinner), findsNothing);
      });
    });

    group('de-duplication', () {
      testWidgets(
        'filters relay video matching active upload title '
        'on own profile',
        (tester) async {
          when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);

          // Active upload with title "Test Draft"
          final draft = _createTestDraft();
          when(() => mockBloc.state).thenReturn(
            BackgroundPublishState(
              uploads: [
                BackgroundUpload(
                  draft: draft,
                  result: null,
                  progress: 0.5,
                ),
              ],
            ),
          );

          // Relay delivers a video with the same title (recent timestamp)
          final now = DateTime.now();
          final nowUnix = now.millisecondsSinceEpoch ~/ 1000;
          final videos = [
            model.VideoEvent(
              id: 'relay-duplicate',
              pubkey: _ownPubkey,
              createdAt: nowUnix,
              content: '',
              timestamp: now,
              title: 'Test Draft',
              videoUrl: 'https://example.com/v0.mp4',
              thumbnailUrl: 'https://example.com/thumb0.jpg',
            ),
            model.VideoEvent(
              id: 'relay-other',
              pubkey: _ownPubkey,
              createdAt: nowUnix - 1,
              content: '',
              timestamp: now.subtract(const Duration(seconds: 1)),
              title: 'Other Video',
              videoUrl: 'https://example.com/v1.mp4',
              thumbnailUrl: 'https://example.com/thumb1.jpg',
            ),
          ];

          await tester.pumpWidget(
            buildSubject(userIdHex: _ownPubkey, videos: videos),
          );

          // 1 upload spinner + 1 published video tile (duplicate filtered)
          expect(find.byType(PartialCircleSpinner), findsOneWidget);
          expect(
            find.bySemanticsLabel(RegExp('Video thumbnail')),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'does not filter videos older than 5 minutes',
        (tester) async {
          when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);

          final draft = _createTestDraft(title: 'Old Video');
          when(() => mockBloc.state).thenReturn(
            BackgroundPublishState(
              uploads: [
                BackgroundUpload(
                  draft: draft,
                  result: null,
                  progress: 0.3,
                ),
              ],
            ),
          );

          // Video with matching title but created 10 minutes ago
          final now = DateTime.now();
          final oldTimestamp = now.subtract(const Duration(minutes: 10));
          final oldUnix = oldTimestamp.millisecondsSinceEpoch ~/ 1000;
          final videos = [
            model.VideoEvent(
              id: 'old-video',
              pubkey: _ownPubkey,
              createdAt: oldUnix,
              content: '',
              timestamp: oldTimestamp,
              title: 'Old Video',
              videoUrl: 'https://example.com/v0.mp4',
              thumbnailUrl: 'https://example.com/thumb0.jpg',
            ),
          ];

          await tester.pumpWidget(
            buildSubject(userIdHex: _ownPubkey, videos: videos),
          );

          // Upload spinner + the old video tile (not filtered)
          expect(find.byType(PartialCircleSpinner), findsOneWidget);
          expect(
            find.bySemanticsLabel(RegExp('Video thumbnail')),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'does not filter videos on another user profile',
        (tester) async {
          when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);

          // Active upload with matching title
          final draft = _createTestDraft();
          when(() => mockBloc.state).thenReturn(
            BackgroundPublishState(
              uploads: [
                BackgroundUpload(
                  draft: draft,
                  result: null,
                  progress: 0.5,
                ),
              ],
            ),
          );

          final now = DateTime.now();
          final nowUnix = now.millisecondsSinceEpoch ~/ 1000;
          final videos = [
            model.VideoEvent(
              id: 'other-user-video',
              pubkey: _otherPubkey,
              createdAt: nowUnix,
              content: '',
              timestamp: now,
              title: 'Test Draft',
              videoUrl: 'https://example.com/v0.mp4',
              thumbnailUrl: 'https://example.com/thumb0.jpg',
            ),
          ];

          await tester.pumpWidget(
            buildSubject(userIdHex: _otherPubkey, videos: videos),
          );

          // No spinner (other user) and video tile is present (no filtering)
          expect(find.byType(PartialCircleSpinner), findsNothing);
          expect(
            find.bySemanticsLabel(RegExp('Video thumbnail')),
            findsOneWidget,
          );
        },
      );
    });

    group('scroll coordination with NestedScrollView', () {
      testWidgets(
        'uses PrimaryScrollController from NestedScrollView ancestor',
        (tester) async {
          when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);
          final videos = _createTestVideos(pubkey: _ownPubkey, count: 6);

          await tester.pumpWidget(
            testProviderScope(
              mockAuthService: mockAuth,
              child: BlocProvider<BackgroundPublishBloc>.value(
                value: mockBloc,
                child: MaterialApp(
                  home: Scaffold(
                    body: NestedScrollView(
                      headerSliverBuilder: (context, innerBoxIsScrolled) => [
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 200),
                        ),
                      ],
                      body: ProfileVideosGrid(
                        videos: videos,
                        userIdHex: _ownPubkey,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(find.byType(ProfileVideosGrid), findsOneWidget);
          expect(find.byType(SliverGrid), findsOneWidget);

          final customScrollView = tester.widget<CustomScrollView>(
            find.byType(CustomScrollView).last,
          );
          expect(customScrollView.controller, isNull);
        },
      );

      testWidgets(
        'header scrolls away when scrolling inside the grid',
        (tester) async {
          when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);
          final videos = _createTestVideos(pubkey: _ownPubkey, count: 30);

          await tester.pumpWidget(
            testProviderScope(
              mockAuthService: mockAuth,
              child: BlocProvider<BackgroundPublishBloc>.value(
                value: mockBloc,
                child: MaterialApp(
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
                      body: ProfileVideosGrid(
                        videos: videos,
                        userIdHex: _ownPubkey,
                      ),
                    ),
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
