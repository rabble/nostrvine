import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/live_chat/live_chat_bloc.dart';
import 'package:openvine/blocs/live_room/live_room_bloc.dart';
import 'package:openvine/screens/live/widgets/live_chat_panel.dart';
import 'package:openvine/screens/live/widgets/live_host_controls_sheet.dart';
import 'package:openvine/screens/live/widgets/live_room_stage.dart';

class LiveRoomView extends StatelessWidget {
  const LiveRoomView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.surfaceBackground,
      appBar: AppBar(
        backgroundColor: VineTheme.surfaceBackground,
        title: BlocBuilder<LiveRoomBloc, LiveRoomState>(
          builder: (context, state) {
            return Text(
              state.room?.title ?? 'Live room',
              style: VineTheme.titleLargeFont(),
            );
          },
        ),
      ),
      body: BlocBuilder<LiveRoomBloc, LiveRoomState>(
        builder: (context, roomState) {
          return switch (roomState.status) {
            LiveRoomStatus.initial || LiveRoomStatus.loading => const Center(
              child: CircularProgressIndicator(color: VineTheme.primary),
            ),
            LiveRoomStatus.failure => Center(
              child: Text(
                roomState.errorMessage ?? 'Unable to open this live room.',
                style: VineTheme.bodyMediumFont(),
              ),
            ),
            LiveRoomStatus.ready => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  LiveRoomStage(
                    speakerPubkeys: roomState.speakerPubkeys,
                    audienceCount:
                        roomState.session?.audienceCount ??
                        roomState.presence.length,
                    statusLabel: roomState.mediaState.status.name,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DivineButton(
                          label: 'Zap',
                          type: DivineButtonType.secondary,
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Zap flow lands in a follow-up slice.',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DivineButton(
                          label: roomState.canPublish
                              ? 'You are on stage'
                              : 'Raise hand',
                          onPressed: roomState.canPublish ? null : () {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (roomState.canModerate)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: DivineButton(
                        label: 'Host controls',
                        type: DivineButtonType.secondary,
                        size: DivineButtonSize.small,
                        onPressed: () {
                          showModalBottomSheet<void>(
                            context: context,
                            backgroundColor: VineTheme.surfaceBackground,
                            builder: (_) => const LiveHostControlsSheet(),
                          );
                        },
                      ),
                    ),
                  if (roomState.canModerate) const SizedBox(height: 16),
                  Expanded(
                    child: BlocBuilder<LiveChatBloc, LiveChatState>(
                      builder: (context, chatState) {
                        return const LiveChatPanel();
                      },
                    ),
                  ),
                ],
              ),
            ),
          };
        },
      ),
    );
  }
}
