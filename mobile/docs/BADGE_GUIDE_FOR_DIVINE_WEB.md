# Badge Guide For `divine-web`

This document describes the current badge behavior in `divine-mobile` as of PR `#2003`.

Use this as the implementation guide for `divine-web`. The goal is to match the mobile app's badge decisions, not to infer behavior from screenshots.

## Source Of Truth

The current mobile implementation lives here:

- `lib/widgets/proofmode_badge_row.dart`
- `lib/widgets/proofmode_badge.dart`
- `lib/widgets/badge_explanation_modal.dart`
- `lib/utils/proofmode_helpers.dart`
- `lib/extensions/video_event_extensions.dart`
- `packages/models/lib/src/video_event.dart`
- `lib/services/moderation_label_service.dart`
- `lib/services/video_moderation_status_service.dart`

## Important High-Level Rules

1. The UI effectively shows one primary status badge per video.
2. `Original Vine` wins over all proof badges.
3. A low AI score can promote an otherwise proofless video to `Human Made`.
4. A high AI score can show `Possibly AI-Generated`, but only when the video is not already proof-backed.
5. Plain proofless Divine-hosted videos do not get a visible badge anymore.
6. Never classify archive Vine content from loop count alone.

## Badge Types

### 1. `Human Made`

Rendered by `ProofModeBadge`.

It has four visual tiers, but the visible text is always `Human Made`:

- `platinum`
  - Trigger: `verified_mobile` proof plus AI score `< 0.5`
  - Meaning: strongest case, device proof plus AI scan agrees it looks human-made
- `verifiedMobile`
  - Trigger: `proofModeVerificationLevel == 'verified_mobile'`
  - Meaning: device attestation / hardware-backed proof
- `verifiedWeb`
  - Trigger A: `proofModeVerificationLevel == 'verified_web'`
  - Trigger B: no proof tags, but AI score `< 0.5`
  - Meaning: web crypto proof, or scan-only likely-human result
- `basicProof`
  - Trigger: `proofModeVerificationLevel == 'basic_proof'`
  - Meaning: basic proof metadata present

### 2. `Original`

Rendered by `OriginalVineBadge`.

Trigger:

- `video.isOriginalVine == true`

Meaning:

- recovered original Vine / archive content

Important:

- This suppresses `Human Made` and `Not Divine Hosted`
- If an archive Vine also has proof tags, mobile still shows `Original`, not `Human Made`

### 3. `Not Divine Hosted`

Rendered by `NotDivineBadge`.

Trigger:

- not hosted on `divine.video`
- no proof-backed badge
- not an original Vine
- no low-score AI promotion
- no high-score AI warning

This is the fallback badge for proofless external content.

### 4. `Possibly AI-Generated`

Rendered by `PossiblyAIBadge`.

Trigger:

- AI result exists
- `aiScore >= 0.5`
- not an original Vine
- not already showing a proof-backed `Human Made` badge

Important:

- current mobile logic does not downgrade a proof-backed video to `Possibly AI-Generated`
- proof-backed videos keep the `Human Made` badge even if an AI score exists

## Proof Inputs

These fields come from `VideoEvent`:

- `proofModeVerificationLevel`
- `proofModeManifest`
- `proofModePgpFingerprint`
- `proofModeDeviceAttestation`
- `proofModeC2paManifestId`

Derived helpers:

- `video.hasProofMode`
- `video.isVerifiedMobile`
- `video.isVerifiedWeb`
- `video.hasBasicProof`
- `video.getVerificationLevel()`
- `video.shouldShowProofModeBadge`

## Original Vine Inputs

Original Vine detection comes from:

- `rawTags['platform'] == 'vine'`

This is deliberate. Mobile no longer trusts loop count or old timestamps by themselves.

Do not do this:

- "If `originalLoops > 0`, treat as Original Vine"
- "If old timestamp plus loops, treat as Original Vine"

Do this:

- require `platform: vine`

There is also a narrower helper:

- `video.isVintageRecoveredVine`

That means:

- `isOriginalVine == true`
- created/published time is before Vine shutdown

Mobile uses `isVintageRecoveredVine` for the comments empty-state archive notice, not for the top-level badge choice.

## Hosting Inputs

Divine-hosted detection is:

- `video.videoUrl?.toLowerCase().contains('divine.video') == true`

This is what mobile uses for badge decisions.

Important:

- Divine hosting is still used in modal copy and AI fallback logic
- it is no longer a visible badge by itself

## AI Inputs

Mobile checks AI results in this order:

1. `ModerationLabelService.getAIDetectionResult(video.id)`
2. `ModerationLabelService.getAIDetectionByHash(resolvedSha256 ?? video.vineId)`
3. For Divine-hosted videos only: `videoModerationStatusProvider(resolvedSha256)`

Where `resolvedSha256` means:

- `normalize(video.sha256)` if present
- otherwise extract the 64-char hash from any Divine media URL path segment
  - this must work for:
    - `https://media.divine.video/{hash}.mp4`
    - `https://media.divine.video/{hash}/720p`
    - `https://media.divine.video/{hash}/hls/master.m3u8`

Notes:

- Kind `1985` labels are the first-class source when present
- Hash lookup is the fallback if event-ID lookup misses
- do not require the `sha256` field to be populated if the hash is recoverable from the media URL
- Divine-hosted videos get an extra fallback to the moderation-service check-result endpoint
- the badge row uses the raw `aiScore` threshold, not `VideoModerationStatus.aiGenerated`

Thresholds used by badge logic:

- `aiScore < 0.5` => likely human / eligible for `Human Made`
- `aiScore >= 0.5` => eligible for `Possibly AI-Generated`

Important:

- `VideoModerationStatus.aiGenerated` uses a different threshold internally in the moderation service model
- mobile badge rendering does not use that boolean for the badge row decision
- for web parity, use the raw score threshold above

## Exact Badge Decision Order

Use this order.

```text
1. Resolve AI result
   a. by event ID
   b. by hash
   c. if still null and Divine-hosted, by moderation status service

2. If Original Vine:
   show Original
   stop

3. Compute base proof verification level

4. If proof-backed and verified_mobile and aiScore < 0.5:
   show Human Made (platinum)
   stop

5. If proof-backed:
   show Human Made (gold / silver / bronze based on verification level)
   stop

6. If no proof and aiScore < 0.5:
   show Human Made (silver)
   stop

7. If no proof and aiScore >= 0.5:
   show Possibly AI-Generated
   stop

8. If Divine-hosted:
   show no badge
   stop

9. Otherwise:
   show Not Divine Hosted
```

In code terms, current mobile behavior is implemented by these booleans:

- `video.shouldShowVineBadge`
- `video.shouldShowProofModeBadge`
- `hasAIScanBadge`
- `isPossiblyAI`
- `video.shouldShowNotDivineBadge`

## Explanation Modal Behavior

The badge opens `BadgeExplanationModal`.

There are two top-level modal modes:

### Original Vine modal

Shown when:

- `video.isOriginalVine == true`

Title:

- `Original Vine Archive`

Content:

- explains this is preserved Vine archive content
- optionally shows original loops
- links to the archive preservation / DMCA page

### Verification modal

Shown for everything else.

Title:

- `Video Verification`

Sections:

- intro sentence
- `ProofMode Verification`
- `AI Detection`
- external links

## Verification Modal Intro Copy Rules

Current mobile intro logic:

1. If `video.hasProofMode`
   - "This video's authenticity is verified using Proofmode technology."
2. Else if AI result exists and `aiScore < 0.5`
   - if Divine-hosted:
     - "This video is hosted on Divine and AI detection indicates it is likely human-made, even though no ProofMode verification data is attached."
   - else:
     - "AI detection indicates this video is likely human-made, though no ProofMode verification data is attached."
3. Else if Divine-hosted
   - "This video is hosted on Divine, but no ProofMode verification data is attached yet."
4. Else
   - "This video is hosted outside Divine and does not include ProofMode verification data."

## Verification Detail Copy Rules

Current mobile descriptions:

- platinum
  - "Platinum: Device hardware attestation, cryptographic signatures, Content Credentials (C2PA), and AI scan confirms human origin."
- gold
  - "Gold: Captured on a real device with hardware attestation, cryptographic signatures, and Content Credentials (C2PA)."
- silver from proof
  - "Silver: Cryptographic signatures prove this video hasn't been altered since recording."
- bronze
  - "Bronze: Basic metadata signatures are present."
- silver from AI-only
  - "Silver: AI scan confirms this video is likely human-created."
- unverified
  - "No verification data available for this video."

Proof checklist items:

- Device attestation
- PGP signature
- C2PA Content Credentials
- Proof manifest

Each item is shown as pass/fail based on whether the corresponding field exists.

## AI Detection Section Behavior

If an AI result already exists:

- show percentage: `N% likelihood of being AI-generated`
- show a progress bar using `aiScore`
- show source if present
- show moderator confirmation if `isVerified == true`

If no AI result exists yet:

- show `AI scan: Not yet scanned`
- show `Check if AI-generated` button

When the user presses `Check if AI-generated`:

- mobile resolves `sha256`
- calls the moderation status service
- if result has `aiScore`, the modal updates in place
- if no result exists yet, it shows `No scan results available yet.`

This same on-demand check exists in:

- the main verification modal
- the `Not Divine Hosted` explanation popup

## Current Edge Cases To Preserve

### Original Vine beats proof

If a video somehow has both:

- `platform: vine`
- proof tags

mobile still shows `Original`, not `Human Made`.

### Low AI score promotes proofless videos

If a video has:

- no proof tags
- AI score `< 0.5`

mobile promotes it to `Human Made` instead of leaving it at:

- no visible badge
- or `Not Divine Hosted`

### High AI score only warns on proofless videos

If a video has:

- proof badge eligibility
- AI score `>= 0.5`

mobile does not replace the proof badge with `Possibly AI-Generated`.

### Loop count alone is not enough

Do not use:

- `originalLoops`
- timestamp
- `publishedAt`

as the primary archive badge trigger.

Only `platform: vine` makes a video an Original Vine.

## Recommended Web Pseudocode

```ts
function resolveBadge(video, aiResult) {
  if (video.rawTags?.platform === "vine") {
    return { kind: "original_vine" };
  }

  const baseLevel = getVerificationLevel(video);
  const hasProof = hasProofMode(video);
  const isLikelyHuman = aiResult != null && aiResult.score < 0.5;
  const isPossiblyAI = aiResult != null && aiResult.score >= 0.5;
  const isDivineHosted = (video.videoUrl ?? "").toLowerCase().includes("divine.video");

  if (hasProof) {
    if (baseLevel === "verified_mobile" && isLikelyHuman) {
      return { kind: "human_made", tier: "platinum" };
    }
    return { kind: "human_made", tier: mapBaseLevelToTier(baseLevel) };
  }

  if (isLikelyHuman) {
    return { kind: "human_made", tier: "silver" };
  }

  if (isPossiblyAI) {
    return { kind: "possibly_ai_generated" };
  }

  if (isDivineHosted) {
    return null;
  }

  return { kind: "not_divine_hosted" };
}
```

## Related Non-Badge Archive Notice

This is not part of the badge row, but it is easy to confuse with badge logic.

In comments, mobile shows a `Classic Vine` archive notice when:

- `video.isVintageRecoveredVine == true`

That means:

- `platform: vine`
- plus pre-shutdown timestamp

This is stricter than `isOriginalVine` and is specific to the comments empty state.

## Short Version

If the web agent only remembers five things, they should be these:

1. `platform: vine` is the only trusted Original Vine signal.
2. Original Vine suppresses all other badge types.
3. Proof-backed videos show `Human Made`.
4. Proofless videos with AI score `< 0.5` also show `Human Made` in silver.
5. Proofless Divine-hosted videos have no visible badge unless AI or proof pushes them into a stronger trust state.
