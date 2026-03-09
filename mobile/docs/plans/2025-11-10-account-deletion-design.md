# Account Deletion Feature - Design Document

**Date:** 2025-11-10
**Status:** Approved for Implementation
**NIP Reference:** [NIP-62 - Request to Vanish](https://nips.nostr.com/62)

## Overview

Implement a complete account deletion feature that allows users to permanently delete their Nostr identity and all associated content from participating relays using NIP-62 "Request to Vanish" protocol.

## User Story

As a user, I want to delete my account and all my content from Nostr relays so that I can remove my digital footprint when I no longer wish to use the platform.

## Requirements

### Functional Requirements

1. **Account Deletion Option**: Accessible from Settings screen
2. **Strong Warning**: Multi-step confirmation with clear permanence warning
3. **NIP-62 Broadcast**: Publish kind 62 event with `ALL_RELAYS` tag to request network-wide deletion
4. **Local Cleanup**: Remove Nostr keys from device storage
5. **Sign Out**: Immediately log user out after deletion
6. **New Account Option**: Offer quick path to create new identity

### Non-Functional Requirements

1. **Permanence**: No undo mechanism - deletion is final
2. **Transparency**: Clear communication about what relays may/may not honor deletion
3. **Simplicity**: Minimal friction for legitimate deletion requests
4. **Error Handling**: Graceful failures with clear user feedback

## Architecture

### Selected Approach: Simple & Direct

**Rationale**: Prioritizes simplicity and clear user experience over complex tracking/undo mechanisms. Account deletion is a rare operation that should be straightforward and immediate.

**Flow**:
1. User taps "Delete Account" in Settings
2. Show strong warning dialog
3. On confirmation: Publish NIP-62 event
4. Delete local keys immediately
5. Sign out user
6. Show completion dialog with "Create New Account" option

### Component Design

#### 1. AccountDeletionService

**Location**: `lib/services/account_deletion_service.dart`

**Purpose**: Handle NIP-62 event creation and broadcast for account deletion

**Key Methods**:
```dart
class AccountDeletionService {
  /// Delete user's account by publishing NIP-62 event
  Future<DeleteAccountResult> deleteAccount({String? customReason});

  /// Create NIP-62 kind 62 event with ALL_RELAYS tag
  Future<Event?> _createNip62Event({String? reason});
}
```

**Dependencies**:
- `NostrService`: For event broadcast
- `AuthService`: For current user identity

#### 2. Settings Screen Updates

**Location**: `lib/screens/settings_screen.dart`

**Changes**:
- Add "Account" section after "Profile" section
- Add "Delete Account" list tile with red icon/text
- Wire up to account deletion dialog flow

**UI Structure**:
```
Settings Screen
├── Profile Section
│   ├── Edit Profile
│   └── Key Management
├── Account Section (NEW)
│   └── Delete Account
├── Network Section
│   ├── Relays
│   └── ...
```

#### 3. Dialogs

**Warning Dialog**:
- Title: "⚠️ Delete Account?"
- Clear explanation of consequences
- Two-button choice: Cancel vs. Delete My Account (red)

**Completion Dialog**:
- Title: "✓ Account Deleted"
- Confirmation message
- Two buttons: Create New Account vs. Close

### NIP-62 Event Structure

```json
{
  "kind": 62,
  "pubkey": "<user_public_key_hex>",
  "created_at": <unix_timestamp>,
  "tags": [
    ["relay", "ALL_RELAYS"]
  ],
  "content": "User requested account deletion via Divine app",
  "id": "<event_id>",
  "sig": "<signature>"
}
```

**Tag Explanation**:
- `["relay", "ALL_RELAYS"]`: Special NIP-62 value requesting network-wide deletion
- No specific relay URLs needed - clients should broadcast to all known relays

**Relay Expectations**:
- Relays receiving this event SHOULD delete all events from the `.pubkey`
- Relays SHOULD prevent deleted events from being re-broadcast
- Relays MAY retain the signed deletion request for legal compliance

### Data Flow

```
User                Settings Screen          AccountDeletionService    NostrService      AuthService
  |                       |                           |                      |                 |
  |--[Tap Delete]-------->|                           |                      |                 |
  |                       |--[Show Warning Dialog]--->|                      |                 |
  |<--[Confirm?]----------|                           |                      |                 |
  |                       |                           |                      |                 |
  |--[Confirm]----------->|                           |                      |                 |
  |                       |--[deleteAccount()]------->|                      |                 |
  |                       |                           |--[Create NIP-62]---->|                 |
  |                       |                           |                      |                 |
  |                       |                           |--[Broadcast Event]-->|                 |
  |                       |                           |<--[BroadcastResult]--|                 |
  |                       |                           |                      |                 |
  |                       |<--[DeleteAccountResult]---|                      |                 |
  |                       |                           |                      |                 |
  |                       |--[signOut(deleteKeys=true)]---------------------->|                 |
  |                       |<--[Signed Out]--------------------------------------|                 |
  |                       |                           |                      |                 |
  |<--[Show Completion]---|                           |                      |                 |
  |                       |                           |                      |                 |
  |--[Create New Account / Close]                     |                      |                 |
```

## Implementation Details

### File Changes

**New Files**:
1. `lib/services/account_deletion_service.dart` - NIP-62 deletion service
2. `lib/widgets/delete_account_dialog.dart` - Warning and completion dialogs
3. `test/services/account_deletion_service_test.dart` - Unit tests
4. `test/widgets/delete_account_dialog_test.dart` - Widget tests
5. `test/integration/account_deletion_flow_test.dart` - Integration tests

**Modified Files**:
1. `lib/screens/settings_screen.dart` - Add Account section and Delete Account option
2. `lib/providers/app_providers.dart` - Add accountDeletionServiceProvider

### Settings Screen Changes

**Visual Design**:
```dart
// Account Section (after Profile section)
_buildSectionHeader('Account'),
_buildSettingsTile(
  context,
  icon: Icons.delete_forever,
  title: 'Delete Account',
  subtitle: 'Permanently delete all your content from Nostr relays',
  onTap: () => _showDeleteAccountWarning(context, ref),
  iconColor: Colors.red,  // Different from default vineGreen
  titleColor: Colors.red,
),
```

### Error Handling

**Scenario 1: Broadcast Failure**
- Show error dialog: "Failed to send deletion request. Your account has not been deleted."
- Allow retry
- Do NOT delete local keys
- Log error details

**Scenario 2: Key Deletion Failure**
- Still sign out user
- Show warning: "Account deletion requested but keys may remain on device"
- Log error for debugging

**Scenario 3: Network Offline**
- Show specific message: "No network connection. Deletion request cannot be sent."
- Do NOT proceed with key deletion
- Allow retry when online

**Scenario 4: User Not Authenticated**
- Hide "Delete Account" option when `!isAuthenticated`
- Prevent access to deletion flow

## Testing Strategy

### Unit Tests

**AccountDeletionService Tests**:
```dart
test('createNip62Event should create kind 62 event')
test('createNip62Event should include ALL_RELAYS tag')
test('createNip62Event should include user pubkey')
test('deleteAccount should broadcast NIP-62 event')
test('deleteAccount should return success when broadcast succeeds')
test('deleteAccount should return failure when broadcast fails')
```

### Widget Tests

**Settings Screen Tests**:
```dart
test('shows Delete Account option when authenticated')
test('hides Delete Account option when not authenticated')
test('Delete Account tile has red icon and text')
test('tapping Delete Account shows warning dialog')
```

**Dialog Tests**:
```dart
test('warning dialog shows correct text and buttons')
test('cancel button closes dialog without deletion')
test('delete button triggers account deletion')
test('completion dialog shows after successful deletion')
test('Create New Account button navigates to ProfileSetupScreen')
test('Close button returns to unauthenticated state')
```

### Integration Tests

**Full Deletion Flow**:
```dart
test('complete account deletion flow from settings to sign out')
test('NIP-62 event is broadcast to configured relays')
test('user keys are deleted from device storage')
test('user is signed out and unauthenticated')
test('Create New Account flow works after deletion')
```

## UI/UX Considerations

### Visual Design

**Dark Mode Compliance**:
- Warning dialog: Black background, white text, red accent for danger
- Delete button: Red background with white text
- Completion dialog: Standard dark theme with vineGreen accent

**Typography**:
- Warning title: 20px bold
- Warning content: 16px regular, line height 1.5 for readability
- Button text: 16px medium weight

**Spacing**:
- Dialog padding: 24px
- Button spacing: 16px between buttons
- Content paragraph spacing: 16px

### User Communication

**Warning Text Principles**:
- ✅ Clear, direct language
- ✅ Specific consequences listed
- ✅ Honesty about relay compliance (some may not honor deletion)
- ❌ No jargon or technical terms
- ❌ No false promises of complete deletion

**Completion Text Principles**:
- ✅ Confirmation that action completed
- ✅ Clear next steps
- ✅ Positive framing for "Create New Account"

## Security Considerations

1. **No Authentication Required**: User is already authenticated to access Settings
2. **Immediate Key Deletion**: Keys removed from device immediately after NIP-62 broadcast
3. **No Recovery**: No backup or undo mechanism - deletion is final
4. **Relay Compliance**: App cannot guarantee all relays will honor deletion (protocol limitation)

## Privacy Considerations

1. **Local Data Cleanup**: Keys deleted from secure storage
2. **Cache Cleanup**: AuthService clears session data
3. **NIP-62 Event Content**: Minimal info ("User requested account deletion via Divine app")
4. **No Tracking**: No analytics event for account deletion

## Future Enhancements

**Not in Initial Implementation**:
1. Export data before deletion (let user download their videos/content)
2. Deletion progress tracking (which relays responded)
3. Partial deletion (specific content types only)
4. Scheduled deletion (delete in 24 hours with undo window)
5. Deletion confirmation email/DM

**Rationale**: Simple & Direct approach prioritizes immediate, frictionless deletion. Advanced features can be added based on user feedback.

## Success Criteria

1. ✅ User can delete their account in < 3 taps from Settings
2. ✅ Warning is clear and impossible to miss
3. ✅ NIP-62 event is correctly formatted and broadcast
4. ✅ Local keys are completely removed from device
5. ✅ User is signed out immediately after deletion
6. ✅ "Create New Account" flow works smoothly
7. ✅ No crashes or errors in happy path
8. ✅ Graceful error handling for network failures

## Rollout Plan

1. **Development**: Implement service, UI, tests
2. **Code Review**: Verify NIP-62 compliance and UX clarity
3. **Manual Testing**: Test on iOS/Android/macOS with real Nostr relays
4. **Beta Release**: Include in next TestFlight build
5. **Monitor**: Watch for user feedback and error rates
6. **Production**: Release with app update

## References

- [NIP-62: Request to Vanish](https://nips.nostr.com/62)
- [NIP-09: Event Deletion Request](https://nips.nostr.com/9) (for context)
- Existing `ContentDeletionService` (NIP-09 for individual videos)
- Apple App Store Guidelines: Right to deletion
