# Blossom Resumable Upload Sessions Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Divine-only resumable upload session support to the mobile client while keeping existing Blossom `PUT /upload` behavior unchanged for legacy and third-party servers.

**Architecture:** Keep `media.divine.video` as the control plane and let it return an opaque `uploadUrl` on `upload.divine.video` for resumable session uploads. Extend the mobile upload stack to detect Divine resumable capability, persist session state in `PendingUpload`, resume uploads after restart/backgrounding, and fall back cleanly to the legacy `PUT /upload` path when the server does not support the extension.

**Tech Stack:** Flutter, Dio, Hive, Riverpod, Blossom auth flow, service tests, model tests, integration tests

---

**External dependency:** The Divine upload server implementation for `POST /upload/init`, `POST /upload/{uploadId}/complete`, and `upload.divine.video` session endpoints is not present in this repository. Use `docs/protocol/blossom/2026-03-26-divine-resumable-upload-sessions-bud.md` as the server contract while implementing the mobile changes below.

## Chunk 1: Protocol Models And Persistence

### Task 1: Persist resumable upload session metadata in mobile models

**Files:**
- Create: `mobile/lib/models/blossom_resumable_upload_session.dart`
- Modify: `mobile/lib/models/pending_upload.dart`
- Modify: `mobile/lib/models/pending_upload.g.dart`
- Test: `mobile/test/models/pending_upload_resumable_upload_session_test.dart`
- Test: `mobile/test/models/pending_upload_proofmode_test.dart`

- [ ] **Step 1: Write the failing model tests**

```dart
test('PendingUpload stores resumable session metadata', () {
  final upload = PendingUpload.create(...).copyWith(
    resumableSession: BlossomResumableUploadSession(
      uploadId: 'up_123',
      uploadUrl: 'https://upload.divine.video/sessions/up_123',
      chunkSize: 8 * 1024 * 1024,
      nextOffset: 16 * 1024 * 1024,
    ),
  );

  expect(upload.resumableSession?.uploadId, 'up_123');
  expect(upload.resumableSession?.nextOffset, 16 * 1024 * 1024);
});
```

- [ ] **Step 2: Run the targeted tests to verify they fail**

Run: `flutter test test/models/pending_upload_resumable_upload_session_test.dart test/models/pending_upload_proofmode_test.dart`

Expected: FAIL because `PendingUpload` has no resumable session fields yet.

- [ ] **Step 3: Add resumable session model and wire it into `PendingUpload`**

```dart
class BlossomResumableUploadSession {
  final String uploadId;
  final String uploadUrl;
  final int chunkSize;
  final int nextOffset;
  final DateTime? expiresAt;
  final Map<String, String>? requiredHeaders;
}
```

- [ ] **Step 4: Regenerate Hive adapters**

Run: `dart run build_runner build --delete-conflicting-outputs`

Expected: `mobile/lib/models/pending_upload.g.dart` updates cleanly.

- [ ] **Step 5: Run the targeted model tests**

Run: `flutter test test/models/pending_upload_resumable_upload_session_test.dart test/models/pending_upload_proofmode_test.dart`

Expected: PASS

- [ ] **Step 6: Commit the model changes**

```bash
git add mobile/lib/models/blossom_resumable_upload_session.dart mobile/lib/models/pending_upload.dart mobile/lib/models/pending_upload.g.dart mobile/test/models/pending_upload_resumable_upload_session_test.dart mobile/test/models/pending_upload_proofmode_test.dart
git commit -m "feat(upload): persist Blossom resumable upload session state"
```

## Chunk 2: Blossom Upload Service Capability And Session Flow

### Task 2: Teach `BlossomUploadService` to negotiate and run resumable sessions

**Files:**
- Modify: `mobile/lib/services/blossom_upload_service.dart`
- Test: `mobile/test/services/blossom_upload_service_test.dart`
- Test: `mobile/test/services/blossom_upload_proofmode_test.dart`

- [ ] **Step 1: Write the failing service tests**

```dart
test('uses resumable init flow for Divine servers that advertise support', () async {
  // mock HEAD /upload capability headers, init response, chunk PUTs, complete response
});

test('falls back to legacy PUT /upload when resumable capability is absent', () async {
  // mock missing capability header and expect existing upload path
});
```

- [ ] **Step 2: Run the targeted service tests to verify they fail**

Run: `flutter test test/services/blossom_upload_service_test.dart test/services/blossom_upload_proofmode_test.dart`

Expected: FAIL because the service only knows the legacy single-shot upload flow.

- [ ] **Step 3: Add capability discovery, init, chunk upload, session HEAD, and complete helpers**

```dart
Future<BlossomUploadResult> uploadVideoResumable(...) async {
  final capability = await _fetchDivineUploadCapability(serverUrl);
  if (!capability.supportsResumable) return _uploadToServer(...);

  final session = await _initResumableUpload(...);
  await _uploadChunks(session, file, onProgress);
  return _completeResumableUpload(session, ...);
}
```

- [ ] **Step 4: Keep legacy `PUT /upload` behavior intact**

Run: `flutter test test/services/blossom_upload_service_test.dart test/services/blossom_upload_proofmode_test.dart`

Expected: PASS for both resumable and legacy cases.

- [ ] **Step 5: Commit the service changes**

```bash
git add mobile/lib/services/blossom_upload_service.dart mobile/test/services/blossom_upload_service_test.dart mobile/test/services/blossom_upload_proofmode_test.dart
git commit -m "feat(upload): add Divine resumable Blossom session flow"
```

## Chunk 3: UploadManager Resume And Lifecycle Recovery

### Task 3: Resume interrupted session uploads from persisted state

**Files:**
- Modify: `mobile/lib/services/upload_manager.dart`
- Test: `mobile/test/services/upload_manager_resumable_upload_test.dart`
- Test: `mobile/test/services/upload_manager_from_draft_test.dart`
- Test: `mobile/test/services/upload_manager_cancel_test.dart`

- [ ] **Step 1: Write the failing UploadManager tests**

```dart
test('restarts a Divine resumable upload from the last committed offset after app restart', () async {
  // seed persisted PendingUpload with resumable session state
});

test('falls back to failed state when a session expires and cannot be resumed', () async {
  // simulate 410 from session HEAD or chunk PUT
});
```

- [ ] **Step 2: Run the targeted tests to verify they fail**

Run: `flutter test test/services/upload_manager_resumable_upload_test.dart test/services/upload_manager_from_draft_test.dart test/services/upload_manager_cancel_test.dart`

Expected: FAIL because `UploadManager` does not persist or resume session offsets yet.

- [ ] **Step 3: Extend `UploadManager` to save session state and resume interrupted uploads**

```dart
if (upload.resumableSession != null) {
  final resumed = await _blossomService.resumeUploadSession(...);
  await _updateUpload(upload.copyWith(resumableSession: resumed.session));
}
```

- [ ] **Step 4: Verify lifecycle-safe resume and legacy fallback**

Run: `flutter test test/services/upload_manager_resumable_upload_test.dart test/services/upload_manager_from_draft_test.dart test/services/upload_manager_cancel_test.dart`

Expected: PASS

- [ ] **Step 5: Commit the UploadManager changes**

```bash
git add mobile/lib/services/upload_manager.dart mobile/test/services/upload_manager_resumable_upload_test.dart mobile/test/services/upload_manager_from_draft_test.dart mobile/test/services/upload_manager_cancel_test.dart
git commit -m "feat(upload): resume Divine upload sessions after interruption"
```

## Chunk 4: Local Harness, Integration Coverage, And Handoff Docs

### Task 4: Add repo-local harness coverage and finalize extension docs

**Files:**
- Modify: `local_stack/blossom-proxy/default.conf.template`
- Modify: `mobile/test/integration/blossom_upload_spec_test.dart`
- Create: `mobile/test/integration/blossom_resumable_upload_integration_test.dart`
- Modify: `docs/protocol/blossom/2026-03-26-divine-resumable-upload-sessions-bud.md`
- Modify: `docs/superpowers/specs/2026-03-26-blossom-resumable-upload-sessions-design.md`

- [ ] **Step 1: Write the failing integration coverage**

```dart
testWidgets('Divine resumable uploads use init, session PUTs, and complete', (...) async {
  // assert opaque uploadUrl handling and final canonical blob URL
});
```

- [ ] **Step 2: Run the targeted integration tests to verify they fail**

Run: `flutter test test/integration/blossom_resumable_upload_integration_test.dart test/integration/blossom_upload_spec_test.dart`

Expected: FAIL because the resumable protocol is not yet exercised.

- [ ] **Step 3: Update local harness and docs to reflect the final contract**

```nginx
# Keep control plane proxied separately from upload data plane for local testing.
```

- [ ] **Step 4: Run the focused verification suite**

Run: `flutter test test/services/blossom_upload_service_test.dart test/services/blossom_upload_proofmode_test.dart test/services/upload_manager_resumable_upload_test.dart test/integration/blossom_resumable_upload_integration_test.dart`

Expected: PASS

- [ ] **Step 5: Commit the harness and docs**

```bash
git add local_stack/blossom-proxy/default.conf.template mobile/test/integration/blossom_upload_spec_test.dart mobile/test/integration/blossom_resumable_upload_integration_test.dart docs/protocol/blossom/2026-03-26-divine-resumable-upload-sessions-bud.md docs/superpowers/specs/2026-03-26-blossom-resumable-upload-sessions-design.md
git commit -m "docs(upload): finalize Divine resumable Blossom extension contract"
```
