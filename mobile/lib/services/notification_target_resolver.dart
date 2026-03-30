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

    if (event.kind == NIP71VideoKinds.shortVideo ||
        event.kind == NIP71VideoKinds.addressableNormalVideo ||
        event.kind == NIP71VideoKinds.addressableShortVideo) {
      return targetId;
    }

    String? replyId;
    String? firstEtagId;

    for (final tag in event.tags) {
      if (tag.length < 2 || tag[0] != 'e') continue;

      final candidateId = tag[1];
      if (candidateId.isEmpty) continue;

      firstEtagId ??= candidateId;

      final marker = tag.length > 3 ? tag[3] : '';
      if (marker == 'root') {
        return candidateId;
      }
      if (marker == 'reply') {
        replyId ??= candidateId;
      }
    }

    return replyId ?? firstEtagId;
  }
}
