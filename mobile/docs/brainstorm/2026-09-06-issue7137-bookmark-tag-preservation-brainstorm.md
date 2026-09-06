# Brainstorm: preserving kind-10003 tags Divine does not model

Date: 2026-09-06 · Issues: #7137 (+ #7134) · Epic: #8294
Findings: `tasks/findings_7137.md` (local-only)

## Problem Statement

`BookmarksRepository` rebuilds the entire kind-10003 `tags` array from a
four-field `BookmarkItem` model on every save, so anything the model does not
represent is destroyed. Measured against 998 real production lists on
`wss://relay.divine.video`, one Divine bookmark toggle rewrites **93.9 %** of
them, destroying **1 155 whole tags** and **3 item-tag positions**.

Two sibling issues describe the two halves: #7137 (positions past the fourth on
an item tag) and #7134 (whole tags outside `e`/`a`/`t`/`r`). Both are direct
children of epic #8294, both unclaimed, and both live in the same function pair.

## Constraints

- **Layering.** All of this is Repository-layer; no UI, BLoC, or Client change.
  `BookmarksRepository` is the only kind-10003 writer in mobile.
- **Coverage gate.** `packages/bookmarks_repository` is pinned at
  `min_coverage: 100` (`.github/workflows/bookmarks_repository.yaml:31`) and
  currently sits exactly there — 88 tests, 293/293 lines. Every added production
  line needs coverage in the same PR.
- **Protocol.** NIP-51 defines bookmark items as ≤3 positions
  (`["e",id,relay]`, `["a",coord,relay]`, `["t",tag]`, `["r",url]`). NIP-01 puts
  the **author pubkey** at `e[3]`; NIP-10 puts a **marker** at `e[3]` and the
  pubkey at `e[4]`. **No spec puts a petname on any tag this class models.**
- **Publish gate.** Every path to `_publishGlobalBookmarks` is already behind
  `_syncGlobalBookmarks(requireAuthoritative: true)`, so a verbatim array
  captured at adopt-time is always relay-fresh at publish-time.
- **Relay ceiling.** `max_event_tags: 2000`; observed max is 577, median 3. No
  headroom concern from preserving more.
- **House rule.** Never truncate Nostr identifiers; prefer preserving whole
  values over shortening them.

## Prior Art

The repo has already shipped this pattern twice.

1. **`_buildMuteListPublishShape`** — `content_blocklist_repository.dart`, kind
   10000. Non-`p` tags pass through verbatim (`bf913581d`, PR #5435); `p` tags
   keep their relay hint via `sourcePubkeyTags` + `putIfAbsent` (`f1205184e`,
   PR #8260, issue #6750, approved by `mbradley`). Its comment states the
   principle: *"a relay hint … is **ours to preserve, not to invent**."*
2. **The private half of this very file.** `_privateTags` (`:245`) carries the
   decrypted array verbatim and mutates it with `removeWhere` (`:861-865`),
   introduced by PR #7222. Its dartdoc (`:164-166`) already names **both**
   defects as the reason:
   > *"The decrypted array verbatim, not just the entries this client models.
   > Re-encrypting from parsed items would silently drop another client's
   > non-item tags and any tag position past the fourth."*

Searched and **not** found: any reusable "preserve unknown tags" helper. The
closest neighbour, `Nip51PeopleListCodec.encode`, rebuilds from scratch and has
the same latent bug (worth a separate issue).

## Approaches Explored

### Approach A: carry the source tag array verbatim  ⭐ recommended

**Description:** Keep the relay's `event.tags` alongside the parsed items. Build
the publish shape by walking that array: a tag outside `{e,a,t,r}` passes through
unchanged; a modelled tag whose `(type,id)` survives the edit is re-emitted
**whole**; a newly added bookmark mints a minimal `['e', id]`. Directly mirrors
`_buildMuteListPublishShape`, keyed on `(type,id)` instead of pubkey.

**Layers affected:** Repository only.

**Pros:**
- Closes #7137 and #7134 with one walk.
- Not a new design — two shipped in-repo precedents, one in the same file.
- Lets `relay`/`petname` be **deleted** rather than corrected: 401/401 observed
  index-3 values are author pubkeys (398) or empty NIP-10 markers (3); **zero**
  are petnames, and nothing in the app reads either field.
- Also removes the trailing-empty-position defect (Divine currently turns
  `['e',id,relay,'',pubkey]` into `['e',id,relay,'']`).
- Narrows the model, which makes sibling #7135 (bookmark by `a` coordinate)
  easier rather than harder.

**Cons / risks:**
- Four state-mutation sites must stay in sync (`:550` absence-clear, `:1000`
  post-publish, `:1099` adopt, `:1211` snapshot load). The absence-clear is the
  landmine: forgetting it republishes a previous account's tags.
- Keying by `(type,id)` collapses duplicates — 14/998 lists, 102 pairs, all
  byte-identical, so nothing is lost, but it is a behaviour change to disclose.
- Divine stops re-stamping its own `client` tag on lists that already carry one
  (`signer_factory.dart:216-219` skips when `hasClientTag`). Correct, and it
  prevents the accretion #7134 flags, but visible.

**Complexity:** Medium.

### Approach B: widen the model

Add `marker` / `authorPubkey`, or a generic `extraPositions` list, to
`BookmarkItem`.

**Pros:** smallest conceptual change; keeps the parse-into-a-model architecture.
**Cons:** still lossy for anything unmodelled, so #7134 stays open; keeps a field
per position forever; makes #7135 harder. It treats "we modelled the wrong
positions" as "we modelled too few positions."
**Complexity:** Low. **Rejected.**

### Approach C: store the raw tag on `BookmarkItem`

Give each item its `List<String> sourceTag`; `toTag()` returns it.

**Pros:** one source of truth, no parallel array, fewer sync points than A.
**Cons:** the item list only ever holds `e/a/t/r` entries, so non-item tags have
nowhere to live — #7134 needs a second array anyway, at which point this **is**
Approach A with extra steps. Also keeps a per-item copy of data only the publish
path uses.
**Complexity:** Low–Medium. **Degenerates into A.**

### Approach D: literal minimal fix

Make `toTag` non-positional (`tag.add(relay ?? '')`) and capture index 4.

**Pros:** exactly what #7137's "second defect" paragraph asks for; tiny diff.
**Cons:** entrenches a field named `petname` that in production holds an author
pubkey 99.3 % of the time, and pads with empty strings to keep positions aligned
— manufacturing the very trailing-empty artefact Divine already emits. Leaves
#7134 untouched.
**Complexity:** Low. **Rejected — cements the wrong model.**

### Approach E: won't-fix

#7137 alone moves 3 positions on 2 of 998 lists.

**Pros:** honest about isolated severity (S4).
**Cons:** the identical edit is worth 1 155 tags on 936 lists via #7134, and the
epic explicitly tracks both. Declining also leaves Divine as the only NIP-51
client on this relay that flattens other clients' lists.
**Complexity:** None. **Rejected.**

## Recommendation

**Approach A**, scoped to close **#7137 and #7134 together** (confirmed with the
issue owner).

It is the only approach that fixes the actual defect — *rebuilding a replaceable
event from a lossy projection* — rather than making the projection slightly less
lossy. It requires no new rationale, no new abstraction, and no new pattern: the
argument for it is already written in a dartdoc six hundred lines above the bug,
and the implementation already exists for the neighbouring list kind.

## Open Questions for /plan

- [x] Scope: close both issues — **decided**.
- [ ] Does `BookmarkItem` keep `relay`/`petname` as deprecated no-ops, or are they
      deleted outright? (Audit says zero readers, zero non-default callers, and the
      package is `publish_to: none` with one dependent — deletion looks safe.)
- [ ] Where does the verbatim array live: a `_publicTags` field mirroring
      `_privateTags`, or a `_lastKnownRemoteTags` name matching
      `_lastKnownRemoteContent`?
- [ ] Should the SharedPreferences snapshot persist the verbatim array too, or is
      relying on the authoritative-sync gate sufficient? (Gate says sufficient.)
- [ ] Ordering: append new bookmarks at the end (NIP-51 guidance) — confirm the
      current behaviour is preserved.

## Prerequisites

None. No design input, no protocol decision, no new package, no dependency.
Worktree `.worktrees/7137-bookmark-tags`, branch
`fix/7137-preserve-kind-10003-tags` from `origin/main` @ `d061eccafc`.

## Next Step

`/plan 7137` — implementation plan built on `tasks/findings_7137.md` and this
direction.
