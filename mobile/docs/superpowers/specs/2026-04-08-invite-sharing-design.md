# Invite Sharing System Design

**Date:** 2026-04-08
**Status:** Approved

## Summary

Allow users to share invite codes with friends. The server (`invite.divine.video`) controls all grant policy. The app checks invite status when users visit the invites screen or notifications tab, displays available codes, and provides copy/share actions.

No push notifications. No background polling. No new server endpoints.

---

## Server-Side Behavior

### `GET /v1/invite-status` gains grant-on-read logic

When a user calls this authenticated endpoint:

1. Returns existing invite codes (existing behavior)
2. Evaluates whether to grant new invites based on internal server policy -- account age, activity signals, last grant timestamp, cohort rules, etc. (new behavior)
3. If granting, atomically creates codes and includes them in the response
4. Response shape is unchanged:

```json
{
  "canInvite": true,
  "remaining": 3,
  "total": 5,
  "codes": [
    {
      "code": "AB23-EF7K",
      "claimed": true,
      "claimedAt": "2025-01-15T10:30:00Z",
      "claimedBy": "64_HEX_PUBKEY"
    },
    {
      "code": "HN4P-QR56",
      "claimed": false,
      "claimedAt": null,
      "claimedBy": null
    }
  ]
}
```

The policy engine is entirely internal to the server. The mobile app never sends activity data or requests grants explicitly -- it just reads status, and the server decides.

---

## App-Side Architecture

### Polling Triggers

1. **Invites screen opened** -- always fetches fresh status
2. **Notifications tab opened** -- silently checks invite status to show/hide the invite notification card

### State Management

**`InviteStatusCubit`** (app-level, BLoC pattern):

- Injected with `InviteApiService` and `Nip98AuthService`
- States: `initial`, `loading`, `loaded(InviteStatus)`, `error`
- Caches last result; each trigger point refreshes
- No background timers or periodic polling

### New on `InviteApiService`

Two methods calling existing server endpoints (not yet wired in the app):

- `getInviteStatus()` -- `GET /v1/invite-status` with NIP-98 auth
- `generateInvite()` -- `POST /v1/generate-invite` with NIP-98 auth

### New Model

`InviteStatus`:
- `canInvite: bool`
- `remaining: int`
- `total: int`
- `codes: List<InviteCode>`

`InviteCode`:
- `code: String`
- `claimed: bool`
- `claimedAt: DateTime?`
- `claimedBy: String?` (hex pubkey)

---

## UI: Settings Integration

### Account Header

The invites row lives in the settings account header area (below profile info, above the main settings menu):

- Always visible as a tappable row labeled "Invites"
- Shows a count badge when unclaimed codes exist
- Navigates to `/settings/invites`

### Invites Screen (`/settings/invites`)

- **Header:** "Invite Friends" with subtitle "Share diVine with people you know"
- **Loading state:** Shimmer/skeleton while fetching
- **Available invites:** List of unclaimed codes, each showing:
  - Code in `XXXX-YYYY` format
  - Copy button -- copies share message to clipboard
  - Share button -- opens native share sheet with share message
- **Used invites:** Secondary/collapsed section showing claimed codes with claimer info (resolved to profile name if possible) and timestamp
- **Empty state:** "No invites available right now" when `canInvite: false` or no codes
- **Error state:** Retry button

### Share Message

```
Join me on diVine! Use invite code XXXX-YYYY to get started:
https://divine.video/invite/XXXX-YYYY
```

---

## UI: Notifications Tab Integration

When the notifications tab opens, the cubit fetches invite status. If unclaimed codes exist, a synthetic notification card appears at the top of the "All" tab:

- Icon: gift/invite-style icon (distinct from bell/system notifications)
- Text: "You have N invites to share with friends!"
- Tapping navigates to `/settings/invites`
- Not persisted to the relay -- derived from invite status API response
- Disappears when all codes are claimed or `canInvite: false`

No changes to the relay notification system or notification types.

---

## Server Prompt (divine-invite-darshan)

The following changes are needed on the invite server:

### Grant-on-read in `GET /v1/invite-status`

When handling an authenticated `GET /v1/invite-status` request:

1. Look up the user's current invite allocation by their pubkey
2. If the user has no allocation OR all codes are claimed, evaluate the grant policy:
   - Check when the user first consumed an invite (account age)
   - Check when invites were last granted to this user (cooldown)
   - Apply any server-configured rules (max grants per user, global rate limits, etc.)
3. If policy says yes: generate N new codes, associate them with the user's pubkey, persist to KV store
4. Return the full invite status including any newly granted codes
5. If policy says no: return current status as-is (which may be `canInvite: false, codes: []`)

The grant policy should be configurable via the `invite_config` config store so it can be tuned without redeployment. Suggested config keys:

- `grant_cooldown_hours` -- minimum hours between auto-grants (default: 168 / 1 week)
- `grant_count` -- number of codes to grant per auto-grant (default: 3)
- `min_account_age_hours` -- minimum account age before eligible for auto-grants (default: 48)
- `max_total_grants` -- maximum total codes a user can be auto-granted (default: 15)

No new endpoints. No changes to response shapes. The grant logic is invisible to the client.

---

## What's NOT in scope

- Push notifications (FCM) for invite grants
- Background polling or timers in the app
- New server endpoints
- Admin UI for managing grants (existing admin endpoints suffice)
- Invite purchase (Cashu buy flow) -- already exists separately
- Invitation graph visualization
