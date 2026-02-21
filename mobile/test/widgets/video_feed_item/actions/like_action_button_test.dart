import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/widgets/video_feed_item/actions/like_action_button.dart';

class _MockVideoInteractionsBloc
    extends MockBloc<VideoInteractionsEvent, VideoInteractionsState>
    implements VideoInteractionsBloc {}

void main() {
  const testPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  late _MockVideoInteractionsBloc mockBloc;
  late VideoEvent testVideo;

  setUp(() {
    mockBloc = _MockVideoInteractionsBloc();
    testVideo = VideoEvent(
      id: 'test-video-id-0123456789abcdef0123456789abcdef0123456789abcdef01',
      pubkey: testPubkey,
      createdAt: 1700000000,
      content: '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
      originalLikes: 100,
    );
  });

  Widget buildSubject({VideoEvent? video}) {
    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<VideoInteractionsBloc>.value(
          value: mockBloc,
          child: LikeActionButton(video: video ?? testVideo),
        ),
      ),
    );
  }

  group(LikeActionButton, () {
    testWidgets(
      'displays state.likeCount when loaded, not video.originalLikes',
      (tester) async {
        when(() => mockBloc.state).thenReturn(
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            likeCount: 50,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('50'), findsOneWidget);
        expect(find.text('100'), findsNothing);
        expect(find.text('150'), findsNothing);
      },
    );

    testWidgets('falls back to video.totalLikes before BLoC has loaded', (
      tester,
    ) async {
      when(() => mockBloc.state).thenReturn(const VideoInteractionsState());

      await tester.pumpWidget(buildSubject());

      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('falls back to combined totalLikes when video has both '
        'originalLikes and nostrLikeCount', (tester) async {
      when(() => mockBloc.state).thenReturn(const VideoInteractionsState());

      final vineImportVideo = VideoEvent(
        id: 'vine-video-id-0123456789abcdef0123456789abcdef0123456789abcdef01',
        pubkey: testPubkey,
        createdAt: 1700000000,
        content: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
        originalLikes: 500,
        nostrLikeCount: 3,
      );

      await tester.pumpWidget(buildSubject(video: vineImportVideo));

      // totalLikes = 500 + 3 = 503
      expect(find.text('503'), findsOneWidget);
      expect(find.text('500'), findsNothing);
    });

    testWidgets('hides count when both sources are 0', (tester) async {
      when(() => mockBloc.state).thenReturn(
        const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          likeCount: 0,
        ),
      );

      await tester.pumpWidget(buildSubject());

      expect(find.text('0'), findsNothing);
    });
  });
}
