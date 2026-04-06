import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/live_discovery/live_discovery_bloc.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_session.dart';
import 'package:openvine/screens/live/go_live_page.dart';
import 'package:openvine/screens/live/live_room_detail_page.dart';
import 'package:openvine/screens/live/live_route_data.dart';
import 'package:openvine/screens/live/widgets/live_room_card.dart';

class LiveDiscoveryView extends StatelessWidget {
  const LiveDiscoveryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.surfaceBackground,
      appBar: AppBar(
        backgroundColor: VineTheme.surfaceBackground,
        title: Text(
          'Live',
          style: VineTheme.headlineSmallFont(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: DivineButton(
              label: 'Go live',
              size: DivineButtonSize.small,
              onPressed: () => context.push(GoLivePage.path),
            ),
          ),
        ],
      ),
      body: BlocBuilder<LiveDiscoveryBloc, LiveDiscoveryState>(
        builder: (context, state) {
          return switch (state.status) {
            LiveDiscoveryStatus.initial ||
            LiveDiscoveryStatus.loading => const Center(
              child: CircularProgressIndicator(color: VineTheme.primary),
            ),
            LiveDiscoveryStatus.failure => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  state.errorMessage ?? 'Live rooms are unavailable.',
                  style: VineTheme.bodyMediumFont(),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            LiveDiscoveryStatus.success => RefreshIndicator(
              onRefresh: () async {
                context.read<LiveDiscoveryBloc>().add(
                  const LiveDiscoveryRequested(force: true),
                );
              },
              child: ListView(
                children: [
                  const SizedBox(height: 8),
                  _DiscoverySection(
                    title: 'Live now',
                    subtitle: 'Drop into rooms that are already rolling.',
                    rooms: state.activeRooms,
                    sessions: state.activeSessions,
                  ),
                  _DiscoverySection(
                    title: 'Upcoming',
                    subtitle: 'See what is lined up next.',
                    rooms: state.upcomingRooms,
                    sessions: state.upcomingSessions,
                  ),
                  if (state.activeRooms.isEmpty && state.upcomingRooms.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No rooms yet. Start the first one.',
                        style: VineTheme.bodyMediumFont(
                          color: VineTheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          };
        },
      ),
    );
  }
}

class _DiscoverySection extends StatelessWidget {
  const _DiscoverySection({
    required this.title,
    required this.subtitle,
    required this.rooms,
    required this.sessions,
  });

  final String title;
  final String subtitle;
  final List<LiveRoom> rooms;
  final List<LiveSession> sessions;

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: VineTheme.titleLargeFont()),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: VineTheme.bodyMediumFont(
                color: VineTheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Nothing here yet.',
              style: VineTheme.bodyMediumFont(
                color: VineTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(title, style: VineTheme.titleLargeFont()),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              subtitle,
              style: VineTheme.bodyMediumFont(
                color: VineTheme.onSurfaceVariant,
              ),
            ),
          ),
          ...rooms.map((room) {
            final session = sessions
                .where((item) => item.roomId == room.id)
                .fold(
                  null,
                  (LiveSession? previous, LiveSession next) {
                    return previous == null || next.isLive ? next : previous;
                  },
                );

            return LiveRoomCard(
              room: room,
              session: session,
              onTap: () {
                context.push(
                  LiveRoomDetailPage.pathFor(room.id),
                  extra: LiveRoomDetailRouteData(
                    room: room,
                    session: session,
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }
}
