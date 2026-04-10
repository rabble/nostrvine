Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This file may reference deleted screens, older branding, or superseded implementation details. Start with docs/README.md and docs/archive/README.md for current guidance.

# Account Deletion (NIP-62) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement NIP-62 account deletion feature allowing users to permanently delete their Nostr identity and all content from relays.

**Architecture:** Add AccountDeletionService for NIP-62 event creation/broadcast, update SettingsScreen with Account section and Delete Account option, implement warning/completion dialog flow that signs out user and deletes keys after successful NIP-62 broadcast.

**Tech Stack:** Flutter, Riverpod, nostr_sdk, NIP-62 protocol

---

## Task 1: Create AccountDeletionService with NIP-62 Event

**Files:**
- Create: `lib/services/account_deletion_service.dart`
- Create: `test/services/account_deletion_service_test.dart`

**Step 1: Write the failing test for NIP-62 event creation**

Create `test/services/account_deletion_service_test.dart`:

```dart
// ABOUTME: Tests for NIP-62 account deletion service
// ABOUTME: Verifies kind 62 event creation, ALL_RELAYS tag, and broadcast behavior

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';

import 'account_deletion_service_test.mocks.dart';

@GenerateMocks([INostrService, AuthService])
void main() {
  group('AccountDeletionService', () {
    late MockINostrService mockNostrService;
    late MockAuthService mockAuthService;
    late AccountDeletionService service;

    setUp(() {
      mockNostrService = MockINostrService();
      mockAuthService = MockAuthService();
      service = AccountDeletionService(
        nostrService: mockNostrService,
        authService: mockAuthService,
      );
    });

    test('createNip62Event should create kind 62 event', () async {
      // Arrange
      const testPubkey = 'test_pubkey_hex';
      when(mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);
      when(mockNostrService.hasKeys).thenReturn(true);

      // Mock key manager for event signing
      when(mockNostrService.createAndSignEvent(
        kind: 62,
        content: anyNamed('content'),
        tags: anyNamed('tags'),
      )).thenAnswer((_) async => Event(
        testPubkey,
        62,
        [['relay', 'ALL_RELAYS']],
        'test content',
        createdAt: 1234567890,
      ));

      // Act
      final event = await service.createNip62Event(
        reason: 'User requested account deletion',
      );

      // Assert
      expect(event, isNotNull);
      expect(event!.kind, equals(62));
    });

    test('createNip62Event should include ALL_RELAYS tag', () async {
      // Arrange
      const testPubkey = 'test_pubkey_hex';
      when(mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);
      when(mockNostrService.hasKeys).thenReturn(true);

      when(mockNostrService.createAndSignEvent(
        kind: 62,
        content: anyNamed('content'),
        tags: anyNamed('tags'),
      )).thenAnswer((_) async => Event(
        testPubkey,
        62,
        [['relay', 'ALL_RELAYS']],
        'test content',
        createdAt: 1234567890,
      ));

      // Act
      final event = await service.createNip62Event(
        reason: 'User requested account deletion',
      );

      // Assert
      expect(event, isNotNull);
      expect(event!.tags, contains(['relay', 'ALL_RELAYS']));
    });

    test('createNip62Event should include user pubkey', () async {
      // Arrange
      const testPubkey = 'test_pubkey_hex';
      when(mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);
      when(mockNostrService.hasKeys).thenReturn(true);

      when(mockNostrService.createAndSignEvent(
        kind: 62,
        content: anyNamed('content'),
        tags: anyNamed('tags'),
      )).thenAnswer((_) async => Event(
        testPubkey,
        62,
        [['relay', 'ALL_RELAYS']],
        'test content',
        createdAt: 1234567890,
      ));

      // Act
      final event = await service.createNip62Event(
        reason: 'User requested account deletion',
      );

      // Assert
      expect(event, isNotNull);
      expect(event!.pubkey, equals(testPubkey));
    });

    test('deleteAccount should broadcast NIP-62 event', () async {
      // Arrange
      const testPubkey = 'test_pubkey_hex';
      when(mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);
      when(mockNostrService.hasKeys).thenReturn(true);

      final mockEvent = Event(
        testPubkey,
        62,
        [['relay', 'ALL_RELAYS']],
        'test content',
        createdAt: 1234567890,
      );

      when(mockNostrService.createAndSignEvent(
        kind: 62,
        content: anyNamed('content'),
        tags: anyNamed('tags'),
      )).thenAnswer((_) async => mockEvent);

      when(mockNostrService.broadcastEvent(any)).thenAnswer(
        (_) async => BroadcastResult(successCount: 3, failureCount: 0),
      );

      // Act
      final result = await service.deleteAccount();

      // Assert
      verify(mockNostrService.broadcastEvent(mockEvent)).called(1);
    });

    test('deleteAccount should return success when broadcast succeeds', () async {
      // Arrange
      const testPubkey = 'test_pubkey_hex';
      when(mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);
      when(mockNostrService.hasKeys).thenReturn(true);

      final mockEvent = Event(
        testPubkey,
        62,
        [['relay', 'ALL_RELAYS']],
        'test content',
        createdAt: 1234567890,
      );

      when(mockNostrService.createAndSignEvent(
        kind: 62,
        content: anyNamed('content'),
        tags: anyNamed('tags'),
      )).thenAnswer((_) async => mockEvent);

      when(mockNostrService.broadcastEvent(any)).thenAnswer(
        (_) async => BroadcastResult(successCount: 3, failureCount: 0),
      );

      // Act
      final result = await service.deleteAccount();

      // Assert
      expect(result.success, isTrue);
      expect(result.error, isNull);
    });

    test('deleteAccount should return failure when broadcast fails', () async {
      // Arrange
      const testPubkey = 'test_pubkey_hex';
      when(mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);
      when(mockNostrService.hasKeys).thenReturn(true);

      final mockEvent = Event(
        testPubkey,
        62,
        [['relay', 'ALL_RELAYS']],
        'test content',
        createdAt: 1234567890,
      );

      when(mockNostrService.createAndSignEvent(
        kind: 62,
        content: anyNamed('content'),
        tags: anyNamed('tags'),
      )).thenAnswer((_) async => mockEvent);

      when(mockNostrService.broadcastEvent(any)).thenAnswer(
        (_) async => BroadcastResult(successCount: 0, failureCount: 3),
      );

      // Act
      final result = await service.deleteAccount();

      // Assert
      expect(result.success, isFalse);
      expect(result.error, isNotNull);
      expect(result.error, contains('Failed to broadcast'));
    });
  });
}
```

**Step 2: Run test to verify it fails**

```bash
cd .worktrees/account-deletion
flutter test test/services/account_deletion_service_test.dart
```

Expected: FAIL with "account_deletion_service.dart not found" or similar import error

**Step 3: Write minimal AccountDeletionService implementation**

Create `lib/services/account_deletion_service.dart`:

```dart
// ABOUTME: Account deletion service implementing NIP-62 Request to Vanish
// ABOUTME: Handles network-wide account deletion by publishing kind 62 events to all relays

import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:unified_logger/unified_logger.dart';

/// Result of account deletion operation
class DeleteAccountResult {
  const DeleteAccountResult({
    required this.success,
    this.error,
    this.deleteEventId,
  });

  final bool success;
  final String? error;
  final String? deleteEventId;

  static DeleteAccountResult createSuccess(String deleteEventId) =>
      DeleteAccountResult(
        success: true,
        deleteEventId: deleteEventId,
      );

  static DeleteAccountResult failure(String error) => DeleteAccountResult(
        success: false,
        error: error,
      );
}

/// Service for deleting user's entire Nostr account via NIP-62
class AccountDeletionService {
  AccountDeletionService({
    required INostrService nostrService,
    required AuthService authService,
  })  : _nostrService = nostrService,
        _authService = authService;

  final INostrService _nostrService;
  final AuthService _authService;

  /// Delete user's account using NIP-62 Request to Vanish
  Future<DeleteAccountResult> deleteAccount({String? customReason}) async {
    try {
      if (!_nostrService.hasKeys) {
        return DeleteAccountResult.failure('No keys available for signing');
      }

      // Create NIP-62 event
      final event = await createNip62Event(
        reason: customReason ?? 'User requested account deletion via Divine app',
      );

      if (event == null) {
        return DeleteAccountResult.failure('Failed to create deletion event');
      }

      // Broadcast to all configured relays
      final broadcastResult = await _nostrService.broadcastEvent(event);

      if (broadcastResult.successCount == 0) {
        Log.error(
          'Failed to broadcast NIP-62 deletion request to any relay',
          name: 'AccountDeletionService',
          category: LogCategory.system,
        );
        return DeleteAccountResult.failure(
          'Failed to broadcast deletion request to relays',
        );
      }

      Log.info(
        'NIP-62 deletion request broadcast to ${broadcastResult.successCount} relay(s)',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );

      return DeleteAccountResult.createSuccess(event.id);
    } catch (e) {
      Log.error(
        'Account deletion failed: $e',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );
      return DeleteAccountResult.failure('Account deletion failed: $e');
    }
  }

  /// Create NIP-62 kind 62 event with ALL_RELAYS tag
  Future<Event?> createNip62Event({required String reason}) async {
    try {
      if (!_nostrService.hasKeys) {
        Log.error(
          'Cannot create NIP-62 event: no keys available',
          name: 'AccountDeletionService',
          category: LogCategory.system,
        );
        return null;
      }

      final pubkey = _authService.currentPublicKeyHex;
      if (pubkey == null) {
        Log.error(
          'Cannot create NIP-62 event: no pubkey available',
          name: 'AccountDeletionService',
          category: LogCategory.system,
        );
        return null;
      }

      // NIP-62 requires relay tag with ALL_RELAYS for network-wide deletion
      final tags = <List<String>>[
        ['relay', 'ALL_RELAYS'],
      ];

      // Create kind 62 event
      final event = await _nostrService.createAndSignEvent(
        kind: 62,
        content: reason,
        tags: tags,
      );

      if (event != null) {
        Log.info(
          'Created NIP-62 deletion event (kind 62): ${event.id}',
          name: 'AccountDeletionService',
          category: LogCategory.system,
        );
      }

      return event;
    } catch (e) {
      Log.error(
        'Failed to create NIP-62 event: $e',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );
      return null;
    }
  }
}
```

**Step 4: Generate mocks**

```bash
cd .worktrees/account-deletion
dart run build_runner build --delete-conflicting-outputs
```

Expected: Generates `account_deletion_service_test.mocks.dart`

**Step 5: Run test to verify it passes**

```bash
flutter test test/services/account_deletion_service_test.dart
```

Expected: All 6 tests PASS

**Step 6: Commit**

```bash
cd .worktrees/account-deletion
git add lib/services/account_deletion_service.dart test/services/account_deletion_service_test.dart
git commit -m "feat: add AccountDeletionService with NIP-62 support

- Implement NIP-62 kind 62 event creation
- Add ALL_RELAYS tag for network-wide deletion
- Handle event broadcast and error cases
- Add comprehensive unit tests"
```

---

## Task 2: Add Riverpod Provider for AccountDeletionService

**Files:**
- Modify: `lib/providers/app_providers.dart`

**Step 1: Write the failing test for provider**

Create `test/providers/account_deletion_provider_test.dart`:

```dart
// ABOUTME: Tests for account deletion Riverpod provider
// ABOUTME: Verifies provider initialization and dependency injection

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/account_deletion_service.dart';

void main() {
  group('accountDeletionServiceProvider', () {
    test('should create AccountDeletionService instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(accountDeletionServiceProvider);

      expect(service, isA<AccountDeletionService>());
    });
  });
}
```

**Step 2: Run test to verify it fails**

```bash
flutter test test/providers/account_deletion_provider_test.dart
```

Expected: FAIL with "accountDeletionServiceProvider not found"

**Step 3: Add provider to app_providers.dart**

Open `lib/providers/app_providers.dart` and add after other service providers:

```dart
// Account Deletion Service
final accountDeletionServiceProvider = Provider<AccountDeletionService>((ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);
  return AccountDeletionService(
    nostrService: nostrService,
    authService: authService,
  );
});
```

Also add import at top of file:

```dart
import 'package:openvine/services/account_deletion_service.dart';
```

**Step 4: Run test to verify it passes**

```bash
flutter test test/providers/account_deletion_provider_test.dart
```

Expected: PASS

**Step 5: Commit**

```bash
git add lib/providers/app_providers.dart test/providers/account_deletion_provider_test.dart
git commit -m "feat: add Riverpod provider for AccountDeletionService"
```

---

## Task 3: Create Delete Account Dialog Widgets

**Files:**
- Create: `lib/widgets/delete_account_dialog.dart`
- Create: `test/widgets/delete_account_dialog_test.dart`

**Step 1: Write the failing test for dialog widgets**

Create `test/widgets/delete_account_dialog_test.dart`:

```dart
// ABOUTME: Tests for account deletion dialog widgets
// ABOUTME: Verifies warning dialog and completion dialog behavior

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/delete_account_dialog.dart';

void main() {
  group('DeleteAccountWarningDialog', () {
    testWidgets('should show warning title and content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDeleteAccountWarningDialog(
                  context: context,
                  onConfirm: () {},
                ),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('⚠️ Delete Account?'), findsOneWidget);
      expect(find.textContaining('PERMANENT'), findsOneWidget);
      expect(find.textContaining('cannot be undone'), findsOneWidget);
    });

    testWidgets('should show Cancel and Delete buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDeleteAccountWarningDialog(
                  context: context,
                  onConfirm: () {},
                ),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete My Account'), findsOneWidget);
    });

    testWidgets('should call onConfirm when Delete button tapped', (tester) async {
      var confirmed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDeleteAccountWarningDialog(
                  context: context,
                  onConfirm: () => confirmed = true,
                ),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete My Account'));
      await tester.pumpAndSettle();

      expect(confirmed, isTrue);
    });

    testWidgets('should close dialog when Cancel tapped', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDeleteAccountWarningDialog(
                  context: context,
                  onConfirm: () {},
                ),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('⚠️ Delete Account?'), findsNothing);
    });
  });

  group('DeleteAccountCompletionDialog', () {
    testWidgets('should show completion message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDeleteAccountCompletionDialog(
                  context: context,
                  onCreateNewAccount: () {},
                ),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('✓ Account Deleted'), findsOneWidget);
      expect(find.textContaining('deletion request has been sent'), findsOneWidget);
    });

    testWidgets('should show Create New Account and Close buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDeleteAccountCompletionDialog(
                  context: context,
                  onCreateNewAccount: () {},
                ),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Create New Account'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('should call onCreateNewAccount when button tapped', (tester) async {
      var createAccountCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDeleteAccountCompletionDialog(
                  context: context,
                  onCreateNewAccount: () => createAccountCalled = true,
                ),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create New Account'));
      await tester.pumpAndSettle();

      expect(createAccountCalled, isTrue);
    });
  });
}
```

**Step 2: Run test to verify it fails**

```bash
flutter test test/widgets/delete_account_dialog_test.dart
```

Expected: FAIL with "delete_account_dialog.dart not found"

**Step 3: Write minimal dialog widget implementation**

Create `lib/widgets/delete_account_dialog.dart`:

```dart
// ABOUTME: Dialog widgets for account deletion flow
// ABOUTME: Warning dialog with confirmation and completion dialog with next steps

import 'package:flutter/material.dart';
import 'package:openvine/theme/vine_theme.dart';

/// Show warning dialog before account deletion
Future<void> showDeleteAccountWarningDialog({
  required BuildContext context,
  required VoidCallback onConfirm,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: const Text(
        '⚠️ Delete Account?',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: const Text(
        'This action is PERMANENT and cannot be undone.\n\n'
        'This will:\n'
        '• Request deletion of ALL your content from Nostr relays\n'
        '• Remove your Nostr keys from this device\n'
        '• Sign you out immediately\n\n'
        'Your videos, profile, and all activity will be deleted from '
        'participating relays. Some relays may not honor deletion requests.\n\n'
        'Are you absolutely sure?',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text(
            'Delete My Account',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}

/// Show completion dialog after account deletion
Future<void> showDeleteAccountCompletionDialog({
  required BuildContext context,
  required VoidCallback onCreateNewAccount,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: const Text(
        '✓ Account Deleted',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: const Text(
        'Your deletion request has been sent to Nostr relays.\n\n'
        'You\'ve been signed out and your keys have been removed from this device.',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Close',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onCreateNewAccount();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: VineTheme.vineGreen,
            foregroundColor: Colors.white,
          ),
          child: const Text(
            'Create New Account',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}
```

**Step 4: Run test to verify it passes**

```bash
flutter test test/widgets/delete_account_dialog_test.dart
```

Expected: All tests PASS

**Step 5: Commit**

```bash
git add lib/widgets/delete_account_dialog.dart test/widgets/delete_account_dialog_test.dart
git commit -m "feat: add delete account warning and completion dialogs

- Warning dialog with clear permanence message
- Completion dialog with Create New Account option
- Dark mode styling consistent with app theme
- Comprehensive widget tests"
```

---

## Task 4: Update Settings Screen with Delete Account Option

**Files:**
- Modify: `lib/screens/settings_screen.dart`
- Create: `test/widgets/settings_delete_account_test.dart`

**Step 1: Write the failing test for Settings screen integration**

Create `test/widgets/settings_delete_account_test.dart`:

```dart
// ABOUTME: Tests for Delete Account integration in Settings screen
// ABOUTME: Verifies Account section appears and delete flow triggers correctly

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/settings_screen.dart';
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/services/auth_service.dart';

import 'settings_delete_account_test.mocks.dart';

@GenerateMocks([AccountDeletionService, AuthService])
void main() {
  group('SettingsScreen - Delete Account', () {
    late MockAccountDeletionService mockDeletionService;
    late MockAuthService mockAuthService;

    setUp(() {
      mockDeletionService = MockAccountDeletionService();
      mockAuthService = MockAuthService();
    });

    testWidgets('should show Delete Account option when authenticated',
        (tester) async {
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentProfile).thenReturn(null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountDeletionServiceProvider.overrideWithValue(mockDeletionService),
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('Delete Account'), findsOneWidget);
      expect(
        find.text('Permanently delete all your content from Nostr relays'),
        findsOneWidget,
      );
    });

    testWidgets('should hide Delete Account when not authenticated',
        (tester) async {
      when(mockAuthService.isAuthenticated).thenReturn(false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountDeletionServiceProvider.overrideWithValue(mockDeletionService),
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('ACCOUNT'), findsNothing);
      expect(find.text('Delete Account'), findsNothing);
    });

    testWidgets('should show warning dialog when Delete Account tapped',
        (tester) async {
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentProfile).thenReturn(null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountDeletionServiceProvider.overrideWithValue(mockDeletionService),
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();

      expect(find.text('⚠️ Delete Account?'), findsOneWidget);
      expect(find.text('PERMANENT'), findsOneWidget);
    });

    testWidgets('Delete Account tile should have red icon and text',
        (tester) async {
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentProfile).thenReturn(null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountDeletionServiceProvider.overrideWithValue(mockDeletionService),
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final deleteAccountTile = find.ancestor(
        of: find.text('Delete Account'),
        matching: find.byType(ListTile),
      );

      expect(deleteAccountTile, findsOneWidget);

      final listTile = tester.widget<ListTile>(deleteAccountTile);
      final leadingIcon = listTile.leading as Icon;
      final titleText = listTile.title as Text;

      expect(leadingIcon.color, equals(Colors.red));
      expect(leadingIcon.icon, equals(Icons.delete_forever));
      expect(titleText.style?.color, equals(Colors.red));
    });
  });
}
```

**Step 2: Run test to verify it fails**

```bash
flutter test test/widgets/settings_delete_account_test.dart
```

Expected: FAIL with "Delete Account not found" or similar

**Step 3: Update SettingsScreen to add Account section**

Open `lib/screens/settings_screen.dart` and modify:

1. Add import at top:
```dart
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/widgets/delete_account_dialog.dart';
import 'package:openvine/screens/profile_setup_screen.dart';
```

2. In the `build` method, after the Profile section (around line 73), add:

```dart
          // Account Section (only show when authenticated)
          if (isAuthenticated) ...[
            _buildSectionHeader('Account'),
            _buildSettingsTile(
              context,
              icon: Icons.delete_forever,
              title: 'Delete Account',
              subtitle: 'Permanently delete all your content from Nostr relays',
              onTap: () => _handleDeleteAccount(context, ref),
              iconColor: Colors.red,
              titleColor: Colors.red,
            ),
          ],
```

3. Update `_buildSettingsTile` method signature to accept optional colors:

```dart
  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
  }) =>
      ListTile(
        leading: Icon(icon, color: iconColor ?? VineTheme.vineGreen),
        title: Text(
          title,
          style: TextStyle(
            color: titleColor ?? Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      );
```

4. Add the delete account handler method at the end of the class:

```dart
  Future<void> _handleDeleteAccount(BuildContext context, WidgetRef ref) async {
    final deletionService = ref.read(accountDeletionServiceProvider);
    final authService = ref.read(authServiceProvider);

    // Show warning dialog
    await showDeleteAccountWarningDialog(
      context: context,
      onConfirm: () async {
        // Show loading indicator
        if (!context.mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: VineTheme.vineGreen),
          ),
        );

        // Execute deletion
        final result = await deletionService.deleteAccount();

        // Close loading indicator
        if (!context.mounted) return;
        Navigator.of(context).pop();

        if (result.success) {
          // Sign out and delete keys
          await authService.signOut(deleteKeys: true);

          // Show completion dialog
          if (!context.mounted) return;
          await showDeleteAccountCompletionDialog(
            context: context,
            onCreateNewAccount: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const ProfileSetupScreen(isNewUser: true),
                ),
                (route) => false,
              );
            },
          );
        } else {
          // Show error
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.error ?? 'Failed to delete account',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }
```

**Step 4: Generate mocks**

```bash
dart run build_runner build --delete-conflicting-outputs
```

**Step 5: Run test to verify it passes**

```bash
flutter test test/widgets/settings_delete_account_test.dart
```

Expected: All tests PASS

**Step 6: Commit**

```bash
git add lib/screens/settings_screen.dart test/widgets/settings_delete_account_test.dart
git commit -m "feat: add Delete Account option to Settings screen

- Add Account section with Delete Account tile
- Red icon and text to indicate destructive action
- Wire up complete deletion flow with dialogs
- Show loading indicator during deletion
- Handle errors with snackbar feedback
- Navigate to ProfileSetupScreen after completion
- Only show when user is authenticated"
```

---

## Task 5: Integration Test for Complete Deletion Flow

**Files:**
- Create: `test/integration/account_deletion_flow_test.dart`

**Step 1: Write integration test**

Create `test/integration/account_deletion_flow_test.dart`:

```dart
// ABOUTME: Integration test for complete account deletion flow
// ABOUTME: Tests end-to-end deletion from Settings through sign out

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/settings_screen.dart';
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';

import 'account_deletion_flow_test.mocks.dart';

@GenerateMocks([INostrService, AuthService])
void main() {
  group('Account Deletion Flow Integration', () {
    late MockINostrService mockNostrService;
    late MockAuthService mockAuthService;

    setUp(() {
      mockNostrService = MockINostrService();
      mockAuthService = MockAuthService();
    });

    testWidgets('complete deletion flow from settings to sign out',
        (tester) async {
      // Arrange
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentProfile).thenReturn(null);
      when(mockAuthService.currentPublicKeyHex).thenReturn('test_pubkey');
      when(mockNostrService.hasKeys).thenReturn(true);

      final mockEvent = Event(
        'test_pubkey',
        62,
        [['relay', 'ALL_RELAYS']],
        'User requested account deletion via Divine app',
        createdAt: 1234567890,
      );

      when(mockNostrService.createAndSignEvent(
        kind: 62,
        content: anyNamed('content'),
        tags: anyNamed('tags'),
      )).thenAnswer((_) async => mockEvent);

      when(mockNostrService.broadcastEvent(any)).thenAnswer(
        (_) async => BroadcastResult(successCount: 3, failureCount: 0),
      );

      when(mockAuthService.signOut(deleteKeys: true))
          .thenAnswer((_) async => Future.value());

      final deletionService = AccountDeletionService(
        nostrService: mockNostrService,
        authService: mockAuthService,
      );

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountDeletionServiceProvider.overrideWithValue(deletionService),
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Delete Account
      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();

      // Verify warning dialog appears
      expect(find.text('⚠️ Delete Account?'), findsOneWidget);

      // Confirm deletion
      await tester.tap(find.text('Delete My Account'));
      await tester.pump(); // Start deletion
      await tester.pump(const Duration(milliseconds: 100)); // Loading indicator
      await tester.pumpAndSettle(); // Complete deletion

      // Verify NIP-62 event was broadcast
      verify(mockNostrService.broadcastEvent(mockEvent)).called(1);

      // Verify user was signed out with keys deleted
      verify(mockAuthService.signOut(deleteKeys: true)).called(1);

      // Verify completion dialog appears
      expect(find.text('✓ Account Deleted'), findsOneWidget);
      expect(find.text('Create New Account'), findsOneWidget);
    });

    testWidgets('should show error when broadcast fails', (tester) async {
      // Arrange
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentProfile).thenReturn(null);
      when(mockAuthService.currentPublicKeyHex).thenReturn('test_pubkey');
      when(mockNostrService.hasKeys).thenReturn(true);

      final mockEvent = Event(
        'test_pubkey',
        62,
        [['relay', 'ALL_RELAYS']],
        'User requested account deletion via Divine app',
        createdAt: 1234567890,
      );

      when(mockNostrService.createAndSignEvent(
        kind: 62,
        content: anyNamed('content'),
        tags: anyNamed('tags'),
      )).thenAnswer((_) async => mockEvent);

      when(mockNostrService.broadcastEvent(any)).thenAnswer(
        (_) async => BroadcastResult(successCount: 0, failureCount: 3),
      );

      final deletionService = AccountDeletionService(
        nostrService: mockNostrService,
        authService: mockAuthService,
      );

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountDeletionServiceProvider.overrideWithValue(deletionService),
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Delete Account
      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();

      // Confirm deletion
      await tester.tap(find.text('Delete My Account'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify error message appears
      expect(find.textContaining('Failed to'), findsOneWidget);

      // Verify user was NOT signed out
      verifyNever(mockAuthService.signOut(deleteKeys: true));
    });
  });
}
```

**Step 2: Run test to verify it passes**

```bash
flutter test test/integration/account_deletion_flow_test.dart
```

Expected: All tests PASS

**Step 3: Commit**

```bash
git add test/integration/account_deletion_flow_test.dart
git commit -m "test: add integration test for account deletion flow

- Test complete flow from Settings to sign out
- Verify NIP-62 event broadcast
- Verify key deletion on success
- Verify error handling on broadcast failure"
```

---

## Task 6: Run Full Test Suite and Flutter Analyze

**Step 1: Run all tests**

```bash
flutter test
```

Expected: All tests PASS (existing + new account deletion tests)

**Step 2: Run Flutter analyze**

```bash
flutter analyze
```

Expected: No issues found

**Step 3: Fix any issues if found**

If any issues are found, fix them and re-run tests/analyze until clean.

**Step 4: Commit any fixes**

```bash
git add .
git commit -m "fix: address analysis issues from account deletion feature"
```

---

## Task 7: Manual Testing on macOS

**Step 1: Build and run on macOS**

```bash
./run_dev.sh macos debug
```

**Step 2: Manual test checklist**

- [ ] Open Settings screen
- [ ] Verify Account section appears (when authenticated)
- [ ] Verify Delete Account option has red icon/text
- [ ] Tap Delete Account
- [ ] Verify warning dialog shows with correct text
- [ ] Tap Cancel - verify dialog closes, no deletion
- [ ] Tap Delete Account again
- [ ] Tap Delete My Account
- [ ] Verify loading indicator appears briefly
- [ ] Verify completion dialog appears
- [ ] Verify user is signed out (redirected to unauthenticated state)
- [ ] Verify Create New Account button navigates to ProfileSetupScreen
- [ ] Create new account and verify Settings no longer shows old account

**Step 3: Check logs for NIP-62 event**

Look for log entries like:
```
Created NIP-62 deletion event (kind 62): <event_id>
NIP-62 deletion request broadcast to N relay(s)
```

**Step 4: Document any issues**

If any issues found during manual testing, document them and fix before final commit.

---

## Task 8: Update CHANGELOG

**Files:**
- Modify: `docs/CHANGELOG.md`

**Step 1: Add entry to CHANGELOG**

Open `docs/CHANGELOG.md` and add at the top of the "Unreleased" section:

```markdown
### Added
- **Account Deletion (NIP-62)**: Users can now permanently delete their Nostr account and all content from participating relays via Settings > Account > Delete Account. This implements the NIP-62 "Request to Vanish" protocol for network-wide deletion.
  - Warning dialog with clear explanation of consequences
  - Immediate key deletion from device after NIP-62 broadcast
  - Completion dialog with option to create new account
  - Red styling to indicate destructive action
```

**Step 2: Commit CHANGELOG**

```bash
git add docs/CHANGELOG.md
git commit -m "docs: add account deletion feature to CHANGELOG"
```

---

## Task 9: Final Commit and Summary

**Step 1: Verify all changes are committed**

```bash
git status
```

Expected: Working tree clean

**Step 2: Review commit history**

```bash
git log --oneline feature/account-deletion ^main
```

Expected: Should show all commits from this implementation

**Step 3: Summary**

The account deletion feature is now complete with:

✅ AccountDeletionService implementing NIP-62
✅ Riverpod provider for dependency injection
✅ Warning and completion dialogs
✅ Settings screen integration with Account section
✅ Complete unit tests for service
✅ Widget tests for dialogs and Settings screen
✅ Integration test for complete flow
✅ Manual testing on macOS
✅ CHANGELOG updated

**Next Steps:**
1. Push branch and create PR
2. Request code review
3. Test on iOS/Android before merging
4. Merge to main after approval

---

## Success Criteria Verification

- [x] User can delete account in < 3 taps from Settings
- [x] Warning is clear and impossible to miss
- [x] NIP-62 event is correctly formatted (kind 62, ALL_RELAYS tag)
- [x] Local keys are completely removed from device
- [x] User is signed out immediately after deletion
- [x] "Create New Account" flow works smoothly
- [x] No crashes or errors in happy path
- [x] Graceful error handling for network failures
- [x] All tests pass
- [x] Flutter analyze shows no issues

## Implementation Notes

- Follow TDD strictly: test first, minimal implementation, verify pass
- Commit frequently (after each passing test)
- Use DRY principles (avoid duplication)
- Follow YAGNI (don't add features not in design)
- Match existing code style (dark mode, VineTheme colors)
- Never truncate Nostr IDs (use full event IDs in logs)
