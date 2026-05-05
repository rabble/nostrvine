# Funnelcake notifications API — changes required

**Date:** 2026-04-20
**Owner:** rabble (mobile), funnelcake backend team
**Status:** Proposal — needs backend sign-off before mobile implementation
**Related mobile work:** `docs/superpowers/specs/2026-04-20-notifications-redesign-design.md` *(to be written)*

---

## Background

Mobile notifications have four user-visible bugs:

1. Rows say "your video" instead of the actual video title.
2. Tapping a comment/reply notification doesn't scroll to the specific comment.
3. Rows misattribute context — "X replied to your video" when X replied to your comment, or on someone else's video.
4. A week-old event can render as "2h ago."

Before writing any backend, we audited the live OpenAPI spec at `https://relay.divine.video/openapi.json` against the mobile client's expectations. This report covers what funnelcake needs to add, what it already has (and mobile is not using correctly), and open questions.

---

## What the API already returns (for reference)

`GET /api/users/{pubkey}/notifications` — response item shape per `openapi.json`:

| Field | Type | Notes |
|---|---|---|
| `source_pubkey` | string | Actor pubkey |
| `source_event_id` | string | Nostr event id that triggered the notification |
| `source_kind` | int | Nostr kind of that event |
| `source_created_at` | int32 (unix s) | **Nostr event's `created_at`** |
| `referenced_event_id` | string | Event being acted on (video, comment, etc.) |
| `notification_type` | string | `reaction` \| `reply` \| `repost` \| `mention` \| `follow` \| `zap` |
| `created_at` | int32 (unix s) | Notification row's ingest/insertion time |
| `read` | int | `0` unread, `1` read |

**Bug #4 (stale timestamps) is not a backend bug.** `source_created_at` is already returned. The mobile package DTO (`packages/funnelcake_api_client/.../relay_notification.dart`) fails to parse it, and the mapper falls back to `created_at` (the row's insertion time), which is arbitrarily later than the Nostr event. **Fix is mobile-only.** No action required from funnelcake for bug #4.

---

## Changes required for funnelcake

Three additive fields on each notification object. All are optional so older clients continue to work. One optional clarification to `notification_type`'s enumerated values.

### 1. `referenced_event_title` — string, nullable

The title of the referenced event, when that event is a kind 34236 video. For other referenced event kinds (or when no title tag is present), return `null`.

```json
{
  "referenced_event_id": "abc123…",
  "referenced_event_title": "Best Post Ever"
}
```

**Why:** Mobile renders "**{actor}** liked your video **{title}**" per the redesigned row. Without this, the client would need a second round-trip to fetch each referenced video and extract its `title` tag. Funnelcake already has the referenced event indexed and can project the title at query time.

**Edge cases:** Referenced event is a comment (kind 1 / 1111) and not a video — `null`. Video has no `title` tag — `null`. Title is empty string — `null`.

---

### 2. `reply_context` — string enum, nullable

Populated only on `notification_type: "reply"`. Classifies the e-tag chain so the client doesn't have to resolve it.

| Value | Meaning |
|---|---|
| `"comment_on_your_video"` | Someone top-level commented on the recipient's video. (If the backend emits this, it should actually use `notification_type: "comment"` — see open question 1 below.) |
| `"reply_to_your_comment_on_your_video"` | Someone replied to a comment the recipient made on their own video. |
| `"reply_to_your_comment_on_others_video"` | Someone replied to a comment the recipient made on someone else's video. |
| `null` | Not a reply, or context couldn't be determined. |

**Why:** Bug #3. The current mobile code distinguishes reply vs comment purely by the server's `notification_type` string, with no way to know whose video the comment chain is on. The backend has the e-tag chain already — single authoritative computation server-side beats every client re-implementing it.

---

### 3. `target_comment_id` — string, nullable

The hex event id of the specific comment the user should scroll to when opening the referenced video's comments sheet.

- For `notification_type: "comment"` (top-level comment on your video), `target_comment_id` == `source_event_id`.
- For `notification_type: "reply"`, `target_comment_id` == `source_event_id` (the new reply).
- For other types, `null`.

**Why:** Bug #2. The mobile app navigates to the video and opens the comments sheet, but has no comment id to scroll to — users land at the top of the thread and have to hunt for the comment that triggered the notification.

We could derive this client-side from `source_event_id` when `source_kind` is a comment kind, but funnelcake already knows the answer cleanly and returning it avoids client-side kind-guessing.

---

### 4. Document and emit `notification_type: "comment"`

The mobile client today treats `"comment"` as a distinct type from `"reply"` — top-level comments on your video vs replies in a thread — and the mobile code also accepts `"contact"` as an alias for `"follow"`. The OpenAPI `notification_type` description lists only `reaction | reply | repost | mention | follow | zap`.

Please confirm which enum values funnelcake actually emits today, and:

- If the backend already emits `"comment"` and/or `"contact"`, update the OpenAPI description to list them.
- If it does not, decide whether to add `"comment"` (so top-level video comments are distinguishable from threaded replies without mobile inspecting e-tags) — mobile needs this split to render the copy correctly.

---

## Summary of required backend work

| Item | Type | Effort estimate (backend) |
|---|---|---|
| Add `referenced_event_title` to notification response | Additive | Low — one join/lookup on referenced event, project `title` tag |
| Add `reply_context` enum to notification response | Additive | Medium — walk e-tag chain to classify, 3 enum values |
| Add `target_comment_id` to notification response | Additive | Low — copy of `source_event_id` for comment/reply types |
| Confirm + document emitted `notification_type` values; consider adding `"comment"` | Clarification or additive | Low–medium depending on outcome |

All four are additive — no breaking changes to current clients. Mobile will parse the new fields when present and fall back to existing behavior when absent, so the two sides can ship independently.

---

## Out of scope

The Figma redesign also shows three notification categories funnelcake doesn't emit today. Each is its own product feature and is **not** part of this report. File separately:

- **Moderation: "Your post has been flagged"** — needs a new notification emission path from the moderation pipeline.
- **Hashtag alerts: "It's time for #highnoon"** — needs a hashtag-subscription system (new product surface, not just a notification type).
- **List follows: "X followed your list **Best List Ever**"** — needs kind 30000 list-follow events indexed into the notifications stream, with `referenced_event_title` returning the list's `d`-tag label.

Once the three core fields above ship, adding any of these later is purely additive to the same schema.

---

## Open questions for funnelcake team

1. **`notification_type: "comment"`** — does it exist today, or should we add it? (See §4.)
2. **`referenced_event_id` semantics on reply notifications** — when someone replies to a comment, is `referenced_event_id` the parent comment or the root video? Mobile needs to navigate to the video and scroll to the reply; if `referenced_event_id` currently points at the parent comment, we'd also want a `root_event_id` or `target_video_id` field. Please confirm current behavior.
3. **Rollout** — can these four fields land in one backend PR, or do they prefer separate deploys? Mobile is fine either way; the client reads them independently.
4. **Availability SLA** — any constraint on how soon after a Nostr event arrives the title/context/target fields are populated? (We don't want a race where the notification is returned before the referenced event is indexed and the fields are all `null` forever.)

---

## Mobile-side followups (tracked separately; not funnelcake's problem)

Documented here only so the shape of the full fix is clear to reviewers:

- Delete the duplicate `RelayNotification` DTO in `mobile/lib/services/relay_notification_api_service.dart`; keep only `packages/funnelcake_api_client/.../relay_notification.dart` and extend it with the new fields.
- Parse `source_created_at` in the package DTO and use it as the authoritative `NotificationItem.timestamp` — this fixes bug #4 today without waiting on backend.
- Thread `target_comment_id` through `PooledFullscreenVideoFeedArgs` into the comments sheet and scroll/highlight.
- Rebuild the notification row UI per the Figma (type badges, grouped avatars, comment preview snippet, "No activity yet" empty state).
- All of the above landed TDD-first.
