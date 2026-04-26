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

## File Structure

- Create: `.github/ios_qa_slots.json`
  - Slot table for `qa01` through `qa15`: bundle IDs, extension bundle IDs, app groups, display names, and Firebase app IDs.
- Create: `.github/scripts/ios_qa_slots.py`
  - Pure Python logic for trust decisions, slot parsing, slot allocation, comment rendering, and directory rendering.
- Create: `.github/scripts/tests/test_ios_qa_slots.py`
  - Unit tests for slot selection, trust, labels, stale states, and rendered comments.
- Create: `.github/workflows/mobile_ios_qa_allocate.yml`
  - Trusted metadata workflow. Uses `pull_request_target`, never checks out PR code, mirrors trusted PR heads to `ios-qa/pr-<number>`, assigns slots, triggers Codemagic, and cleans up on close.
- Create: `mobile/lib/config/build_identity.dart`
  - Build-time identity values shared by Firebase options and push registration.
- Modify: `mobile/lib/firebase_options.dart`
  - Use build-time iOS Firebase app ID and bundle ID while preserving production defaults.
- Modify: `mobile/lib/services/push_notification_service.dart`
  - Use build-time push app identifier while preserving `co.openvine.app` by default.
- Create: `mobile/test/config/build_identity_test.dart`
  - Tests default production identity and QA identity under `--dart-define`.
- Create: `mobile/scripts/ci/configure_ios_qa_slot.py`
  - Patch iOS project build settings and entitlements for one QA slot.
- Create: `mobile/scripts/ci/tests/test_configure_ios_qa_slot.py`
  - Unit tests for project/entitlement patching using temporary fixtures.
- Modify: `codemagic.yaml`
  - Add an `ios-qa-pr-build` workflow using Ad Hoc signing, slot configuration, stale checks, Firebase distribution, and GitHub notification.

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
GITHUB_TOKEN or GH_TOKEN with PR comment permissions
FIREBASE_TOKEN or service-account auth usable by firebase-tools
QA_FIREBASE_GROUP_ALIAS=ios-qa
```

Codemagic must also have access to the Ad Hoc signing certificate and `qa01` provisioning profiles.

- [ ] **Step 5: Configure GitHub secrets**

Add:

```text
CODEMAGIC_APP_ID
CODEMAGIC_API_TOKEN
DIVINEVIDEO_ORG_READ_TOKEN
```

`DIVINEVIDEO_ORG_READ_TOKEN` must be able to check active org membership for private members.

## Chunk 1: Build-Time App Identity

### Task 1: Add Identity Defaults And Tests

**Files:**

- Create: `mobile/lib/config/build_identity.dart`
- Create: `mobile/test/config/build_identity_test.dart`

- [ ] **Step 1: Write the default identity test**

Create `mobile/test/config/build_identity_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/config/build_identity.dart';

void main() {
  test('uses production iOS identity by default', () {
    expect(BuildIdentity.iosBundleId, 'co.openvine.app');
    expect(BuildIdentity.pushAppIdentifier, 'co.openvine.app');
    expect(BuildIdentity.firebaseIosAppId, '1:972941478875:ios:f61272b3cf485df244b5fe');
  });
}
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```bash
cd mobile
flutter test test/config/build_identity_test.dart
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
  --dart-define=FIREBASE_IOS_APP_ID=1:972941478875:ios:qa01placeholder
```

Expected: FAIL until the test is extended for override mode.

- [ ] **Step 6: Extend the test for override mode**

Append to `mobile/test/config/build_identity_test.dart`:

```dart
  test('can use QA identity from dart defines', () {
    const expectedBundleId = String.fromEnvironment('EXPECTED_IOS_BUNDLE_ID');
    const expectedFirebaseAppId = String.fromEnvironment(
      'EXPECTED_FIREBASE_IOS_APP_ID',
    );

    if (expectedBundleId.isEmpty && expectedFirebaseAppId.isEmpty) {
      return;
    }

    expect(BuildIdentity.iosBundleId, expectedBundleId);
    expect(BuildIdentity.pushAppIdentifier, expectedBundleId);
    expect(BuildIdentity.firebaseIosAppId, expectedFirebaseAppId);
  });
```

Run:

```bash
cd mobile
flutter test test/config/build_identity_test.dart \
  --dart-define=IOS_BUNDLE_ID=co.openvine.app.qa01 \
  --dart-define=PUSH_APP_IDENTIFIER=co.openvine.app.qa01 \
  --dart-define=FIREBASE_IOS_APP_ID=1:972941478875:ios:qa01placeholder \
  --dart-define=EXPECTED_IOS_BUNDLE_ID=co.openvine.app.qa01 \
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
- `INFOPLIST_KEY_CFBundleDisplayName = divine;` changes to `"Divine QA 01";`.
- `group.co.openvine.app` changes to `group.co.openvine.app.qa01` in both entitlements files.
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
```

Use `plistlib` for entitlements. Patch `Runner.xcodeproj/project.pbxproj` as text, but keep replacements narrow and fail if an expected production identifier is not found.

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
  --display-name "Divine QA 01"

git diff -- mobile/ios/Runner.xcodeproj/project.pbxproj \
  mobile/ios/Runner/Runner.entitlements \
  mobile/ios/NotificationServiceExtension/NotificationServiceExtension.entitlements
```

Expected: diff shows only bundle ID, display name, and app group changes.

- [ ] **Step 4: Revert the dry-run project changes**

Run:

```bash
git checkout -- mobile/ios/Runner.xcodeproj/project.pbxproj \
  mobile/ios/Runner/Runner.entitlements \
  mobile/ios/NotificationServiceExtension/NotificationServiceExtension.entitlements
```

This checkout is only for changes made by this dry-run step.

- [ ] **Step 5: Commit**

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

Create `.github/ios_qa_slots.json` with all 15 slots. Use the real Firebase app IDs as they are created. For slots not created yet, set `firebaseAppId` to an empty string and keep the allocator disabled for those slots.

```json
{
  "slots": [
    {
      "slot": "qa01",
      "label": "ios-qa-slot-01",
      "bundleId": "co.openvine.app.qa01",
      "extensionBundleId": "co.openvine.app.qa01.NotificationServiceExtension",
      "appGroup": "group.co.openvine.app.qa01",
      "displayName": "Divine QA 01",
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
- Existing slot label is preserved.
- First free slot is assigned.
- Queued state when all configured slots are occupied.
- Closed PR cleanup returns labels to remove and mirror branch to delete.
- Comment renderer includes slot, PR, SHA, Firebase testing URI, and Codemagic URL.

Run:

```bash
python3 -m unittest .github/scripts/tests/test_ios_qa_slots.py
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
def is_trusted_pr(head_repo_owner, author_is_org_member): ...
def is_eligible_pr(is_draft, labels): ...
def current_slot(labels): ...
def choose_slot(slots, open_prs): ...
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
```

The workflow can pass event JSON paths and write outputs to `$GITHUB_OUTPUT`.

- [ ] **Step 3: Run tests**

Run:

```bash
python3 -m unittest .github/scripts/tests/test_ios_qa_slots.py
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
    paths:
      - "mobile/**"
      - "codemagic.yaml"
  workflow_dispatch:
    inputs:
      pr_number:
        required: true
```

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

- [ ] **Step 2: Add trust check**

The workflow should call the GitHub org membership API using `DIVINEVIDEO_ORG_READ_TOKEN` when `head.repo.owner.login != "divinevideo"`.

Expected trusted condition:

```text
head repo owner is divinevideo OR author is active divinevideo org member/owner
```

- [ ] **Step 3: Mirror trusted PR head to base repo**

For trusted eligible PRs:

```bash
git fetch origin "pull/${PR_NUMBER}/head"
git push origin "FETCH_HEAD:refs/heads/ios-qa/pr-${PR_NUMBER}" --force
```

For closed PRs:

```bash
git push origin ":refs/heads/ios-qa/pr-${PR_NUMBER}" || true
```

- [ ] **Step 4: Trigger Codemagic**

Use the Codemagic Builds API with:

```text
workflow_id=ios-qa-pr-build
branch=ios-qa/pr-<number>
environment variables:
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
```

Use `CODEMAGIC_APP_ID` and `CODEMAGIC_API_TOKEN` from GitHub secrets.

- [ ] **Step 5: Update labels and comments**

The workflow should:

- Add or preserve `ios-qa-slot-NN`.
- Add `ios-qa:building` when a build is triggered.
- Add `ios-qa:queued` when no slot is available.
- Add a sticky comment with a hidden marker `<!-- divine-ios-qa-build -->`.
- Avoid duplicate comments.

- [ ] **Step 6: Validate workflow YAML**

Run:

```bash
ruby -e "require 'yaml'; YAML.load_file('.github/workflows/mobile_ios_qa_allocate.yml')"
python3 -m unittest .github/scripts/tests/test_ios_qa_slots.py
```

Expected: both commands exit 0.

- [ ] **Step 7: Commit**

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
- &configure_ios_qa_slot
  name: Configure iOS QA slot
  script: |
    python3 scripts/ci/configure_ios_qa_slot.py \
      --project-root . \
      --bundle-id "$QA_BUNDLE_ID" \
      --extension-bundle-id "$QA_EXTENSION_BUNDLE_ID" \
      --app-group "$QA_APP_GROUP" \
      --display-name "$QA_DISPLAY_NAME"

- &verify_ios_qa_head
  name: Verify mirrored PR SHA
  script: |
    ACTUAL_SHA="$(git rev-parse HEAD)"
    if [ "$ACTUAL_SHA" != "$PR_HEAD_SHA" ]; then
      echo "Stale mirror branch: expected $PR_HEAD_SHA, got $ACTUAL_SHA"
      exit 1
    fi
```

- [ ] **Step 2: Add QA build script**

Build with slot dart defines:

```yaml
- &build_ios_qa
  name: Build iOS QA IPA
  script: |
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
    npm install -g firebase-tools
    IPA_PATH="$(ls build/ios/ipa/*.ipa | head -1)"
    firebase appdistribution:distribute "$IPA_PATH" \
      --app "$QA_FIREBASE_APP_ID" \
      --groups "$QA_FIREBASE_GROUP_ALIAS" \
      --release-notes "PR #$PR_NUMBER $PR_HEAD_SHA ($QA_SLOT)" \
      --json > "$CM_BUILD_DIR/firebase-distribution.json"
```

- [ ] **Step 4: Add stale PR check before distribution**

Before Firebase distribution, call GitHub API using `GH_TOKEN` and verify:

```text
PR is open
PR head SHA equals PR_HEAD_SHA
```

If stale, exit 0 after notifying GitHub with stale status. Do not upload the IPA.

- [ ] **Step 5: Add GitHub notification script**

After Firebase distribution, parse `firebase-distribution.json`, extract the tester URI, and update the sticky PR comment. If Firebase CLI JSON shape differs, adapt the parser and document the observed output in the commit.

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
    ios_signing:
      distribution_type: ad_hoc
      bundle_identifier: $QA_BUNDLE_ID
  triggering:
    events: []
  scripts:
    - *verify_ios_qa_head
    - *setup_code_signing_xcode
    - *install_flutterfire
    - *enable_spm
    - *prepare_ios_spm_packages
    - *configure_ios_qa_slot
    - *pod_install
    - *build_ios_qa
    - *distribute_ios_qa_firebase
  artifacts:
    - build/ios/ipa/*.ipa
    - build/ios/archive/Runner.xcarchive/dSYMs/**
    - /tmp/xcodebuild_logs/*.log
    - firebase-distribution.json
```

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
- Firebase install links.
- Codemagic build links.
- Last updated timestamp.

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
- Assign queued PRs when slots are free.
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
python3 -m unittest .github/scripts/tests/test_ios_qa_slots.py
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

- [ ] **Step 1: Run local verification**

Run:

```bash
python3 -m unittest .github/scripts/tests/test_ios_qa_slots.py
python3 -m unittest mobile/scripts/ci/tests/test_configure_ios_qa_slot.py
ruby -e "require 'yaml'; YAML.load_file('codemagic.yaml')"
ruby -e "require 'yaml'; YAML.load_file('.github/workflows/mobile_ios_qa_allocate.yml')"
cd mobile
flutter test test/config/build_identity_test.dart
```

Expected: all pass.

- [ ] **Step 2: Trigger one trusted PR manually**

Use workflow dispatch on `Mobile iOS QA Allocate` with a trusted PR number.

Expected:

- PR receives `ios-qa-slot-01`.
- PR receives `ios-qa:building`.
- Branch `ios-qa/pr-<number>` exists and points to the PR head SHA.
- Codemagic starts `ios-qa-pr-build`.

- [ ] **Step 3: Verify Firebase install**

Expected:

- Firebase App Distribution shows a release for `co.openvine.app.qa01`.
- PR sticky comment includes Firebase tester link.
- QA can install `Divine QA 01` on a registered iOS device.
- Production/TestFlight app remains installed side by side.

- [ ] **Step 4: Verify close cleanup**

Close or use a throwaway test PR.

Expected:

- Slot labels are removed.
- Mirror branch is deleted.
- Directory updates.

## Chunk 8: Expand To 15 Slots

### Task 12: Enable Remaining Slots

**Files:**

- Modify: `.github/ios_qa_slots.json`
- Possibly modify: Apple/Firebase/Codemagic external config only

- [ ] **Step 1: Create remaining Apple/Firebase identities**

Repeat external setup for `qa02` through `qa15`.

- [ ] **Step 2: Fill real Firebase app IDs**

Update `.github/ios_qa_slots.json`.

- [ ] **Step 3: Run slot tests**

Run:

```bash
python3 -m unittest .github/scripts/tests/test_ios_qa_slots.py
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
python3 -m unittest .github/scripts/tests/test_ios_qa_slots.py
python3 -m unittest mobile/scripts/ci/tests/test_configure_ios_qa_slot.py
ruby -e "require 'yaml'; YAML.load_file('codemagic.yaml')"
ruby -e "require 'yaml'; YAML.load_file('.github/workflows/mobile_ios_qa_allocate.yml')"
cd mobile
flutter test test/config/build_identity_test.dart
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

