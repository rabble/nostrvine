# CAWG Identity Publishing Protocol

Status: Draft for mobile implementation on 2026-03-29.

This document defines the Divine mobile payloads for Nostr-first creator
identity publishing. The goal is to keep authorship anchored to the creator's
Nostr key while making verified external claims portable through CAWG.

## Core Rules

- Nostr remains the source of truth for authorship.
- The creator signs the creator-binding payload with their own Nostr key.
- `verifier.divine.video` may attest only to external claims.
- Divine does not certify authorship, personhood, or rights ownership.
- CAWG issuance is additive and non-blocking.

## Assertion Labels

- Creator binding: `video.divine.nostr.creator_binding`
- CAWG overlay: `cawg.identity`

These labels are stored in mobile proof state as:

- `creatorBindingAssertionLabel`
- `cawgIdentityAssertionLabel`
- `creatorBindingPayloadJson`
- `verifiedIdentityBundleJson`

## Canonical Creator-Binding Payload

Version `1` uses the following canonical JSON field names:

```json
{
  "version": 1,
  "pubkey": "<creator hex pubkey>",
  "sig_alg": "nostr.secp256k1",
  "created_at": "2026-03-29T08:30:00Z",
  "claims": {
    "nip05": "alice@example.com",
    "website": "https://example.com",
    "social_handles": [
      {
        "platform": "github",
        "handle": "alice"
      }
    ]
  },
  "referenced_assertions": [
    "c2pa.hash.data",
    "c2pa.actions.v2"
  ],
  "hard_binding": {
    "alg": "sha256",
    "value": "<binding digest>"
  },
  "signature": "<creator signature hex or base64url>"
}
```

### Required Fields

- `version`
- `pubkey`
- `sig_alg`
- `created_at`
- `claims`
- `referenced_assertions`
- `hard_binding`
- `signature`

### Optional Claim Fields

- `claims.nip05`
- `claims.website`
- `claims.social_handles`

`social_handles` is an array of objects with:

- `platform`
- `handle`

## Verifier Request

Mobile sends only claims the creator wants verified. Example:

```json
{
  "pubkey": "<creator hex pubkey>",
  "requested_claims": {
    "nip05": "alice@example.com",
    "website": "https://example.com",
    "social_handles": [
      {
        "platform": "github",
        "handle": "alice",
        "method": "oauth"
      },
      {
        "platform": "x",
        "handle": "@alice",
        "method": "public_proof"
      }
    ]
  },
  "creator_binding": {
    "assertion_label": "video.divine.nostr.creator_binding",
    "payload_json": "<creatorBindingPayloadJson>"
  }
}
```

## Verifier Response

The verifier returns only the claims it successfully verified. Example:

```json
{
  "issuer": "verifier.divine.video",
  "status": "partial_success",
  "verified_claims": [
    {
      "type": "nip05",
      "value": "alice@example.com",
      "method": "nip05_dns",
      "verified_at": "2026-03-29T08:35:00Z"
    },
    {
      "type": "social_handle",
      "platform": "github",
      "value": "alice",
      "method": "oauth",
      "verified_at": "2026-03-29T08:36:00Z"
    }
  ],
  "failed_claims": [
    {
      "type": "social_handle",
      "platform": "x",
      "value": "@alice",
      "reason": "proof_not_found"
    }
  ],
  "identity_assertion_label": "cawg.identity",
  "identity_assertion_payload": "<signed verifier payload>"
}
```

## Supported Verification Methods

### NIP-05

- Resolve the claimed `nip05`
- Confirm it maps to the same pubkey as the creator binding

### Domain Control

Supported methods:

- DNS record
- file at URL
- HTML meta tag
- administrative email, when available

### Social Handles

Preferred method:

- OAuth or federated login

Fallback method:

- public proof using a verifier-issued nonce in a bio, profile, or post

## Failure Policy

- Publish must succeed when verifier calls fail.
- Failed optional claims are omitted, not fatal.
- Creator-binding-only publish is a valid intermediate state.

## Current Shipping Boundary

This protocol defines the mobile-side shapes now.

### Shipped In This Repo

- user-signed creator-binding payload transport in `NativeProofData`
- optional verifier claim fetch through `verifier.divine.video`
- Nostr discovery tags:
  - `["identity_binding", "nostr_creator"]`
  - `["identity_verifier", "<issuer>"]`
  - `["identity_portable", "cawg"]`
- creator-binding-only publish as a valid intermediate milestone

### Blocked For Strict Full CAWG Embedding

`c2pa_flutter` still needs API support for:

- placeholder assertions
- assertion-reference enumeration with hashes
- assertion replacement after signature collection
- a builder path for final CAWG insertion before signing completes

Until that lands, Divine can ship creator binding plus verifier metadata
transport, but not claim strict end-to-end CAWG 1.2 final-assertion support.

### External Verifier Workstream

`verifier.divine.video` still needs to expose:

- OAuth and federated verification adapters for supported social platforms
- public-proof challenge issuance and verification
- NIP-05 verification endpoint
- domain-control verification endpoint
- CAWG issuance endpoint
- verifier issuer metadata for portable display and trust decisions
