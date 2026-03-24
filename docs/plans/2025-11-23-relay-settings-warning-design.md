Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This file may reference deleted screens, older branding, or superseded implementation details. Start with docs/README.md and docs/archive/README.md for current guidance.

# Relay Settings Warning & Discovery Design

**Date:** 2025-11-23
**Status:** Approved
**Component:** Relay Settings Screen

## Problem Statement

Users can remove all relays from their configuration, including the default divine relay (`wss://relay.divine.video`), which renders the app non-functional. When no relays are configured:
- Videos cannot be loaded
- Content cannot be posted
- Data synchronization stops
- The app becomes unusable

The current empty state provides insufficient warning about these consequences and doesn't offer an easy recovery path.

## Design Goals

1. **Maintain user control** - Allow users to remove all relays (respects "open system" philosophy)
2. **Clear consequences** - Make it obvious that the app won't work without relays
3. **Easy recovery** - Provide one-tap restoration of default relay
4. **Discovery support** - Help users find additional public relays
5. **Contextual help** - Provide relay discovery links where users need them

## Design Decisions

### User Control Philosophy
**Decision:** Allow removal of all relays with warnings, rather than blocking removal.

**Rationale:**
- Aligns with "Divine is an open system - you control your connections" message
- Advanced users may want to temporarily clear relays
- Better UX to warn and provide easy restore than to block actions

### Warning Prominence
**Decision:** Enhanced empty state in Relay Settings screen (not app-wide banners or blocking modals).

**Rationale:**
- Users in Relay Settings understand they're managing connections
- Less intrusive than app-wide warnings
- Contextual to where the problem was created
- Sufficient for preventing accidental breakage

## UI Changes

### 1. Info Banner Enhancement

**Location:** Lines 40-81 in `relay_settings_screen.dart`

**Addition:** Add relay discovery link below existing "Learn more about Nostr →" link

```dart
const SizedBox(height: 4),
GestureDetector(
  onTap: () => _launchNostrWatch(),
  child: Text(
    'Find public relays at nostr.watch →',
    style: TextStyle(
      color: VineTheme.vineGreen,
      fontSize: 13,
      decoration: TextDecoration.underline,
    ),
  ),
),
```

**Purpose:** Provide relay discovery option for users exploring settings

---

### 2. Empty State Warning Redesign

**Location:** Lines 85-118 in `relay_settings_screen.dart`

**Current State:**
- Icon: `Icons.cloud_off` (grey)
- Message: "No external relays configured"
- Subtitle: "Add relays to sync your content"
- Single button: "Add Relay"

**New State:**
- **Icon:** `Icons.error_outline` (orange `Colors.orange[700]`, size 64)
- **Primary message:** "App Not Functional" (white, fontSize 18, fontWeight bold)
- **Secondary message:** "Divine requires at least one relay to load videos, post content, and sync data." (grey, fontSize 14)
- **Two buttons (stacked vertically):**
  1. **Primary:** "Restore Default Relay" (VineTheme.vineGreen background, white text)
     - Calls `_restoreDefaultRelay()`
     - One-tap fix for most users
  2. **Secondary:** "Add Custom Relay" (grey background, white text)
     - Calls existing `_showAddRelayDialog()`
     - For advanced users who want specific relays

**Visual Hierarchy:**
```
┌─────────────────────────────────┐
│                                 │
│        ⚠️ (error icon)          │
│                                 │
│      App Not Functional         │
│                                 │
│  Divine requires at least one   │
│  relay to load videos, post     │
│  content, and sync data.        │
│                                 │
│  ┌───────────────────────────┐  │
│  │ Restore Default Relay     │  │ (green)
│  └───────────────────────────┘  │
│                                 │
│  ┌───────────────────────────┐  │
│  │ Add Custom Relay          │  │ (grey)
│  └───────────────────────────┘  │
│                                 │
└─────────────────────────────────┘
```

---

### 3. Add Relay Dialog Enhancement

**Location:** Lines 310-410 in `relay_settings_screen.dart`

**Addition:** Insert helper text with relay discovery link before the TextField

```dart
Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const Text(
      'Enter the WebSocket URL of the relay you want to add:',
      style: TextStyle(color: Colors.grey),
    ),
    const SizedBox(height: 8),
    GestureDetector(
      onTap: () => _launchNostrWatch(),
      child: Text(
        'Browse public relays at nostr.watch',
        style: TextStyle(
          color: VineTheme.vineGreen,
          fontSize: 13,
          decoration: TextDecoration.underline,
        ),
      ),
    ),
    const SizedBox(height: 16),
    TextField(...), // existing TextField
  ],
)
```

**Purpose:** Just-in-time help when users are actively adding a relay

---

## New Methods

### `_restoreDefaultRelay()`

**Purpose:** Add default divine relay back to configuration

**Implementation:**
```dart
Future<void> _restoreDefaultRelay() async {
  try {
    final nostrService = ref.read(nostrServiceProvider);
    final defaultRelay = AppConstants.defaultRelayUrl;

    final success = await nostrService.addRelay(defaultRelay);

    if (success) {
      ref.invalidate(nostrServiceProvider);

      if (mounted) {
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restored default relay: $defaultRelay'),
            backgroundColor: Colors.green[700],
          ),
        );
      }

      Log.info('Restored default relay', name: 'RelaySettingsScreen');
    } else {
      _showError('Failed to restore default relay. Please check your network connection.');
    }
  } catch (e) {
    Log.error('Failed to restore default relay: $e', name: 'RelaySettingsScreen');
    _showError('Failed to restore default relay: ${e.toString()}');
  }
}
```

**Error Handling:**
- Network failures → Show error message to user
- Log all failures for debugging
- Use existing `_showError()` method for consistency

---

### `_launchNostrWatch()`

**Purpose:** Open nostr.watch in external browser

**Implementation:**
```dart
Future<void> _launchNostrWatch() async {
  final url = Uri.parse('https://nostr.watch');
  try {
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showError('Could not open browser');
    }
  } catch (e) {
    Log.error('Failed to launch nostr.watch: $e', name: 'RelaySettingsScreen');
    _showError('Failed to open link');
  }
}
```

**Pattern:** Same as existing `_launchNostrDocs()` method for consistency

---

## User Flows

### Flow 1: User Removes All Relays

1. User taps "Remove" on last relay
2. Confirmation dialog shows (existing behavior)
3. User confirms removal
4. UI shows enhanced empty state:
   - Error icon + "App Not Functional" message
   - Clear explanation of consequences
   - "Restore Default Relay" button (prominent)
   - "Add Custom Relay" button (secondary)

### Flow 2: User Restores Default Relay

1. User sees empty state warning
2. Taps "Restore Default Relay" button
3. App adds `wss://relay.divine.video` to configuration
4. Success snackbar appears
5. UI switches to relay list view (non-empty state)
6. App functionality restored

### Flow 3: User Discovers Relays

**From Info Banner:**
1. User opens Relay Settings
2. Reads info banner
3. Taps "Find public relays at nostr.watch →"
4. Browser opens to https://nostr.watch
5. User browses relay list, copies URL
6. Returns to app, taps "Add Relay"

**From Add Dialog:**
1. User taps "Add Relay" button
2. Dialog opens
3. Sees "Browse public relays at nostr.watch" link
4. Taps link → browser opens
5. Copies relay URL from nostr.watch
6. Returns to dialog, pastes URL, adds relay

---

## Implementation Notes

### Files to Modify
- `mobile/lib/screens/relay_settings_screen.dart` (single file change)

### Code Changes Required
1. Update empty state widget (lines 85-118)
2. Add `_restoreDefaultRelay()` method
3. Add `_launchNostrWatch()` method
4. Add nostr.watch link to info banner
5. Enhance add relay dialog with discovery link

### Testing Considerations
- Test empty state display when `externalRelays.length == 0`
- Verify "Restore Default Relay" successfully adds `AppConstants.defaultRelayUrl`
- Confirm UI updates after restore (setState + provider invalidation)
- Test nostr.watch link opens in external browser
- Verify error handling for network failures during restore

### Edge Cases
- User has no network connection when restoring → Show clear error message
- Browser fails to open nostr.watch → Show "Could not open browser" error
- Default relay fails to connect after restore → Existing retry logic handles this

---

## Success Metrics

**Problem Prevention:**
- Users understand consequences of removing all relays
- Empty state provides clear severity indication

**Easy Recovery:**
- One-tap restore to functional state
- Default relay addition success rate

**Discovery Support:**
- Users can find additional public relays
- Contextual help reduces support requests

---

## Future Enhancements (Out of Scope)

1. **Recommended relay list:** Curated list of reliable public relays in-app
2. **Relay health indicators:** Show connection quality/uptime for each relay
3. **Auto-restore on app launch:** Optionally restore default relay on first launch after complete removal
4. **Relay profiles:** Display relay descriptions/policies from NIP-11

These enhancements can be considered in future iterations based on user feedback.
