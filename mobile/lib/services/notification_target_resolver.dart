import 'package:models/models.dart' show NIP71VideoKinds;
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/video_event_service.dart';

class NotificationTargetResolver {
  NotificationTargetResolver({
    required VideoEventService videoEventService,
    required NostrClient nostrService,
  }) : _videoEventService = videoEventService,
       _nostrService = nostrService;

  final VideoEventService _videoEventService;
  final NostrClient _nostrService;

  Future<String?> resolveVideoEventIdFromNotificationTarget(
    String targetId,
  ) async {
    final directVideo = _videoEventService.getVideoById(targetId);
    if (directVideo != null) {
      return targetId;
    }

    final event = await _nostrService.fetchEventById(targetId);
    if (event == null) {
      return null;
    }

    if (NIP71VideoKinds.isAcceptableVideoKind(event.kind)) {
      return targetId;
    }

    // NIP-22: uppercase A tag = root addressable scope. Prefer this when
    // available because it remains valid across NIP-33 video replacements.
    for (final tag in event.tags) {
      if (tag.length >= 2 && tag[0] == 'A' && _isVideoAddressableId(tag[1])) {
        return tag[1];
      }
    }

    // NIP-22: uppercase E tag = root scope, points to root video event.
    for (final tag in event.tags) {
      if (tag.length >= 2 && tag[0] == 'E' && tag[1].isNotEmpty) {
        return tag[1];
      }
    }

    // Fallback: lowercase e tags (NIP-10 style / older events).
    //
    // Reply markers point at the immediate parent, which can be another
    // comment. Never route to those blindly; only unmarked legacy candidates
    // are probed below.
    final legacyCandidates = <String>[];

    for (final tag in event.tags) {
      if (tag.length < 2 || tag[0] != 'e') continue;

      final candidateId = tag[1];
      if (candidateId.isEmpty) continue;

      final marker = tag.length > 3 ? tag[3] : '';
      if (marker == 'root') {
        return candidateId;
      }
      if (marker.isEmpty) {
        legacyCandidates.add(candidateId);
      }
    }

    for (final candidateId in legacyCandidates) {
      if (await _isResolvableVideoEvent(candidateId)) {
        return candidateId;
      }
    }

    return null;
  }

  bool _isVideoAddressableId(String value) {
    final parts = value.split(':');
    if (parts.length < 3) return false;

    final kind = int.tryParse(parts.first);
    return kind != null && NIP71VideoKinds.isAcceptableVideoKind(kind);
  }

  Future<bool> _isResolvableVideoEvent(String eventId) async {
    final cachedVideo = _videoEventService.getVideoById(eventId);
    if (cachedVideo != null) return true;

    final event = await _nostrService.fetchEventById(eventId);
    return event != null && NIP71VideoKinds.isAcceptableVideoKind(event.kind);
  }
}
