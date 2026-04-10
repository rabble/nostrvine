import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/models/invite_models.dart';
import 'package:openvine/screens/settings/invites_screen.dart';

class _MockInviteStatusCubit extends MockCubit<InviteStatusState>
    implements InviteStatusCubit {}

void main() {
  group(InvitesView, () {
    late _MockInviteStatusCubit mockCubit;

    setUp(() {
      mockCubit = _MockInviteStatusCubit();
    });

    Widget buildSubject() {
      return MaterialApp(
        home: BlocProvider<InviteStatusCubit>.value(
          value: mockCubit,
          child: const Scaffold(body: InvitesView()),
        ),
      );
    }

    group('renders', () {
      testWidgets('loading indicator when loading', (tester) async {
        when(() => mockCubit.state).thenReturn(
          const InviteStatusState(status: InviteStatusLoadingStatus.loading),
        );
        await tester.pumpWidget(buildSubject());
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('empty state when no invites', (tester) async {
        when(() => mockCubit.state).thenReturn(
          const InviteStatusState(
            status: InviteStatusLoadingStatus.loaded,
            inviteStatus: InviteStatus(
              canInvite: false,
              remaining: 0,
              total: 0,
              codes: [],
            ),
          ),
        );
        await tester.pumpWidget(buildSubject());
        expect(find.text('No invites available right now'), findsOneWidget);
      });

      testWidgets('invite codes when available', (tester) async {
        when(() => mockCubit.state).thenReturn(
          const InviteStatusState(
            status: InviteStatusLoadingStatus.loaded,
            inviteStatus: InviteStatus(
              canInvite: true,
              remaining: 2,
              total: 3,
              codes: [
                InviteCode(code: 'AB23-EF7K', claimed: false),
                InviteCode(code: 'HN4P-QR56', claimed: false),
              ],
            ),
          ),
        );
        await tester.pumpWidget(buildSubject());
        expect(find.text('AB23-EF7K'), findsOneWidget);
        expect(find.text('HN4P-QR56'), findsOneWidget);
        expect(
          find.text('Share diVine with people you know'),
          findsOneWidget,
        );
      });

      testWidgets('claimed codes section', (tester) async {
        when(() => mockCubit.state).thenReturn(
          const InviteStatusState(
            status: InviteStatusLoadingStatus.loaded,
            inviteStatus: InviteStatus(
              canInvite: true,
              remaining: 0,
              total: 1,
              codes: [
                InviteCode(
                  code: 'CCCC-DDDD',
                  claimed: true,
                  claimedBy: 'abc123',
                ),
              ],
            ),
          ),
        );
        await tester.pumpWidget(buildSubject());
        expect(find.text('CCCC-DDDD'), findsOneWidget);
        expect(find.text('Claimed'), findsOneWidget);
        expect(find.text('Used invites'), findsOneWidget);
      });

      testWidgets('retry button on error', (tester) async {
        when(() => mockCubit.state).thenReturn(
          const InviteStatusState(status: InviteStatusLoadingStatus.error),
        );
        await tester.pumpWidget(buildSubject());
        expect(find.text('Retry'), findsOneWidget);
        expect(find.text('Could not load invites'), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('tapping retry calls load', (tester) async {
        when(() => mockCubit.state).thenReturn(
          const InviteStatusState(status: InviteStatusLoadingStatus.error),
        );
        when(() => mockCubit.load()).thenAnswer((_) async {});
        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text('Retry'));
        verify(() => mockCubit.load()).called(1);
      });
    });
  });
}
