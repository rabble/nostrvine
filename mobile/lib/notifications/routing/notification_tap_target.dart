// ABOUTME: Source-agnostic decision for where a notification tap should go.
// ABOUTME: One contract shared by in-app row taps, FCM push taps, and local taps.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart' show NIP71VideoKinds, NotificationKind;
import 'package:openvine/services/notification_helpers.dart'
    show parseAddressableId;

/// Normalized destination for a notification tap.
///
/// Built from either a `NotificationItem` (in-app row tap) or a push/local
/// payload (`type` + `referencedEventId`/`eventId` [+ `senderPubkey`]). All
/// three entry points resolve through [resolveNotificationTapTarget] so the
/// kind -> destination decision cannot drift.
///
/// This is intentionally Flutter-free: it decides *what* to open, not *how*.
/// Each executor maps the target to its own navigation mechanism (the in-app
/// path opens [PooledFullscreenVideoFeedScreen] with a pre-fetched stream; the
/// push path pushes a video `DeepLink` / navigates to the profile or inbox).
sealed class NotificationTapTarget extends Equatable {
  const NotificationTapTarget();
}

/// Open the video associated with the notification.
///
/// The executor owns resolving the concrete route id (preferring a stable
/// NIP-33 addressable id, otherwise walking the target event to its root
/// video) and the fallback when that resolution fails. That fallback applies
/// only to the event-id walk: a stable addressable id is routed to directly,
/// and an unfetchable video then intentionally surfaces its failure at the
/// destination rather than rerouting to profile/inbox — the video detail
/// error state for push taps; for in-app row taps, which also navigate
/// first, a snackbar over the empty fullscreen feed. See #5079.
class OpenVideoTarget extends NotificationTapTarget {
  const OpenVideoTarget({required this.autoOpenComments});

  /// Whether the opened video should auto-expand its comments.
  final bool autoOpenComments;

  @override
  List<Object?> get props => [autoOpenComments];
}

/// Open the actor's profile (e.g. a follow notification, or a tap whose video
/// target could not be determined).
class OpenProfileTarget extends NotificationTapTarget {
  const OpenProfileTarget(this.actorPubkey);

  /// Hex pubkey of the actor whose profile to open.
  final String actorPubkey;

  @override
  List<Object?> get props => [actorPubkey];
}

/// Deterministic safe fallback: open the notifications inbox.
///
/// Used when a tap carries no resolvable video target and no actor pubkey, so
/// an unresolved tap lands somewhere sensible instead of silently doing
/// nothing.
class OpenInboxTarget extends NotificationTapTarget {
  const OpenInboxTarget();

  @override
  List<Object?> get props => const [];
}

/// Whether a tap of [kind] should open the video with its comments expanded.
///
/// Single source of truth for the auto-open-comments policy across every
/// entry point. The push path historically keyed this off a `'reply'` string
/// the backend never sends, so comments never auto-opened from a push; routing
/// through this helper fixes that drift.
bool notificationKindOpensComments(NotificationKind? kind) =>
    kind == NotificationKind.comment ||
    kind == NotificationKind.reply ||
    kind == NotificationKind.likeComment ||
    kind == NotificationKind.mention;

/// Maps the push wire `type` to a [NotificationKind].
///
/// `divine-push-service` sends a lowercase, five-value vocabulary
/// (`like`/`comment`/`follow`/`mention`/`repost`). It never sends `reply`,
/// `likeComment`, or `system`. Unknown / absent values return `null`, which
/// [resolveNotificationTapTarget] treats as a best-effort video/profile/inbox
/// tap.
NotificationKind? notificationKindFromPushType(String? type) {
  switch (type) {
    case 'like':
      return NotificationKind.like;
    case 'comment':
      return NotificationKind.comment;
    case 'follow':
      return NotificationKind.follow;
    case 'mention':
      return NotificationKind.mention;
    case 'repost':
      return NotificationKind.repost;
    default:
      // Keep unknown values non-fatal: a mistyped or legacy-cased payload
      // should still fall back to the best available target.
      return null;
  }
}

/// Returns [referencedAddress] when it is a usable video coordinate, else null.
///
/// The push service sends `referencedAddress` as the signed NIP-33 coordinate
/// (`kind:pubkey:d-tag`) of the referenced event. It is only a video *route*
/// when its kind is one the raw-coordinate route resolver accepts — i.e. a
/// NIP-71 video kind ([NIP71VideoKinds.isVideoKind]). Gating on the same
/// predicate guarantees a non-null result resolves to a video, so the executor
/// can push it directly without a relay round-trip; non-video or malformed
/// coordinates return null and the caller falls back to the event-id walk.
/// Coordinates with an empty pubkey or d-tag (e.g. `34236::`) parse but cannot
/// route to a video, so they also return null and fall back the same way.
String? videoAddressableTarget(String? referencedAddress) {
  if (referencedAddress == null || referencedAddress.isEmpty) return null;
  final parsed = parseAddressableId(referencedAddress);
  if (parsed == null) return null;
  // Push-service also rejects these before sending; keep the app guard as
  // defense-in-depth for stale local payloads and future non-push callers.
  if (parsed.pubkey.isEmpty || parsed.dTag.isEmpty) return null;
  return NIP71VideoKinds.isVideoKind(parsed.kind) ? referencedAddress : null;
}

/// Decides where a notification tap should go.
///
/// [hasVideoTarget] is supplied by the caller: `true` when it holds a video
/// event id, a stable addressable id, or a target event id that can be walked
/// to a video. The id mechanics stay in the executor so this decision is pure
/// and testable in isolation.
///
/// Policy:
/// * `follow` → the actor's profile (or the inbox if no pubkey is known).
/// * `system` → the inbox.
/// * any other kind with a video target → the video, with comments auto-opened
///   per [notificationKindOpensComments].
/// * any other kind without a video target → the actor's profile, or the inbox
///   when no pubkey is known.
NotificationTapTarget resolveNotificationTapTarget({
  required NotificationKind? kind,
  required bool hasVideoTarget,
  String? actorPubkey,
}) {
  if (kind == NotificationKind.follow) {
    return _profileOrInbox(actorPubkey);
  }
  if (kind == NotificationKind.system) {
    return const OpenInboxTarget();
  }
  if (hasVideoTarget) {
    return OpenVideoTarget(
      autoOpenComments: notificationKindOpensComments(kind),
    );
  }
  return _profileOrInbox(actorPubkey);
}

NotificationTapTarget _profileOrInbox(String? actorPubkey) =>
    (actorPubkey != null && actorPubkey.isNotEmpty)
    ? OpenProfileTarget(actorPubkey)
    : const OpenInboxTarget();
