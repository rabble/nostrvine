import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/live_room/live_room_bloc.dart';
import 'package:openvine/screens/live/widgets/live_local_media_controls.dart';
import 'package:openvine/screens/live/widgets/live_speaker_queue_sheet.dart';

class LiveHostControlsSheet extends StatelessWidget {
  const LiveHostControlsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: BlocBuilder<LiveRoomBloc, LiveRoomState>(
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Host controls',
                  style: VineTheme.headlineSmallFont(),
                ),
                const SizedBox(height: 8),
                Text(
                  'Keep the stage tight, work the raised hands, and degrade cleanly when the network gets weird.',
                  style: VineTheme.bodyMediumFont(
                    color: VineTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                if (state.canPublish) ...[
                  LiveLocalMediaControls(
                    cameraButtonLabel: state.mediaState.canPublish
                        ? (state.mediaState.cameraEnabled
                              ? 'Camera on'
                              : 'Camera off')
                        : 'Camera off',
                    microphoneButtonLabel: state.mediaState.canPublish
                        ? (state.mediaState.microphoneEnabled
                              ? 'Mic on'
                              : 'Mic off')
                        : 'Mic off',
                    onToggleCamera: () {
                      context.read<LiveRoomBloc>().add(
                        const ToggleCameraRequested(),
                      );
                    },
                    onToggleMicrophone: () {
                      context.read<LiveRoomBloc>().add(
                        const ToggleMicrophoneRequested(),
                      );
                    },
                    onSwitchCamera: () {
                      context.read<LiveRoomBloc>().add(
                        const SwitchCameraRequested(),
                      );
                    },
                    onEnableAudioOnly: () {
                      context.read<LiveRoomBloc>().add(
                        const EnableAudioOnlyRequested(),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
                DivineButton(
                  label: 'Manage speakers',
                  type: DivineButtonType.secondary,
                  size: DivineButtonSize.small,
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: VineTheme.surfaceBackground,
                      isScrollControlled: true,
                      builder: (_) => SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                          child: LiveSpeakerQueueSheet(
                            hostPubkey: state.room?.hostPubkey ?? '',
                            presence: state.presence,
                            speakerPubkeys: state.speakerPubkeys,
                            onPromote: (pubkey) {
                              context.read<LiveRoomBloc>().add(
                                PromoteSpeakerRequested(pubkey),
                              );
                            },
                            onDemote: (pubkey) {
                              context.read<LiveRoomBloc>().add(
                                DemoteSpeakerRequested(pubkey),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
