// ABOUTME: Inbox page that provides BLoC dependencies for the inbox view.
// ABOUTME: Sets up ConversationListBloc, DmUnreadCountCubit, and
// ABOUTME: MyFollowingBloc from Riverpod providers. The DmRepository
// ABOUTME: gift-wrap subscription is auth-session-scoped via
// ABOUTME: dmRepositoryProvider, not driven by this screen's lifecycle.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/dm/conversation_actions/conversation_actions_cubit.dart';
import 'package:openvine/blocs/dm/conversation_list/conversation_list_bloc.dart';
import 'package:openvine/blocs/dm/conversation_mute/conversation_mute_cubit.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/inbox/inbox_view.dart';

/// Inbox page (DM conversation list + notifications).
///
/// Provides [ConversationListBloc], [DmUnreadCountCubit], and
/// [MyFollowingBloc] to the widget tree. The gift-wrap subscription that
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => ConversationListBloc(
              dmRepository: dmRepository,
              followRepository: followRepository,
              contentBlocklistRepository: blocklistRepository,
            )..add(const ConversationListStarted()),
          ),
          BlocProvider(
            create: (_) => DmUnreadCountCubit(dmRepository: dmRepository),
          ),
          BlocProvider(
            create: (_) => MyFollowingBloc(
              followRepository: followRepository,
              contentBlocklistRepository: blocklistRepository,
            )..add(const MyFollowingListLoadRequested()),
          ),
          BlocProvider(create: (_) => ConversationMuteCubit(prefs: prefs)),
          BlocProvider(
            create: (_) => ConversationActionsCubit(
              contentReportingService: reportingService,
              contentBlocklistRepository: blocklistRepository,
              dmRepository: dmRepository,
              currentUserPubkey: currentUserPubkey,
            ),
          ),
        ],
        child: const InboxView(),
      ),
    );
  }
}
