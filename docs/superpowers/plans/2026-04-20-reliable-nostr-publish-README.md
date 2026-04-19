# Reliable Nostr Publish — 8-PR plan series

Makes every Nostr publish in divine-mobile durable: relay OK confirmation, bounded retry, consistent UX mapping, no silent failures.

## Execution order

Each PR stacks on PR 1. PRs 2–7 are independent of each other and can ship in parallel once PR 1 merges; PR 8 should be last (it relies on PR 6's NIP-17 work for one of its paths).

| # | Plan | Scope | Call sites migrated |
|---|------|-------|----------------------|
| 1 | [pr1](./2026-04-20-reliable-nostr-publish-pr1.md) | Foundation: `PublishOutcome`, `publishEventAwaitOk`, `publishEventWithRetry`, `PublishResultMapper`, NIP-09 deletion reference | 1 (`content_deletion_service`) |
| 2 | [pr2-video](./2026-04-20-reliable-nostr-publish-pr2-video.md) | Video publish + rebroadcast; deletes existing ad-hoc retry loop | 2 (`video_event_publisher`, `share_video_menu` edit) |
| 3 | [pr3-social](./2026-04-20-reliable-nostr-publish-pr3-social.md) | Follow sets, reactions, reposts, comments, generic social base | 8 (`social_service` ×2, `SocialEventServiceBase`, `likes_repository` ×4, `comments_repository` ×2) |
| 4 | [pr4-moderation](./2026-04-20-reliable-nostr-publish-pr4-moderation.md) | Mutes, blocklists, reports | 3 (`mute_service`, `content_blocklist_service`, `content_reporting_service`) |
| 5 | [pr5-lists](./2026-04-20-reliable-nostr-publish-pr5-lists.md) | Bookmarks, curated lists, curation, account labels | 5 (`bookmark_service` ×2, `curated_list_service`, `curation_service`, `account_label_service`) |
| 6 | [pr6-dm](./2026-04-20-reliable-nostr-publish-pr6-dm.md) | NIP-17 gift wraps, NIP-04 fallback, DM deletion, pending/failed UX | 4 (`nip17_message_service` ×2, `dm_repository` ×2) |
| 7 | [pr7-account-deletion](./2026-04-20-reliable-nostr-publish-pr7-account-deletion.md) | NIP-62 + batched kind-5 with progress UI | 2 (`account_deletion_service` ×2) |
| 8 | [pr8-cleanup](./2026-04-20-reliable-nostr-publish-pr8-cleanup.md) | Deprecate legacy NIP-04 share; annotate intentional fire-and-forget | Removes/annotates 7 (video_sharing, view_event_publisher ×2, push_notification_service ×3, corrupted_video_repair) |

**Total covered:** 29 call sites migrated + 7 annotated fire-and-forget = every `publishEvent` in `mobile/lib` and `mobile/packages/` accounted for.

## Shared contract

Every migrated caller returns a result type carrying:
- `PublishOutcome outcome` — per-relay ack map with `acceptedBy`, `rejectedBy`, `noResponseFrom`.
- `PublishUserFeedback feedback` — `{severity, messageKey, retryable, firstRejectionReason}` from `PublishResultMapper.map(outcome)`.

UI rule: never show a success confirmation unless `outcome.acceptedByAny`. Show a retry affordance when `feedback.retryable`. Show the specific rejection reason when `feedback.firstRejectionReason != null`.

State rule per `.claude/rules/state_management.md`: use status enums + the `feedback` object. Never store raw error strings in state.

## Not in scope

- Relay-level load balancing / outbox pattern across sessions. Retry is in-memory.
- A cross-session "pending publish" queue (events persist only via the existing resumable-signed-event cache in `video_event_publisher`).
- Profile (kind 0) publishing. Profile edits currently route through funnelcake REST — no kind-0 publish goes through `publishEvent`. If that changes, add a PR 9 at that time.
- Changing the event schema or relay routing for any existing kind.
