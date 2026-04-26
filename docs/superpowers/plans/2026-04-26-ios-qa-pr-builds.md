# iOS QA PR Builds Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an automated iOS QA distribution lane where trusted mobile PRs get reusable side-by-side Ad Hoc builds published through Firebase App Distribution.

**Architecture:** GitHub Actions owns trust checks, slot allocation, labels, mirror branches, comments, and the active build directory. Codemagic owns the signed Ad Hoc IPA build for a specific QA slot. The Flutter app and iOS project read build identity from explicit build-time inputs so one codebase can produce production and `qa01` through `qa15` apps.

**Tech Stack:** GitHub Actions, Python 3 standard library tests, Codemagic YAML, Flutter/Dart compile-time environment values, Xcode project/entitlements patching, Firebase App Distribution CLI, Apple Ad Hoc signing.

---

## Source Documents

- Design spec: `docs/superpowers/specs/2026-04-26-ios-qa-pr-builds-design.md`
- Existing iOS Codemagic workflow: `codemagic.yaml`
- Existing web PR preview workflows: `.github/workflows/mobile_pr_preview_build.yml`, `.github/workflows/mobile_pr_preview_deploy.yml`
- Existing web preview comment renderer: `.github/scripts/mobile_pr_preview_comment.py`
- External docs checked on 2026-04-26:
  - [Codemagic Builds API](https://docs.codemagic.io/rest-api/builds/): `POST /builds` accepts `appId`, `workflowId`, `branch`, `environment.variables`, and returns `buildId`.
  - [Codemagic iOS signing](https://docs.codemagic.io/yaml-code-signing/signing-ios/): Firebase/App Distribution uses Ad Hoc signing; bundle-identifier based signing also fetches matching extension profiles.
  - [Firebase App Distribution CLI](https://firebase.google.com/docs/app-distribution/ios/distribute-cli): use the stable `testing_uri` for testers; direct binary links expire quickly.
  - [Codemagic Firebase distribution](https://docs.codemagic.io/yaml-distributing/firebase-app-distribution/): prefer Firebase service-account auth over deprecated Firebase token auth.
  - [Codemagic post-publish scripts](https://docs.codemagic.io/yaml-distributing/post-publish/): post-publish scripts run even after build failure unless the build is canceled or times out; use them for GitHub status notification.
  - [GitHub Security Lab pwn request guidance](https://securitylab.github.com/resources/github-actions-preventing-pwn-requests/): `pull_request_target` must not execute PR-controlled code in a privileged context.

## File Structure

- Create: `.github/ios_qa_slots.json`
  - Slot table for `qa01` through `qa15`: enabled flag, bundle IDs, extension bundle IDs, app groups, display names, and Firebase app IDs.
- Create: `.github/scripts/ios_qa_slots.py`
  - Pure Python logic for trust decisions, slot parsing, slot allocation, sticky comment state markers, comment rendering, and directory rendering.
- Create: `.github/scripts/tests/test_ios_qa_slots.py`
  - Unit tests for slot selection, trust, labels, sticky state markers, stale states, queued ordering, and rendered comments.
- Create: `.github/workflows/mobile_ios_qa_allocate.yml`
  - Trusted metadata workflow. Uses `pull_request_target`, checks out only base-repo scripts, never executes PR code, mirrors trusted PR heads to `ios-qa/pr-<number>`, assigns slots, triggers Codemagic, and cleans up on close.
- Create: `mobile/lib/config/build_identity.dart`
  - Build-time identity values shared by Firebase options and push registration.
- Modify: `mobile/lib/firebase_options.dart`
  - Use build-time iOS Firebase app ID and bundle ID while preserving production defaults.
- Modify: `mobile/lib/services/push_notification_service.dart`
  - Use build-time push app identifier while preserving `co.openvine.app` by default.
- Create: `mobile/test/config/build_identity_test.dart`
  - Tests default production identity and QA identity under `--dart-define`.
- Create: `mobile/scripts/ci/configure_ios_qa_slot.py`
  - Patch iOS project build settings, entitlements, `GoogleService-Info.plist`, and `firebase_app_id_file.json` for one QA slot. Supports a no-write dry-run diff for the real project check.
- Create: `mobile/scripts/ci/tests/test_configure_ios_qa_slot.py`
  - Unit tests for project, entitlement, and Firebase metadata patching using temporary fixtures.
- Modify: `codemagic.yaml`
  - Add an `ios-qa-pr-build` workflow using Ad Hoc signing, slot configuration before signing-profile application, stale checks, Firebase service-account distribution, and GitHub notification.

## Chunk 0: External Setup Checklist

This chunk is a prerequisite. Do not start build automation until `qa01` exists in Apple Developer, Firebase, Codemagic, and GitHub secrets.

- [ ] **Step 1: Create Apple identifiers for `qa01`**

Create:

```text
co.openvine.app.qa01
co.openvine.app.qa01.NotificationServiceExtension
group.co.openvine.app.qa01
```

Enable the capabilities needed by the main app and extension. At minimum include app groups. Add push notifications and associated domains only if QA must test those flows in stage 1.

- [ ] **Step 2: Create Ad Hoc provisioning profiles for `qa01`**

Create profiles for:

```text
co.openvine.app.qa01
co.openvine.app.qa01.NotificationServiceExtension
```

Include the current QA device UDIDs. Remember Apple device limits: Ad Hoc devices are capped per product family per membership year.

- [ ] **Step 3: Create Firebase iOS app for `qa01`**

Create a Firebase iOS app with bundle ID:

```text
co.openvine.app.qa01
```

Record its Firebase app ID for `.github/ios_qa_slots.json`.

- [ ] **Step 4: Configure Codemagic environment groups**

Add or confirm groups:

```text
zendesk_credentials
proofmode_credentials
github_credentials
firebase_app_distribution
ios_qa_signing
```

Expected secrets:

```text
IOS_QA_GITHUB_TOKEN with PR comment/label permissions and pull request read permissions
FIREBASE_SERVICE_ACCOUNT JSON with Firebase App Distribution Admin role
GOOGLE_APPLICATION_CREDENTIALS=$CM_BUILD_DIR/firebase_credentials.json
QA_FIREBASE_GROUP_ALIAS=ios-qa
```

Use Firebase token auth only as a temporary fallback; Codemagic's Firebase App Distribution docs mark token auth deprecated. Codemagic must also have access to the Ad Hoc signing certificate and `qa01` provisioning profiles.

- [ ] **Step 5: Configure GitHub secrets**

Add:

```text
CODEMAGIC_APP_ID
CODEMAGIC_API_TOKEN
DIVINEVIDEO_ORG_READ_TOKEN
```

`DIVINEVIDEO_ORG_READ_TOKEN` must be able to check active org membership for private members.

- [ ] **Step 6: Configure GitHub variables**

Add:

```text
IOS_QA_DIRECTORY_ISSUE_NUMBER
IOS_QA_DEFAULT_ENV=STAGING
```

If there is not yet a QA tracking issue, create one titled `iOS QA PR Builds` and store its issue number in `IOS_QA_DIRECTORY_ISSUE_NUMBER`.

- [ ] **Step 7: Bootstrap GitHub labels**

Create or update the labels the allocator uses before enabling the workflow. The repo does not currently have `ios-qa*` labels, so this must be idempotent and part of rollout.

Run:

```bash
for n in $(seq -w 1 15); do
  gh label create "ios-qa-slot-$n" \
    --color "0E8A16" \
    --description "iOS QA build slot $n" \
    --force
done

gh label create "ios-qa:building" \
  --color "FBCA04" \
  --description "iOS QA build is running" \
  --force
gh label create "ios-qa:ready" \
  --color "0E8A16" \
  --description "iOS QA build is ready for testing" \
  --force
gh label create "ios-qa:queued" \
  --color "D4C5F9" \
  --description "iOS QA build is waiting for a slot" \
  --force
gh label create "ios-qa:failed" \
  --color "D93F0B" \
  --description "iOS QA build failed" \
  --force
gh label create "needs-ios-qa" \
  --color "5319E7" \
  --description "Build this draft PR for iOS QA" \
  --force
```

Expected: command exits 0 and `gh label list --limit 300 | rg '^ios-qa|^needs-ios-qa'` shows all 20 labels.

## Chunk 1: Build-Time App Identity

### Task 1: Add Identity Defaults And Tests

**Files:**

- Create: `mobile/lib/config/build_identity.dart`
- Create: `mobile/test/config/build_identity_test.dart`

- [ ] **Step 1: Write the identity test**

Create `mobile/test/config/build_identity_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/config/build_identity.dart';

void main() {
  test('uses iOS identity from dart defines with production defaults', () {
    const expectedBundleId = String.fromEnvironment(
      'EXPECTED_IOS_BUNDLE_ID',
      defaultValue: 'co.openvine.app',
    );
    const expectedPushAppIdentifier = String.fromEnvironment(
      'EXPECTED_PUSH_APP_IDENTIFIER',
      defaultValue: expectedBundleId,
    );
    const expectedFirebaseAppId = String.fromEnvironment(
      'EXPECTED_FIREBASE_IOS_APP_ID',
      defaultValue: '1:972941478875:ios:f61272b3cf485df244b5fe',
    );

    expect(BuildIdentity.iosBundleId, expectedBundleId);
    expect(BuildIdentity.pushAppIdentifier, expectedPushAppIdentifier);
    expect(BuildIdentity.firebaseIosAppId, expectedFirebaseAppId);
  });
}
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```bash
cd mobile
flutter test test/config/build_identity_test.dart
flutter test test/config/build_identity_test.dart \
  --dart-define=IOS_BUNDLE_ID=co.openvine.app.qa01 \
  --dart-define=PUSH_APP_IDENTIFIER=co.openvine.app.qa01 \
  --dart-define=FIREBASE_IOS_APP_ID=1:972941478875:ios:qa01placeholder \
  --dart-define=EXPECTED_IOS_BUNDLE_ID=co.openvine.app.qa01 \
  --dart-define=EXPECTED_PUSH_APP_IDENTIFIER=co.openvine.app.qa01 \
  --dart-define=EXPECTED_FIREBASE_IOS_APP_ID=1:972941478875:ios:qa01placeholder
```

Expected: FAIL because `BuildIdentity` does not exist.

- [ ] **Step 3: Add the build identity implementation**

Create `mobile/lib/config/build_identity.dart`:

```dart
// ABOUTME: Centralizes build-time app identity for production and QA slot builds.
// ABOUTME: Values default to production and can be overridden by CI dart-defines.

class BuildIdentity {
  static const iosBundleId = String.fromEnvironment(
    'IOS_BUNDLE_ID',
    defaultValue: 'co.openvine.app',
  );

  static const pushAppIdentifier = String.fromEnvironment(
    'PUSH_APP_IDENTIFIER',
    defaultValue: iosBundleId,
  );

  static const firebaseIosAppId = String.fromEnvironment(
    'FIREBASE_IOS_APP_ID',
    defaultValue: '1:972941478875:ios:f61272b3cf485df244b5fe',
  );
}
```

- [ ] **Step 4: Run the default identity test**

Run:

```bash
cd mobile
flutter test test/config/build_identity_test.dart
```

Expected: PASS.

- [ ] **Step 5: Run the QA override test command**

Run:

```bash
cd mobile
flutter test test/config/build_identity_test.dart \
  --dart-define=IOS_BUNDLE_ID=co.openvine.app.qa01 \
  --dart-define=PUSH_APP_IDENTIFIER=co.openvine.app.qa01 \
  --dart-define=FIREBASE_IOS_APP_ID=1:972941478875:ios:qa01placeholder \
  --dart-define=EXPECTED_IOS_BUNDLE_ID=co.openvine.app.qa01 \
  --dart-define=EXPECTED_PUSH_APP_IDENTIFIER=co.openvine.app.qa01 \
  --dart-define=EXPECTED_FIREBASE_IOS_APP_ID=1:972941478875:ios:qa01placeholder
```

Expected: PASS.

### Task 2: Wire Identity Into Firebase And Push

**Files:**

- Modify: `mobile/lib/firebase_options.dart`
- Modify: `mobile/lib/services/push_notification_service.dart`
- Test: `mobile/test/config/build_identity_test.dart`

- [ ] **Step 1: Update Firebase iOS options**

Modify `mobile/lib/firebase_options.dart`:

```dart
import 'package:openvine/config/build_identity.dart';
```

Then change the iOS options:

```dart
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyChiPGndRdZwsMoLqnel2WSocROmoKLdB4',
    appId: BuildIdentity.firebaseIosAppId,
    messagingSenderId: '972941478875',
    projectId: 'openvine-co',
    storageBucket: 'openvine-co.firebasestorage.app',
    iosBundleId: BuildIdentity.iosBundleId,
  );
```

- [ ] **Step 2: Update push app identifier**

Modify `mobile/lib/services/push_notification_service.dart`:

```dart
import 'package:openvine/config/build_identity.dart';
```

Then change:

```dart
static const pushAppIdentifier = BuildIdentity.pushAppIdentifier;
```

- [ ] **Step 3: Run focused tests**

Run:

```bash
cd mobile
flutter test test/config/build_identity_test.dart
flutter test test/config/build_identity_test.dart \
  --dart-define=IOS_BUNDLE_ID=co.openvine.app.qa01 \
  --dart-define=PUSH_APP_IDENTIFIER=co.openvine.app.qa01 \
  --dart-define=FIREBASE_IOS_APP_ID=1:972941478875:ios:qa01placeholder \
  --dart-define=EXPECTED_IOS_BUNDLE_ID=co.openvine.app.qa01 \
  --dart-define=EXPECTED_PUSH_APP_IDENTIFIER=co.openvine.app.qa01 \
  --dart-define=EXPECTED_FIREBASE_IOS_APP_ID=1:972941478875:ios:qa01placeholder
```

Expected: both commands PASS.

- [ ] **Step 4: Commit**

Run:

```bash
git add mobile/lib/config/build_identity.dart \
  mobile/lib/firebase_options.dart \
  mobile/lib/services/push_notification_service.dart \
  mobile/test/config/build_identity_test.dart
git commit -m "feat(ios): make app identity build configurable"
```

## Chunk 2: iOS Slot Project Patching

### Task 3: Add Patch Script Tests

**Files:**

- Create: `mobile/scripts/ci/tests/test_configure_ios_qa_slot.py`
- Create later: `mobile/scripts/ci/configure_ios_qa_slot.py`

- [ ] **Step 1: Write failing Python tests**

Create tests that copy minimal fixtures into a temp directory and verify:

- `PRODUCT_BUNDLE_IDENTIFIER = co.openvine.app;` changes to `co.openvine.app.qa01`.
- `PRODUCT_BUNDLE_IDENTIFIER = co.openvine.app.NotificationServiceExtension;` changes to `co.openvine.app.qa01.NotificationServiceExtension`.
- `PRODUCT_BUNDLE_IDENTIFIER = co.openvine.app.RunnerTests;` does not change.
- `INFOPLIST_KEY_CFBundleDisplayName = divine;` changes to `"Divine QA 01";`.
- `group.co.openvine.app` changes to `group.co.openvine.app.qa01` in both entitlements files.
- `BUNDLE_ID` in `Runner/GoogleService-Info.plist` changes to `co.openvine.app.qa01`.
- `GOOGLE_APP_ID` in `Runner/GoogleService-Info.plist` and `ios/firebase_app_id_file.json` changes to the slot Firebase app ID.
- `--dry-run` prints a unified diff and leaves fixture files unchanged.
- Missing required arguments fail with a non-zero exit.

Run:

```bash
python3 -m unittest mobile/scripts/ci/tests/test_configure_ios_qa_slot.py
```

Expected: FAIL because `configure_ios_qa_slot.py` does not exist.

### Task 4: Implement Project Patching Script

**Files:**

- Create: `mobile/scripts/ci/configure_ios_qa_slot.py`
- Test: `mobile/scripts/ci/tests/test_configure_ios_qa_slot.py`

- [ ] **Step 1: Implement the script**

The script should accept:

```text
--project-root mobile
--bundle-id co.openvine.app.qa01
--extension-bundle-id co.openvine.app.qa01.NotificationServiceExtension
--app-group group.co.openvine.app.qa01
--display-name "Divine QA 01"
--firebase-ios-app-id 1:972941478875:ios:qa01placeholder
```

Use `plistlib` for entitlements and Firebase plist/JSON metadata. Patch `Runner.xcodeproj/project.pbxproj` as text, but keep replacements narrow, do not change RunnerTests bundle IDs, and fail if an expected production identifier is not found. The script must support `--dry-run` for the real-project check.

- [ ] **Step 2: Run script tests**

Run:

```bash
python3 -m unittest mobile/scripts/ci/tests/test_configure_ios_qa_slot.py
```

Expected: PASS.

- [ ] **Step 3: Run a local dry check on the real project**

Run from repo root:

```bash
python3 mobile/scripts/ci/configure_ios_qa_slot.py \
  --project-root mobile \
  --bundle-id co.openvine.app.qa01 \
  --extension-bundle-id co.openvine.app.qa01.NotificationServiceExtension \
  --app-group group.co.openvine.app.qa01 \
  --display-name "Divine QA 01" \
  --firebase-ios-app-id 1:972941478875:ios:qa01placeholder \
  --dry-run
```

Expected: stdout diff shows only bundle ID, display name, app group, Firebase bundle ID, and Firebase app ID changes. `git diff -- mobile/ios` is empty after the command.

Run:

```bash
git diff --exit-code -- mobile/ios/Runner.xcodeproj/project.pbxproj \
  mobile/ios/Runner/Runner.entitlements \
  mobile/ios/NotificationServiceExtension/NotificationServiceExtension.entitlements \
  mobile/ios/Runner/GoogleService-Info.plist \
  mobile/ios/firebase_app_id_file.json
```

Expected: exits 0.

- [ ] **Step 4: Commit**

Run:

```bash
git add mobile/scripts/ci/configure_ios_qa_slot.py \
  mobile/scripts/ci/tests/test_configure_ios_qa_slot.py
git commit -m "build(ios): add qa slot project patcher"
```

## Chunk 3: Slot Allocation Library

### Task 5: Add Slot Map

**Files:**

- Create: `.github/ios_qa_slots.json`

- [ ] **Step 1: Add slot map**

Create `.github/ios_qa_slots.json` with all 15 slots. Use the real Firebase app IDs as they are created. For slots not created yet, set `enabled` to `false` and `firebaseAppId` to an empty string. Stage 1 should enable only `qa01`.

```json
{
  "slots": [
    {
      "slot": "qa01",
      "label": "ios-qa-slot-01",
      "enabled": true,
      "bundleId": "co.openvine.app.qa01",
      "extensionBundleId": "co.openvine.app.qa01.NotificationServiceExtension",
      "appGroup": "group.co.openvine.app.qa01",
      "displayName": "Divine QA 01",
      "firebaseAppId": "1:972941478875:ios:qa01placeholder"
    },
    {
      "slot": "qa02",
      "label": "ios-qa-slot-02",
      "enabled": false,
      "bundleId": "co.openvine.app.qa02",
      "extensionBundleId": "co.openvine.app.qa02.NotificationServiceExtension",
      "appGroup": "group.co.openvine.app.qa02",
      "displayName": "Divine QA 02",
      "firebaseAppId": ""
    }
  ]
}
```

- [ ] **Step 2: Validate JSON**

Run:

```bash
python3 -m json.tool .github/ios_qa_slots.json >/tmp/ios_qa_slots.json
```

Expected: command exits 0.

### Task 6: Add Slot Library Tests

**Files:**

- Create: `.github/scripts/tests/test_ios_qa_slots.py`
- Create later: `.github/scripts/ios_qa_slots.py`

- [ ] **Step 1: Write failing tests**

Cover:

- Trusted when `head_repo_owner == "divinevideo"`.
- Trusted when membership API result is active member.
- Not trusted for outside fork and non-member.
- Draft PR without `needs-ios-qa` is not eligible.
- Draft PR with `needs-ios-qa` is eligible.
- PRs with no changes under `mobile/**` or `codemagic.yaml` are skipped but still cleaned up if labels already exist.
- Existing slot label is preserved.
- First free enabled slot is assigned.
- Disabled slots and slots with empty `firebaseAppId` are not assigned.
- Queued state when all enabled slots are occupied.
- Queued PRs are ordered by oldest `needs-ios-qa`/ready eligibility timestamp, then PR number for deterministic reconciliation.
- Closed PR cleanup returns labels to remove and mirror branch to delete.
- Sticky state marker round-trips JSON for slot, PR number, full commit SHA, status, Codemagic build ID/URL, Firebase `testing_uri`, and failure reason.
- Required-label renderer returns all 15 slot labels plus `ios-qa:building`, `ios-qa:ready`, `ios-qa:queued`, `ios-qa:failed`, and `needs-ios-qa`.
- Firebase distribution parser extracts `testing_uri` from known Firebase CLI JSON shapes: top-level, `result`, and `result.release`. It rejects JSON that only has `binary_download_uri`.
- Comment renderer includes slot, PR, full SHA, Firebase testing URI, and Codemagic URL. Do not truncate Nostr IDs; commit SHAs may be shortened only for display if the full SHA remains in the hidden state marker and table.

Run:

```bash
PYTHONPATH=.github/scripts python3 -m unittest discover -s .github/scripts/tests -p 'test_*.py'
```

Expected: FAIL because `ios_qa_slots.py` does not exist.

### Task 7: Implement Slot Library

**Files:**

- Create: `.github/scripts/ios_qa_slots.py`
- Test: `.github/scripts/tests/test_ios_qa_slots.py`

- [ ] **Step 1: Implement pure functions first**

Required functions:

```python
def load_slots(path): ...
def enabled_slots(slots): ...
def is_trusted_pr(head_repo_owner, author_is_org_member): ...
def is_eligible_pr(is_draft, labels): ...
def current_slot(labels): ...
def choose_slot(slots, open_prs): ...
def render_state_marker(state): ...
def parse_state_marker(comment_body): ...
def required_labels(slots): ...
def extract_firebase_testing_uri(firebase_distribution_json): ...
def render_status_comment(...): ...
def render_directory(...): ...
```

- [ ] **Step 2: Add CLI modes**

CLI modes:

```text
allocate
render-comment
render-directory
cleanup
parse-comment-state
render-codemagic-payload
upsert-comment
notify-github
render-label-bootstrap
parse-firebase-distribution
```

The workflow can pass event JSON paths and write outputs to `$GITHUB_OUTPUT`. Use JSON files for PR metadata to avoid shell interpolation of untrusted PR titles, branch names, labels, or author names.

- [ ] **Step 3: Run tests**

Run:

```bash
PYTHONPATH=.github/scripts python3 -m unittest discover -s .github/scripts/tests -p 'test_*.py'
```

Expected: PASS.

- [ ] **Step 4: Commit**

Run:

```bash
git add .github/ios_qa_slots.json \
  .github/scripts/ios_qa_slots.py \
  .github/scripts/tests/test_ios_qa_slots.py
git commit -m "ci(ios): add qa slot allocation logic"
```

## Chunk 4: GitHub Allocator Workflow

### Task 8: Add Trusted Allocator Workflow

**Files:**

- Create: `.github/workflows/mobile_ios_qa_allocate.yml`
- Modify: `.github/scripts/ios_qa_slots.py` if CLI gaps appear
- Test: `.github/scripts/tests/test_ios_qa_slots.py`

- [ ] **Step 1: Add workflow skeleton**

Use `pull_request_target` so secrets are available, but never check out or execute PR code in this workflow.

Triggers:

```yaml
on:
  pull_request_target:
    branches: [main]
    types: [opened, synchronize, reopened, ready_for_review, converted_to_draft, closed, labeled, unlabeled]
  workflow_dispatch:
    inputs:
      pr_number:
        required: true
```

Do not use workflow `paths` filters here. The script should decide whether the PR touches mobile/Codemagic files so close events, manual dispatches, and scheduled reconciliation cannot be skipped by path filtering.

Permissions:

```yaml
permissions:
  contents: write
  issues: write
  pull-requests: write
```

Concurrency:

```yaml
concurrency:
  group: ios-qa-slot-allocator
  cancel-in-progress: false
```

- [ ] **Step 2: Add idempotent label bootstrap**

The workflow should ensure labels exist before it tries to apply them. Add a step that renders the required labels from `.github/scripts/ios_qa_slots.py render-label-bootstrap`, then creates/updates them through the GitHub API or `gh label create --force`.

Expected labels:

```text
ios-qa-slot-01 through ios-qa-slot-15
ios-qa:building
ios-qa:ready
ios-qa:queued
ios-qa:failed
needs-ios-qa
```

- [ ] **Step 3: Add trust check**

The workflow should call the GitHub org membership API using `DIVINEVIDEO_ORG_READ_TOKEN` when `head.repo.owner.login != "divinevideo"`.

Expected trusted condition:

```text
head repo owner is divinevideo OR author is active divinevideo org member/owner
```

For `workflow_dispatch`, fetch the PR metadata with the GitHub API by `pr_number` and write it to a JSON file consumed by `.github/scripts/ios_qa_slots.py`.

- [ ] **Step 4: Mirror trusted PR head to base repo**

For trusted eligible PRs:

```bash
git fetch --no-tags origin "pull/${PR_NUMBER}/head"
git push "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" \
  "FETCH_HEAD:refs/heads/ios-qa/pr-${PR_NUMBER}" --force
```

For closed PRs:

```bash
git push "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" \
  ":refs/heads/ios-qa/pr-${PR_NUMBER}" || true
```

The checkout step must use the base repository only, with `persist-credentials: false`. Fetching the PR head is allowed only after the trust check and only for mirroring; no step may run code from `FETCH_HEAD`.

- [ ] **Step 5: Trigger Codemagic**

Use the Codemagic Builds API with `appId`, `workflowId`, `branch`, labels, and `environment.variables`:

```bash
payload_file="${RUNNER_TEMP}/codemagic-ios-qa-build.json"
python3 .github/scripts/ios_qa_slots.py render-codemagic-payload \
  --app-id "$CODEMAGIC_APP_ID" \
  --workflow-id ios-qa-pr-build \
  --branch "ios-qa/pr-${PR_NUMBER}" \
  --pr-json "$RUNNER_TEMP/pr.json" \
  --slot-json "$RUNNER_TEMP/slot.json" \
  --default-env "${IOS_QA_DEFAULT_ENV:-STAGING}" \
  > "$payload_file"

curl --fail-with-body \
  -H "Content-Type: application/json" \
  -H "x-auth-token: ${CODEMAGIC_API_TOKEN}" \
  --data @"$payload_file" \
  -X POST https://api.codemagic.io/builds \
  > "$RUNNER_TEMP/codemagic-response.json"
```

The payload must include these `environment.variables`:

```text
PR_NUMBER
PR_HEAD_SHA
PR_HEAD_REPO
PR_HEAD_REF
QA_SLOT
QA_BUNDLE_ID
QA_EXTENSION_BUNDLE_ID
QA_APP_GROUP
QA_DISPLAY_NAME
QA_FIREBASE_APP_ID
DEFAULT_ENV
CODEMAGIC_APP_ID
```

Use `CODEMAGIC_APP_ID` and `CODEMAGIC_API_TOKEN` from GitHub secrets.

- [ ] **Step 6: Update labels and comments**

The workflow should:

- Add or preserve `ios-qa-slot-NN`.
- Add `ios-qa:building` when a build is triggered.
- Add `ios-qa:queued` when no slot is available.
- Add or update a sticky comment with a hidden marker `<!-- divine-ios-qa-build:v1 ... -->` containing JSON state.
- Avoid duplicate comments.
- Store the Codemagic `buildId` returned by `POST /builds` in the hidden state marker.

- [ ] **Step 7: Validate workflow YAML**

Run:

```bash
ruby -e "require 'yaml'; YAML.load_file('.github/workflows/mobile_ios_qa_allocate.yml')"
PYTHONPATH=.github/scripts python3 -m unittest discover -s .github/scripts/tests -p 'test_*.py'
```

Expected: both commands exit 0.

- [ ] **Step 8: Commit**

Run:

```bash
git add .github/workflows/mobile_ios_qa_allocate.yml .github/scripts/ios_qa_slots.py
git commit -m "ci(ios): allocate qa slots for trusted prs"
```

## Chunk 5: Codemagic QA Build Workflow

### Task 9: Add iOS QA Workflow

**Files:**

- Modify: `codemagic.yaml`

- [ ] **Step 1: Add QA scripts**

Add reusable scripts:

```yaml
- &validate_ios_qa_env
  name: Validate iOS QA environment
  script: |
    set -eu
    for name in \
      PR_NUMBER PR_HEAD_SHA PR_HEAD_REPO PR_HEAD_REF \
      QA_SLOT QA_BUNDLE_ID QA_EXTENSION_BUNDLE_ID QA_APP_GROUP \
      QA_DISPLAY_NAME QA_FIREBASE_APP_ID DEFAULT_ENV \
      CODEMAGIC_APP_ID IOS_QA_GITHUB_TOKEN QA_FIREBASE_GROUP_ALIAS
    do
      eval "value=\${$name:-}"
      if [ -z "$value" ]; then
        echo "Missing required iOS QA variable: $name"
        exit 1
      fi
    done
    echo "GH_TOKEN=$IOS_QA_GITHUB_TOKEN" >> "$CM_ENV"

- &configure_ios_qa_slot
  name: Configure iOS QA slot
  script: |
    set -eu
    python3 scripts/ci/configure_ios_qa_slot.py \
      --project-root . \
      --bundle-id "$QA_BUNDLE_ID" \
      --extension-bundle-id "$QA_EXTENSION_BUNDLE_ID" \
      --app-group "$QA_APP_GROUP" \
      --display-name "$QA_DISPLAY_NAME" \
      --firebase-ios-app-id "$QA_FIREBASE_APP_ID"

- &verify_ios_qa_head
  name: Verify mirrored PR SHA
  script: |
    set -eu
    ACTUAL_SHA="$(git rev-parse HEAD)"
    if [ "$ACTUAL_SHA" != "$PR_HEAD_SHA" ]; then
      echo "Stale mirror branch: expected $PR_HEAD_SHA, got $ACTUAL_SHA"
      exit 1
    fi

- &write_firebase_credentials
  name: Write Firebase service-account credentials
  script: |
    set -eu
    if [ -n "${FIREBASE_SERVICE_ACCOUNT:-}" ]; then
      : "${GOOGLE_APPLICATION_CREDENTIALS:=$CM_BUILD_DIR/firebase_credentials.json}"
      printf '%s' "$FIREBASE_SERVICE_ACCOUNT" > "$GOOGLE_APPLICATION_CREDENTIALS"
      echo "GOOGLE_APPLICATION_CREDENTIALS=$GOOGLE_APPLICATION_CREDENTIALS" >> "$CM_ENV"
      exit 0
    fi

    if [ -n "${FIREBASE_TOKEN:-}" ]; then
      echo "Using deprecated FIREBASE_TOKEN fallback. Prefer FIREBASE_SERVICE_ACCOUNT."
      exit 0
    fi

    echo "Missing FIREBASE_SERVICE_ACCOUNT or FIREBASE_TOKEN"
    exit 1
```

- [ ] **Step 2: Add QA build script**

Build with slot dart defines:

```yaml
- &build_ios_qa
  name: Build iOS QA IPA
  script: |
    set -eu
    flutter build ipa --release --build-number="$PROJECT_BUILD_NUMBER" \
      --dart-define=ZENDESK_APP_ID="$ZENDESK_APP_ID" \
      --dart-define=ZENDESK_CLIENT_ID="$ZENDESK_CLIENT_ID" \
      --dart-define=ZENDESK_URL="$ZENDESK_URL" \
      --dart-define=DEFAULT_ENV="$DEFAULT_ENV" \
      --dart-define=PROOFMODE_SIGNING_SERVER_ENDPOINT="$PROOFMODE_SIGNING_SERVER_ENDPOINT" \
      --dart-define=PROOFMODE_SIGNING_SERVER_TOKEN="$PROOFMODE_SIGNING_SERVER_TOKEN" \
      --dart-define=IOS_BUNDLE_ID="$QA_BUNDLE_ID" \
      --dart-define=PUSH_APP_IDENTIFIER="$QA_BUNDLE_ID" \
      --dart-define=FIREBASE_IOS_APP_ID="$QA_FIREBASE_APP_ID" \
      --export-options-plist=/Users/builder/export_options.plist
```

- [ ] **Step 3: Add Firebase distribution script**

Install Firebase CLI if needed, distribute the IPA, and capture JSON output:

```yaml
- &distribute_ios_qa_firebase
  name: Distribute iOS QA build to Firebase
  script: |
    set -eu
    if [ "${STALE_IOS_QA_BUILD:-}" = "true" ]; then
      echo "Skipping Firebase distribution for stale iOS QA build"
      exit 0
    fi

    npm install -g firebase-tools
    IPA_PATH="$(ls build/ios/ipa/*.ipa | head -1)"
    firebase_token_args=""
    if [ -n "${FIREBASE_TOKEN:-}" ] && [ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]; then
      firebase_token_args="--token $FIREBASE_TOKEN"
    fi
    firebase appdistribution:distribute "$IPA_PATH" \
      --app "$QA_FIREBASE_APP_ID" \
      --groups "$QA_FIREBASE_GROUP_ALIAS" \
      --release-notes "PR #$PR_NUMBER $PR_HEAD_SHA ($QA_SLOT)" \
      --json \
      $firebase_token_args \
      > firebase-distribution.json

    python3 ../.github/scripts/ios_qa_slots.py parse-firebase-distribution \
      --json-file firebase-distribution.json \
      --require-testing-uri \
      > firebase-distribution-links.json
```

`parse-firebase-distribution` must support the Firebase CLI JSON shapes observed in tests: top-level links, `result` links, and `result.release` links. It must fail when only `binary_download_uri` is present, because that link expires after one hour and is not acceptable for QA comments.

- [ ] **Step 4: Add stale PR check before distribution**

Before Firebase distribution, call GitHub API using `IOS_QA_GITHUB_TOKEN` and verify:

```text
PR is open
PR head SHA equals PR_HEAD_SHA
```

If stale, exit 0 after notifying GitHub with stale status. Do not upload the IPA.

Add a reusable script:

```yaml
- &verify_ios_qa_pr_current
  name: Verify PR is still current before distribution
  script: |
    set -eu
    pr_json="pr-current.json"
    curl --fail-with-body \
      -H "Authorization: Bearer $IOS_QA_GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/$CM_REPO_SLUG/pulls/$PR_NUMBER" \
      > "$pr_json"

    python3 - "$pr_json" <<'PY'
    import json
    import os
    import sys

    pr = json.load(open(sys.argv[1], encoding="utf-8"))
    expected = os.environ["PR_HEAD_SHA"]
    actual = pr["head"]["sha"]
    if pr["state"] != "open" or actual != expected:
        print(f"STALE_IOS_QA_BUILD=true", file=open(os.environ["CM_ENV"], "a", encoding="utf-8"))
        print(f"Stale PR build: state={pr['state']} expected={expected} actual={actual}")
        raise SystemExit(0)
    PY
```

Make `*distribute_ios_qa_firebase` skip upload when `STALE_IOS_QA_BUILD=true`, then run the GitHub notification script with `status=stale`.

- [ ] **Step 5: Add GitHub notification script**

Add this as a Codemagic post-publish script so it runs even when the main build fails. After Firebase distribution, parse `firebase-distribution.json`, extract `testing_uri`, and update the sticky PR comment. If `STALE_IOS_QA_BUILD=true`, update the same sticky comment with stale status and do not require a Firebase JSON file. If Firebase CLI JSON shape differs, adapt the parser and document the observed output in the commit.

The notification script should:

- Replace `ios-qa:building` with `ios-qa:ready` on successful distribution.
- Replace `ios-qa:building` with `ios-qa:failed` on build/distribution failure.
- Keep the slot label on ready, stale, and failed states.
- Preserve a hidden JSON state marker with full commit SHA, Codemagic build URL, Firebase `testing_uri`, and updated timestamp.
- Use `IOS_QA_GITHUB_TOKEN`/`GH_TOKEN` from Codemagic, not a GitHub Actions token.
- Tolerate early build failures before validation has run. If the minimum GitHub context (`IOS_QA_GITHUB_TOKEN`, `CM_REPO_SLUG`, `PR_NUMBER`) is missing, log the missing keys and exit 0 instead of masking the original build failure.

Add a reusable script:

```yaml
- &notify_ios_qa_github
  name: Notify GitHub about iOS QA build
  script: |
    set -u
    missing_context=""
    for name in IOS_QA_GITHUB_TOKEN CM_REPO_SLUG PR_NUMBER; do
      eval "value=\${$name:-}"
      if [ -z "$value" ]; then
        missing_context="$missing_context $name"
      fi
    done
    if [ -n "$missing_context" ]; then
      echo "Cannot update GitHub for iOS QA build; missing:$missing_context"
      exit 0
    fi

    status="ready"
    firebase_json="firebase-distribution.json"
    if [ "${STALE_IOS_QA_BUILD:-}" = "true" ]; then
      status="stale"
      firebase_json=""
    elif [ ! -s "$firebase_json" ]; then
      status="failed"
      firebase_json=""
    fi
    if [ -n "${CODEMAGIC_APP_ID:-}" ] && [ -n "${CM_BUILD_ID:-}" ]; then
      codemagic_build_url="https://codemagic.io/app/$CODEMAGIC_APP_ID/build/$CM_BUILD_ID"
    else
      codemagic_build_url="Codemagic build URL unavailable"
    fi
    qa_slot="${QA_SLOT:-unknown}"
    pr_head_sha="${PR_HEAD_SHA:-unknown}"

    if [ -n "$firebase_json" ]; then
      python3 ../.github/scripts/ios_qa_slots.py render-comment \
        --status "$status" \
        --pr-number "$PR_NUMBER" \
        --slot "$qa_slot" \
        --sha "$pr_head_sha" \
        --codemagic-build-url "$codemagic_build_url" \
        --firebase-json "$firebase_json" \
        > ios-qa-comment.md
    else
      python3 ../.github/scripts/ios_qa_slots.py render-comment \
        --status "$status" \
        --pr-number "$PR_NUMBER" \
        --slot "$qa_slot" \
        --sha "$pr_head_sha" \
        --codemagic-build-url "$codemagic_build_url" \
        > ios-qa-comment.md
    fi

    python3 ../.github/scripts/ios_qa_slots.py notify-github \
      --repo "$CM_REPO_SLUG" \
      --issue-number "$PR_NUMBER" \
      --token-env IOS_QA_GITHUB_TOKEN \
      --status "$status" \
      --body-file ios-qa-comment.md
```

Implement marker-based update-or-create in this task: list existing issue comments, find `<!-- divine-ios-qa-build:v1`, patch that comment when present, and create only when absent. The same mode should update labels for `ready`, `failed`, and `stale` statuses.

- [ ] **Step 6: Add `ios-qa-pr-build` workflow**

Add workflow:

```yaml
ios-qa-pr-build:
  name: iOS QA PR Build
  working_directory: mobile
  max_build_duration: 60
  instance_type: mac_mini_m2
  integrations:
    app_store_connect: API key for Codemagic
  environment:
    flutter: 3.41.1
    xcode: latest
    cocoapods: default
    groups:
      - zendesk_credentials
      - proofmode_credentials
      - github_credentials
      - firebase_app_distribution
      - ios_qa_signing
    vars:
      QA_FIREBASE_GROUP_ALIAS: ios-qa
    ios_signing:
      distribution_type: ad_hoc
      bundle_identifier: $QA_BUNDLE_ID
  triggering:
    events: []
  scripts:
    - *validate_ios_qa_env
    - *verify_ios_qa_head
    - *write_firebase_credentials
    - *install_flutterfire
    - *enable_spm
    - *flutter_pub_get
    - *prepare_ios_spm_packages
    - *configure_ios_qa_slot
    - *setup_code_signing_xcode
    - *pod_install
    - *build_ios_qa
    - *verify_ios_qa_pr_current
    - *distribute_ios_qa_firebase
  artifacts:
    - build/ios/ipa/*.ipa
    - build/ios/archive/Runner.xcarchive/dSYMs/**
    - /tmp/xcodebuild_logs/*.log
    - firebase-distribution.json
    - firebase-distribution-links.json
    - pr-current.json
    - ios-qa-comment.md
  publishing:
    scripts:
      - *notify_ios_qa_github
```

The slot patch must run before `*setup_code_signing_xcode`; otherwise `xcode-project use-profiles` can bind production profiles to the unpatched project.

If Codemagic does not accept `$QA_BUNDLE_ID` in `ios_signing.bundle_identifier`, replace this with 15 generated workflows or a script-level `app-store-connect fetch-signing-files` approach after proving the constraint in a dry run.

- [ ] **Step 7: Validate YAML**

Run:

```bash
ruby -e "require 'yaml'; YAML.load_file('codemagic.yaml')"
```

Expected: exits 0.

- [ ] **Step 8: Commit**

Run:

```bash
git add codemagic.yaml
git commit -m "ci(ios): add qa pr codemagic workflow"
```

## Chunk 6: Directory And Reconciliation

### Task 10: Add Active Directory And Cleanup

**Files:**

- Modify: `.github/scripts/ios_qa_slots.py`
- Modify: `.github/workflows/mobile_ios_qa_allocate.yml`
- Test: `.github/scripts/tests/test_ios_qa_slots.py`

- [ ] **Step 1: Add directory renderer tests**

Test that rendered directory includes:

- Active slots.
- Queued PRs.
- Failed PRs.
- Stale builds superseded by newer commits.
- Firebase install links.
- Codemagic build links.
- Last updated timestamp.
- Build metadata recovered from sticky comment state markers.

- [ ] **Step 2: Add scheduled reconciliation**

Extend the workflow:

```yaml
on:
  schedule:
    - cron: "17 15 * * *"
```

The scheduled job should:

- List open PRs.
- Remove stale slot labels from closed PRs if any remain.
- Delete stale `ios-qa/pr-*` branches for closed PRs.
- Assign queued PRs when slots are free, using deterministic queued ordering from the slot library.
- Refresh stale/building states whose Codemagic build has finished without a post-publish update.
- Re-render the active build directory.

- [ ] **Step 3: Decide directory home**

Use a sticky issue comment if a QA tracking issue exists. If not, create a new issue titled:

```text
iOS QA PR Builds
```

Store its issue number in a GitHub Actions variable:

```text
IOS_QA_DIRECTORY_ISSUE_NUMBER
```

- [ ] **Step 4: Run tests**

Run:

```bash
PYTHONPATH=.github/scripts python3 -m unittest discover -s .github/scripts/tests -p 'test_*.py'
ruby -e "require 'yaml'; YAML.load_file('.github/workflows/mobile_ios_qa_allocate.yml')"
```

Expected: PASS / exit 0.

- [ ] **Step 5: Commit**

Run:

```bash
git add .github/scripts/ios_qa_slots.py \
  .github/scripts/tests/test_ios_qa_slots.py \
  .github/workflows/mobile_ios_qa_allocate.yml
git commit -m "ci(ios): reconcile qa slots and directory"
```

## Chunk 7: Stage 1 Verification

### Task 11: Prove `qa01` End To End

**Files:**

- No source changes expected unless verification exposes issues.

GitHub only runs `pull_request_target` and `workflow_dispatch` workflows that exist on `main`. Do not treat the bootstrap PR as fully end-to-end verified until this workflow has been merged or otherwise exists on `main`; use a throwaway trusted mobile PR for the live `qa01` proof.

- [ ] **Step 1: Run local verification**

Run:

```bash
PYTHONPATH=.github/scripts python3 -m unittest discover -s .github/scripts/tests -p 'test_*.py'
python3 -m unittest mobile/scripts/ci/tests/test_configure_ios_qa_slot.py
ruby -e "require 'yaml'; YAML.load_file('codemagic.yaml')"
ruby -e "require 'yaml'; YAML.load_file('.github/workflows/mobile_ios_qa_allocate.yml')"
python3 mobile/scripts/ci/configure_ios_qa_slot.py \
  --project-root mobile \
  --bundle-id co.openvine.app.qa01 \
  --extension-bundle-id co.openvine.app.qa01.NotificationServiceExtension \
  --app-group group.co.openvine.app.qa01 \
  --display-name "Divine QA 01" \
  --firebase-ios-app-id 1:972941478875:ios:qa01placeholder \
  --dry-run >/tmp/ios-qa-slot-dry-run.diff
git diff --exit-code -- mobile/ios/Runner.xcodeproj/project.pbxproj \
  mobile/ios/Runner/Runner.entitlements \
  mobile/ios/NotificationServiceExtension/NotificationServiceExtension.entitlements \
  mobile/ios/Runner/GoogleService-Info.plist \
  mobile/ios/firebase_app_id_file.json
cd mobile
flutter test test/config/build_identity_test.dart
flutter test test/config/build_identity_test.dart \
  --dart-define=IOS_BUNDLE_ID=co.openvine.app.qa01 \
  --dart-define=PUSH_APP_IDENTIFIER=co.openvine.app.qa01 \
  --dart-define=FIREBASE_IOS_APP_ID=1:972941478875:ios:qa01placeholder \
  --dart-define=EXPECTED_IOS_BUNDLE_ID=co.openvine.app.qa01 \
  --dart-define=EXPECTED_PUSH_APP_IDENTIFIER=co.openvine.app.qa01 \
  --dart-define=EXPECTED_FIREBASE_IOS_APP_ID=1:972941478875:ios:qa01placeholder
```

Expected: all pass.

- [ ] **Step 2: Trigger one trusted throwaway PR manually**

After the bootstrap workflow exists on `main`, use workflow dispatch on `Mobile iOS QA Allocate` with a trusted throwaway PR number.

Expected:

- PR receives `ios-qa-slot-01`.
- PR receives `ios-qa:building`.
- Branch `ios-qa/pr-<number>` exists and points to the PR head SHA.
- Codemagic starts `ios-qa-pr-build`.
- PR sticky comment contains `<!-- divine-ios-qa-build:v1` with the full PR head SHA and Codemagic build ID.

- [ ] **Step 3: Verify Firebase install**

Expected:

- Firebase App Distribution shows a release for `co.openvine.app.qa01`.
- PR sticky comment includes Firebase `testing_uri`.
- PR label changes from `ios-qa:building` to `ios-qa:ready`.
- QA can install `Divine QA 01` on a registered iOS device.
- Production/TestFlight app remains installed side by side.

- [ ] **Step 4: Verify close cleanup**

Close or use a throwaway test PR.

Expected:

- Slot labels are removed.
- Mirror branch is deleted.
- Directory updates.
- A still-running Codemagic build skips distribution when it reaches the stale/closed check.

## Chunk 8: Expand To 15 Slots

### Task 12: Enable Remaining Slots

**Files:**

- Modify: `.github/ios_qa_slots.json`
- Possibly modify: Apple/Firebase/Codemagic external config only

- [ ] **Step 1: Create remaining Apple/Firebase identities**

Repeat external setup for `qa02` through `qa15`.

- [ ] **Step 2: Fill real Firebase app IDs and enable slots**

Update `.github/ios_qa_slots.json` with each real Firebase app ID and set `enabled: true` only after the matching Apple identifiers, App Group, Ad Hoc profiles, Firebase app, and Codemagic signing assets exist.

- [ ] **Step 3: Run slot tests**

Run:

```bash
PYTHONPATH=.github/scripts python3 -m unittest discover -s .github/scripts/tests -p 'test_*.py'
python3 -m json.tool .github/ios_qa_slots.json >/tmp/ios_qa_slots.json
```

Expected: PASS / exit 0.

- [ ] **Step 4: Commit**

Run:

```bash
git add .github/ios_qa_slots.json
git commit -m "ci(ios): enable all qa slots"
```

## Final Verification

- [ ] **Run all local non-signing verification**

```bash
PYTHONPATH=.github/scripts python3 -m unittest discover -s .github/scripts/tests -p 'test_*.py'
python3 -m unittest mobile/scripts/ci/tests/test_configure_ios_qa_slot.py
ruby -e "require 'yaml'; YAML.load_file('codemagic.yaml')"
ruby -e "require 'yaml'; YAML.load_file('.github/workflows/mobile_ios_qa_allocate.yml')"
python3 mobile/scripts/ci/configure_ios_qa_slot.py \
  --project-root mobile \
  --bundle-id co.openvine.app.qa01 \
  --extension-bundle-id co.openvine.app.qa01.NotificationServiceExtension \
  --app-group group.co.openvine.app.qa01 \
  --display-name "Divine QA 01" \
  --firebase-ios-app-id 1:972941478875:ios:qa01placeholder \
  --dry-run >/tmp/ios-qa-slot-dry-run.diff
git diff --exit-code -- mobile/ios/Runner.xcodeproj/project.pbxproj \
  mobile/ios/Runner/Runner.entitlements \
  mobile/ios/NotificationServiceExtension/NotificationServiceExtension.entitlements \
  mobile/ios/Runner/GoogleService-Info.plist \
  mobile/ios/firebase_app_id_file.json
cd mobile
flutter test test/config/build_identity_test.dart
flutter test test/config/build_identity_test.dart \
  --dart-define=IOS_BUNDLE_ID=co.openvine.app.qa01 \
  --dart-define=PUSH_APP_IDENTIFIER=co.openvine.app.qa01 \
  --dart-define=FIREBASE_IOS_APP_ID=1:972941478875:ios:qa01placeholder \
  --dart-define=EXPECTED_IOS_BUNDLE_ID=co.openvine.app.qa01 \
  --dart-define=EXPECTED_PUSH_APP_IDENTIFIER=co.openvine.app.qa01 \
  --dart-define=EXPECTED_FIREBASE_IOS_APP_ID=1:972941478875:ios:qa01placeholder
cd ..
```

- [ ] **Review diff**

```bash
git diff --stat origin/main...HEAD
git diff origin/main...HEAD -- .github codemagic.yaml mobile/lib mobile/scripts mobile/test docs/superpowers
```

- [ ] **Push and open PR**

```bash
git push -u origin HEAD
gh pr create \
  --title "ci(ios): add QA PR build slots" \
  --body "Adds the iOS QA PR build slot design and implementation for Ad Hoc Firebase distribution."
```
