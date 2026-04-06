import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

@immutable
enum LiveSessionStatus {
  planned,
  live,
  ended
  ;

  static LiveSessionStatus fromTagValue(String? rawStatus) {
    final normalized = rawStatus?.trim().toLowerCase();
    switch (normalized) {
      case 'planned':
        return LiveSessionStatus.planned;
      case 'ended':
        return LiveSessionStatus.ended;
      case 'live':
      default:
        return LiveSessionStatus.live;
    }
  }

  String get tagValue {
    switch (this) {
      case LiveSessionStatus.planned:
        return 'planned';
      case LiveSessionStatus.live:
        return 'live';
      case LiveSessionStatus.ended:
        return 'ended';
    }
  }
}

@immutable
class LiveSession extends Equatable {
  const LiveSession({
    required this.id,
    required this.roomId,
    required this.status,
    required this.startedAt,
    required this.endedAt,
    required this.speakerPubkeys,
    required this.audienceCount,
  });

  final String id;
  final String roomId;
  final LiveSessionStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final List<String> speakerPubkeys;
  final int audienceCount;

  bool get isLive => status == LiveSessionStatus.live;

  bool get hasEnded => status == LiveSessionStatus.ended;

  LiveSession copyWith({
    String? id,
    String? roomId,
    LiveSessionStatus? status,
    DateTime? startedAt,
    DateTime? endedAt,
    List<String>? speakerPubkeys,
    int? audienceCount,
  }) {
    return LiveSession(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      speakerPubkeys: speakerPubkeys ?? this.speakerPubkeys,
      audienceCount: audienceCount ?? this.audienceCount,
    );
  }

  @override
  List<Object?> get props => [
    id,
    roomId,
    status,
    startedAt,
    endedAt,
    speakerPubkeys,
    audienceCount,
  ];
}
