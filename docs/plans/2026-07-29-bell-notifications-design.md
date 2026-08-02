# Design: bell notifications (subscribe to a creator's new posts)

Status: design, not yet approved
Date: 2026-07-29
Companion work: `divine-push-service` PR #34 / issue #33, `divine-funnelcake` (in-app row)

## Problem

Every notification Divine sends today is *"someone acted on your content"* —
like, comment, repost, mention. Users have asked for the inverse: **tell me
when a creator I care about posts**. That is a subscription to someone else's
output, and nothing in the current model supports it.

This doc covers the mobile half: the bell UI, the subscription list we publish,
the preference change that makes delivery possible, and how a new-post push is
parsed and routed on tap. It also states the contract `divine-funnelcake` needs
to honor for the in-app row.

The service half is specified in `divine-push-service`
`docs/plans/new-post-notifications.md`. Read it first; this doc assumes it.

## Protocol shape (agreed with the service)

The subscription list is a NIP-51 people list with a reserved `d` tag,
published by this client and read by the push service:

```
kind 30000
["d", "notify"]
["title", "Notify"]
["p", "<creator-pubkey-hex>"]   × N
```

Replaceable, public, portable. The service maintains a `creator → [subscribers]`
reverse index from it.

---

## Three findings that block the plan as written

I verified the service plan's mobile-side assumptions against `origin/main`
(`9e16e73a2`). Three of them do not hold. Each is a silent failure — nothing
crashes, the feature just does nothing.

### 1. `d=notify` collides with the user-facing People Lists UI — bells are user-deletable

`Nip51PeopleListCodec.decode`
(`mobile/packages/people_lists_repository/lib/src/nip51_people_list_codec.dart:95`)
turns any kind 30000 event into a user-editable `UserList`. It excludes exactly
one reserved identifier:

```dart
static const String blockedDTag = 'block';        // :51
...
if (dTag == null || dTag == blockedDTag) {        // :101
  return null;
}
```

A `d=notify` list is not excluded. It would decode into a `UserList` named
"Notify" and appear in the People Lists UI alongside the user's own lists —
renameable, editable, deletable. A user tidying their lists silently wipes every
bell they have set, and the app gives no indication that is what happened.

**Fix:** replace the single constant with a reserved set, and exclude on
membership:

```dart
/// Reserved `d` tag values for app-managed kind 30000 lists.
///
/// These are excluded from the user-facing list collection so app-managed
/// lists cannot be edited, renamed, or deleted as ordinary people lists.
static const Set<String> reservedDTags = {blockedDTag, notifyDTag};

static const String blockedDTag = 'block';
static const String notifyDTag = 'notify';
```

`blockedDTag` stays as a named constant — it is referenced elsewhere and in the
package's public docs (`people_lists_repository.dart:81`). The docs on `decode`
and the codec's ABOUTME line both need updating; they name `d=block` specifically.

This is the load-bearing fix. Without it the feature is actively destructive.

### 2. `NotificationPreferences` structurally cannot express kind 34236

The service gates delivery on the kind list published in the kind-3083
preferences event. `NotificationPreferences`
(`mobile/lib/models/notification_preferences.dart`) is five fixed booleans, and
`toKindsList()` can only ever emit a subset of `{1, 3, 7, 16}`:

```dart
List<int> toKindsList() {
  final kinds = <int>{};
  if (likesEnabled) kinds.add(7);
  if (commentsEnabled || mentionsEnabled) kinds.add(1);
  if (followsEnabled) kinds.add(3);
  if (repostsEnabled) kinds.add(16);
  return kinds.toList()..sort();
}
```

`push_notification_service.dart:254` publishes exactly this list. So **34236 is
never published today**, and the service's `is_enabled` check gates every
new-post push off.

The service plan (task 4) treats this as a soft ordering dependency — "confirm
the mobile PR publishes preferences alongside the first bell." It is not a
timing risk. It is a guaranteed failure until this model changes. The plan's
statement that *"the client publishes kind 3083 including 34236 at the same
moment it publishes the notify list"* describes work that does not exist yet.

**Fix:** add a sixth flag.

```dart
const NotificationPreferences({
  ...
  this.newPostsEnabled = true,
});
```

- `toKindsList()`: `if (newPostsEnabled) kinds.add(34236);`
- `fromKindsList()`: `newPostsEnabled: kinds.contains(34236)`
- `fromJson`/`toJson`/`copyWith`/`props`: mirror the existing five
- `notification_settings_screen.dart`: a sixth toggle following the existing
  five (`:110`–`:156`)

Note `fromKindsList` defaults every flag from list membership, so a user whose
stored preferences predate this change reads back `newPostsEnabled: false`. That
is correct and self-healing: the first time they touch the settings screen or
set a bell we republish with 34236 included. See [Ordering](#ordering-and-rollout).

The existing "comments and mentions both map to kind 1" limitation is documented
in the model and is unaffected — 34236 is distinct from kind 1, so new-post
pushes toggle independently of video mentions. That part of the service plan
does hold.

### 3. `newPost` is not a routable wire type

`notificationKindFromWire`
(`mobile/lib/notifications/routing/notification_tap_target.dart:92`) switches on
the FCM `type` string and returns `null` for anything unrecognized. The service
will send `type: "newPost"` (the service's `display_name()`), which falls through
to `null` and degrades the tap route.

`parseFcmPayload` itself is type-agnostic and will *not* drop the push — it only
returns null when nothing routable is present, and a new-post push always carries
`referencedAddress`. So the notification displays; only the tap target is wrong.

**Fix:** add `NotificationKind.newPost` to the enum
(`mobile/packages/models/lib/src/notification_item.dart:12`) and a `case
'newPost'` to the wire switch. A new-post notification is video-anchored, so it
routes through the existing `videoAddressableTarget(referencedAddress)` path —
the same one "Inspired by" mentions already use. No new routing logic.

Adding an enum value breaks the exhaustive switch in
`notification_type_icon_spec.dart:40`, which is the desired behavior — the
compiler will demand an icon spec. Use a Phosphor icon per the visual identity
rules; `bell` is the obvious choice and matches the affordance.

`NotificationKind` is described in its own doc comment as "matching the Figma
design spec," so the new value wants a design sign-off, not just a code change.

---

## Bell UI

**Placement.** On the creator's profile, next to Follow. The bell is
follow-gated: visible and tappable only when the viewer already follows the
creator. Unfollowing removes the bell and the subscription together.

**States.** Off (outline bell) / on (filled bell). No third "all posts vs.
highlights" state — we have one notification tier, and inventing a second
control implies a filtering feature that does not exist.

**Feedback.** The toggle is optimistic: flip immediately, publish in the
background, revert with a snackbar on publish failure. Follow the existing
snackbar precedent for failed kind-30000 publishes (there is one already for
block-list publish failure, `app_localizations.dart:13767`).

**Copy** (provisional — needs brand sign-off per `brand-guidelines/TONE_OF_VOICE.md`):

| Surface | String |
|---|---|
| Bell on, confirmation | "You'll hear about new vines from {name}." |
| Bell off, confirmation | "Bell off. No more new-vine pings from {name}." |
| Publish failed | "Couldn't save that. Try again?" |
| Settings toggle label | "New vines from creators you've belled" |

All four are new `app_en.arb` keys and must be mirrored into every other
`app_*.arb` locale or added to `_knownUntranslatedDebt`, per AGENTS.md.

## Publishing the notify list

New repository method rather than routing through `PeopleListsRepository`'s
user-list surface — the reserved list is app-managed and must not be reachable
by list-editing UI (finding 1).

Read-modify-write on the current list:

1. Read the current `d=notify` event. `NostrListServiceMixin.filterMyParameterizedEvents`
   (`nostr_list_service_mixin.dart:107`) already returns the latest event per
   `(kind, d-tag)` and is the right helper — it handles the replaceable-event
   "most recent wins" rule we would otherwise reimplement.
2. Add or remove the creator's pubkey.
3. Re-encode all `p` tags and publish.

Three rules the implementation has to get right:

- **Never truncate pubkeys.** Full 64-char hex on every `p` tag, per repo policy
  and because the service parses them as `PublicKey`.
- **Publish the full list every time.** It is a replaceable event; a partial
  list is a destructive write.
- **Serialize concurrent toggles.** Two fast bell taps racing produces two
  read-modify-write cycles against the same base event, and the loser silently
  drops the other's change. Queue mutations per-list. `PeopleListsRepository`
  already has a mutation-sequencing concept (`people_lists_mutation.dart`) worth
  reusing rather than reinventing.

Unfollow must remove the creator from the list. If that publish fails, the local
state and the relay disagree and the user keeps getting pushes for someone they
unfollowed — retry on next app start rather than dropping it.

## Ordering and rollout

The dangerous rollout is a build that publishes notify lists **without** the
preference change. The service finds watchers, builds targets, then gates every
one of them off at the `is_enabled` check. No error, no push, and it looks like
a service bug — exactly the failure the service plan warns about.

Findings 1–3 and the notify-list publishing must therefore ship in **one mobile
release**. Do not split the preference change into a follow-up PR.

Given that, ordering between the repos is safe in both directions:

- Service first: no notify lists exist, no watchers found, nothing happens.
- Mobile first: bells accumulate, pushes start flowing when the service deploys.

Republish kind 3083 on first launch after upgrade, not only when the settings
screen is opened. Existing users have stored preferences without 34236
(finding 2); waiting for them to visit settings means their first bell silently
does nothing.

## FunnelCake contract for the in-app row

The push is rate-limited to one per (subscriber, creator) per hour. The in-app
feed is **not** — a user who gets one push for a six-post burst opens the app and
sees all six. That is the intended split, and it means FunnelCake needs its own
fan-out rather than mirroring what the push service sent.

FunnelCake already materializes kind 34236 into the notification inbox, but only
when the event carries a `p` tag
(`database/migrations/000188_curated_list_notification_sources.up.sql:23-30`) —
that is the mention path. New-post rows are the case with **no** `p` tag, and
the recipient set cannot be read off the event at all. It has to come from a
join against the `d=notify` subscription lists.

What FunnelCake needs from us:

- The list is public kind 30000, `d=notify`, `p`-tagged. It is on the relay
  already; no new API surface from mobile.
- A `newPost` notification type on the inbox row, matching the push service's
  `display_name()` string exactly. Mobile switches on one string across both
  transports.
- Dedup against the mention path: if a video both mentions the user and comes
  from a creator they have belled, that is **one** row, typed `mention`. Same
  rule the push service applies.

Open question for that team, and the reason this section is a contract and not a
design: this is the inbox's first subscription-driven fan-out. Every existing
source resolves recipients from tags on the event itself. A join against a
subscription table is a different write shape, and the
`notification_list_add_seen` table
(`000188_curated_list_notification_sources.up.sql:59`) is the closest existing
precedent. I have not verified whether the materialization path can express that
join, and I should not design another team's schema. **This needs a FunnelCake
owner before the mobile row is built.**

Mobile can ship bells + push without the in-app row. The row is additive.

## Test plan

Unit:

- `Nip51PeopleListCodec.decode` returns `null` for `d=notify` and for `d=block`;
  still decodes ordinary lists. Regression test for finding 1.
- `toKindsList()` includes 34236 when `newPostsEnabled`, omits it when not.
- `fromKindsList([7, 1, 3, 16])` yields `newPostsEnabled: false` — the
  pre-upgrade shape.
- `notificationKindFromWire('newPost')` returns `NotificationKind.newPost`.
- Notify-list publish: add to empty, add to existing, remove down to empty,
  pubkeys never truncated.
- Concurrent toggles resolve to one list containing both changes.

Widget:

- Bell hidden when not following; visible and toggleable when following.
- Optimistic flip reverts with a snackbar on publish failure.
- Settings screen shows the sixth toggle and republishes on change.

Integration / manual, once the service branch is deployed:

1. Bell creator B from account A. Confirm the kind 30000 `d=notify` event on the
   relay carries B's full `p` tag.
2. Confirm the list does **not** appear in A's People Lists UI.
3. Post as B, confirm A gets a push titled "New vine", and that tapping it opens
   the video rather than falling back to a profile or the inbox.
4. Post again within the hour, confirm no second push.
5. Unbell, confirm the `p` tag is gone from the republished list and pushes stop.
6. Unfollow B while belled, confirm the bell and the subscription both clear.

Per AGENTS.md: run the affected package tests plus `flutter analyze` before any
push, and `dart run build_runner build --delete-conflicting-outputs` if the
`NotificationPreferences` change touches generated code.

## Risks

**Public subscription lists.** `d=notify` is world-readable, so who you have
belled is public. This is a deliberate product tradeoff for portability, decided
on the service side. Worth confirming it survives contact with the bell UI — a
user tapping a bell on a profile has no reason to expect they just published
that fact. If we want it, it needs to be said in the UI, not buried here. **I
think this deserves an explicit product call before the bell ships**, separately
from the protocol decision already made.

**Reserved-tag squatting.** Any user could already have a list with `d=notify`
from another Nostr client. After finding 1's fix it vanishes from their Divine
list UI, and we would overwrite it on their first bell. Rare, but it is data
loss on a replaceable event we do not own. Cheapest mitigation is to check for a
pre-existing `d=notify` list with a `title` we did not write before the first
publish, and leave it alone if so.

**`d=block` is called legacy.** `moderation_providers.dart:220` describes the
kind-30000 block list as legacy, superseded by the kind-10000 mute list. The
service plan cites `d=block` as the precedent to mirror. The *mechanism*
(reserved `d` tag, hidden from list UI) is sound and still live in the codec, so
mirroring it is fine — but we are extending a pattern the moderation code is
moving away from. Not a blocker; worth a sentence of agreement so nobody
deprecates the codec exclusion out from under bells.
