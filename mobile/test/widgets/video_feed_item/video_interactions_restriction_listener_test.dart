// ABOUTME: Verifies restricted interaction publishes open Account Status.
// ABOUTME: Pins the typed BLoC-state to UI-navigation boundary.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/settings/account_status_screen.dart';
import 'package:openvine/widgets/video_feed_item/video_interactions_restriction_listener.dart';

class _MockVideoInteractionsBloc
    extends MockBloc<VideoInteractionsEvent, VideoInteractionsState>
    implements VideoInteractionsBloc {}

void main() {
  group('navigation', () {
    testWidgets('opens Account Status with confirmed-publish evidence', (
      tester,
    ) async {
      final bloc = _MockVideoInteractionsBloc();
      const initial = VideoInteractionsState(
        status: VideoInteractionsStatus.success,
      );
      const restricted = VideoInteractionsState(
        status: VideoInteractionsStatus.accountRestricted,
        accountRestrictionRevision: 1,
      );
      whenListen(bloc, Stream.value(restricted), initialState: initial);

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                BlocProvider<VideoInteractionsBloc>.value(
                  value: bloc,
                  child: const VideoInteractionsRestrictionListener(
                    child: SizedBox(),
                  ),
                ),
          ),
          GoRoute(
            path: '/account-status',
            name: AccountStatusScreen.routeName,
            builder: (context, state) => Text('confirmed=${state.extra}'),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('confirmed=true'), findsOneWidget);
    });
  });
}
