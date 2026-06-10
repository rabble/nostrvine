import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/fullscreen_feed/fullscreen_feed_bloc.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/widgets/profile/profile_video_feed_view.dart';
import 'package:videos_repository/videos_repository.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _FakeSystemVolumeListener implements SystemVolumeListener {
  @override
  void hideSystemUI() {}

  @override
  StreamSubscription<double> listen(void Function(double volume) onData) {
    return const Stream<double>.empty().listen(onData);
  }
}

class _FakeVideoEvent extends Fake implements VideoEvent {}

const _profilePubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

VideoEvent _video(
  String id, {
  required int createdAt,
  String? stableId,
}) {
  return VideoEvent(
    id: id,
    pubkey: _profilePubkey,
    createdAt: createdAt,
    content: '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
    title: 'Video $id',
    videoUrl: 'https://example.com/$id.mp4',
    thumbnailUrl: 'https://example.com/$id.jpg',
    rawTags: stableId == null ? const {} : {'d': stableId},
  );
}

void main() {
  group(ProfileVideoFeedView, () {
    late _MockVideosRepository videosRepository;
    late _MockVideoEventService videoEventService;
    late _MockContentBlocklistRepository blocklistRepository;

    setUpAll(() {
      registerFallbackValue(_FakeVideoEvent());
    });

    setUp(() {
      videosRepository = _MockVideosRepository();
      videoEventService = _MockVideoEventService();
      blocklistRepository = _MockContentBlocklistRepository();

      when(
        () => videoEventService.authorVideos(any()),
      ).thenReturn(const <VideoEvent>[]);
      when(
        () => videoEventService.filterVideoList(any()),
      ).thenAnswer((i) => i.positionalArguments.first as List<VideoEvent>);
      when(
        () => videoEventService.isVideoEventLocallyDeleted(any()),
      ).thenReturn(false);
      when(
        () => videoEventService.subscribeToUserVideos(any()),
      ).thenAnswer((_) async {});
      when(() => videoEventService.addListener(any())).thenReturn(null);
      when(() => videoEventService.removeListener(any())).thenReturn(null);
      when(
        () => videoEventService.addVideoUpdateListener(any()),
      ).thenReturn(() {});
      when(
        () => videoEventService.addNewVideoListener(any()),
      ).thenReturn(() {});
      when(
        () => videoEventService.removedVideoIds,
      ).thenAnswer((_) => const Stream<String>.empty());
      when(
        () => blocklistRepository.shouldFilterFromFeeds(any()),
      ).thenReturn(false);
    });

    testWidgets(
      'seeds fullscreen with the tapped video before live profile videos load',
      (tester) async {
        const targetStableId = 'stable-target';
        final newest = _video('newest-video', createdAt: 3000);
        final target = _video(
          'target-video',
          createdAt: 2000,
          stableId: targetStableId,
        );
        final oldest = _video('oldest-video', createdAt: 1000);
        final seedVideos = [newest, target, oldest];

        when(
          () => videosRepository.getAuthorFeed(
            authorPubkey: any(named: 'authorPubkey'),
            offset: any(named: 'offset'),
            relaySeed: any(named: 'relaySeed'),
            skipCache: any(named: 'skipCache'),
          ),
        ).thenAnswer(
          (_) async => const AuthorFeedResult(
            authorPubkey: _profilePubkey,
            hasMore: false,
          ),
        );

        await tester.pumpWidget(
          testProviderScope(
            additionalOverrides: [
              videosRepositoryProvider.overrideWithValue(videosRepository),
              videoEventServiceProvider.overrideWithValue(videoEventService),
              contentBlocklistRepositoryProvider.overrideWithValue(
                blocklistRepository,
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: BlocProvider(
                create: (_) => VideoVolumeCubit(
                  sharedPreferences: createMockSharedPreferences(),
                  systemVolumeListener: _FakeSystemVolumeListener(),
                ),
                child: ProfileVideoFeedView(
                  npub: 'npub1profile',
                  userIdHex: _profilePubkey,
                  videoIndex: 0,
                  videos: seedVideos,
                  initialVideoId: target.id,
                  initialStableId: targetStableId,
                  contextTitleOverride: 'Profile',
                  onPageChanged: (_) {},
                ),
              ),
            ),
          ),
        );

        await tester.runAsync(() async {
          await Future<void>.delayed(Duration.zero);
        });

        final contentContext = tester.element(
          find.byType(FullscreenFeedContent),
        );
        final fullscreenBloc = contentContext.read<FullscreenFeedBloc>();

        expect(fullscreenBloc.state.status, FullscreenFeedStatus.ready);
        expect(fullscreenBloc.state.videos, seedVideos);
        expect(fullscreenBloc.state.currentIndex, 1);
        expect(fullscreenBloc.state.currentVideo?.id, target.id);
      },
    );
  });
}
