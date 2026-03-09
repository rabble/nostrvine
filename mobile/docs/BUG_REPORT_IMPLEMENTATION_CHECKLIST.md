# Bug Report System Implementation Checklist

**Reference**: See `BUG_REPORT_SYSTEM_ARCHITECTURE.md` for complete architecture details.

---

## Prerequisites

### 1. Verify NIP-44/NIP-59 Support in nostr_sdk

```bash
# Check if NIP-44 and NIP-59 are implemented
ls -la ../nostr_sdk/lib/nip44/
ls -la ../nostr_sdk/lib/nip59/

# Look for encryption/decryption methods
grep -r "encrypt\|decrypt" ../nostr_sdk/lib/nip44/
grep -r "seal\|gift.*wrap" ../nostr_sdk/lib/nip59/
```

**Action Required**:
- [ ] Verify NIP-44 encryption support exists
- [ ] Verify NIP-59 seal/gift-wrap support exists
- [ ] If missing, research alternative: rust-nostr FFI or Dart implementation

### 2. Set Up Bug Report Recipient

**Action Required**:
- [ ] Generate or obtain Divine support Nostr keypair
- [ ] Set pubkey in `lib/config/bug_report_config.dart`
- [ ] Securely store nsec for decryption tool (Phase 7)
- [ ] Test decryption manually with nostr client (e.g., nak, nostr-tools)

### 3. Add Dependencies (if needed)

```yaml
# pubspec.yaml
dependencies:
  uuid: ^4.5.1  # For report ID generation
  package_info_plus: ^8.0.3  # For app version info
  # device_info_plus already exists for ProofMode
```

---

## Phase 1: LogCaptureService

### Files to Create

```
lib/models/log_entry.dart                    (Data model)
lib/services/log_capture_service.dart        (Service implementation)
test/unit/services/log_capture_service_test.dart  (Unit tests)
```

### Implementation Checklist

- [ ] **Create `lib/models/log_entry.dart`**
  - [ ] Define LogEntry class with timestamp, level, message, category, etc.
  - [ ] Add toJson() and fromJson() methods

- [ ] **Write failing test**: Buffer stores logs
  ```dart
  test('captureLog should store log entry in buffer', () { ... });
  ```

- [ ] **Implement `lib/services/log_capture_service.dart`**
  - [ ] Singleton pattern with `instance` getter
  - [ ] Circular buffer using `Queue<LogEntry>` (max 1000)
  - [ ] `captureLog(LogEntry entry)` method
  - [ ] Thread-safe with mutex/lock

- [ ] **Write failing test**: Buffer respects max size
  ```dart
  test('buffer should not exceed 1000 entries', () { ... });
  ```

- [ ] **Implement**: Evict oldest when buffer full
  - [ ] `if (_buffer.length >= _maxSize) _buffer.removeFirst();`

- [ ] **Write failing test**: getRecentLogs returns chronological order
  ```dart
  test('getRecentLogs should return entries in chronological order', () { ... });
  ```

- [ ] **Implement**: `getRecentLogs({int? limit})` with sorting

- [ ] **Write failing test**: clearBuffer removes all entries
  ```dart
  test('clearBuffer should remove all entries', () { ... });
  ```

- [ ] **Implement**: `clearBuffer()` method

- [ ] **Integrate with UnifiedLogger**
  - [ ] Modify `lib/utils/unified_logger.dart`
  - [ ] Call `LogCaptureService.instance.captureLog()` in `_log()` method

- [ ] **Run tests**: `flutter test test/unit/services/log_capture_service_test.dart`

- [ ] **Run `flutter analyze`**: Fix any issues

---

## Phase 2: BugReportService

### Files to Create

```
lib/models/bug_report_data.dart              (Data model)
lib/models/bug_report_result.dart            (Result model)
lib/config/bug_report_config.dart            (Configuration)
lib/services/bug_report_service.dart         (Service implementation)
test/unit/services/bug_report_service_test.dart  (Unit tests)
test/unit/models/bug_report_data_test.dart   (Model tests)
```

### Implementation Checklist

- [ ] **Create `lib/config/bug_report_config.dart`**
  - [ ] Define `supportPubkey` constant (TODO: replace with actual)
  - [ ] Define `maxLogEntries = 1000`
  - [ ] Define `maxReportSizeBytes = 1024 * 1024`
  - [ ] Define `sensitivePatterns` regex list

- [ ] **Create `lib/models/bug_report_result.dart`**
  - [ ] BugReportResult class with success/error/reportId/messageEventId
  - [ ] Factory methods: `createSuccess()`, `failure()`

- [ ] **Create `lib/models/bug_report_data.dart`**
  - [ ] BugReportData class with all diagnostic fields
  - [ ] `toJson()` method
  - [ ] `toFormattedReport()` method for human-readable text

- [ ] **Write failing test**: BugReportData serialization
  ```dart
  test('BugReportData should serialize to JSON', () { ... });
  ```

- [ ] **Write failing test**: collectDiagnostics gathers device info
  ```dart
  test('collectDiagnostics should gather device info', () async { ... });
  ```

- [ ] **Implement `lib/services/bug_report_service.dart`**
  - [ ] Constructor with dependencies (LogCaptureService, NostrService, etc.)
  - [ ] `collectDiagnostics({required String userDescription})` method
  - [ ] Device info from `ProofModeAttestationService.getDeviceInfo()`
  - [ ] App version from `PackageInfo.fromPlatform()`
  - [ ] Recent logs from `LogCaptureService.getRecentLogs()`
  - [ ] Error counts from `ErrorAnalyticsTracker` (add getter for error counts map)
  - [ ] Relay status from `NostrService.getRelayStatus()`

- [ ] **Write failing test**: sanitizeSensitiveData removes nsec keys
  ```dart
  test('sanitizeSensitiveData should remove nsec keys', () { ... });
  ```

- [ ] **Implement**: `_sanitizeSensitiveData(BugReportData data)` method
  - [ ] Apply regex patterns to userDescription
  - [ ] Apply regex patterns to log messages and errors
  - [ ] Return sanitized copy of BugReportData

- [ ] **Write failing test**: Report size validation
  ```dart
  test('should reject reports exceeding max size', () { ... });
  ```

- [ ] **Implement**: Size checking and truncation if needed

- [ ] **Run tests**: `flutter test test/unit/services/bug_report_service_test.dart`

- [ ] **Run `flutter analyze`**: Fix any issues

---

## Phase 3: NIP17MessageService

### Files to Create

```
lib/services/nip17_message_service.dart      (Service implementation)
lib/models/nip17_send_result.dart            (Result model)
test/unit/services/nip17_message_service_test.dart  (Unit tests)
test/integration/nip17_message_integration_test.dart (Integration tests)
```

### Implementation Checklist

- [ ] **CRITICAL: Verify NIP-44/NIP-59 APIs in nostr_sdk**
  - [ ] Document encryption method signatures
  - [ ] Document seal/gift-wrap helper methods (if any)

- [ ] **Create `lib/models/nip17_send_result.dart`**
  - [ ] NIP17SendResult class with success/error/messageEventId/recipientPubkey

- [ ] **Write failing test**: createKind14Message creates unsigned event
  ```dart
  test('createKind14Message should create unsigned kind 14', () { ... });
  ```

- [ ] **Implement**: `_createKind14Message()` private method
  - [ ] Return Map with kind: 14, unsigned
  - [ ] Include p-tag, client-tag

- [ ] **Write failing test**: sealMessage encrypts with sender's key
  ```dart
  test('sealMessage should create signed kind 13', () async { ... });
  ```

- [ ] **Implement**: `_sealMessage()` private method
  - [ ] JSON encode kind 14
  - [ ] Encrypt with NIP-44 to recipient pubkey
  - [ ] Sign with sender's key → kind 13 Event

- [ ] **Write failing test**: giftWrapMessage uses random keypair
  ```dart
  test('giftWrapMessage should use random keypair', () async { ... });
  ```

- [ ] **Implement**: `_giftWrapMessage()` private method
  - [ ] Generate random keypair
  - [ ] Encrypt kind 13 seal with NIP-44 to recipient
  - [ ] Randomize timestamp: `now - Random().nextInt(172800)` (2 days in seconds)
  - [ ] Sign with random keypair → kind 1059 Event

- [ ] **Write failing test**: sendPrivateMessage broadcasts gift wrap
  ```dart
  test('sendPrivateMessage should broadcast kind 1059', () async { ... });
  ```

- [ ] **Implement**: `sendPrivateMessage()` public method
  - [ ] Call _createKind14Message()
  - [ ] Call _sealMessage()
  - [ ] Call _giftWrapMessage()
  - [ ] Broadcast via NostrService
  - [ ] Return NIP17SendResult

- [ ] **Run unit tests**: `flutter test test/unit/services/nip17_message_service_test.dart`

- [ ] **Write integration test**: End-to-end NIP-17 send
  ```dart
  test('should send and decrypt NIP-17 message', () async { ... });
  ```

- [ ] **Run integration tests**: `flutter test test/integration/nip17_message_integration_test.dart`

- [ ] **Manual test**: Send test message and decrypt with recipient account

- [ ] **Run `flutter analyze`**: Fix any issues

---

## Phase 4: UI Integration

### Files to Create

```
lib/widgets/bug_report_dialog.dart           (Dialog widget)
lib/screens/bug_report_screen.dart           (Optional full-screen form)
test/widgets/bug_report_dialog_test.dart     (Widget tests)
test/goldens/widgets/bug_report_dialog_golden_test.dart (Golden tests)
```

### Implementation Checklist

- [ ] **Write failing widget test**: Dialog shows description field
  ```dart
  testWidgets('BugReportDialog should show description field', (tester) async { ... });
  ```

- [ ] **Implement `lib/widgets/bug_report_dialog.dart`**
  - [ ] AlertDialog with TextField for description
  - [ ] Disclosure text explaining what data is included
  - [ ] Submit and Cancel buttons
  - [ ] Loading state during submission
  - [ ] Success/error SnackBar handling

- [ ] **Write failing widget test**: Submit calls BugReportService
  ```dart
  testWidgets('Submit should call BugReportService.sendBugReport', (tester) async { ... });
  ```

- [ ] **Implement**: Service integration
  - [ ] Use Riverpod provider for BugReportService
  - [ ] Call `collectDiagnostics()` and `sendBugReport()`
  - [ ] Handle success/error results

- [ ] **Write failing widget test**: Shows success snackbar
  ```dart
  testWidgets('Should show success snackbar on submit', (tester) async { ... });
  ```

- [ ] **Implement**: SnackBar display logic

- [ ] **Run widget tests**: `flutter test test/widgets/bug_report_dialog_test.dart`

- [ ] **Write golden test**: Dialog appearance
  ```dart
  testGoldens('BugReportDialog renders correctly', (tester) async { ... });
  ```

- [ ] **Update goldens**: `./scripts/golden.sh update test/goldens/widgets/bug_report_dialog_golden_test.dart`

- [ ] **Integrate into Settings screen**
  - [ ] Modify `lib/screens/settings_screen.dart`
  - [ ] Add "Report a Bug" ListTile
  - [ ] Wire up to show BugReportDialog

- [ ] **Test manually**: Open Settings → Report a Bug → Fill form → Submit

- [ ] **Run `flutter analyze`**: Fix any issues

---

## Phase 5: Testing & Polish

### Checklist

- [ ] **End-to-End Integration Test**
  ```dart
  test('complete bug report flow', () async { ... });
  ```
  - [ ] Generate test logs
  - [ ] Trigger bug report submission
  - [ ] Verify event broadcast
  - [ ] (Manual) Decrypt on recipient side

- [ ] **Analytics Integration**
  - [ ] Track `bug_report_submitted` event
  - [ ] Track `bug_report_failed` event
  - [ ] Include report_id, log_count, error_count in parameters

- [ ] **Documentation**
  - [ ] User guide: How to report bugs (in Settings screen help text)
  - [ ] Developer guide: How to decrypt bug reports (separate doc for support team)

- [ ] **Platform Testing**
  - [ ] Test on iOS (physical device + simulator)
  - [ ] Test on Android (physical device + emulator)
  - [ ] Test on Web (Chrome)
  - [ ] Test on macOS

- [ ] **Edge Cases**
  - [ ] Test without authentication (no user pubkey)
  - [ ] Test with empty logs
  - [ ] Test with huge logs (verify truncation)
  - [ ] Test relay connection failures

- [ ] **Final Code Review**
  - [ ] Run `flutter analyze` - zero issues
  - [ ] Run `flutter test` - all tests pass
  - [ ] Check test coverage: `flutter test --coverage`
  - [ ] Review sanitization patterns - ensure no data leaks

---

## Verification

### Pre-Merge Checklist

- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] All widget tests pass
- [ ] All golden tests pass
- [ ] `flutter analyze` returns zero issues
- [ ] Test coverage ≥ 80%
- [ ] Manual testing completed on all platforms
- [ ] Bug report successfully decrypted by recipient
- [ ] Documentation complete
- [ ] Privacy review: No sensitive data in reports
- [ ] Performance check: Log capture doesn't impact app performance

### Deployment Checklist

- [ ] Update `CHANGELOG.md` with bug report feature
- [ ] Update app version in `pubspec.yaml`
- [ ] Create PR with complete architecture + implementation
- [ ] Code review by Rabble
- [ ] Merge to main branch
- [ ] Deploy to TestFlight/Google Play Beta
- [ ] Announce feature to users
- [ ] Monitor analytics for bug report submissions

---

## Quick Reference: File Tree

```
lib/
├── models/
│   ├── log_entry.dart                    # NEW
│   ├── bug_report_data.dart              # NEW
│   ├── bug_report_result.dart            # NEW
│   └── nip17_send_result.dart            # NEW
├── config/
│   └── bug_report_config.dart            # NEW
├── services/
│   ├── log_capture_service.dart          # NEW
│   ├── bug_report_service.dart           # NEW
│   └── nip17_message_service.dart        # NEW
├── widgets/
│   └── bug_report_dialog.dart            # NEW
├── screens/
│   ├── bug_report_screen.dart            # NEW (optional)
│   └── settings_screen.dart              # MODIFIED
└── utils/
    └── unified_logger.dart                # MODIFIED

test/
├── unit/
│   ├── models/
│   │   └── bug_report_data_test.dart     # NEW
│   └── services/
│       ├── log_capture_service_test.dart # NEW
│       ├── bug_report_service_test.dart  # NEW
│       └── nip17_message_service_test.dart # NEW
├── integration/
│   ├── bug_report_e2e_test.dart          # NEW
│   └── nip17_message_integration_test.dart # NEW
├── widgets/
│   └── bug_report_dialog_test.dart       # NEW
└── goldens/
    └── widgets/
        └── bug_report_dialog_golden_test.dart # NEW

docs/
├── BUG_REPORT_SYSTEM_ARCHITECTURE.md     # CREATED
└── BUG_REPORT_IMPLEMENTATION_CHECKLIST.md # CREATED
```

---

## Estimated Effort

**Phase 1 (LogCaptureService)**: 2-3 hours
**Phase 2 (BugReportService)**: 4-6 hours
**Phase 3 (NIP17MessageService)**: 6-8 hours (most complex)
**Phase 4 (UI Integration)**: 3-4 hours
**Phase 5 (Testing & Polish)**: 4-6 hours

**Total Estimated Time**: 19-27 hours

---

## Support & Questions

If you encounter issues during implementation:

1. **NIP-44/NIP-59 APIs unclear**: Check rust-nostr documentation or ask in Nostr developer channels
2. **Encryption failing**: Verify nostr_sdk version and NIP-44 compatibility
3. **Tests failing**: Review architecture doc for expected behavior
4. **Integration questions**: Reference existing VideoSharingService (NIP-04 example)

**Ready to begin?** Start with Phase 1: LogCaptureService TDD implementation!
