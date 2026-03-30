# Nostr-First CAWG Identity Publishing Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a user-signed Nostr creator-binding assertion to published media and optionally embed a CAWG Identity 1.2 overlay issued by `verifier.divine.video` for verified `nip05`, website/domain, and social-handle claims.

**Architecture:** Keep Nostr authorship primary by signing an asset-specific payload with the creator's existing Nostr key, then attach CAWG portability metadata only for external claims that Divine verified. Extend the current C2PA publishing path so CAWG issuance is additive and non-blocking, with publish success preserved when verifier calls fail.

## Status On 2026-03-29

Implemented in this repo:

- creator-binding payload generation
- non-blocking verifier client wiring
- proof payload transport for creator binding and verifier bundle data
- Nostr discovery tags for binding and CAWG portability hints
- creator-binding-only publish as the current intermediate milestone

Still blocked for strict full CAWG embedding:

- `c2pa_flutter` placeholder assertions
- assertion-reference enumeration with hashes
- assertion replacement after signature collection
- final builder insertion path for CAWG assertions

Still external to this repo:

- `verifier.divine.video` OAuth adapters
- public-proof challenge flow
- NIP-05 and domain verification endpoints
- CAWG issuance endpoint
- verifier issuer metadata

**Tech Stack:** Flutter, Dart, existing `c2pa_flutter` integration, `AuthServiceSigner` / Nostr key container, existing ProofMode/C2PA publish flow, REST client code, repo docs under `mobile/docs/`

---

## File Map

### Repo files to create

- `mobile/docs/CAWG_IDENTITY_PUBLISHING_PROTOCOL.md`
  Defines the canonical creator-binding payload, verifier request/response shapes, supported verification methods, and Nostr event tag hints.
- `mobile/lib/services/nostr_creator_binding_service.dart`
  Builds the canonical payload and obtains the user signature using the existing Nostr key material.
- `mobile/lib/services/cawg_verifier_client.dart`
  Calls `verifier.divine.video` for claim verification and CAWG issuance.
- `mobile/lib/services/c2pa_identity_manifest_service.dart`
  Bridges current C2PA signing flow to new identity assertions and hides manifest-assembly complexity from publish code.
- `mobile/test/services/nostr_creator_binding_service_test.dart`
  Covers canonical payload generation, signature input stability, and signed output shape.
- `mobile/test/services/cawg_verifier_client_test.dart`
  Covers verifier success, partial-claim failure, timeout, and non-blocking fallback.
- `mobile/test/services/c2pa_identity_manifest_service_test.dart`
  Covers manifest assembly decisions and fallback behavior when CAWG issuance is absent.
- `mobile/test/services/video_event_publisher_cawg_identity_test.dart`
  Covers end-to-end publish metadata decisions and event tag emission.
- `mobile/packages/models/test/src/creator_identity_claim_test.dart`
  Covers model parsing/serialization for creator-binding metadata.

### Repo files to modify

- `mobile/lib/services/auth_service_signer.dart`
  Add a narrow raw-signing helper or companion abstraction for canonical creator-binding payload signatures.
- `mobile/lib/services/c2pa_signing_service.dart`
  Replace the ad hoc JSON-only manifest path with a serviceable builder path or adapter that can host identity assertions.
- `mobile/lib/services/native_proofmode_service.dart`
  Thread identity-publishing context into existing proof generation flow without making CAWG mandatory.
- `mobile/lib/services/video_event_publisher.dart`
  Attach new Nostr event tags and make identity embedding non-blocking.
- `mobile/lib/providers/app_providers.dart`
  Register the new services.
- `mobile/lib/providers/video_publish_provider.dart`
  Thread verified-identity state and publish options into the upload pipeline.
- `mobile/packages/models/lib/src/native_proof_data.dart`
  Add optional fields for creator-binding or CAWG metadata references when needed by the app-layer publish flow.
- `mobile/packages/models/lib/src/pending_upload.dart`
  Persist identity-publishing state for retries and background publish continuation.
- `mobile/packages/models/lib/src/video_event.dart`
  Parse new Nostr tag hints for downstream display and future verification work.
- `mobile/docs/NOSTR_VIDEO_EVENTS.md`
  Document the new tags and publishing behavior.

### External dependency track

- `guardianproject/c2pa-flutter` or Divine's fork of it
  Must expose enough API surface for placeholder assertions, referenced-assertion hashing, and final assertion replacement. Treat this as a blocking dependency for full CAWG embedding.
- `verifier.divine.video`
  New external service. This repo should document and consume its API, but the service implementation is outside this repo.

## Prerequisites

- Confirm the exact `c2pa_flutter` extension strategy before starting Task 3.
- Confirm canonical payload format in `mobile/docs/CAWG_IDENTITY_PUBLISHING_PROTOCOL.md` before shipping any mobile implementation.
- Keep CAWG issuance optional until verifier SLAs and support are proven.

## Chunk 1: Protocol And Model Scaffolding

### Task 1: Define the canonical protocol and storage model

**Files:**
- Create: `mobile/docs/CAWG_IDENTITY_PUBLISHING_PROTOCOL.md`
- Modify: `mobile/packages/models/lib/src/native_proof_data.dart`
- Modify: `mobile/packages/models/lib/src/pending_upload.dart`
- Test: `mobile/packages/models/test/src/creator_identity_claim_test.dart`

- [ ] **Step 1: Write the failing model test**

Create `mobile/packages/models/test/src/creator_identity_claim_test.dart` with coverage for:
- canonical creator-binding payload field names
- optional `nip05`, `website`, and `social_handles`
- persistence round-trip through app model JSON

- [ ] **Step 2: Run the model test to verify it fails**

Run: `flutter test packages/models/test/src/creator_identity_claim_test.dart`
Expected: FAIL because the new identity metadata shape does not exist yet.

- [ ] **Step 3: Add minimal model fields to existing upload/proof state**

Update `mobile/packages/models/lib/src/native_proof_data.dart` and `mobile/packages/models/lib/src/pending_upload.dart` to carry only the metadata the publish pipeline actually needs, such as:

```dart
final String? creatorBindingAssertionLabel;
final String? cawgIdentityAssertionLabel;
final String? creatorBindingPayloadJson;
final String? verifiedIdentityBundleJson;
```

Keep these optional and additive. Do not make existing publish flows depend on them.

- [ ] **Step 4: Write the protocol document**

Create `mobile/docs/CAWG_IDENTITY_PUBLISHING_PROTOCOL.md` with:
- canonical payload versioning
- required fields for the user-signed creator binding
- verifier API request and response JSON
- supported verification methods:
  - `nip05`
  - domain control
  - OAuth social proof
  - public-proof social fallback
- explicit statement that Divine does not certify authorship

- [ ] **Step 5: Run the model test to verify it passes**

Run: `flutter test packages/models/test/src/creator_identity_claim_test.dart`
Expected: PASS

- [ ] **Step 6: Commit the protocol and model scaffolding**

```bash
git add mobile/docs/CAWG_IDENTITY_PUBLISHING_PROTOCOL.md \
  mobile/packages/models/lib/src/native_proof_data.dart \
  mobile/packages/models/lib/src/pending_upload.dart \
  mobile/packages/models/test/src/creator_identity_claim_test.dart
git commit -m "feat(identity): define nostr-first identity publishing protocol"
```

## Chunk 2: User-Signed Creator Binding

### Task 2: Add the Nostr creator-binding service

**Files:**
- Create: `mobile/lib/services/nostr_creator_binding_service.dart`
- Modify: `mobile/lib/services/auth_service_signer.dart`
- Modify: `mobile/lib/providers/app_providers.dart`
- Test: `mobile/test/services/nostr_creator_binding_service_test.dart`

- [ ] **Step 1: Write the failing service test**

Create `mobile/test/services/nostr_creator_binding_service_test.dart` with cases for:
- canonical payload stability
- inclusion of hard-binding and referenced-assertion data
- signing with the authenticated creator key
- deterministic payload output for identical inputs

- [ ] **Step 2: Run the service test to verify it fails**

Run: `flutter test test/services/nostr_creator_binding_service_test.dart`
Expected: FAIL because the service and raw-signing hook do not exist.

- [ ] **Step 3: Add a narrow raw-signing hook**

Extend `mobile/lib/services/auth_service_signer.dart` with a helper that can sign the canonical creator-binding byte payload without pretending the verifier is the author. Keep the API small:

```dart
Future<String> signCanonicalPayload(Uint8List payload);
Future<String> currentPubkey();
```

Use the existing secure key container; do not duplicate key access logic.

- [ ] **Step 4: Implement the creator-binding service**

Create `mobile/lib/services/nostr_creator_binding_service.dart` to:
- accept the active pubkey, claims, hard-binding reference, and referenced assertions
- serialize the canonical payload exactly as documented
- sign it with the current Nostr signer
- return a structure ready for C2PA embedding

- [ ] **Step 5: Register the service**

Add a provider to `mobile/lib/providers/app_providers.dart` so publish code can request the service without hidden singletons.

- [ ] **Step 6: Run the service test to verify it passes**

Run: `flutter test test/services/nostr_creator_binding_service_test.dart`
Expected: PASS

- [ ] **Step 7: Commit the creator-binding service**

```bash
git add mobile/lib/services/nostr_creator_binding_service.dart \
  mobile/lib/services/auth_service_signer.dart \
  mobile/lib/providers/app_providers.dart \
  mobile/test/services/nostr_creator_binding_service_test.dart
git commit -m "feat(identity): add user-signed nostr creator binding"
```

### Task 3: Add manifest assembly support for identity assertions

**Files:**
- Create: `mobile/lib/services/c2pa_identity_manifest_service.dart`
- Modify: `mobile/lib/services/c2pa_signing_service.dart`
- Test: `mobile/test/services/c2pa_identity_manifest_service_test.dart`

- [ ] **Step 1: Write the failing manifest service test**

Create `mobile/test/services/c2pa_identity_manifest_service_test.dart` with cases for:
- base C2PA manifest generation still includes current actions and training-mining behavior
- creator-binding assertion is included when signing inputs are available
- CAWG assertion is omitted cleanly when verifier output is absent
- placeholder path is selected when full CAWG embedding is enabled

- [ ] **Step 2: Run the manifest service test to verify it fails**

Run: `flutter test test/services/c2pa_identity_manifest_service_test.dart`
Expected: FAIL because the new manifest service does not exist.

- [ ] **Step 3: Implement the new manifest service**

Create `mobile/lib/services/c2pa_identity_manifest_service.dart` to own:
- base assertion assembly
- creator-binding assertion insertion
- optional CAWG assertion insertion
- adaptation to current `c2pa_flutter` capabilities

Keep it separate from `C2paSigningService` so signing transport and manifest composition do not collapse into one file.

- [ ] **Step 4: Adapt `C2paSigningService` to use the new manifest layer**

Refactor `mobile/lib/services/c2pa_signing_service.dart` so its job becomes:
- gather inputs
- request manifest assembly from `C2paIdentityManifestService`
- sign the file using the chosen builder path

Do not regress existing training-mining behavior or ProofMode integration.

- [ ] **Step 5: Document the external blocker**

Add a short dependency-gap section to the service comments or protocol doc noting that full CAWG embedding requires `c2pa_flutter` support for placeholder assertions and referenced-assertion hashing.

- [ ] **Step 6: Run the manifest service test to verify it passes**

Run: `flutter test test/services/c2pa_identity_manifest_service_test.dart`
Expected: PASS

- [ ] **Step 7: Commit the manifest assembly work**

```bash
git add mobile/lib/services/c2pa_identity_manifest_service.dart \
  mobile/lib/services/c2pa_signing_service.dart \
  mobile/test/services/c2pa_identity_manifest_service_test.dart \
  mobile/docs/CAWG_IDENTITY_PUBLISHING_PROTOCOL.md
git commit -m "feat(identity): prepare c2pa manifest assembly for creator binding"
```

## Chunk 3: Verifier Overlay And Publish Integration

### Task 4: Add the verifier client and non-blocking identity fetch

**Files:**
- Create: `mobile/lib/services/cawg_verifier_client.dart`
- Modify: `mobile/lib/providers/app_providers.dart`
- Modify: `mobile/lib/providers/video_publish_provider.dart`
- Test: `mobile/test/services/cawg_verifier_client_test.dart`

- [ ] **Step 1: Write the failing verifier client test**

Create `mobile/test/services/cawg_verifier_client_test.dart` with cases for:
- successful CAWG issuance response
- partial success when only some claims verify
- timeout or network failure falling back to creator-binding-only publish
- explicit handling of OAuth-required versus public-proof-required claim states

- [ ] **Step 2: Run the verifier client test to verify it fails**

Run: `flutter test test/services/cawg_verifier_client_test.dart`
Expected: FAIL because the client does not exist.

- [ ] **Step 3: Implement the verifier client**

Create `mobile/lib/services/cawg_verifier_client.dart` with narrowly scoped methods, for example:

```dart
Future<VerifierClaimBundle> verifyClaims(VerifierClaimRequest request);
Future<VerifierProofChallenge> createPublicProofChallenge(...);
Future<VerifierCredentialResult?> issueIdentityAssertion(...);
```

The client should treat verifier output as optional and preserve publish success when requests fail.

- [ ] **Step 4: Register the client provider**

Add a provider in `mobile/lib/providers/app_providers.dart` and thread it into `mobile/lib/providers/video_publish_provider.dart`.

- [ ] **Step 5: Keep social verification policy explicit**

In `video_publish_provider.dart`, implement the policy:
- prefer OAuth/federated login where supported
- allow public-proof fallback
- never block publishing on unverifiable optional claims

- [ ] **Step 6: Run the verifier client test to verify it passes**

Run: `flutter test test/services/cawg_verifier_client_test.dart`
Expected: PASS

- [ ] **Step 7: Commit the verifier client**

```bash
git add mobile/lib/services/cawg_verifier_client.dart \
  mobile/lib/providers/app_providers.dart \
  mobile/lib/providers/video_publish_provider.dart \
  mobile/test/services/cawg_verifier_client_test.dart
git commit -m "feat(identity): add non-blocking verifier overlay client"
```

### Task 5: Integrate identity publishing into the current upload and Nostr event flow

**Files:**
- Modify: `mobile/lib/services/native_proofmode_service.dart`
- Modify: `mobile/lib/services/video_event_publisher.dart`
- Modify: `mobile/packages/models/lib/src/video_event.dart`
- Modify: `mobile/docs/NOSTR_VIDEO_EVENTS.md`
- Test: `mobile/test/services/video_event_publisher_cawg_identity_test.dart`

- [ ] **Step 1: Write the failing publisher integration test**

Create `mobile/test/services/video_event_publisher_cawg_identity_test.dart` with cases for:
- creator-binding-only publish when verifier output is missing
- creator-binding plus CAWG publish when verifier output exists
- new event tags are emitted without changing core event ownership
- no publish regression when CAWG embedding fails late

- [ ] **Step 2: Run the publisher integration test to verify it fails**

Run: `flutter test test/services/video_event_publisher_cawg_identity_test.dart`
Expected: FAIL because the identity publish path is not integrated.

- [ ] **Step 3: Thread identity state through proof generation**

Update `mobile/lib/services/native_proofmode_service.dart` so identity-publishing context can travel alongside existing ProofMode data, but do not make ProofMode dependent on verifier success.

- [ ] **Step 4: Add Nostr tag hints in the event publisher**

Update `mobile/lib/services/video_event_publisher.dart` to add simple discovery tags such as:

```text
["identity_binding", "nostr_creator"]
["identity_verifier", "verifier.divine.video"]
["identity_portable", "cawg"]
```

These tags are hints only. They must not be treated as the source of truth for authorship.

- [ ] **Step 5: Parse new tags in the video model**

Update `mobile/packages/models/lib/src/video_event.dart` to expose the new tag hints for future UI work without changing current badge classification behavior.

- [ ] **Step 6: Update the event documentation**

Modify `mobile/docs/NOSTR_VIDEO_EVENTS.md` to document:
- the user-signed creator-binding layer
- optional CAWG verifier overlay
- the new tag hints and their semantics

- [ ] **Step 7: Run the publisher integration test to verify it passes**

Run: `flutter test test/services/video_event_publisher_cawg_identity_test.dart`
Expected: PASS

- [ ] **Step 8: Run a focused regression suite**

Run:

```bash
flutter test test/services/c2pa_training_mining_assertion_test.dart
flutter test test/services/video_event_publisher_native_proof_test.dart
flutter test test/services/blossom_upload_proofmode_test.dart
flutter test test/services/video_event_publisher_cawg_identity_test.dart
```

Expected: PASS for all targeted publish and proof tests.

- [ ] **Step 9: Commit the publish integration**

```bash
git add mobile/lib/services/native_proofmode_service.dart \
  mobile/lib/services/video_event_publisher.dart \
  mobile/packages/models/lib/src/video_event.dart \
  mobile/docs/NOSTR_VIDEO_EVENTS.md \
  mobile/test/services/video_event_publisher_cawg_identity_test.dart
git commit -m "feat(identity): publish nostr-first creator binding with cawg overlay"
```

## Chunk 4: External Follow-Through

### Task 6: Close the dependency gap outside this repo

**Files:**
- Modify: `mobile/docs/CAWG_IDENTITY_PUBLISHING_PROTOCOL.md`
- Modify: `docs/superpowers/specs/2026-03-29-nostr-first-cawg-identity-publishing-design.md`
- Modify: `docs/superpowers/plans/2026-03-29-nostr-first-cawg-identity-publishing.md`

- [ ] **Step 1: Open the `c2pa_flutter` dependency workstream**

Document the exact missing APIs in `mobile/docs/CAWG_IDENTITY_PUBLISHING_PROTOCOL.md`:
- placeholder assertions
- assertion-reference enumeration with hashes
- assertion replacement after signature collection
- builder path support for final CAWG insertion

- [ ] **Step 2: Open the `verifier.divine.video` workstream**

Document the external service deliverables:
- OAuth verification adapters
- public-proof challenge flow
- NIP-05 and domain verification endpoints
- CAWG issuance endpoint
- verifier issuer metadata

- [ ] **Step 3: Record the shipping gate**

Update the design and plan docs to mark full CAWG embedding as blocked until the C2PA dependency gap is resolved, while preserving creator-binding-only publish as an intermediate milestone.

- [ ] **Step 4: Commit the final planning updates**

```bash
git add mobile/docs/CAWG_IDENTITY_PUBLISHING_PROTOCOL.md \
  docs/superpowers/specs/2026-03-29-nostr-first-cawg-identity-publishing-design.md \
  docs/superpowers/plans/2026-03-29-nostr-first-cawg-identity-publishing.md
git commit -m "docs: capture external blockers for nostr-first cawg publishing"
```

## Verification Checklist

- `flutter test packages/models/test/src/creator_identity_claim_test.dart`
- `flutter test test/services/nostr_creator_binding_service_test.dart`
- `flutter test test/services/c2pa_identity_manifest_service_test.dart`
- `flutter test test/services/cawg_verifier_client_test.dart`
- `flutter test test/services/video_event_publisher_cawg_identity_test.dart`
- `flutter test test/services/c2pa_training_mining_assertion_test.dart`
- `flutter test test/services/video_event_publisher_native_proof_test.dart`
- `flutter test test/services/blossom_upload_proofmode_test.dart`

## Notes For Implementers

- Do not let the verifier become the source of truth for authorship.
- Do not block publish on optional CAWG issuance.
- Keep Nostr event ownership unchanged.
- Treat `verifier.divine.video` as issuer-scoped metadata, not universal truth.
- Preserve existing ProofMode and training-mining behavior while identity work is added incrementally.
