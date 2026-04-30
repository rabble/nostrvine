# iOS QA PR Builds Design

## Goal

Give QA installable iOS builds for active mobile PRs without using TestFlight as the bottleneck. QA should be able to open a PR or a directory, see which build belongs to that PR, and install it on registered iOS devices.

## Decision

Use 15 reusable iOS QA slots. Each slot is a fixed Apple/Firebase app identity that can be installed side by side with the production app and with the other QA slots.

Slots:

- `qa01` through `qa15`
- Main bundle IDs: `co.openvine.app.qa01` through `co.openvine.app.qa15`
- Extension bundle IDs: `co.openvine.app.qa01.NotificationServiceExtension` through `co.openvine.app.qa15.NotificationServiceExtension`
- Display names: `Divine QA 01` through `Divine QA 15`
- App groups: `group.co.openvine.app.qa01` through `group.co.openvine.app.qa15`

Avoid dynamic per-PR bundle IDs. The one-time setup for 15 identities is manageable; unbounded per-PR identities would create ongoing Apple, Firebase, provisioning, entitlement, and cleanup work.

## Current External Constraints Checked

- [Codemagic Builds API](https://docs.codemagic.io/rest-api/builds/) starts YAML workflows with `POST /builds`, `appId`, `workflowId`, `branch`, and optional `environment.variables`.
- [Codemagic iOS signing](https://docs.codemagic.io/yaml-code-signing/signing-ios/) recommends `distribution_type: ad_hoc` when signed iOS artifacts are distributed through a third-party service such as Firebase App Distribution.
- [Firebase App Distribution CLI](https://firebase.google.com/docs/app-distribution/ios/distribute-cli) supports iOS IPA upload, group distribution, and returns release links including `testing_uri`; direct binary links expire quickly and should not be used as the stable QA link.
- [Codemagic Firebase distribution](https://docs.codemagic.io/yaml-distributing/firebase-app-distribution/) marks Firebase token auth deprecated; service-account auth with `GOOGLE_APPLICATION_CREDENTIALS` is the preferred CI path.
- [Codemagic post-publish scripts](https://docs.codemagic.io/yaml-distributing/post-publish/) run even after build failure unless the build is canceled or times out, so GitHub status notification belongs there.
- [GitHub Security Lab pwn request guidance](https://securitylab.github.com/resources/github-actions-preventing-pwn-requests/) still treats `pull_request_target` plus checkout/execution of PR-controlled code as the dangerous pattern. The allocator may inspect PR metadata and push a trusted mirror ref, but it must not execute PR code.

## Trust Model

Native iOS PR builds require signing and Firebase distribution credentials, so they cannot follow the exact web-preview security model.

Autobuild only when the PR is trusted:

1. The PR head repository owner is `divinevideo`; or
2. The PR author is an active member or owner of the `divinevideo` GitHub organization.

For PRs outside that trust model:

- Do not trigger Codemagic.
- Do not expose signing, App Store Connect, or Firebase credentials.
- Add or update a PR comment explaining that iOS QA build was skipped because the PR is outside the trusted build policy.
- A maintainer can make the PR buildable by moving/mirroring the branch under `divinevideo`, or by using a future explicit trusted override if we choose to add one.

Private org membership may not be visible to the default `GITHUB_TOKEN`, so the membership check needs a GitHub token with enough permission to read org membership.

Codemagic API builds are started by branch or tag. To support trusted member PRs from personal forks, GitHub Actions should mirror every trusted PR head SHA to a temporary branch in `divinevideo/divine-mobile`, for example `ios-qa/pr-3407`, then ask Codemagic to build that mirror branch. This gives Codemagic a branch it can fetch from the configured repository while preserving the exact PR SHA in build metadata.

The allocator workflow uses `pull_request_target` for secrets and write permissions, but it must check out only the base repository workflow/scripts. It may fetch and push a trusted PR head as a passive git object after the trust check; it must not run Flutter, npm, shell scripts, hooks, or any executable content from the PR inside GitHub Actions. Treat PR titles, branch names, and labels as untrusted strings: pass them through environment variables or JSON files, never by direct shell interpolation.

## Slot Lifecycle

GitHub labels are the source of truth:

- `ios-qa-slot-01` through `ios-qa-slot-15`
- `ios-qa:building`
- `ios-qa:ready`
- `ios-qa:queued`
- `ios-qa:failed`
- `needs-ios-qa`

Slot labels are the source of truth for assignment. Build result metadata is stored in the sticky PR comment as a hidden JSON state marker so reconciliation and the active directory can recover the latest built SHA, Codemagic build ID/URL, Firebase `testing_uri`, stale status, and failure reason without committing generated state.

Slot assignment:

1. A ready-for-review PR becomes eligible automatically.
2. A draft PR becomes eligible only when labeled `needs-ios-qa`.
3. If the PR already has a slot label, keep that slot and rebuild it on new commits.
4. Only slots marked enabled in `.github/ios_qa_slots.json` are assignable. Stage 1 should enable only `qa01`.
5. If it has no slot label, find the first enabled slot not currently used by an open PR.
6. If a slot is available, add `ios-qa-slot-NN` and `ios-qa:building`.
7. If no slot is available, add `ios-qa:queued` and comment with the active build directory.

Cleanup:

- On PR close, remove `ios-qa-slot-NN`, `ios-qa:building`, `ios-qa:ready`, `ios-qa:queued`, and `ios-qa:failed`.
- Delete the temporary mirror branch `ios-qa/pr-<number>`.
- Update the active build directory.
- The installed app can remain on QA devices until that slot is reused.
- A scheduled reconciliation workflow should run daily to repair missed label/comment/directory updates.

## Concurrency

The allocator workflow must use one global concurrency group, for example:

```yaml
concurrency:
  group: ios-qa-slot-allocator
  cancel-in-progress: false
```

This prevents two PR workflows from seeing the same free slot and assigning it twice.

Codemagic builds should still be per-PR cancellable or replaceable. A newer commit for the same PR should supersede the older build before distribution.

## Build Flow

1. GitHub Actions receives a `pull_request_target` event, `workflow_dispatch`, schedule event, or label event.
2. The allocator checks trust, PR state, draft state, file relevance, enabled slots, and current labels. File relevance is checked in script, not with workflow `paths`, so cleanup and manual reconciliation still run.
3. The allocator assigns or reuses a slot.
4. The allocator mirrors the trusted PR head SHA to `ios-qa/pr-<number>` in the base repository.
5. The allocator triggers Codemagic through `POST /builds` with branch `ios-qa/pr-<number>`, `workflowId=ios-qa-pr-build`, explicit labels, and explicit metadata:
   - `PR_NUMBER`
   - `PR_HEAD_SHA`
   - `PR_HEAD_REPO`
   - `PR_HEAD_REF`
   - `QA_SLOT`
   - `QA_BUNDLE_ID`
   - `QA_EXTENSION_BUNDLE_ID`
   - `QA_APP_GROUP`
   - `QA_DISPLAY_NAME`
   - `QA_FIREBASE_APP_ID`
   - `DEFAULT_ENV`
6. The allocator stores the returned Codemagic `buildId` in the sticky PR comment state marker and labels the PR `ios-qa:building`.
7. Codemagic checks out the mirror branch, verifies `git rev-parse HEAD` equals `PR_HEAD_SHA`, patches build settings and Firebase metadata for the slot, applies Ad Hoc signing profiles, builds an IPA, and runs another stale-SHA check before distribution.
8. If the PR head SHA still matches `PR_HEAD_SHA`, Codemagic uploads the IPA to Firebase App Distribution.
9. If the PR has moved on or closed, Codemagic skips Firebase distribution and reports a stale build.
10. Codemagic updates the sticky PR comment state marker. GitHub reconciliation uses that marker plus labels and PR metadata to regenerate the active QA directory.

## iOS Identity Requirements

Each slot needs Apple Developer setup:

- App ID for the main app bundle ID.
- App ID for the notification service extension bundle ID.
- Ad Hoc provisioning profile for the main app.
- Ad Hoc provisioning profile for the notification service extension.
- App group matching the slot.
- Push notification capability if QA builds need push behavior.
- Associated domains if QA builds need universal links or password-manager flows.

The current app has production identifiers hard-coded in places that must become slot-configurable:

- Xcode main bundle ID.
- Xcode notification extension bundle ID.
- Main app entitlements.
- Notification extension entitlements.
- `mobile/ios/Runner/GoogleService-Info.plist`.
- `mobile/ios/firebase_app_id_file.json`.
- Firebase iOS app ID and bundle ID.
- Push registration app identifier.

## Firebase Requirements

Each slot should have a Firebase iOS app record so Firebase App Distribution, Crashlytics, and app metadata line up with the slot bundle ID.

Distribution should publish to a stable QA tester group, for example `ios-qa`.

The PR comment should link to Firebase's `testing_uri` rather than a short-lived raw binary URL.

If a QA device is not in the Ad Hoc provisioning profile, Firebase can help collect UDIDs, but the Apple profile still must be regenerated with that device before the build can install.

Firebase releases are available in App Distribution for 150 days. That is enough for active PR review, but the active directory should show last-updated time and not imply that historical PR links are permanent.

## QA Directory

Generate a single active-build directory from GitHub state. This can be a sticky GitHub issue, a markdown artifact committed only if needed, or a PR comment on an always-open tracking issue.

Directory fields:

- Slot
- PR number and title
- PR author
- Draft/ready state
- Latest built commit SHA
- Build status
- Firebase install link
- Last updated time
- Codemagic build URL
- Notes for skipped, queued, stale, or failed builds

The directory should be generated from labels, PR metadata, and sticky comment state markers, not manually edited.

## Error Handling

All slots full:

- Label the PR `ios-qa:queued`.
- Comment with the active directory and current slot occupants.
- The daily reconciliation or close-event cleanup should assign queued PRs when slots free up.

Codemagic build fails:

- Replace `ios-qa:building` with `ios-qa:failed`.
- Keep the slot assigned to the PR.
- Update the PR comment with the Codemagic build URL and failure status.

PR updates while build is running:

- Keep the same slot.
- Mark the old build stale.
- Trigger a replacement build for the new head SHA.
- Do not distribute the stale IPA.

PR closes during build:

- Release the slot labels.
- Skip distribution if Codemagic reaches the stale/closed check.

Device cannot install:

- Comment should point QA to the Firebase device registration flow.
- After UDIDs are added in Apple Developer, profiles must be regenerated and Codemagic signing assets refreshed.

Trust check fails:

- Do not trigger a signed build.
- Comment with the trusted-build policy.

## Rollout Plan

Stage 1 proves one slot end to end:

- Configure `qa01` Apple/Firebase identity.
- Add the build-time configuration path.
- Add the allocator in dry-run or one-slot mode.
- Merge the bootstrap workflow PR so `pull_request_target`/`workflow_dispatch` exists on `main`.
- Build and distribute one trusted throwaway PR through Firebase.

Stage 2 expands to 15 slots:

- Add the remaining 14 Apple/Firebase identities.
- Add the full slot map.
- Enable automatic assignment for ready PRs and `needs-ios-qa` draft PRs.
- Add queued-state handling and daily reconciliation.

## Open Decisions

- Whether QA builds should use production, staging, or a selectable `DEFAULT_ENV` by default.
- Whether universal links and web credentials should be enabled for QA slot app IDs.
- Whether push notifications must work in QA builds from day one.
- Whether to add a maintainer-only override for trusted builds from non-org forks.
