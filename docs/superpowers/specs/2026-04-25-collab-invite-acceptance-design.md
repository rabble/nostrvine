# Collaborator Invite Acceptance Design

## Goal

Replace immediate collaborator tagging with an invite-and-accept flow. A video
collaboration should mean "this is also my work", not "I reposted this".

## Product Semantics

Collaborators are co-creators. The app must not represent collaborator
acceptance as a repost, and collaborator acceptances must not increment repost
counts or create repost feedback for ranking systems.

The creator can invite collaborators while preparing a video. Invited users see
an encrypted invite and can accept or ignore it. Accepted videos appear under
the collaborator's collab/profile/feed surfaces as canonical original videos
with collaborator context.

## Protocol Shape

Video events remain the canonical media object:

- Kind `34235` or `34236`
- Addressed by `<kind>:<creatorPubkey>:<dTag>`
- Creator-authored only

Pending collaborators are represented on the latest creator-authored video event
with NIP-53-style role tags:

```json
["p", "<collaborator_pubkey>", "<relay_hint>", "Collaborator"]
```

Confirmed collaborators may later be represented with an embedded proof:

```json
["p", "<collaborator_pubkey>", "<relay_hint>", "Collaborator", "<proof>"]
```

The proof follows the NIP-53 idea: the collaborator signs the SHA-256 hash of
the complete video address string, and the proof is encoded as hex.

The MVP should also support a public acceptance event so collaborators can
accept while the creator is offline. The final event kind needs Funnelcake
allowlist agreement before implementation. The intended tags are:

```json
["a", "34236:<creator_pubkey>:<d_tag>", "<relay_hint>", "root"]
["p", "<creator_pubkey>"]
["role", "Collaborator"]
["proof", "<signature_hex>"]
```

An acceptance event alone does not grant collaborator status. Funnelcake should
only confirm it when the latest creator-authored video still names that pubkey
as role `Collaborator`, unless a future creator-signed public invite event is
added.

## Invite Delivery

Invite delivery uses existing NIP-17 encrypted direct messages. The message
should contain a small human-readable body plus structured tags so the app can
render it as a collaborator invite instead of generic chat text.

Suggested rumor tags:

```json
["divine", "collab-invite"]
["a", "<video_address>", "<relay_hint>", "root"]
["p", "<creator_pubkey>"]
["role", "Collaborator"]
["title", "<video_title>"]
["thumb", "<thumbnail_url>"]
```

The plain text body should remain useful in clients that do not understand the
tags.

## Funnelcake Query Contract

Hot queries should not rely on ad hoc joins against historical
`event_tags_flat_data`. Funnelcake should materialize current collaborator
state keyed by latest logical video address:

`video_collaborators_current_data`

- `collaborator_pubkey FixedString(64)`
- `status Enum8('pending' = 0, 'confirmed' = 1, 'invalid' = 2)`
- `video_event_id FixedString(64)`
- `video_kind UInt16`
- `video_pubkey FixedString(64)`
- `video_d_tag String`
- `video_address String`
- `role LowCardinality(String)`
- `relay_hint String`
- `proof String`
- `confirmation_source Enum8('embedded' = 1, 'acceptance' = 2, 'both' = 3)`
- `acceptance_event_id FixedString(64) DEFAULT ''`
- `created_at DateTime`
- `published_at UInt32`
- `indexed_at DateTime`

Suggested order for current snapshot reads:

```sql
ORDER BY (
  collaborator_pubkey,
  status,
  published_at,
  video_pubkey,
  video_kind,
  video_d_tag
)
```

Following feeds should use a denormalized actor edge table:

`video_feed_edges_current_data`

- `actor_pubkey FixedString(64)`
- `edge_type Enum8('author'=1, 'collaborator'=2)`
- `video_event_id FixedString(64)`
- `video_address String`
- `published_at UInt32`
- `created_at DateTime`

Suggested order:

```sql
ORDER BY (actor_pubkey, published_at, video_event_id)
```

This makes author videos and confirmed collaborator videos the same feed
primitive. Query followed pubkeys once, dedupe video IDs, then join to
`video_stats`.

## Replacement Semantics

Collab state follows the latest logical video address, not historical event IDs.
When a creator republishes a replaceable video event:

- the latest tags are the full current collaborator set
- removed collaborator tags disappear from current collaborator read models
- changed roles/proofs replace prior state
- acceptance events remain valid by address, but only count while the latest
  video still names that collaborator

This is why direct `event_tags_flat_data` reads are insufficient for hot product
queries: it contains historical tags from old versions.

## Mobile Behavior

### Publish Flow

The metadata UI should say "Invite collaborator". Selected users are stored as
pending collaborator pubkeys on the draft. Publishing writes role-based `p` tags
to the video event and attempts to send NIP-17 invite messages after the event
address is known.

If invite delivery fails, the video can still publish with pending tags. The app
should show a non-blocking failure so the creator can retry from the published
video later.

### Inbox Flow

The app should detect NIP-17 messages tagged `["divine", "collab-invite"]` and
render them as collaborator invites with accept/ignore actions. Until the
dedicated UI exists, these messages may appear as normal DMs with structured
body text.

### Accept Flow

Accept signs the video address and publishes the public acceptance event once
Funnelcake confirms the kind and allowlist. Before that endpoint/event kind is
available, mobile can prepare the invite parsing and pending tag publish flow,
but accepted collab state remains blocked on backend support.

### Profile And Feed Reads

The profile collabs tab should eventually request confirmed collabs from
Funnelcake, not raw `p` tags. Until the backend read model ships, existing
client-side filtering can remain as a compatibility fallback but should be
treated as "mentioned/pending-or-legacy", not authoritative confirmed collabs.

## Error Handling

- Invalid pubkey: reject before adding to draft.
- Mutual follow check fails: keep existing rejection behavior.
- Invite DM publish fails: keep video publish successful and surface retry.
- Acceptance proof signing fails: show an error and keep invite pending.
- Acceptance publish fails: do not mark accepted locally as authoritative.
- Funnelcake reports invalid proof: render as pending or invalid, not confirmed.

## Testing

Mobile tests should cover:

- role-based collaborator `p` tags on published video events
- NIP-17 invite message payload construction
- draft state stores pending invitees without treating them as confirmed
- acceptance payload/proof construction once the event kind is finalized
- profile collab client falls back cleanly when confirmed-collab API is absent

Funnelcake tests should cover:

- current read model only reflects latest video replacement state
- pending, confirmed, and invalid status derivation
- acceptance event cannot self-attach without latest creator-authored pending tag
- feed edge materialization for author and collaborator actors
- repost counts exclude collaborator acceptances
