import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_room_recording.dart';
import 'package:openvine/models/live/live_session.dart';
import 'package:openvine/screens/live/live_room_page.dart';
import 'package:openvine/screens/live/live_route_data.dart';
import 'package:openvine/screens/live/widgets/live_replay_banner.dart';

class LiveRoomDetailView extends StatelessWidget {
  const LiveRoomDetailView({
    required this.room,
    this.session,
    this.recording,
    super.key,
  });

  final LiveRoom room;
  final LiveSession? session;
  final LiveRoomRecording? recording;

  @override
  Widget build(BuildContext context) {
    final currentSession = session;
    final isLive = currentSession?.isLive ?? false;
    final sessionId = currentSession?.id ?? room.id;

    return Scaffold(
      backgroundColor: VineTheme.surfaceBackground,
      appBar: AppBar(
        backgroundColor: VineTheme.surfaceBackground,
        title: Text(
          'Room detail',
          style: VineTheme.titleLargeFont(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (currentSession?.hasEnded == true && recording != null) ...[
            LiveReplayBanner(recording: recording!),
            const SizedBox(height: 16),
          ],
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: const LinearGradient(
                colors: <Color>[
                  Color(0xFF111A16),
                  Color(0xFF1E2A22),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isLive
                        ? VineTheme.primary
                        : VineTheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isLive ? 'Live now' : 'Scheduled',
                    style: VineTheme.labelLargeFont(
                      color: isLive ? VineTheme.onPrimary : VineTheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(room.title, style: VineTheme.headlineSmallFont()),
                const SizedBox(height: 8),
                Text(
                  room.summary,
                  style: VineTheme.bodyLargeFont(
                    color: VineTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Host: ${room.hostPubkey}',
                  style: VineTheme.bodyMediumFont(
                    color: VineTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${currentSession?.speakerPubkeys.length ?? 1} speakers · ${currentSession?.audienceCount ?? 0} listeners',
                  style: VineTheme.bodyMediumFont(
                    color: VineTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          DivineButton(
            label: isLive ? 'Join live' : 'Open room',
            expanded: true,
            onPressed: () {
              context.push(
                LiveRoomPage.pathFor(room.id, sessionId),
                extra: LiveRoomRouteData(
                  room: room,
                  session: currentSession,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          DivineButton(
            label: 'Share room',
            expanded: true,
            type: DivineButtonType.secondary,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Share flow lands in the next slice.'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
