// ABOUTME: Widget tests for MessageRequestsView.
// ABOUTME: Verifies list rendering (loading, empty, with requests), navigation
// ABOUTME: to request preview, and app bar title.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation_list/conversation_list_bloc.dart';
import 'package:openvine/blocs/dm/message_requests/message_request_actions_cubit.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/inbox/message_requests/message_requests_view.dart';
import 'package:openvine/screens/inbox/message_requests/request_preview_page.dart';
import 'package:openvine/screens/inbox/message_requests/widgets/request_tile.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;

import '../../../helpers/go_router.dart';
import '../../../helpers/test_provider_overrides.dart';

class _MockConversationListBloc
    extends MockBloc<ConversationListEvent, ConversationListState>
    implements ConversationListBloc {}

class _MockMessageRequestActionsCubit
    extends MockCubit<MessageRequestActionsState>
    implements MessageRequestActionsCubit {}

class _MockAuthService extends MockAuthService {
  _MockAuthService(this._pubkey) {
    when(() => authState).thenReturn(AuthState.authenticated);
    when(
      () => authStateStream,
    ).thenAnswer((_) => const Stream<AuthState>.empty());
  }
  final String _pubkey;

  @override
  String? get currentPublicKeyHex => _pubkey;
}

void main() {
  const currentPubkey =
      'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd';
  const otherPubkey =
      '1122334411223344112233441122334411223344112233441122334411223344';

  final now = DateTime.now();
  final nowUnix = now.millisecondsSinceEpoch ~/ 1000;

  group(MessageRequestsView, () {
    late _MockConversationListBloc mockBloc;
    late _MockMessageRequestActionsCubit mockActionsCubit;
    late _MockAuthService mockAuthService;
    late MockGoRouter mockGoRouter;

    setUp(() {
      mockBloc = _MockConversationListBloc();
      mockActionsCubit = _MockMessageRequestActionsCubit();
      mockAuthService = _MockAuthService(currentPubkey);
      mockGoRouter = MockGoRouter();

      when(
        () => mockActionsCubit.state,
      ).thenReturn(const MessageRequestActionsState());
    });

    Widget buildSubject({ConversationListState? state}) {
      final blocState = state ?? const ConversationListState();
      whenListen(
        mockBloc,
        Stream<ConversationListState>.value(blocState),
        initialState: blocState,
      );

      return testMaterialApp(
        mockAuthService: mockAuthService,
        additionalOverrides: [goRouterProvider.overrideWithValue(mockGoRouter)],
        home: MockGoRouterProvider(
          goRouter: mockGoRouter,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<ConversationListBloc>.value(value: mockBloc),
              BlocProvider<MessageRequestActionsCubit>.value(
                value: mockActionsCubit,
              ),
            ],
            child: const MessageRequestsView(),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders app bar with "Message requests" title', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.text('Message requests'), findsOneWidget);
      });

      testWidgets('renders $CircularProgressIndicator when status is initial', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('renders "No message requests" when loaded with empty list', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            state: const ConversationListState(
              status: ConversationListStatus.loaded,
            ),
          ),
        );
        await tester.pump();

        expect(find.text('No message requests'), findsOneWidget);
      });

      testWidgets('renders $RequestTile when loaded with requests', (
        tester,
      ) async {
        final testProfile = UserProfile(
          pubkey: otherPubkey,
          displayName: 'RequestUser',
          rawData: const {},
          createdAt: now,
          eventId:
              'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        );

        final request = DmConversation(
          id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
          participantPubkeys: const [currentPubkey, otherPubkey],
          isGroup: false,
          createdAt: nowUnix,
          lastMessageContent: 'Hey',
          lastMessageTimestamp: nowUnix,
        );

        final state = ConversationListState(
          status: ConversationListStatus.loaded,
          requestConversations: [request],
        );

        whenListen(
          mockBloc,
          Stream<ConversationListState>.value(state),
          initialState: state,
        );

        await tester.pumpWidget(
          testMaterialApp(
            mockAuthService: mockAuthService,
            additionalOverrides: [
              goRouterProvider.overrideWithValue(mockGoRouter),
              userProfileReactiveProvider(
                otherPubkey,
              ).overrideWith((ref) => Stream.value(testProfile)),
            ],
            home: MockGoRouterProvider(
              goRouter: mockGoRouter,
              child: MultiBlocProvider(
                providers: [
                  BlocProvider<ConversationListBloc>.value(value: mockBloc),
                  BlocProvider<MessageRequestActionsCubit>.value(
                    value: mockActionsCubit,
                  ),
                ],
                child: const MessageRequestsView(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RequestTile), findsOneWidget);
      });
    });

    group('navigation', () {
      testWidgets('calls pushNamed to request preview when request is tapped', (
        tester,
      ) async {
        final testProfile = UserProfile(
          pubkey: otherPubkey,
          displayName: 'RequestUser',
          rawData: const {},
          createdAt: now,
          eventId:
              'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        );

        final request = DmConversation(
          id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
          participantPubkeys: const [currentPubkey, otherPubkey],
          isGroup: false,
          createdAt: nowUnix,
          lastMessageContent: 'Hey',
          lastMessageTimestamp: nowUnix,
        );

        whenListen(
          mockBloc,
          Stream<ConversationListState>.value(
            ConversationListState(
              status: ConversationListStatus.loaded,
              requestConversations: [request],
            ),
          ),
          initialState: ConversationListState(
            status: ConversationListStatus.loaded,
            requestConversations: [request],
          ),
        );

        when(
          () => mockGoRouter.pushNamed(
            any(),
            pathParameters: any(named: 'pathParameters'),
            extra: any(named: 'extra'),
          ),
        ).thenAnswer((_) async => null);

        await tester.pumpWidget(
          testMaterialApp(
            mockAuthService: mockAuthService,
            additionalOverrides: [
              goRouterProvider.overrideWithValue(mockGoRouter),
              userProfileReactiveProvider(
                otherPubkey,
              ).overrideWith((ref) => Stream.value(testProfile)),
            ],
            home: MockGoRouterProvider(
              goRouter: mockGoRouter,
              child: MultiBlocProvider(
                providers: [
                  BlocProvider<ConversationListBloc>.value(value: mockBloc),
                  BlocProvider<MessageRequestActionsCubit>.value(
                    value: mockActionsCubit,
                  ),
                ],
                child: const MessageRequestsView(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(RequestTile));
        await tester.pump();

        verify(
          () => mockGoRouter.pushNamed(
            RequestPreviewPage.routeName,
            pathParameters: {
              'id':
                  'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
            },
            extra: [otherPubkey],
          ),
        ).called(1);
      });
    });
  });
}
