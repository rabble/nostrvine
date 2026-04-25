// ABOUTME: View for the message requests inbox list.
// ABOUTME: Shows all pending message requests with bulk actions via "..." menu.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation_list/conversation_list_bloc.dart';
import 'package:openvine/blocs/dm/message_requests/message_request_actions_cubit.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/inbox/message_requests/request_preview_page.dart';
import 'package:openvine/screens/inbox/message_requests/widgets/request_bulk_actions_sheet.dart';
import 'package:openvine/screens/inbox/message_requests/widgets/request_tile.dart';

/// View for the message requests inbox.
///
/// Displays a scrollable list of message request conversations with
/// an app bar containing a back button, title, and bulk actions menu.
class MessageRequestsView extends ConsumerWidget {
  const MessageRequestsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final currentPubkey = authService.currentPublicKeyHex ?? '';

    return Scaffold(
      backgroundColor: VineTheme.surfaceBackground,
      appBar: DiVineAppBar(
        title: 'Message requests',
        showBackButton: true,
        onBackPressed: context.pop,
        actions: [
          DiVineAppBarAction(
            icon: SvgIconSource(DivineIconName.dotsThree.assetPath),
            onPressed: () => _showBulkActions(context),
            semanticLabel: 'More options',
          ),
        ],
      ),
      body: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(VineTheme.bottomSheetBorderRadius),
        ),
        child: ColoredBox(
          color: VineTheme.surfaceContainerHigh,
          child: _RequestList(currentPubkey: currentPubkey),
        ),
      ),
    );
  }

  Future<void> _showBulkActions(BuildContext context) async {
    final result = await RequestBulkActionsSheet.show(context);
    if (result == null || !context.mounted) return;

    final requests = context
        .read<ConversationListBloc>()
        .state
        .requestConversations;
    final ids = requests.map((c) => c.id).toList();

    if (!context.mounted) return;
    final actionsCubit = context.read<MessageRequestActionsCubit>();

    switch (result) {
      case RequestBulkAction.markAllRead:
        await actionsCubit.markAllRequestsAsRead(ids);
      case RequestBulkAction.removeAll:
        await actionsCubit.removeAllRequests(ids);
        if (context.mounted) context.pop();
    }
  }
}

class _RequestList extends StatelessWidget {
  const _RequestList({required this.currentPubkey});

  final String currentPubkey;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConversationListBloc, ConversationListState>(
      buildWhen: (prev, curr) =>
          prev.requestConversations != curr.requestConversations ||
          prev.status != curr.status,
      builder: (context, state) {
        if (state.status == ConversationListStatus.initial ||
            state.status == ConversationListStatus.loading) {
          return const Center(
            child: CircularProgressIndicator(color: VineTheme.primary),
          );
        }

        final requests = state.requestConversations;
        if (requests.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'No message requests',
                style: VineTheme.titleMediumFont(
                  color: VineTheme.onSurfaceMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return RequestTile(
              conversation: request,
              currentUserPubkey: currentPubkey,
              onTap: () => _onRequestTapped(context, request),
            );
          },
        );
      },
    );
  }

  void _onRequestTapped(BuildContext context, DmConversation conversation) {
    final otherPubkeys = conversation.participantPubkeys
        .where((pk) => pk != currentPubkey)
        .toList();

    context.pushNamed(
      RequestPreviewPage.routeName,
      pathParameters: {'id': conversation.id},
      extra: otherPubkeys,
    );
  }
}
