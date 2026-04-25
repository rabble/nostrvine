// ABOUTME: Widget tests for RequestPreviewView.
// ABOUTME: Verifies rendering of profile info, action buttons, message count,
// ABOUTME: and navigation to profile view, conversation, and decline action.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/message_requests/message_request_actions_cubit.dart';
import 'package:openvine/blocs/dm/message_requests/request_preview_cubit.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/inbox/message_requests/request_preview_view.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/widgets/user_avatar.dart';

import '../../../helpers/go_router.dart';
import '../../../helpers/test_provider_overrides.dart';

class _MockMessageRequestActionsCubit
    extends MockCubit<MessageRequestActionsState>
    implements MessageRequestActionsCubit {}

class _MockRequestPreviewCubit extends MockCubit<RequestPreviewState>
    implements RequestPreviewCubit {}

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
  const conversationId =
      'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

  group(RequestPreviewView, () {
    late _MockMessageRequestActionsCubit mockActionsCubit;
    late _MockRequestPreviewCubit mockPreviewCubit;
    late _MockAuthService mockAuthService;
    late MockGoRouter mockGoRouter;
    late UserProfile testProfile;

    setUp(() {
      mockActionsCubit = _MockMessageRequestActionsCubit();
      mockPreviewCubit = _MockRequestPreviewCubit();
      mockAuthService = _MockAuthService(currentPubkey);
      mockGoRouter = MockGoRouter();

      when(
        () => mockActionsCubit.state,
      ).thenReturn(const MessageRequestActionsState());

      when(() => mockPreviewCubit.state).thenReturn(
        const RequestPreviewState(
          status: RequestPreviewStatus.loaded,
          messageCount: 3,
          participantPubkeys: [otherPubkey],
        ),
      );

      when(() => mockPreviewCubit.conversationId).thenReturn(conversationId);

      testProfile = UserProfile(
        pubkey: otherPubkey,
        displayName: 'TestUser',
        rawData: const {},
        createdAt: DateTime.now(),
        eventId:
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
      );
    });

    Widget buildSubject({RequestPreviewState? previewState}) {
      if (previewState != null) {
        when(() => mockPreviewCubit.state).thenReturn(previewState);
      }

      return testMaterialApp(
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
              BlocProvider<RequestPreviewCubit>.value(value: mockPreviewCubit),
              BlocProvider<MessageRequestActionsCubit>.value(
                value: mockActionsCubit,
              ),
            ],
            child: const RequestPreviewView(),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders app bar with display name as title', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text('TestUser'), findsWidgets);
      });

      testWidgets('renders $UserAvatar', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.byType(UserAvatar), findsOneWidget);
      });

      testWidgets('renders "View profile" button', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text('View profile'), findsOneWidget);
      });

      testWidgets('renders "View messages" button', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text('View messages'), findsOneWidget);
      });

      testWidgets('renders "Decline and remove" button', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text('Decline and remove'), findsOneWidget);
      });

      testWidgets('renders message count description', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.textContaining('3 messages'), findsOneWidget);
      });
    });

    group('navigation', () {
      testWidgets('navigates to profile view when "View profile" tapped', (
        tester,
      ) async {
        when(() => mockGoRouter.push(any())).thenAnswer((_) async => null);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.text('View profile'));
        await tester.pump();

        verify(
          () => mockGoRouter.push(any(that: startsWith('/profile-view/'))),
        ).called(1);
      });

      testWidgets('navigates to conversation when "View messages" tapped', (
        tester,
      ) async {
        when(
          () => mockGoRouter.pushReplacementNamed(
            any(),
            pathParameters: any(named: 'pathParameters'),
            extra: any(named: 'extra'),
          ),
        ).thenAnswer((_) async => null);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.text('View messages'));
        await tester.pump();

        verify(
          () => mockGoRouter.pushReplacementNamed(
            ConversationPage.routeName,
            pathParameters: {'id': conversationId},
            extra: [otherPubkey],
          ),
        ).called(1);
      });

      testWidgets(
        'calls declineRequest and pops when "Decline and remove" tapped',
        (tester) async {
          when(
            () => mockActionsCubit.declineRequest(any()),
          ).thenAnswer((_) async {});

          when(() => mockGoRouter.pop()).thenAnswer((_) async {});

          await tester.pumpWidget(buildSubject());
          await tester.pumpAndSettle();

          await tester.tap(find.text('Decline and remove'));
          await tester.pumpAndSettle();

          verify(
            () => mockActionsCubit.declineRequest(conversationId),
          ).called(1);

          verify(() => mockGoRouter.pop()).called(1);
        },
      );
    });
  });
}
