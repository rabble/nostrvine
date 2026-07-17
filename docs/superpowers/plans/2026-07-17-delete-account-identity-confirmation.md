# Delete-account identity + username confirmation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> ⛔ **DO NOT EXECUTE YET — sequenced behind PR #6138.** #6138 (username-burn on
> delete, issue #6126) rewrites the same functions this plan targets
> (`showDeleteAllContentWarningDialog`, `executeAccountDeletion`), the settings
> tile, `app_en.arb`, and `delete_account_dialog_test.dart`. Plan of record:
> #6138 merges first, then rebase this branch onto fresh `origin/main` and
> **re-derive Tasks 1 / 4 / 5 against #6138's merged dialog** (identity block +
> username gate must coexist with the burn checkbox; `executeAccountDeletion`
> must fuse burn-first with the confirmed-pubkey verify-and-abort). This
> version was written against the pre-#6138 dialog.

**Goal:** On the account-deletion confirmation, show which account is being deleted (avatar + name + username/npub) and require re-typing that account's username (DELETE fallback), bind the deletion to the confirmed account, and correct the overstated deletion copy.

**Architecture:** A plain `DeleteAccountConfirmation` value object holds the identity + required token, derived in `_DeleteAccountTile` from the account's own claimed handle (resolved before the dialog opens). The existing dialog renders it; `AccountDeletionService.deleteAccount` verifies the current account still matches the confirmed one and aborts on mismatch.

**Tech Stack:** Flutter, `flutter_bloc`/Riverpod (this feature uses Riverpod for the existing tile + provider reads; no new bloc), `mocktail`, `flutter_test`. Design spec: `docs/superpowers/specs/2026-07-16-delete-account-identity-confirmation-design.md`. Issue: #6137.

## Global Constraints

- Run all Flutter commands from `mobile/`.
- Dart 80-column formatting (`dart format`); no raw `Colors.*` / inline `TextStyle` — use `VineTheme.*`.
- All user-facing strings via `context.l10n`; every test `MaterialApp` needs `localizationsDelegates: AppLocalizations.localizationsDelegates` + `supportedLocales: AppLocalizations.supportedLocales`.
- Token = full `displayNip05` (`@name.divine.video` / `name@domain`); match is trim + lowercase + strip one leading `@` (username case) or trim + uppercase == `DELETE` (fallback). **No** bare/short form.
- Identity display always shows at least the npub — the account is never unlabeled.
- Never truncate Nostr IDs in logs/analytics; the on-screen truncated npub is UI-only via `NostrKeyUtils.truncateNpub`.
- Conventional-commit messages; commit after each task.

---

### Task 1: l10n copy (additions + subtitle correction)

Adds the new confirmation strings and corrects the danger-zone tile subtitle. The old prompt key stays for now (the dialog still uses it) so the build stays green; it is retired in Task 4.

**Files:**
- Modify: `mobile/lib/l10n/app_en.arb`
- Modify: `mobile/test/l10n/arb_consistency_test.dart` (line 182, `_knownUntranslatedDebt`)
- Generated: `mobile/lib/l10n/generated/*` (via `flutter gen-l10n`)

**Interfaces:**
- Produces l10n getters: `deleteAccountWarningBody`, `deleteAccountConfirmUsernamePrompt`, `deleteAccountConfirmDeletePrompt`, `deleteAccountConfirmationHintUsername` (all `String`); updated `nostrSettingsDeleteAccountSubtitle`.

- [ ] **Step 1: Add the four new keys to `app_en.arb`**

Insert next to the other `deleteAccount*` keys (alphabetical block near `deleteAccountConfirmationHint`):

```json
"deleteAccountConfirmDeletePrompt": "To confirm, type:",
"deleteAccountConfirmUsernamePrompt": "To confirm, type your username:",
"deleteAccountConfirmationHintUsername": "Type your username",
"deleteAccountWarningBody": "This permanently deletes your account and all your content from Divine, and sends a deletion request to other Nostr relays. Some relays and clients may still keep copies.",
```

- [ ] **Step 2: Correct the tile subtitle value in `app_en.arb`**

Replace the existing `nostrSettingsDeleteAccountSubtitle` value:

```json
"nostrSettingsDeleteAccountSubtitle": "Permanently delete your account and content from Divine, and request removal from other Nostr relays. Some copies may remain.",
```

- [ ] **Step 3: Allow the new English-only keys as known untranslated debt**

In `mobile/test/l10n/arb_consistency_test.dart`, replace line 182:

```dart
const _knownUntranslatedDebt = <String>{
  'deleteAccountConfirmDeletePrompt',
  'deleteAccountConfirmUsernamePrompt',
  'deleteAccountConfirmationHintUsername',
  'deleteAccountWarningBody',
};
```

- [ ] **Step 4: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: exit 0; `lib/l10n/generated/app_localizations.dart` now declares the four new getters.

- [ ] **Step 5: Run the ARB consistency test**

Run: `flutter test test/l10n/arb_consistency_test.dart`
Expected: PASS (missing-key diff is covered by `_knownUntranslatedDebt`).

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/l10n/app_en.arb mobile/lib/l10n/generated mobile/test/l10n/arb_consistency_test.dart
git commit -m "feat(delete-account): add confirmation copy and correct delete-relay overstatement (#6137)"
```

---

### Task 2: `DeleteAccountConfirmation` value object

Pure logic: derives the required token + identifier from the account's claimed handle, and matches typed input. No Flutter, trivially unit-testable.

**Files:**
- Create: `mobile/lib/widgets/delete_account_confirmation.dart`
- Test: `mobile/test/widgets/delete_account_confirmation_test.dart`

**Interfaces:**
- Produces: `class DeleteAccountConfirmation` with factory
  `DeleteAccountConfirmation({required String pubkeyHex, required String displayName, required String? avatarUrl, required String? handle})`
  and fields `pubkeyHex`, `displayName`, `avatarUrl` (`String?`), `identifierLine` (`String`), `requiredToken` (`String`), `isUsernameConfirmation` (`bool`), plus `bool matches(String input)`.
- Consumes: `NostrKeyUtils.truncateNpub` from `package:openvine/utils/nostr_key_utils.dart`.

- [ ] **Step 1: Write the failing test**

Create `mobile/test/widgets/delete_account_confirmation_test.dart`:

```dart
// ABOUTME: Unit tests for DeleteAccountConfirmation token derivation + matching
// ABOUTME: Covers Divine handle, external handle, and no-handle (DELETE) cases

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/delete_account_confirmation.dart';

void main() {
  // Any valid 64-char hex pubkey; only used for the npub-fallback path.
  const pubkeyHex =
      '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';

  group(DeleteAccountConfirmation, () {
    group('Divine handle', () {
      final c = DeleteAccountConfirmation(
        pubkeyHex: pubkeyHex,
        displayName: 'Rabble',
        avatarUrl: null,
        handle: '@rabble.divine.video',
      );

      test('is a username confirmation with the full handle as token', () {
        expect(c.isUsernameConfirmation, isTrue);
        expect(c.requiredToken, equals('@rabble.divine.video'));
        expect(c.identifierLine, equals('@rabble.divine.video'));
      });

      test('matches the exact handle, and the @-less and cased forms', () {
        expect(c.matches('@rabble.divine.video'), isTrue);
        expect(c.matches('rabble.divine.video'), isTrue);
        expect(c.matches('  @RABBLE.DIVINE.VIDEO  '), isTrue);
      });

      test('does not match the bare local part or DELETE', () {
        expect(c.matches('rabble'), isFalse);
        expect(c.matches('@rabble'), isFalse);
        expect(c.matches('DELETE'), isFalse);
      });
    });

    group('external handle', () {
      final c = DeleteAccountConfirmation(
        pubkeyHex: pubkeyHex,
        displayName: 'Alice',
        avatarUrl: null,
        handle: 'alice@example.com',
      );

      test('uses the external handle as token, case-insensitively', () {
        expect(c.isUsernameConfirmation, isTrue);
        expect(c.requiredToken, equals('alice@example.com'));
        expect(c.matches('ALICE@example.com'), isTrue);
        expect(c.matches('alice@example.com '), isTrue);
      });
    });

    group('no handle', () {
      final c = DeleteAccountConfirmation(
        pubkeyHex: pubkeyHex,
        displayName: 'Wild Otter 7',
        avatarUrl: null,
        handle: null,
      );

      test('falls back to DELETE and shows a truncated npub', () {
        expect(c.isUsernameConfirmation, isFalse);
        expect(c.requiredToken, equals('DELETE'));
        expect(c.identifierLine, startsWith('npub1'));
      });

      test('matches DELETE case-insensitively and trimmed, not a handle', () {
        expect(c.matches('delete'), isTrue);
        expect(c.matches('  DELETE '), isTrue);
        expect(c.matches('rabble.divine.video'), isFalse);
      });
    });

    test('empty handle is treated as no handle', () {
      final c = DeleteAccountConfirmation(
        pubkeyHex: pubkeyHex,
        displayName: 'X',
        avatarUrl: null,
        handle: '',
      );
      expect(c.isUsernameConfirmation, isFalse);
      expect(c.requiredToken, equals('DELETE'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/delete_account_confirmation_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../delete_account_confirmation.dart'`.

- [ ] **Step 3: Write minimal implementation**

Create `mobile/lib/widgets/delete_account_confirmation.dart`:

```dart
// ABOUTME: Value object for the delete-account confirmation dialog
// ABOUTME: Derives the required confirm token (username or DELETE) and matches input

import 'package:openvine/utils/nostr_key_utils.dart';

const String _deleteToken = 'DELETE';

/// Identity + confirm-token for the account-deletion dialog.
///
/// [handle] is the account's claimed `displayNip05` (full form, e.g.
/// `@name.divine.video` or `name@domain`) or `null`/empty when the account has
/// none. When present it becomes the required token; otherwise the token is
/// `DELETE` and the shown identifier is a truncated npub.
class DeleteAccountConfirmation {
  const DeleteAccountConfirmation._({
    required this.pubkeyHex,
    required this.displayName,
    required this.avatarUrl,
    required this.identifierLine,
    required this.requiredToken,
    required this.isUsernameConfirmation,
  });

  factory DeleteAccountConfirmation({
    required String pubkeyHex,
    required String displayName,
    required String? avatarUrl,
    required String? handle,
  }) {
    final hasHandle = handle != null && handle.isNotEmpty;
    return DeleteAccountConfirmation._(
      pubkeyHex: pubkeyHex,
      displayName: displayName,
      avatarUrl: avatarUrl,
      identifierLine: hasHandle
          ? handle
          : NostrKeyUtils.truncateNpub(pubkeyHex),
      requiredToken: hasHandle ? handle : _deleteToken,
      isUsernameConfirmation: hasHandle,
    );
  }

  final String pubkeyHex;
  final String displayName;
  final String? avatarUrl;

  /// Identifier shown in the identity block (handle, or truncated npub).
  final String identifierLine;

  /// String the user must type. Shown verbatim as the monospace target.
  final String requiredToken;

  /// Whether the token is a username (vs the `DELETE` fallback).
  final bool isUsernameConfirmation;

  /// Whether [input] satisfies the confirmation.
  ///
  /// Username: case-insensitive, trimmed, leading `@` optional.
  /// Fallback: case-insensitive, trimmed, equals `DELETE`.
  bool matches(String input) {
    if (isUsernameConfirmation) {
      return _normalizeHandle(input) == _normalizeHandle(requiredToken);
    }
    return input.trim().toUpperCase() == _deleteToken;
  }

  static String _normalizeHandle(String value) {
    final trimmed = value.trim().toLowerCase();
    return trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/delete_account_confirmation_test.dart`
Expected: PASS (all groups).

- [ ] **Step 5: Analyze + commit**

Run: `flutter analyze lib/widgets/delete_account_confirmation.dart test/widgets/delete_account_confirmation_test.dart`
Expected: `No issues found!`

```bash
git add mobile/lib/widgets/delete_account_confirmation.dart mobile/test/widgets/delete_account_confirmation_test.dart
git commit -m "feat(delete-account): DeleteAccountConfirmation token value object (#6137)"
```

---

### Task 3: Bind deletion to the confirmed account

`deleteAccount` gains an optional `expectedPubkey`; when it does not match the live `currentPublicKeyHex`, the method aborts before fetching/publishing anything.

**Files:**
- Modify: `mobile/lib/services/account_deletion_service.dart` (`deleteAccount`, right after the pubkey read at ~line 61)
- Test: `mobile/test/services/account_deletion_service_test.dart`

**Interfaces:**
- Produces: `Future<DeleteAccountResult> deleteAccount({String? customReason, void Function(int, int)? onProgress, String? expectedPubkey})` — aborts with `DeleteAccountResult.failure('Signed-in account changed; deletion aborted')` when `expectedPubkey != null && expectedPubkey != currentPublicKeyHex`.

- [ ] **Step 1: Write the failing test**

Add inside the existing `group('AccountDeletionService', ...)` in `test/services/account_deletion_service_test.dart`:

```dart
    group('expectedPubkey binding', () {
      test('aborts and returns failure when expectedPubkey != current', () async {
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(testPublicKey);

        final result = await service.deleteAccount(
          expectedPubkey: 'a_different_pubkey_than_current',
        );

        expect(result.success, isFalse);
        expect(result.error, contains('account changed'));
        verifyNever(() => mockNostrService.queryEvents(any()));
      });

      test('proceeds past the guard when expectedPubkey == current', () async {
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(testPublicKey);

        await service.deleteAccount(expectedPubkey: testPublicKey);

        // Guard passed → it reached event fetching.
        verify(() => mockNostrService.queryEvents(any())).called(greaterThan(0));
      });
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/account_deletion_service_test.dart --plain-name "expectedPubkey binding"`
Expected: FAIL — `deleteAccount` has no `expectedPubkey` parameter (compile error), or the abort assertion fails.

- [ ] **Step 3: Add the parameter + guard**

In `deleteAccount`, extend the signature and insert the guard immediately after the existing empty-pubkey check (after line ~64):

```dart
  Future<DeleteAccountResult> deleteAccount({
    String? customReason,
    void Function(int current, int total)? onProgress,
    String? expectedPubkey,
  }) async {
    try {
      if (!_authService.isAuthenticated) {
        return DeleteAccountResult.failure('Not authenticated');
      }

      final pubkey = _authService.currentPublicKeyHex;
      if (pubkey == null || pubkey.isEmpty) {
        return DeleteAccountResult.failure('No pubkey available');
      }

      if (expectedPubkey != null && expectedPubkey != pubkey) {
        Log.warning(
          'Deletion aborted: signed-in account changed since confirmation',
          name: 'AccountDeletionService',
          category: LogCategory.auth,
        );
        return DeleteAccountResult.failure(
          'Signed-in account changed; deletion aborted',
        );
      }
      // ... existing reason / fetch / publish continues unchanged ...
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/account_deletion_service_test.dart`
Expected: PASS (new group + existing tests still green).

- [ ] **Step 5: Analyze + commit**

Run: `flutter analyze lib/services/account_deletion_service.dart test/services/account_deletion_service_test.dart`
Expected: `No issues found!`

```bash
git add mobile/lib/services/account_deletion_service.dart mobile/test/services/account_deletion_service_test.dart
git commit -m "feat(delete-account): bind deletion to confirmed account, abort on mismatch (#6137)"
```

---

### Task 4: Dialog — identity block, required confirmation, bound execution

Rewrites `showDeleteAllContentWarningDialog` to render the identity block + account-specific token, extracts a stateful dialog widget and `_DeleteIdentityHeader`, threads the confirmed pubkey through `executeAccountDeletion` into `deleteAccount`, uses the new copy, and retires the old prompt key.

**Files:**
- Modify: `mobile/lib/widgets/delete_account_dialog.dart`
- Modify: `mobile/lib/l10n/app_en.arb` + all `mobile/lib/l10n/app_*.arb` (retire `deleteAccountFinalConfirmationBody`)
- Modify: `mobile/test/widgets/delete_account_dialog_test.dart`

**Interfaces:**
- Consumes: `DeleteAccountConfirmation` (Task 2); `deleteAccount(expectedPubkey:)` (Task 3); l10n getters (Task 1); `UserAvatar` from `package:openvine/widgets/user_avatar.dart`.
- Produces:
  `Future<void> showDeleteAllContentWarningDialog({required BuildContext context, required DeleteAccountConfirmation confirmation, required VoidCallback onConfirm})`
  and `Future<void> executeAccountDeletion({required BuildContext context, required AccountDeletionService deletionService, required AuthService authService, required String confirmedPubkey, String screenName})`.

- [ ] **Step 1: Update existing dialog tests for the new required parameter (write the failing tests)**

Replace the top helpers + the DELETE-input group in `test/widgets/delete_account_dialog_test.dart` and add the username group. Full new file:

```dart
// ABOUTME: Tests for the delete account confirmation dialog
// ABOUTME: Covers Divine/external username and DELETE-fallback confirmation

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:openvine/widgets/delete_account_confirmation.dart';
import 'package:openvine/widgets/delete_account_dialog.dart';

class _MockAccountDeletionService extends Mock
    implements AccountDeletionService {}

class _MockAuthService extends Mock implements AuthService {}

const _pubkeyHex =
    '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';

DeleteAccountConfirmation _deleteFallback() => DeleteAccountConfirmation(
  pubkeyHex: _pubkeyHex,
  displayName: 'Wild Otter 7',
  avatarUrl: null,
  handle: null,
);

DeleteAccountConfirmation _divineUsername() => DeleteAccountConfirmation(
  pubkeyHex: _pubkeyHex,
  displayName: 'Rabble',
  avatarUrl: null,
  handle: '@rabble.divine.video',
);

Widget _wrapWithRouter(Widget child) {
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, state) => child)],
  );
  return MaterialApp.router(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  );
}

Future<void> _showDialog(
  WidgetTester tester, {
  DeleteAccountConfirmation? confirmation,
  VoidCallback? onConfirm,
}) async {
  await tester.pumpWidget(
    _wrapWithRouter(
      Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            key: const Key('open'),
            onPressed: () => showDeleteAllContentWarningDialog(
              context: context,
              confirmation: confirmation ?? _deleteFallback(),
              onConfirm: onConfirm ?? () {},
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

ElevatedButton _deleteButton(WidgetTester tester) => tester.widget<ElevatedButton>(
  find.widgetWithText(ElevatedButton, 'Delete All Content'),
);

void main() {
  group('DELETE fallback (no username)', () {
    testWidgets('empty keeps the button disabled', (tester) async {
      await _showDialog(tester);
      expect(_deleteButton(tester).onPressed, isNull);
    });

    testWidgets('wrong word keeps the button disabled', (tester) async {
      await _showDialog(tester);
      await tester.enterText(find.byType(TextField), 'confirm');
      await tester.pump();
      expect(_deleteButton(tester).onPressed, isNull);
    });

    testWidgets('case-insensitive, trimmed DELETE enables the button', (
      tester,
    ) async {
      await _showDialog(tester);
      await tester.enterText(find.byType(TextField), '  Delete ');
      await tester.pump();
      expect(_deleteButton(tester).onPressed, isNotNull);
    });

    testWidgets('tapping enabled button calls onConfirm', (tester) async {
      var called = false;
      await _showDialog(tester, onConfirm: () => called = true);
      await tester.enterText(find.byType(TextField), 'delete');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete All Content'));
      await tester.pumpAndSettle();
      expect(called, isTrue);
    });
  });

  group('username confirmation', () {
    testWidgets('shows the identity (name + handle)', (tester) async {
      await _showDialog(tester, confirmation: _divineUsername());
      expect(find.text('Rabble'), findsOneWidget);
      expect(find.text('@rabble.divine.video'), findsWidgets);
    });

    testWidgets('typing DELETE does not enable the button', (tester) async {
      await _showDialog(tester, confirmation: _divineUsername());
      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();
      expect(_deleteButton(tester).onPressed, isNull);
    });

    testWidgets('typing the handle enables the button', (tester) async {
      await _showDialog(tester, confirmation: _divineUsername());
      await tester.enterText(find.byType(TextField), '@rabble.divine.video');
      await tester.pump();
      expect(_deleteButton(tester).onPressed, isNotNull);
    });

    testWidgets('typing the handle without @ also enables the button', (
      tester,
    ) async {
      await _showDialog(tester, confirmation: _divineUsername());
      await tester.enterText(find.byType(TextField), 'rabble.divine.video');
      await tester.pump();
      expect(_deleteButton(tester).onPressed, isNotNull);
    });
  });

  group('executeAccountDeletion', () {
    testWidgets('shows failure when local data cleanup fails after sign-out', (
      tester,
    ) async {
      final deletionService = _MockAccountDeletionService();
      final authService = _MockAuthService();
      when(
        () => deletionService.deleteAccount(
          onProgress: any(named: 'onProgress'),
          expectedPubkey: any(named: 'expectedPubkey'),
        ),
      ).thenAnswer((_) async => DeleteAccountResult.createSuccess('event-id'));
      when(
        authService.deleteKeycastAccount,
      ).thenAnswer((_) async => (true, null));
      when(
        () => authService.signOut(deleteKeys: true, deleteLocalUserData: true),
      ).thenThrow(
        const UserDataCleanupException(
          'Signed out but local user data cleanup failed',
        ),
      );

      late BuildContext capturedContext;
      await tester.pumpWidget(
        _wrapWithRouter(
          Builder(
            builder: (context) {
              capturedContext = context;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      );

      await executeAccountDeletion(
        context: capturedContext,
        deletionService: deletionService,
        authService: authService,
        confirmedPubkey: _pubkeyHex,
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Account deleted and signed out, but some local data could not be '
          'removed from this device.',
        ),
        findsOneWidget,
      );
      expect(find.text('Your account has been deleted'), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widgets/delete_account_dialog_test.dart`
Expected: FAIL — `showDeleteAllContentWarningDialog`/`executeAccountDeletion` don't accept `confirmation`/`confirmedPubkey`.

- [ ] **Step 3: Rewrite the dialog + identity header + execution signature**

In `mobile/lib/widgets/delete_account_dialog.dart`: add the imports, replace `showDeleteAllContentWarningDialog` with the version below, add `_DeleteConfirmationDialog` and `_DeleteIdentityHeader`, and add `required String confirmedPubkey` to `executeAccountDeletion` — passing it into `deletionService.deleteAccount`.

Add imports at top:

```dart
import 'package:openvine/widgets/delete_account_confirmation.dart';
import 'package:openvine/widgets/user_avatar.dart';
```

Replace `showDeleteAllContentWarningDialog(...)` (the whole function) with:

```dart
/// Confirmation dialog before deleting all content.
///
/// Shows [confirmation]'s identity block and requires the user to re-type its
/// [DeleteAccountConfirmation.requiredToken] (the account's username, or
/// `DELETE` when it has none).
Future<void> showDeleteAllContentWarningDialog({
  required BuildContext context,
  required DeleteAccountConfirmation confirmation,
  required VoidCallback onConfirm,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _DeleteConfirmationDialog(
      confirmation: confirmation,
      onConfirm: onConfirm,
    ),
  );
}

class _DeleteConfirmationDialog extends StatefulWidget {
  const _DeleteConfirmationDialog({
    required this.confirmation,
    required this.onConfirm,
  });

  final DeleteAccountConfirmation confirmation;
  final VoidCallback onConfirm;

  @override
  State<_DeleteConfirmationDialog> createState() =>
      _DeleteConfirmationDialogState();
}

class _DeleteConfirmationDialogState extends State<_DeleteConfirmationDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.confirmation;
    final enabled = c.matches(_controller.text);
    return AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      scrollable: true,
      title: Text(
        context.l10n.deleteAccountFinalConfirmationTitle,
        style: const TextStyle(
          color: VineTheme.error,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DeleteIdentityHeader(confirmation: c),
          const SizedBox(height: 16),
          Text(
            context.l10n.deleteAccountWarningBody,
            style: const TextStyle(
              color: VineTheme.whiteText,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            c.isUsernameConfirmation
                ? context.l10n.deleteAccountConfirmUsernamePrompt
                : context.l10n.deleteAccountConfirmDeletePrompt,
            style: const TextStyle(color: VineTheme.whiteText, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            c.requiredToken,
            style: const TextStyle(
              color: VineTheme.error,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            style: const TextStyle(color: VineTheme.whiteText),
            autocorrect: false,
            textCapitalization: c.isUsernameConfirmation
                ? TextCapitalization.none
                : TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: c.isUsernameConfirmation
                  ? context.l10n.deleteAccountConfirmationHintUsername
                  : context.l10n.deleteAccountConfirmationHint,
              hintStyle: const TextStyle(color: VineTheme.lightText),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: VineTheme.cardBackground),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: VineTheme.error),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: context.pop,
          child: Text(
            context.l10n.commonCancel,
            style: const TextStyle(color: VineTheme.lightText, fontSize: 16),
          ),
        ),
        ElevatedButton(
          onPressed: enabled
              ? () {
                  context.pop();
                  widget.onConfirm();
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: VineTheme.error,
            foregroundColor: VineTheme.whiteText,
            disabledBackgroundColor: VineTheme.cardBackground,
            disabledForegroundColor: VineTheme.lightText,
          ),
          child: Text(
            context.l10n.deleteAccountDeleteAllContentButton,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

class _DeleteIdentityHeader extends StatelessWidget {
  const _DeleteIdentityHeader({required this.confirmation});

  final DeleteAccountConfirmation confirmation;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        UserAvatar(
          imageUrl: confirmation.avatarUrl,
          name: confirmation.displayName,
          placeholderSeed: confirmation.pubkeyHex,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                confirmation.displayName,
                style: VineTheme.titleMediumFont(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                confirmation.identifierLine,
                style: VineTheme.bodyMediumFont(
                  color: VineTheme.secondaryText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

Then update `executeAccountDeletion`: add `required String confirmedPubkey` to its parameters and pass it through:

```dart
Future<void> executeAccountDeletion({
  required BuildContext context,
  required AccountDeletionService deletionService,
  required AuthService authService,
  required String confirmedPubkey,
  String screenName = 'AccountDeletion',
}) async {
```

and change the `deleteAccount` call:

```dart
    final result = await deletionService.deleteAccount(
      onProgress: cubit.updateProgress,
      expectedPubkey: confirmedPubkey,
    );
```

- [ ] **Step 4: Retire the old prompt l10n key**

The dialog no longer references `deleteAccountFinalConfirmationBody` or the local `requiredText`. Remove the key from every locale and regenerate:

Run:
```bash
sed -i '' '/"deleteAccountFinalConfirmationBody":/d' mobile/lib/l10n/app_*.arb
cd mobile && flutter gen-l10n && cd ..
```
Expected: the `deleteAccountFinalConfirmationBody` getter is gone from `lib/l10n/generated/`; no remaining references (verify next step).

- [ ] **Step 5: Verify no stale references, then run tests**

Run: `rg -n "deleteAccountFinalConfirmationBody|requiredText" mobile/lib`
Expected: no matches.

Run: `flutter test test/widgets/delete_account_dialog_test.dart test/l10n/arb_consistency_test.dart`
Expected: PASS.

- [ ] **Step 6: Analyze + commit**

Run: `flutter analyze lib/widgets/delete_account_dialog.dart test/widgets/delete_account_dialog_test.dart`
Expected: `No issues found!`

```bash
git add mobile/lib/widgets/delete_account_dialog.dart mobile/lib/l10n mobile/test/widgets/delete_account_dialog_test.dart
git commit -m "feat(delete-account): show identity + require username in confirm dialog (#6137)"
```

---

### Task 5: Resolve identity before confirm + wire the tile

`_DeleteAccountTile` resolves the account's profile (bounded wait, existing progress overlay), builds the `DeleteAccountConfirmation`, opens the dialog, and passes the confirmed pubkey into execution.

**Files:**
- Modify: `mobile/lib/screens/settings/nostr_settings_screen.dart` (`_DeleteAccountTile._handleDeleteAllContent`, imports)
- Test: `mobile/test/screens/settings/nostr_settings_screen_delete_tile_test.dart`

**Interfaces:**
- Consumes: `fetchUserProfileProvider(pubkey).future` → `Future<UserProfile?>` (`package:openvine/providers/user_profile_providers.dart`); `DeleteAccountConfirmation` (Task 2); `showDeleteAllContentWarningDialog` + `executeAccountDeletion` (Task 4); `models.UserProfile` getters `bestDisplayName` / `picture` / `displayNip05` / static `defaultDisplayNameFor`.

- [ ] **Step 1: Write the failing test**

Create `mobile/test/screens/settings/nostr_settings_screen_delete_tile_test.dart`. It pumps just the tile with an overridden `fetchUserProfileProvider` and asserts the dialog opens showing the resolved handle.

```dart
// ABOUTME: Tests that the delete-account tile resolves identity before the dialog
// ABOUTME: Verifies the confirmation shows the account's username, not a bare npub

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/widgets/delete_account_dialog.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockAccountDeletionService extends Mock
    implements AccountDeletionService {}

const _pubkeyHex =
    '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';

void main() {
  testWidgets('resolves the profile and shows the username in the dialog', (
    tester,
  ) async {
    final auth = _MockAuthService();
    when(() => auth.currentPublicKeyHex).thenReturn(_pubkeyHex);

    final profile = UserProfile(
      pubkey: _pubkeyHex,
      name: 'Rabble',
      nip05: '_@rabble.divine.video',
    );

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => _openFromTile(context, tester),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          accountDeletionServiceProvider
              .overrideWithValue(_MockAccountDeletionService()),
          fetchUserProfileProvider(_pubkeyHex)
              .overrideWith((ref) async => profile),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Rabble'), findsOneWidget);
    expect(find.text('@rabble.divine.video'), findsWidgets);
  });
}

// Mirrors _DeleteAccountTile._handleDeleteAllContent (kept in sync with it).
Future<void> _openFromTile(BuildContext context, WidgetTester tester) async {
  final container = ProviderScope.containerOf(context);
  final auth = container.read(authServiceProvider);
  final pubkey = auth.currentPublicKeyHex!;
  final profile = await container.read(fetchUserProfileProvider(pubkey).future);
  if (!context.mounted) return;
  await showDeleteAllContentWarningDialog(
    context: context,
    confirmation: DeleteAccountConfirmation(
      pubkeyHex: pubkey,
      displayName: profile?.bestDisplayName ??
          UserProfile.defaultDisplayNameFor(pubkey),
      avatarUrl: profile?.picture,
      handle: profile?.displayNip05,
    ),
    onConfirm: () {},
  );
}
```

> Note: this test drives the same logic the tile runs. If the real tile is
> preferred as the unit under test, pump `const NostrSettingsScreen()` inside
> the same `ProviderScope` overrides and tap the "Delete Account and Data"
> tile instead — the assertions are identical. Confirm the exact
> `DeleteAccountConfirmation` import used above compiles (it is exported from
> `delete_account_dialog.dart`'s import of `delete_account_confirmation.dart`;
> add a direct import if the analyzer flags it).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/settings/nostr_settings_screen_delete_tile_test.dart`
Expected: FAIL (until the tile logic + imports exist / compile).

- [ ] **Step 3: Update the tile's imports**

In `mobile/lib/screens/settings/nostr_settings_screen.dart`, change the `auth_service` import to hide the thin `UserProfile`, and add the models + provider + value-object imports:

```dart
import 'package:openvine/services/auth_service.dart' hide UserProfile;
```

Add (with the other `package:openvine/...` imports):

```dart
import 'package:models/models.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/delete_account_confirmation.dart';
```

> If the analyzer reports `AuthState`/`AuthService` now hidden, mirror the
> exact `hide`/`show` form used at `settings_screen.dart:39`.

- [ ] **Step 4: Rewrite `_handleDeleteAllContent`**

Add a resolve-timeout constant near the top of the file (after imports):

```dart
const Duration _profileResolveTimeout = Duration(seconds: 3);
```

Replace `_DeleteAccountTile._handleDeleteAllContent` with:

```dart
  Future<void> _handleDeleteAllContent(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final deletionService = ref.read(accountDeletionServiceProvider);
    final authService = ref.read(authServiceProvider);
    final pubkey = authService.currentPublicKeyHex;
    if (pubkey == null || pubkey.isEmpty) return;

    final overlay = _ProgressOverlay.show(context);
    UserProfile? profile;
    try {
      profile = await ref
          .read(fetchUserProfileProvider(pubkey).future)
          .timeout(_profileResolveTimeout, onTimeout: () => null);
    } catch (_) {
      profile = null;
    } finally {
      overlay.dismiss();
    }
    if (!context.mounted) return;

    final confirmation = DeleteAccountConfirmation(
      pubkeyHex: pubkey,
      displayName:
          profile?.bestDisplayName ?? UserProfile.defaultDisplayNameFor(pubkey),
      avatarUrl: profile?.picture,
      handle: profile?.displayNip05,
    );

    await showDeleteAllContentWarningDialog(
      context: context,
      confirmation: confirmation,
      onConfirm: () => executeAccountDeletion(
        context: context,
        deletionService: deletionService,
        authService: authService,
        confirmedPubkey: pubkey,
        screenName: 'NostrSettingsScreen',
      ),
    );
  }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/screens/settings/nostr_settings_screen_delete_tile_test.dart`
Expected: PASS.

- [ ] **Step 6: Analyze + commit**

Run: `flutter analyze lib/screens/settings/nostr_settings_screen.dart test/screens/settings/nostr_settings_screen_delete_tile_test.dart`
Expected: `No issues found!`

```bash
git add mobile/lib/screens/settings/nostr_settings_screen.dart mobile/test/screens/settings/nostr_settings_screen_delete_tile_test.dart
git commit -m "feat(delete-account): resolve identity before confirm and bind the tile (#6137)"
```

---

### Task 6: Full verification sweep

**Files:** none (verification only).

- [ ] **Step 1: Analyze the whole surface**

Run: `flutter analyze lib test integration_test`
Expected: `No issues found!` Fix any issue and re-run before proceeding.

- [ ] **Step 2: Run every touched suite**

Run:
```bash
flutter test \
  test/widgets/delete_account_confirmation_test.dart \
  test/widgets/delete_account_dialog_test.dart \
  test/services/account_deletion_service_test.dart \
  test/screens/settings/nostr_settings_screen_delete_tile_test.dart \
  test/l10n/arb_consistency_test.dart
```
Expected: all PASS.

- [ ] **Step 3: Format check**

Run: `dart format lib/widgets/delete_account_confirmation.dart lib/widgets/delete_account_dialog.dart lib/screens/settings/nostr_settings_screen.dart lib/services/account_deletion_service.dart`
Expected: no files changed (or commit the formatting).

- [ ] **Step 4: Confirm clean tree + push**

Run: `git status --short`
Expected: clean (all intended files committed).

```bash
git fetch origin && git rebase origin/main
git push --force-with-lease -u origin feat/delete-account-identity-confirm
```

---

## Self-Review

**Spec coverage:**
- Show identity (avatar + name + username/npub) → Task 4 `_DeleteIdentityHeader`, driven by Task 2 derivation.
- Account-specific token, DELETE fallback, strict full-form + @/case leniency → Task 2 (`matches`) + tests.
- Resolve-before-confirm (Q1) with bounded wait + degrade → Task 5.
- Bind deletion, verify-and-abort (Q2) → Task 3 + Task 4 threading.
- NIP-05-only token (Q3) → Task 2 (`handle` = `displayNip05`; no `vine_username`).
- Copy corrected + tile subtitle → Task 1; old prompt key retired → Task 4.
- Claimed handle, not verification-gated → Task 5 reads `displayNip05` directly (no `nip05VerificationProvider`).
- Tests for three account shapes, binding, resolve → Tasks 2/3/4/5.
- `hide UserProfile` import clash → Task 5 Step 3.

**Placeholder scan:** none — every code step carries full code; every command has expected output.

**Type consistency:** `DeleteAccountConfirmation({pubkeyHex, displayName, avatarUrl, handle})` and fields `requiredToken`/`identifierLine`/`isUsernameConfirmation`/`matches` are used identically in Tasks 2/4/5. `deleteAccount({..., expectedPubkey})` defined in Task 3, called in Task 4. `executeAccountDeletion({..., confirmedPubkey})` defined in Task 4, called in Task 5.

**Open verification for the implementer (flagged, not placeholders):**
- Task 5 test constructs `UserProfile(pubkey:, name:, nip05:)` — confirm the `models.UserProfile` constructor's required/named parameters and adjust the fixture if its signature differs. The behavior asserted (name + handle appear) is what matters.
- Confirm `authServiceProvider` / `accountDeletionServiceProvider` / `fetchUserProfileProvider` override APIs compile as written under this repo's Riverpod version.
