// ABOUTME: Parses collaborator invite DMs from structured NIP-17 tags.
// ABOUTME: Ignores plaintext fallback copy to avoid ambiguous invite parsing.

import 'package:models/models.dart';
import 'package:openvine/models/collaborator_invite.dart';

class CollaboratorInviteParser {
  const CollaboratorInviteParser._();

  static final _hexPubkey = RegExp(r'^[0-9a-fA-F]{64}$');

  static CollaboratorInvite? parse(DmMessage message) {
    final tags = message.tags;
    if (!tags.any(_isInviteMarker)) return null;

    final addressTag = _firstWhereOrNull(tags, _isAddressTag);
    if (addressTag == null) return null;

    final address = _parseAddress(addressTag[1]);
    if (address == null) return null;

    final creatorTag = _firstWhereOrNull<String>(
      tags
          .where((tag) => tag.length >= 2 && tag[0] == 'p')
          .map((tag) => tag[1]),
      _isPubkey,
    );

    if (creatorTag != null && creatorTag != address.creatorPubkey) {
      return null;
    }

    final role = _tagValue(tags, 'role') ?? 'Collaborator';
    if (role != 'Collaborator') return null;

    return CollaboratorInvite(
      messageId: message.id,
      videoAddress: address.videoAddress,
      videoKind: address.videoKind,
      creatorPubkey: creatorTag ?? address.creatorPubkey,
      videoDTag: address.videoDTag,
      role: role,
      relayHint: _nonEmpty(addressTag.length >= 3 ? addressTag[2] : null),
      title: _tagValue(tags, 'title'),
      thumbnailUrl: _tagValue(tags, 'thumb'),
    );
  }

  static bool _isInviteMarker(List<String> tag) {
    return tag.length >= 2 && tag[0] == 'divine' && tag[1] == 'collab-invite';
  }

  static bool _isAddressTag(List<String> tag) {
    return tag.length >= 2 && tag[0] == 'a';
  }

  static _ParsedAddress? _parseAddress(String value) {
    final parts = value.split(':');
    if (parts.length != 3) return null;

    final kind = int.tryParse(parts[0]);
    final creatorPubkey = parts[1];
    final dTag = parts[2];
    if (kind == null || !_isPubkey(creatorPubkey) || dTag.isEmpty) {
      return null;
    }

    return _ParsedAddress(
      videoAddress: value,
      videoKind: kind,
      creatorPubkey: creatorPubkey,
      videoDTag: dTag,
    );
  }

  static String? _tagValue(List<List<String>> tags, String name) {
    for (final tag in tags) {
      if (tag.length < 2 || tag[0] != name) continue;
      return _nonEmpty(tag[1]);
    }
    return null;
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static bool _isPubkey(String value) => _hexPubkey.hasMatch(value);

  static T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T) test) {
    for (final value in values) {
      if (test(value)) return value;
    }
    return null;
  }
}

class _ParsedAddress {
  const _ParsedAddress({
    required this.videoAddress,
    required this.videoKind,
    required this.creatorPubkey,
    required this.videoDTag,
  });

  final String videoAddress;
  final int videoKind;
  final String creatorPubkey;
  final String videoDTag;
}
