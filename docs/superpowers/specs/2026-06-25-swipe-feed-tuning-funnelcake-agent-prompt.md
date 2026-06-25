# Briefing prompt — funnelcake/Gorse agent

Companion to `2026-06-25-swipe-feed-tuning-design.md` (the divine-mobile client
spec). Hand the fenced block below to an agent working in the funnelcake / Gorse
backend. It is self-contained — the agent does not need access to the mobile
repo.

---

````markdown
# Task: ingest Divine "feed-tuning" Nostr events into Gorse to personalize recommendations

You're working in the funnelcake / Gorse backend. The divine-mobile client is
shipping a "swipe to tune your feed" feature: swipe right = "more like this",
swipe left = "less like this" on a video. Each swipe publishes a small public
Nostr event to the relay. **Your job is the backend half: read those events off
the relay and feed them into Gorse so they reshape that user's recommendations**
(the `GET /api/users/{pubkey}/recommendations` endpoint the app already calls).

Start by using the `using-divine-brain` skill to ground yourself in how
funnelcake, the relay, and Gorse fit together, and read the relay LLM guide
(`https://relay.divine.video/docs/llm-guide`).

## The event contract (what the client publishes)

A **dedicated regular (append-only) Nostr kind owned by Divine** — NOT a standard
kind. (Deliberately not NIP-32 kind 1985, to avoid colliding with moderation
tooling. It is recommendation feedback, never a moderation/block signal.)

```jsonc
{
  "kind": 4242,                 // EventKind.feedTuning. Regular range 1000-9999.
  "content": "",
  "tags": [
    ["direction", "more"],                              // "more" | "less"
    ["e", "<videoEventId>", "<relayHint>"],             // the video — ALWAYS present, authoritative item key
    ["a", "34236:<authorPubkey>:<dTag>", "<relayHint>"],// addressable coord — present ONLY when a real d-tag exists
    ["p", "<authorPubkey>"],                            // creator — for creator-level generalization
    ["t", "<hashtag>"],                                 // 0..n topic tags — for topic-level generalization
    ["k", "34236"]                                      // target event kind
  ]
}
```

Semantics you must honor:
- **`e` is the authoritative item id, always present.** Key your Gorse item on
  `e`; treat `a` / `k` / `p` / `t` as enrichment. Expect and tolerate `e`-only
  events (`a` is omitted when the source video has no trustworthy d-tag).
- **Append-only, latest-wins.** A user may swipe a video multiple times; the
  newest event by `created_at` for a given (pubkey, target) is current intent.
- **Undo / retract = NIP-09.** A kind-5 deletion event referencing a feed-tuning
  event id means "forget that signal." Handle deletions.
- `pubkey` = the user, video = the item, `direction` = positive/negative feedback.

## What to figure out (design before you build)

Produce a short spec, then a plan, then implement. Decide and document:

1. **Ingestion path.** How does funnelcake consume relay events today
   (subscription, crawler, batch)? Add the new kind to that path. The relay must
   allow-list the kind before events flow (see Coordination).
2. **Gorse mapping.** Map to Gorse's feedback model (user, item, feedback type,
   timestamp):
   - How do "more"/"less" become Gorse feedback? Check the deployed Gorse
     version's negative-feedback support (see the `gorse-*` skills and the live
     config) before deciding the feedback-type taxonomy.
   - How do `p` (creator) and `t` (topic) generalize? **KISS: start item-level
     only** unless creator/topic clearly adds value — the tags are there when you
     want them; let Gorse's own collaborative filtering generalize first.
   - Reflect latest-wins + deletions in Gorse (overwrite / delete feedback row /
     tombstone).
3. **Idempotency & volume.** Swiping is high-frequency. Ingestion must be
   idempotent on event id and tolerate bursts.
4. **Verification.** Prove a "less" swipe actually demotes that item in
   `/api/users/{pubkey}/recommendations`. Define a test or manual check.

## Coordination with the mobile side (cross-repo, do not skip)

- **The kind number is pinned on mobile.** Use kind `4242` for funnelcake
  ingestion so both repos agree on the same regular-range constant.
- **Relay allow-listing.** The relay rejects unknown kinds by policy in some
  paths. Get the new kind accepted or the whole loop is inert.
- These are the critical-path blockers; surface them early.

## Constraints

- Recommendation input only. Never wire into moderation, blocking, reporting, or
  trust/reputation surfaces.
- Don't truncate Nostr ids anywhere (ids, logs, analytics).
- Follow funnelcake's existing deploy workflow (`funnelcake-deployment-workflow`
  skill); don't hand-edit production config without it.

Deliver: a short design doc + implementation plan, the agreed kind number, and
the relay allow-list status. Flag open questions back rather than guessing on
Gorse taxonomy.
````
