// ABOUTME: Inbox page that provides BLoC dependencies for the inbox view.
// ABOUTME: Sets up ConversationListBloc, DmUnreadCountCubit,
// ABOUTME: MyFollowingBloc from Riverpod providers, and drives the
// ABOUTME: DmRepository gift-wrap subscription lifecycle — the
// ABOUTME: subscription is only open while the inbox is visible.

import 'dart:async';

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
import 'package:openvine/repositories/dm_repository.dart';
import 'package:openvine/screens/inbox/inbox_view.dart';

/// Inbox page (DM conversation list + notifications).
///
/// Provides [ConversationListBloc], [DmUnreadCountCubit], and
/// [MyFollowingBloc] to the widget tree. Drives the [DmRepository]
/// gift-wrap subscription lifecycle so DM processing only runs while
/// the inbox is on screen — see
/// docs/plans/2026-04-05-dm-scaling-fix-design.md.
class InboxPage extends ConsumerStatefulWidget {
  const InboxPage({super.key});

  /// Route name for this screen.
  static const routeName = 'inbox';

  /// Path for this route.
  static const path = '/inbox';

  @override
  ConsumerState<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends ConsumerState<InboxPage> {
  late final DmRepository _dmRepository;

  @override
  void initState() {
    super.initState();
    _dmRepository = ref.read(dmRepositoryProvider);
    // Open the gift-wrap subscription only while the inbox is visible.
    // This keeps cold start and background time off the DM decrypt path.
    _dmRepository.startListening();
  }

  @override
  void dispose() {
    // Tear down the subscription when the inbox closes so the main
    // isolate stops processing gift wraps in the background.
    unawaited(_dmRepository.stopListening());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dmRepository = _dmRepository;
    final followRepository = ref.watch(followRepositoryProvider);
    final blocklistService = ref.watch(contentBlocklistServiceProvider);
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
              contentBlocklistService: blocklistService,
            )..add(const ConversationListStarted()),
          ),
          BlocProvider(
            create: (_) => DmUnreadCountCubit(dmRepository: dmRepository),
          ),
          BlocProvider(
            create: (_) => MyFollowingBloc(
              followRepository: followRepository,
              contentBlocklistService: blocklistService,
            )..add(const MyFollowingListLoadRequested()),
          ),
          BlocProvider(
            create: (_) => ConversationMuteCubit(prefs: prefs),
          ),
          BlocProvider(
            create: (_) => ConversationActionsCubit(
              contentReportingService: reportingService,
              contentBlocklistService: blocklistService,
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
