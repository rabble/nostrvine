# Nostr-First CAWG Identity Publishing Design

Status: Approved for planning on 2026-03-29.

## Goal

Publish Divine videos with portable identity metadata that survives outside Nostr while keeping authorship anchored to the creator's Nostr key.

## Problem

Today Divine publishes:

- a user-signed Nostr event
- C2PA provenance and ProofMode data inside the media
- optional CAWG training-mining preferences

That is enough for Nostr-native authorship and some provenance, but it does not make creator identity portable when the media file leaves Nostr. CAWG Identity 1.2 solves the portability problem, but its standard signing paths do not make a Nostr key the primary author-signing mechanism.

## Product Requirements

- Nostr remains the primary identity system.
- The creator, not Divine, signs the authorship binding for the media.
- The identity layer should be visible to apps that inspect the media outside Nostr.
- Divine may run one verifier at `verifier.divine.video`.
- The verifier may attest to external claims only:
  - `nip05`
  - website or domain control
  - social handles
- Social verification should support OAuth first and public-proof fallback.
- CAWG issuance must be additive and non-blocking. If it fails, user-signed publishing still succeeds.

## Non-Goals

- Divine certifying that a user controls the Nostr key they just used
- Divine acting as the source of truth for authorship
- personhood, copyright ownership, or "human verified" claims
- full inbound CAWG verification UX in Divine v1
- multi-verifier federation in v1

## Trust Model

### Primary trust signal

The creator's Nostr pubkey is the source of truth for authorship.

The media file should carry an asset-specific assertion signed by the same Nostr key used to publish the Nostr event. That assertion answers:

- which pubkey created this asset binding
- which asset-specific provenance statements that pubkey is standing behind

### Secondary trust signal

`verifier.divine.video` is an optional identity attester. It does not replace the Nostr trust model. It only says:

- this pubkey was linked to this `nip05`, domain, and/or social handle
- the link existed at issuance time
- Divine observed the link using a documented verification method

### Portability

When a file leaves Nostr, external viewers can still inspect:

- C2PA provenance
- the user-signed creator binding
- the CAWG identity credential issued by `verifier.divine.video`

That gives Nostr-native authorship plus CAWG-readable identity portability.

## Architecture

The final media file should carry two identity layers:

### 1. Divine custom creator-binding assertion

Proposed label:

`video.divine.nostr.creator_binding`

Purpose:

- bind the creator's Nostr key to the asset-specific provenance statement
- keep authorship 100% user signed

Proposed content:

- `version`
- `pubkey`
- `sig_alg`
- `created_at`
- `claims`
- `claims.nip05` optional
- `claims.website` optional
- `claims.social_handles` optional
- `referenced_assertions`
- `hard_binding`
- `signature`
- `signer_hint` optional

The signature payload must be canonical and asset-specific. It should include the selected hard-binding assertion plus the assertion references the creator is explicitly standing behind.

### 2. CAWG identity assertion

Label:

`cawg.identity`

Purpose:

- make verified external identity claims portable to non-Nostr apps and Content Credentials viewers

For v1, Divine should use the CAWG Identity 1.2 `cawg.identity_claims_aggregation` path. The verifier-issued credential should include only verified external claims and verifier metadata. It should not restate authorship as though Divine were the author.

## Verification Methods

### NIP-05

Divine verifies that the claimed `nip05` resolves to the same pubkey that signed the creator-binding assertion.

### Website or domain

Divine verifies domain control using one or more supported methods:

- DNS record
- file-at-URL proof
- meta tag proof
- administrative email where available

### Social handles

Phase 1 supports:

- OAuth or federated login when supported by the provider
- public-proof fallback when OAuth is unavailable

Public proof means the user places a verifier-issued nonce in a verifiable public location controlled by the social account, such as a profile bio or post.

## Publish Flow

1. User records or imports media.
2. Mobile constructs the normal C2PA manifest with actions, hard binding, ProofMode data, and training-mining preferences.
3. Mobile computes the canonical creator-binding payload from asset-specific C2PA data.
4. The user's Nostr key signs that payload.
5. Mobile adds `video.divine.nostr.creator_binding` to the manifest.
6. Mobile sends optional identity claims to `verifier.divine.video`.
7. The verifier validates claims and returns a CAWG identity assertion payload or signed credential for embedding.
8. Mobile embeds the CAWG identity assertion if available.
9. Mobile finalizes the media file and publishes the normal Nostr event with the same pubkey.

Failure behavior:

- If the verifier is unavailable, publish with the user-signed creator binding only.
- If one claim fails verification, omit only that claim.
- If no external claims are verified, the publish path still succeeds.

## Verifier Responsibilities

`verifier.divine.video` may attest only to:

- verifier identity
- verification method
- verification timestamps
- the external identifiers that were verified for the same pubkey

It may not attest to:

- authorship independent of the user's signature
- bare key ownership as a separate trust claim
- ownership, rights transfer, or personhood

## Nostr Event Layer

The Nostr event remains unchanged as the canonical Nostr publish action, but Divine should add discovery tags that tell Nostr-native clients:

- this media contains a user-signed creator binding
- this media optionally contains verifier-issued CAWG identity metadata

These tags are hints only. They do not replace inspecting the embedded media metadata.

## Technical Constraints

The current `c2pa_flutter` usage in Divine relies on a simple JSON manifest path. CAWG identity creation requires more control:

- placeholder assertions
- deterministic referenced-assertion hashing
- replacement of placeholder assertion bytes after signature collection
- access to active manifest assertion references before final signing

That means Phase 1 depends on extending the `c2pa_flutter` fork or upstream API before full CAWG embedding can ship.

## Shipping Gate

As of 2026-03-29, this repo can ship the intermediate milestone:

- creator-signed Nostr binding data carried in media proof payloads
- optional verifier metadata transport
- Nostr discovery tags for binding and portable identity hints

This repo does not yet ship strict full CAWG embedding because that still
depends on `c2pa_flutter` support for placeholder assertions, referenced
assertion hashes, placeholder replacement, and final insertion before signing.

Separately, `verifier.divine.video` still needs production OAuth adapters,
public-proof challenge flow, NIP-05/domain endpoints, CAWG issuance, and
issuer metadata. Those are external deliverables, not mobile-only changes.

## Rollout Plan

### Phase 1

- publishing only
- one verifier: `verifier.divine.video`
- external claims: `nip05`, website/domain, social handles
- user-signed creator-binding assertion
- optional CAWG overlay

### Phase 2

- inbound verification and display inside Divine
- badge and explanation updates
- viewer-side verifier trust configuration

### Phase 3

- support third-party verifiers in addition to Divine
- policy and trust configuration for multiple issuers

## Key Decision

Divine should ship a Nostr-first model with a CAWG overlay:

- authorship is always creator signed
- external identity is optionally verifier attested
- CAWG exists for portability, not control
