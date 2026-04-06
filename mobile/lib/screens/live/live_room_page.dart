import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/live_chat/live_chat_bloc.dart';
import 'package:openvine/blocs/live_room/live_room_bloc.dart';
import 'package:openvine/models/live/live_role.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_session.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/live_providers.dart';
import 'package:openvine/screens/live/live_room_view.dart';

class LiveRoomPage extends ConsumerStatefulWidget {
  const LiveRoomPage({
    required this.roomId,
    required this.sessionId,
    this.initialRoom,
    this.initialSession,
    this.initialRole,
    super.key,
  });

  static const String routeName = 'liveRoom';
  static const String pathPattern = '/live/room/:roomId/session/:sessionId';

  static String pathFor(String roomId, String sessionId) =>
      '/live/room/$roomId/session/$sessionId';

  final String roomId;
  final String sessionId;
  final LiveRoom? initialRoom;
  final LiveSession? initialSession;
  final LiveRole? initialRole;

  @override
  ConsumerState<LiveRoomPage> createState() => _LiveRoomPageState();
}

class _LiveRoomPageState extends ConsumerState<LiveRoomPage> {
  late final Future<_LiveRoomPayload?> _payloadFuture = _loadPayload();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LiveRoomPayload?>(
      future: _payloadFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: VineTheme.surfaceBackground,
            body: Center(
              child: CircularProgressIndicator(color: VineTheme.primary),
            ),
          );
        }

        final payload = snapshot.data;
        if (payload == null) {
          return Scaffold(
            backgroundColor: VineTheme.surfaceBackground,
            appBar: AppBar(backgroundColor: VineTheme.surfaceBackground),
            body: Center(
              child: Text(
                'Room unavailable.',
                style: VineTheme.bodyMediumFont(),
              ),
            ),
          );
        }

        return MultiBlocProvider(
          providers: [
            BlocProvider<LiveRoomBloc>(
              create: (_) =>
                  LiveRoomBloc(
                    liveRepository: ref.watch(liveRepositoryProvider),
                    liveApiService: ref.watch(liveApiServiceProvider),
                    liveKitRoomService: ref.watch(liveKitRoomServiceProvider),
                  )..add(
                    LiveRoomJoinRequested(
                      room: payload.room,
                      role: payload.role,
                    ),
                  ),
            ),
            BlocProvider<LiveChatBloc>(
              create: (_) => LiveChatBloc(
                liveChatRepository: ref.watch(liveChatRepositoryProvider),
              ),
            ),
          ],
          child: BlocListener<LiveRoomBloc, LiveRoomState>(
            listenWhen: (previous, current) =>
                previous.sessionAddress != current.sessionAddress &&
                current.sessionAddress != null,
            listener: (context, state) {
              final sessionAddress = state.sessionAddress;
              if (sessionAddress == null) {
                return;
              }

              context.read<LiveChatBloc>().add(
                LiveChatStarted(sessionAddress: sessionAddress),
              );
            },
            child: const LiveRoomView(),
          ),
        );
      },
    );
  }

  Future<_LiveRoomPayload?> _loadPayload() async {
    final initialRoom = widget.initialRoom;
    final currentUserPubkey =
        ref.read(authServiceProvider).currentPublicKeyHex ?? '';

    if (initialRoom != null) {
      final role =
          widget.initialRole ??
          (initialRoom.hostPubkey == currentUserPubkey
              ? LiveRole.host
              : LiveRole.audience);
      return _LiveRoomPayload(
        room: initialRoom,
        role: role,
      );
    }

    final repository = ref.read(liveRepositoryProvider);
    final rooms = await repository.fetchPublicRooms();
    final room = rooms.where((item) => item.id == widget.roomId).firstOrNull;
    if (room == null) {
      return null;
    }
    final role = room.hostPubkey == currentUserPubkey
        ? LiveRole.host
        : LiveRole.audience;
    return _LiveRoomPayload(
      room: room,
      role: role,
    );
  }
}

class _LiveRoomPayload {
  const _LiveRoomPayload({
    required this.room,
    required this.role,
  });

  final LiveRoom room;
  final LiveRole role;
}
