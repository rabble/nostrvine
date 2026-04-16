import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/comments/comments_bloc.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/screens/comments/widgets/comment_item.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/clickable_hashtag_text.dart';

import '../../builders/comment_builder.dart';

class _FakeNostrClient implements NostrClient {
  const _FakeNostrClient();

  @override
  String get publicKey => '';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockCommentsBloc extends MockBloc<CommentsEvent, CommentsState>
    implements CommentsBloc {}

const _testHexPubkey =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _testRootEventId =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _testRootAuthorPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  setUpAll(() {
    registerFallbackValue(const CommentsLoadRequested());
  });

  Widget buildTestWidget(
    String content,
    _MockCommentsBloc mockCommentsBloc,
  ) {
    final comment = CommentBuilder()
        .withAuthorPubkey(_testHexPubkey)
        .withRootEventId(_testRootEventId)
        .withRootAuthorPubkey(_testRootAuthorPubkey)
        .withContent(content)
        .build();

    return ProviderScope(
      overrides: [
        nostrServiceProvider.overrideWithValue(const _FakeNostrClient()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: BlocProvider<CommentsBloc>.value(
            value: mockCommentsBloc,
            child: SingleChildScrollView(child: CommentItem(comment: comment)),
          ),
        ),
      ),
    );
  }

  Text contentText(WidgetTester tester) {
    return tester.widget<Text>(
      find.descendant(
        of: find.byType(ClickableHashtagText),
        matching: find.byType(Text),
      ),
    );
  }

  testWidgets('renders bare npub mentions as interactive profile links', (
    tester,
  ) async {
    final mockCommentsBloc = _MockCommentsBloc();
    when(() => mockCommentsBloc.state).thenReturn(
      const CommentsState(
        rootEventId: _testRootEventId,
        rootAuthorPubkey: _testRootAuthorPubkey,
        status: CommentsStatus.success,
      ),
    );
    final npub = NostrKeyUtils.encodePubKey(_testHexPubkey);

    await tester.pumpWidget(
      buildTestWidget('My account is $npub', mockCommentsBloc),
    );
    await tester.pump();

    expect(find.byType(ClickableHashtagText), findsOneWidget);
    expect(find.textContaining('@npub1'), findsOneWidget);
  });

  testWidgets('renders comment urls with tappable spans', (tester) async {
    final mockCommentsBloc = _MockCommentsBloc();
    when(() => mockCommentsBloc.state).thenReturn(
      const CommentsState(
        rootEventId: _testRootEventId,
        rootAuthorPubkey: _testRootAuthorPubkey,
        status: CommentsStatus.success,
      ),
    );
    await tester.pumpWidget(
      buildTestWidget(
        'checkout https://divine.video/leaderboard',
        mockCommentsBloc,
      ),
    );
    await tester.pump();

    expect(find.byType(ClickableHashtagText), findsOneWidget);

    final text = contentText(tester);
    final textSpan = text.textSpan! as TextSpan;
    final spans = textSpan.children!.cast<TextSpan>();
    final linkSpan = spans.firstWhere(
      (span) => span.text == 'https://divine.video/leaderboard',
    );

    expect(linkSpan.recognizer, isA<TapGestureRecognizer>());
  });
}
