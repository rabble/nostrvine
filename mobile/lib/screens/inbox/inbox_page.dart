// ABOUTME: Inbox page that provides BLoC dependencies for the inbox view.
// ABOUTME: Sets up ConversationListBloc and MyFollowingBloc from Riverpod
// ABOUTME: providers. The DmRepository
// ABOUTME: gift-wrap subscription is auth-session-scoped via
// ABOUTME: dmRepositoryProvider, not driven by this screen's lifecycle.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/dm/conversation_actions/conversation_actions_cubit.dart';
import 'package:openvine/blocs/dm/conversation_list/conversation_list_bloc.dart';
import 'package:openvine/blocs/dm/conversation_mute/conversation_mute_cubit.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/blocs/notifications/badge/notification_badge_cubit.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/inbox/inbox_view.dart';

/// Inbox page (DM conversation list + notifications).
///
/// Provides [ConversationListBloc] and [MyFollowingBloc] to the widget
/// tree. The gift-wrap subscription that
/// powers DM ingestion is owned by `dmRepositoryProvider` for the entire
/// authenticated session — this screen does NOT start or stop it (#2931).
class InboxPage extends ConsumerWidget {
  const InboxPage({super.key});

  /// Route name for this screen.
  static const routeName = 'inbox';

  /// Path for this route.
  static const path = '/inbox';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dmRepository = ref.watch(dmRepositoryProvider);
    final followRepository = ref.watch(followRepositoryProvider);
    final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);
    final prefs = ref.watch(sharedPreferencesProvider);
    final reportingService = ref.watch(contentReportingServiceProvider).value;
    final currentUserPubkey =
        ref.watch(authServiceProvider).currentPublicKeyHex ?? '';
    final protectedMinorInboxGate = ref.watch(protectedMinorInboxGateProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: MultiBlocProvider(
        // `dmRepositoryProvider` is keepAlive but its body rebuilds a
        // brand-new DmRepository whenever the nostr session advances
        // (identityKnown -> nostrReady) or on account switch, and only the
        // *ready* instance ever gets setCredentials()/startListening(). A
        // BlocProvider factory runs once and captures whichever instance was
        // current at mount; if the inbox is opened during the not-ready
        // window the ConversationListBloc stays wired to that orphaned repo,
        // whose userPubkeyStream never fires — so the list spins forever
        // while DMs ingest on the new instance. Re-key on the captured
        // repositories' identities so the blocs are rebuilt bound to the
        // fresh instances on every flip. The tuple carries EVERY watched
        // value a create: factory below captures whose identity can change
        // at runtime (currentUserPubkey flips on account switch) — or the
        // cubits capturing them silently keep the stale instance. See
        // .claude/rules/state_management.md ("Bridging Riverpod-provided
        // dependencies into BlocProvider").
        //
        // reportingService is deliberately NOT in this tuple: it resolves
        // from null asynchronously shortly after every inbox mount, and
        // keying the whole MultiBlocProvider on it tore down and recreated
        // all five blocs (double ConversationListStarted + list reload)
        // right after every open. Only its consumer — the
        // ConversationActionsCubit provider below — is re-keyed on it.
        key: ValueKey((
          dmRepository,
          followRepository,
          blocklistRepository,
          currentUserPubkey,
          protectedMinorInboxGate,
        )),
        providers: [
          BlocProvider(
            create: (_) => ConversationListBloc(
              dmRepository: dmRepository,
              followRepository: followRepository,
              contentBlocklistRepository: blocklistRepository,
              protectedMinorInboxGate: protectedMinorInboxGate,
            )..add(const ConversationListStarted()),
          ),
          // Inbox-scope NotificationBadgeCubit feeds the segmented
          // toggle's notifications count. Mirrors the app-shell-scope
          // cubit provided in `main.dart` so `inbox_view.dart` can read
          // via `context.watch<NotificationBadgeCubit>()`.
          BlocProvider(
            create: (_) => NotificationBadgeCubit(
              repository: ref.read(notificationRepositoryProvider),
            ),
          ),
          BlocProvider(
            create: (_) => MyFollowingBloc(
              followRepository: followRepository,
              contentBlocklistRepository: blocklistRepository,
            )..add(const MyFollowingListLoadRequested()),
          ),
          BlocProvider(create: (_) => ConversationMuteCubit(prefs: prefs)),
          // Re-keyed on the async-resolving reportingService alone (last in
          // the list so the swap recreates the smallest possible subtree):
          // the actions cubit is action-only state and cheap to rebuild,
          // and without the key it would capture the pre-resolution null
          // forever, silently failing every report.
          BlocProvider(
            key: ValueKey(reportingService),
            create: (_) => ConversationActionsCubit(
              contentReportingService: reportingService,
              contentBlocklistRepository: blocklistRepository,
              dmRepository: dmRepository,
              currentUserPubkey: currentUserPubkey,
            ),
          ),
        ],
        child: const _InboxNotificationBadgeRepositorySync(child: InboxView()),
      ),
    );
  }
}

class _InboxNotificationBadgeRepositorySync extends ConsumerWidget {
  const _InboxNotificationBadgeRepositorySync({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(notificationRepositoryProvider, (_, repository) {
      context.read<NotificationBadgeCubit>().setRepository(repository);
    });
    return child;
  }
}
