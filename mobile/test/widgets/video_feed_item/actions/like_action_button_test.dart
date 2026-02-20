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
      'displays only state.likeCount, does not add video.originalLikes',
      (tester) async {
        when(() => mockBloc.state).thenReturn(
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            likeCount: 50,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('50'), findsOneWidget);
        expect(find.text('150'), findsNothing);
      },
    );

    testWidgets('hides count when likeCount is 0', (tester) async {
      when(() => mockBloc.state).thenReturn(
        const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          likeCount: 0,
        ),
      );

      await tester.pumpWidget(buildSubject());

      expect(find.text('0'), findsNothing);
    });

    testWidgets('hides count before BLoC has loaded', (tester) async {
      when(() => mockBloc.state).thenReturn(
        const VideoInteractionsState(
          status: VideoInteractionsStatus.initial,
          likeCount: 42,
        ),
      );

      await tester.pumpWidget(buildSubject());

      expect(find.text('42'), findsNothing);
    });

    testWidgets(
      'renders disabled state with no count when bloc is unavailable',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: LikeActionButton(video: testVideo)),
          ),
        );

        expect(find.byType(LikeActionButton), findsOneWidget);
        expect(find.text('100'), findsNothing);
      },
    );
  });
}
