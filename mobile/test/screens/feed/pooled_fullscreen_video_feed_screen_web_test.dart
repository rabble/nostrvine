import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/fullscreen_feed/fullscreen_feed_bloc.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:openvine/widgets/web_video_feed.dart';

import '../../helpers/test_provider_overrides.dart';
import '../../test_data/video_test_data.dart';

class MockFullscreenFeedBloc
    extends MockBloc<FullscreenFeedEvent, FullscreenFeedState>
    implements FullscreenFeedBloc {}

const _testVideoId =
    'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
const _testPubkey =
    'd4e5f6789012345678901234567890abcdef123456789012345678901234a1b2c3';

void main() {
  group('PooledFullscreenVideoFeedScreen web', () {
    late MockFullscreenFeedBloc mockBloc;
    late MockAuthService mockAuthService;
    late MockProfileRepository mockProfileRepository;
    late StreamController<FullscreenFeedState> stateController;

    setUpAll(() {
      registerFallbackValue(const FullscreenFeedStarted());
    });

    setUp(() {
      mockBloc = MockFullscreenFeedBloc();
      mockAuthService = createMockAuthService();
      mockProfileRepository = createMockProfileRepository();
      stateController = StreamController<FullscreenFeedState>.broadcast();

      when(() => mockBloc.stream).thenAnswer((_) => stateController.stream);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(null);
    });

    tearDown(() async {
      await stateController.close();
    });

    testWidgets(
      'renders social controls overlay for web video feed',
      (tester) async {
        final video = createTestVideoEvent(
          id: _testVideoId,
          pubkey: _testPubkey,
        );
        final state = FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [video],
        );
        when(() => mockBloc.state).thenReturn(state);

        await tester.pumpWidget(
          testMaterialApp(
            mockAuthService: mockAuthService,
            mockProfileRepository: mockProfileRepository,
            home: BlocProvider<FullscreenFeedBloc>.value(
              value: mockBloc,
              child: const FullscreenFeedContent(),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(WebVideoFeed), findsOneWidget);
        expect(find.byType(VideoOverlayActions), findsOneWidget);
      },
      skip: !kIsWeb,
    );
  });
}
