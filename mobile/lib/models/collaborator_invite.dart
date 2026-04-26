// ABOUTME: Typed metadata parsed from a structured collaborator invite DM.
// ABOUTME: Represents local invite UX data, not authoritative collab state.

import 'package:equatable/equatable.dart';

class CollaboratorInvite extends Equatable {
  const CollaboratorInvite({
    required this.messageId,
    required this.videoAddress,
    required this.videoKind,
    required this.creatorPubkey,
    required this.videoDTag,
    required this.role,
    this.relayHint,
    this.title,
    this.thumbnailUrl,
  });

  final String messageId;
  final String videoAddress;
  final int videoKind;
  final String creatorPubkey;
  final String videoDTag;
  final String role;
  final String? relayHint;
  final String? title;
  final String? thumbnailUrl;

  @override
  List<Object?> get props => [
    messageId,
    videoAddress,
    videoKind,
    creatorPubkey,
    videoDTag,
    role,
    relayHint,
    title,
    thumbnailUrl,
  ];
}
