# Brainstorm: Collaborator accept/ignore actions have no effect (#4192)

Date: 2026-05-11 (v2 — re-run after end-to-end code verification)

## Problem Statement

When the inviter posts a video with collaborators, mobile writes
`['p', pubkey, relay, 'collaborator']` tags onto the kind-34236 event eagerly
on initial publish (`video_event_publisher.dart:835`) and on edit-republish
(`share_video_menu.dart:1567`). Every render surface — `CollaboratorAvatarRow`
in the feed item (`video_feed_item.dart:1699-1702`), `MetadataCollaboratorsSection`
in the expanded sheet (`metadata_user_chips.dart:36-60`) — reads
`video.collaboratorPubkeys` directly from the parsed event tags
(`video_event.dart:436-445`). When the recipient taps Accept,
`CollaboratorResponseService.acceptInvite` publishes a kind-34238 event with
`['status', 'accepted']` (`collaborator_response_service.dart:54-87`), but
**no mobile code anywhere subscribes to, parses, or reads kind-34238** —
verified at confidence 1.00 by grepping every `.dart` file in `mobile/lib`
and `mobile/packages`: exactly one non-test occurrence of `34238`, the
constant definition itself. When the recipient taps Ignore, the local
invite store transitions to `ignored` (`collaborator_invite_actions_cubit.dart:89-98`),
but the local store has only one read consumer in the entire codebase:
the same DM card that wrote it. The visible result: Accept and Ignore
both produce only the literal "Accepted" / "Ignored" status text inside
the DM card; the video itself, the inviter's view, every third party's
view, and the recipient's own collabs tab are all unchanged.

## Constraints

- Layered architecture: UI → BLoC → Repository → Client. Source-selection
  and fallback logic belong in the repository layer
  (`.claude/rules/architecture.md`).
- BLoC-first for new state management; Riverpod legacy only.
- Dark mode; `VineTheme` and `divine_ui`.
- The Nostr protocol shape is *intentionally settled* on kind-34238 by
  PR #4045 (merged 2026-05-06 — three days before #4192 was filed).
  PR #4040 (the same day, 8 hours earlier) tried the video-copy
  approach and was reverted. The team's verified preference is
  kind-34238 + spec-aligned semantics.
- Two-repo lifecycle plan exists:
  `docs/superpowers/plans/2026-04-25-collab-full-lifecycle.md` — 18
  tasks, Funnelcake-first. #4192 is item 1 ("accept/ignore action
  correctness") of parent epic #4201's execution order.
- Engineering standard from #4192: "Fix the problem without adding
  new technical debt. If the touched path already has known audit or
  refactor debt, repay the relevant portion as part of the
  implementation."
- Memory: never stack PRs; PR title must be conventional-commit;
  rebase onto fresh `origin/main` before push.

## Prior Art (verified)

- **Spec**:
  `docs/superpowers/specs/2026-04-25-collab-invite-acceptance-design.md`
  defines pending vs confirmed semantics. §"Protocol Shape" intends
  pending collaborators to be on the latest creator-authored video
  event with role `Collaborator`; confirmation derives from
  (creator tag) ∧ (kind-34238 acceptance) ∧ Funnelcake current-state
  edge.
- **Lifecycle plan**:
  `docs/superpowers/plans/2026-04-25-collab-full-lifecycle.md` —
  Funnelcake Tasks 1–6 ship the `video_collaborators_current_data`
  read model; Mobile Tasks 15–17 flip the read paths.
- **Already shipped in mobile** (verified by reading each file):
  - `collaborator_response_service.dart` — kind-34238 publish.
  - `collaborator_invite_actions_cubit.dart` — accept (publish +
    local-store) and ignore (local-store only).
  - `collaborator_invite_card.dart` — only consumer of the local
    invite store.
  - `funnelcake_api_client.dart:739` `getCollabVideos` — confirmed-
    edges contract on the mobile side; consumed only by
    `profile_collab_videos_bloc.dart` (2 call sites).
  - `share_video_menu.dart:1565-1633` — post-publish add re-publishes
    kind-34236 with collaborator p-tag and sends NIP-17 invite.
- **Recent git history that matters** (full `git log --oneline`
  verified):
  - #3373 → #3559/#3566 → #3683 → #3686 → #3845 → #3888 (model
    requires the role marker) → #4040 (video-copy approach) →
    **#4045 (reverted to kind-34238)** → #4093 (publish-result
    refactor). The protocol path has settled on kind-34238 with
    explicit intent.

## Reframe given verified context

The earlier brainstorm reasoned about three competing approaches
without verifying which protocol path the team actually chose three
days before the bug was filed. With the #4040 → #4045 sequence in
hand, two things are now clear:

1. The team **explicitly rejected** the "publish a video copy on
   accept" approach (#4040) and chose kind-34238 with read-side
   confirmation TBD. Any new approach that re-proposes the video-
   copy semantics needs to address why #4045 reverted it.
2. The bug is **not** that the protocol is wrong. The bug is that
   the read side of the chosen protocol is empty. The fix is to
   add the missing read side, not to change the wire format.

This narrows the design space considerably.

## Approaches Explored

### Approach A — Wire confirmed-status into every render site (full read-side)

**Description.** New mobile-only read path: subscribe to kind-34238
events from the relay for every video address currently rendered or
addressed by an open BLoC, dedup by `(videoAddress, collaboratorPubkey)`,
verify against the latest creator-authored kind-34236 tags, and
expose per-video `Map<String, CollaboratorStatus>`. Every render site
(`CollaboratorAvatarRow`, `MetadataCollaboratorsSection`, the share
sheet edit dialog) consumes the map and shows only confirmed
collaborators; the inviter sees a pending decoration for unaccepted
entries on their own video.

**Layers affected:** Client (new relay subscription); Repository (new
package `collaborator_repository`); BLoC (new
`VideoCollaboratorStatusCubit`); UI (three render sites + edit dialog).

**Pros:**

- Covers items 1, 2, and 3 of epic #4201 acceptance criteria
  ("accept/ignore correctness"; "confirmed collaborator state
  consistency"; "profile/feed rendering correctness") with one
  shipped PR.
- Aligns with #4045's settled protocol.
- Composable with the lifecycle plan: the new repository can later
  swap from "relay subscription" to "Funnelcake confirmed-edges
  endpoint" without touching cubits or UI.

**Cons:**

- Largest scope. Relay traffic scales linearly with visible-video
  count; needs ref-counted subscription dedup, viewport-aware
  unsubscribe, and TTL caching to stay sane on hot feeds.
- Changes third-party viewer behavior (hides pending collaborator
  avatars from non-author / non-collaborator viewers). That's a
  visible regression vs today, even if it's product-correct. Needs
  product sign-off.
- The "verify against latest kind-34236" cross-check requires
  mobile to track the creator-authored event for each video, which
  is what `VideoEventService` already does — but plumbing the join
  to the kind-34238 stream is non-trivial.

**Risks / Unknowns:**

- Is the visible regression for third-party viewers acceptable, or
  do we keep current behavior for them and only fix
  inviter/recipient visibility?
- Performance impact on cold start when the home feed renders 30+
  videos that each have a collaborator (each adds a subscription).

**Complexity:** High.

### Approach B — Defer the `'collaborator'` p-tag until acceptance

**Description.** Drop the role tag from initial publish. Mobile
subscribes to kind-34238 for own-authored videos; on acceptance,
re-publish the replaceable kind-34236 with the now-confirmed
collaborator added.

**Eliminated.** The spec §"Protocol Shape" explicitly commits to
"pending collaborators are represented on the latest creator-
authored video event with role `Collaborator`." Re-publishing the
replaceable event on every acceptance is exactly the race that
#3705 is filed for ("Transient duplicate video on own profile
during collab accept via Connect"); making it worse before #3705
is fixed is unacceptable. Also breaks interop with Connect, which
already follows the current shape.

**Complexity:** High; rejected on correctness.

### Approach C — UI-honesty cosmetic patch

**Description.** Keep behavior; rename Accept/Ignore to
"Acknowledge"/"Hide"; clarify in copy that the collaboration is
attached on publish and the recipient's role is to acknowledge.

**Eliminated.** Issue body explicitly cites the engineering
standard "Fix the problem without adding new technical debt …
repay the relevant portion as part of the implementation."
Acknowledging the bug in copy does not satisfy "fix"; the parent
epic's item 1 ("recipient accept/ignore works reliably") is not
met.

**Complexity:** Low; rejected on scope-vs-standard mismatch.

### Approach D — Wait for the full two-repo lifecycle

**Description.** Block #4192 on `docs/superpowers/plans/2026-04-25-collab-full-lifecycle.md`
Tasks 1–6 (Funnelcake) and 15–17 (mobile read flip).

**Eliminated.** Two-repo coordination, slow, scope-creep, and
duplicates the existing plan rather than executing on #4192. The
mobile half of the read fix can be shipped first using a relay
subscription and *later* swap data sources to Funnelcake without
touching consumers (this is Approach A's composability story).

**Complexity:** High; rejected on scope.

### Approach E — Revive #4040 (kind-34236 video copy on accept)

**Description.** Re-introduce the video-copy protocol that #4040
shipped briefly. Accept publishes a kind-34236 authored by the
accepter referencing the source video. Read side becomes trivially
"is there a video copy from this collaborator?".

**Eliminated.** The team reverted this approach in #4045 eight
hours later on the same day. Without a documented reason for
revisiting the decision, a new PR proposing it again would
re-litigate a decision the area DRI (`@rabble`) just made. If the
revert reason was specifically "no read side yet" we could revisit,
but: #4045's PR body says "Stop copying the source video event
under the collaborator pubkey" — i.e., the conflation between
"collaborator" and "author of a copy" was the issue, not the read
side.

**Complexity:** Medium; rejected on social grounds.

### Approach F — Scope to inviter + recipient observability (narrow read side)

**Description.** Same architectural shape as Approach A —
subscribe to kind-34238, expose per-video confirmed status — but
narrower scope:

- **Mobile subscribes** to kind-34238 events filtered to videos
  authored by the current user **only** (one subscription per
  own-authored video with collab p-tags). This bounds traffic to
  N = own-videos-with-collabs, which is small.
- **Inviter side render**: on the inviter's own videos
  (in their home feed, their profile feed, the metadata sheet,
  the share edit dialog), show "pending" decoration for tagged-
  but-not-accepted collaborators; full avatar/chip for confirmed
  collaborators. After a recipient accepts, the relay echo flips
  the avatar from pending to confirmed within seconds —
  observable end-to-end.
- **Recipient side render**: the local invite store
  (`accepted`/`ignored`) is consulted for the *current user as
  collaborator on this video*. When the current user is rendered
  in `CollaboratorAvatarRow` and their local store says
  `ignored`, hide their own avatar from their own view of the
  video; when `accepted` or `pending`, show normally. Ignore now
  has a visible effect: the recipient stops seeing their own
  avatar on the video.
- **Third-party viewers**: unchanged. They continue to see raw
  collaborator p-tags as today. The wider product-correct fix
  (hide pending from third parties) defers to the lifecycle
  plan / #4201's broader acceptance criteria.

**Layers affected:** Client (kind-34238 subscription, scoped);
new Repository package `collaborator_repository`; BLoC
(`VideoCollaboratorStatusCubit`); UI (`CollaboratorAvatarRow`,
`MetadataCollaboratorsSection`, share sheet edit dialog).

**Pros:**

- **Targets exactly the bug as filed.** "Accept and ignore actions
  have no effect" — after this PR, both actions have visible,
  testable, end-to-end effects:
  - Accept → inviter's avatar flips from pending to confirmed.
  - Ignore → recipient's own avatar disappears from their own view.
- **Bounded relay traffic.** Subscription scope is "own-authored
  videos with collab p-tags" — orders of magnitude smaller than
  Approach A's "every visible video".
- **No third-party regression.** Anyone outside the inviter/
  recipient pair sees the same thing they see today. Avoids the
  product-sign-off blocker.
- **Composable with the lifecycle plan.** The repository's
  source can later swap from relay to Funnelcake without touching
  cubit or UI; the third-party render flip becomes a one-line
  feature flag in the cubit once Funnelcake is ready.
- **Repays the touched-path debt.** The hardcoded English in
  `metadata_user_chips.dart:27,49,77,125` ("Creator",
  "Collaborators", "Inspired by", "Reposted by") sits on the
  modified file; running an l10n pass on it satisfies the
  engineering standard's debt-repayment requirement.

**Cons:**

- Item 2 of epic #4201 acceptance ("confirmed collaborator state
  consistency across DM/UI/REST/relay") is only partially met —
  third-party REST/relay consistency stays out of scope until the
  Funnelcake half lands.
- Inviter-side relay subscription introduces a new always-on
  consumer per authored video. Need lifecycle ownership (when does
  the subscription end? when the video is deleted? when the user
  signs out?).

**Risks / Unknowns:**

- If the inviter has 100s of own videos with collabs, 100s of
  active subscriptions. Mitigation: subscribe lazily when the
  inviter renders the metadata sheet or edit dialog for that
  video; for the home feed, accept the lazy-load gap (avatars
  appear once the subscription resolves).
- The cross-check "kind-34238 from a tagged pubkey + creator-side
  tag still present on latest kind-34236" is mobile-side
  reproduction of Funnelcake's planned `video_collaborators_current_data`
  logic. Has to be re-verified on every replaceable update.

**Complexity:** Medium-High.

## Recommendation

**Approach F**, with the explicit understanding that:

- It directly fixes the issue as filed (#4192 = "accept/ignore
  has no effect" — both gain visible effects for the people
  performing the action).
- It defers the third-party rendering question to the lifecycle
  plan, where it belongs.
- It is composable with Approach A: if/when product wants the
  full third-party fix, the same `collaborator_repository`
  package gains an option to subscribe to kind-34238 for any
  rendered video, not only own-authored — and the cubit + UI
  paths are unchanged.

Rationale ranked by weight:

1. **Right-sized to the issue.** The bug title is about
   accept/ignore actions having no effect. Approach F makes
   both actions have observable, testable effects end-to-end.
2. **No social blocker.** Doesn't re-litigate #4045's protocol
   decision; doesn't require product sign-off on third-party
   regression.
3. **Bounded scope.** One PR, one new package, three render
   sites, one cubit. Reviewable in one sitting.
4. **Composable.** The same repository becomes the home for
   the third-party fix later (Approach A extension) and the
   Funnelcake swap later (lifecycle plan).
5. **Repays touched-path debt** (l10n in `metadata_user_chips.dart`)
   per #4192's engineering standard.
6. **Aligns with `state_management.md`** — the repository
   carries the source-selection / cross-source join logic; the
   cubit only exposes state; UI only reads state.

## Open Questions for /plan

- [ ] Subscription lifecycle: does the inviter's
      kind-34238 subscription start at login (for all
      own-authored videos with collabs) or lazily when a
      relevant surface (metadata sheet / edit dialog / their
      own feed) renders the video? Tradeoff: eagerness costs
      relay sockets but makes first-render correct;
      laziness defers the cost but adds a "loading" state.
- [ ] Repository instance scope: app-wide singleton or
      per-screen? App-wide is simpler for dedup but couples
      to auth lifecycle (sign-out must close subscriptions
      and clear cache).
- [ ] Should `ignoreInvite` continue to be local-only per
      spec §"Accept Flow"? (Brainstorm v1 raised this; the
      verified protocol decision in #4045 means yes — keep
      ignore local; no kind-34238 with `status: 'ignored'`.)
- [ ] Inviter-side "(pending)" copy and styling — product
      decision: greyed avatar, hourglass icon, "Pending"
      label, hidden entirely? Today the avatar row has no
      empty/loading state; will need a small design touch.
- [ ] Scope of l10n pass on `metadata_user_chips.dart`:
      add the 4 hardcoded English strings ("Creator",
      "Collaborators", "Inspired by", "Reposted by") to ARB
      in the same PR? Aligns with the engineering standard
      but expands scope to a touched-path fix.
- [ ] Does `share_video_menu.dart`'s edit dialog flow
      benefit from the same per-pubkey status? The inviter
      currently can remove a collaborator (republish without
      the tag) but can't see at a glance which are pending.

## Prerequisites

- [ ] Confirm `nostr_client` exposes a way to subscribe to
      `kinds: [34238]` with a `#a` filter — verified via
      `subscribed_list_video_cache.dart:284-291` precedent
      that does `Filter(kinds: [kind], authors: [pubkey], d: [dTag])`
      — `#a` filter support is the open question, since
      kind-34238 uses an `a` tag, not a `d` tag, for the
      video address.
- [ ] Decide subscription lifecycle (open question above).

## Next Step

Run `/plan https://github.com/divinevideo/divine-mobile/issues/4192`
to produce the concrete implementation plan for Approach F. The
plan should explicitly note: scope is mobile inviter + recipient
visibility only; third-party rendering parity defers to the
lifecycle plan and the broader items 2–4 of epic #4201.
