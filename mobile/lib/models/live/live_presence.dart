import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:openvine/models/live/live_role.dart';

@immutable
class LivePresence extends Equatable {
  const LivePresence({
    required this.sessionId,
    required this.pubkey,
    required this.role,
    required this.handRaised,
    required this.updatedAt,
  });

  final String sessionId;
  final String pubkey;
  final LiveRole role;
  final bool handRaised;
  final DateTime updatedAt;

  LivePresence copyWith({
    String? sessionId,
    String? pubkey,
    LiveRole? role,
    bool? handRaised,
    DateTime? updatedAt,
  }) {
    return LivePresence(
      sessionId: sessionId ?? this.sessionId,
      pubkey: pubkey ?? this.pubkey,
      role: role ?? this.role,
      handRaised: handRaised ?? this.handRaised,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [sessionId, pubkey, role, handRaised, updatedAt];
}
