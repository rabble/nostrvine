Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This file may reference deleted screens, older branding, or superseded implementation details. Start with docs/README.md and docs/archive/README.md for current guidance.

# Content Moderation UX Design
**Date:** 2025-11-06
**Status:** Approved
**Approach:** Progressive Disclosure (Approach 1)

## Overview

Improve visibility of content moderation features to ensure Apple App Store compliance while maintaining a clean, non-intrusive user experience. All backend services (ContentModerationService, ContentReportingService, MuteService) already exist and are fully functional.

## Problem Statement

- Report content functionality exists but is buried 3 levels deep in ShareVideoMenu
- Block user functionality has no UI exposure
- No central moderation control panel for users
- Apple App Store requires clearly visible content reporting mechanisms

## Design Goals

1. **Multi-location Access**: Report/Block available on video feed, profile screen, and share menu
2. **App Store Compliance**: Moderation features must be obviously visible to reviewers
3. **User Control**: Full moderation control center in Settings
4. **Non-intrusive**: Features visible but not dominating the UI
5. **Nostr-compliant**: Transparent about NIP-51 (mute lists) and NIP-56 (reporting)

## Architecture

### 1. Video Feed Item Enhancements
**File:** `mobile/lib/widgets/video_feed_item.dart`

**Changes:**
- Add flag icon (🚩) to video overlay next to share button
- Icon specifications:
  - Size: 18px
  - Color: White with 70% opacity (normal), Orange (active)
  - Position: Right of share button in bottom action row

**Interaction:**
- Tap flag icon → Show bottom sheet with quick actions:
  1. "Report Content" (opens full NIP-56 report dialog)
  2. "Block @username" (shows confirmation dialog)
  3. "Not Interested" (temporary mute)
  4. "Cancel"

**Widget Test Coverage:**
- Flag icon renders on video feed items
- Tapping flag shows bottom sheet
- Bottom sheet contains all expected actions
- Actions are properly labeled

### 2. Profile Screen Block Button
**File:** `mobile/lib/screens/profile_screen_router.dart`

**Changes:**
- Add "Block User" button in profile header (other users only)
- Button specifications:
  - Style: Outlined button
  - Color: Red border and text
  - Position: Top-right, next to Follow button
  - States: "Block User" → "Unblock" (after blocking)

**Interaction:**
- Tap "Block User" → Show confirmation dialog:
  - Title: "Block @username?"
  - Body: "You won't see their content in feeds. They won't be notified. You can still visit their profile."
  - Actions: [Cancel (gray)] [Block (red)]
- After blocking: Button changes to "Unblock" (gray outline)

**Widget Test Coverage:**
- Block button appears on other users' profiles
- Block button does NOT appear on own profile
- Button shows "Unblock" when user is already blocked
- Tapping block shows confirmation dialog

### 3. Share Menu Reorganization
**File:** `mobile/lib/widgets/share_video_menu.dart`

**Changes:**
- Move "Content Actions" section from bottom to top (after Video Status)
- Rename section to "Safety Actions"
- Apply warning styling:
  - Background: `Colors.orange.withAlpha(26)` (0.1 opacity)
  - Border: `Colors.orange.withAlpha(77)` (0.3 opacity)
  - Icons: Orange color
- Add "Block User" action to this section

**New Section Order:**
1. Video Status (existing)
2. **⚠️ Safety Actions** (moved from bottom, styled)
   - Report Content
   - Block @username
3. Share With
4. Add to List
5. Bookmarks
6. Follow Sets
7. Delete (own content only)

**Widget Test Coverage:**
- Safety Actions section appears at top
- Section has orange warning styling
- Section contains Report and Block actions
- Block action only shows for other users' content

### 4. Safety Settings Screen (NEW)
**File:** `mobile/lib/screens/safety_settings_screen.dart`

**Screen Structure:**

#### Section A: Blocked Users
- List of blocked users:
  - Avatar
  - Display name
  - Username
  - "Unblock" button
- Search bar to filter blocked users
- Empty state: "No blocked users"
- Tap user → Navigate to profile

#### Section B: Muted Content
**Subsection B.1: Muted Users**
- List of temporarily muted users
- "Unmute" button for each
- Empty state: "No muted users"

**Subsection B.2: Muted Keywords**
- Chips showing muted keywords
- X button to remove
- "Add Keyword" button
- Empty state: "No muted keywords"

**Subsection B.3: Muted Hashtags**
- Chips showing muted hashtags
- X button to remove
- "Add Hashtag" button
- Empty state: "No muted hashtags"

#### Section C: Content Filters
- Toggle: "Enable default moderation list" (divine's curated NIP-51 list)
- Dropdown: Auto-hide level
  - Options: Info / Warning / Hide / Block
  - Default: Hide
- Toggle: "Show content warnings"
- Link: "Learn about NIP-51 mute lists" → Opens docs

#### Section D: Report History
- List of submitted reports:
  - Date
  - Content type (Video/User)
  - Reason (e.g., "Spam", "Harassment")
  - Status indicator
- Tap report → View details (shows NIP-56 event ID)
- Empty state: "You haven't reported any content"
- "Clear History" button (keeps only last 90 days)

**Widget Test Coverage:**
- All 4 sections render correctly
- Blocked users list shows avatars and usernames
- Muted content sections show appropriate empty states
- Content filter toggles work
- Report history shows submitted reports

### 5. Settings Integration
**File:** `mobile/lib/screens/settings_screen.dart`

**Changes:**
- Add new section header: "Safety & Privacy"
- Add settings tile:
  - Icon: `Icons.shield` (VineTheme.vineGreen)
  - Title: "Safety & Moderation"
  - Subtitle: "Block users, report content, and manage filters"
  - Action: Navigate to SafetySettingsScreen

**Position:** After "Network" section, before app info

**Widget Test Coverage:**
- Safety & Privacy section appears in settings
- Tapping tile navigates to SafetySettingsScreen

## Integration Test Flows

### Flow 1: Report Content from Video Feed
1. User scrolls to video in feed
2. User taps flag icon on video
3. Bottom sheet appears with "Report Content" option
4. User taps "Report Content"
5. Report dialog appears with violation categories
6. User selects category (e.g., "Spam")
7. User taps "Report"
8. NIP-56 event created and broadcast
9. Success snackbar appears: "✓ Content reported via NIP-56"
10. Report appears in Safety Settings → Report History

### Flow 2: Block User from Profile
1. User navigates to another user's profile
2. "Block User" button visible in header
3. User taps "Block User"
4. Confirmation dialog appears
5. User taps "Block" in dialog
6. MuteService.blockUser() called
7. Button changes to "Unblock"
8. User's videos no longer appear in feeds
9. User appears in Safety Settings → Blocked Users

### Flow 3: Manage Blocked Users
1. User opens Settings
2. User taps "Safety & Moderation"
3. SafetySettingsScreen opens
4. User scrolls to "Blocked Users" section
5. List shows all blocked users with avatars
6. User taps "Unblock" on a user
7. Confirmation dialog appears
8. User confirms
9. User removed from blocked list
10. User's videos return to feeds

## Technical Implementation Notes

### Services (Already Implemented)
- **ContentModerationService**: NIP-51 mute lists, severity levels, filtering
- **ContentReportingService**: NIP-56 reporting (kind 1984), Apple compliance
- **MuteService**: Mute users, hashtags, keywords, threads
- **ContentBlocklistService**: Internal blocklist management

### No Service Changes Required
All backend services are fully implemented and tested. This is purely a UI/UX enhancement to expose existing functionality.

### New Files to Create
1. `mobile/lib/screens/safety_settings_screen.dart` - Main settings screen
2. `mobile/lib/widgets/moderation_action_sheet.dart` - Bottom sheet for quick actions
3. `mobile/lib/widgets/block_confirmation_dialog.dart` - Reusable block confirmation
4. `mobile/test/widgets/safety_settings_screen_test.dart` - Widget tests
5. `mobile/test/integration/moderation_flow_test.dart` - Integration tests

### Files to Modify
1. `mobile/lib/widgets/video_feed_item.dart` - Add flag icon
2. `mobile/lib/screens/profile_screen_router.dart` - Add block button
3. `mobile/lib/widgets/share_video_menu.dart` - Reorganize sections
4. `mobile/lib/screens/settings_screen.dart` - Add safety tile

## UI Specifications

### Colors (Using VineTheme)
- Background: `Colors.black` or `VineTheme.backgroundColor`
- Text: `VineTheme.whiteText`
- Secondary Text: `VineTheme.secondaryText`
- Accent: `VineTheme.vineGreen`
- Warning/Safety: `Colors.orange`
- Danger/Block: `Colors.red`
- Card Background: `VineTheme.cardBackground`

### Icon Sizes
- Video overlay icons: 18-20px
- Settings icons: 24px
- List item icons: 20px

### Spacing
- Section padding: 16px
- Item spacing: 8-12px
- Card margin: 16px horizontal

## User Education

### Nostr Protocol Transparency
- Link to NIP-51 docs in Content Filters section
- Show NIP-56 event IDs in Report History
- Explain that blocking is client-side (not protocol-level)
- Note: "They won't be notified" (privacy-preserving)

### Empty States
All lists include helpful empty states:
- "No blocked users" → "Block users to hide their content from your feeds"
- "No muted keywords" → "Mute keywords to filter content"
- "You haven't reported any content" → "Report content that violates policies"

## Success Metrics

### Apple App Store Compliance
- [ ] Report button visible without drilling down
- [ ] Block user functionality clearly accessible
- [ ] Moderation controls in Settings
- [ ] User can manage blocked/muted content

### User Experience
- [ ] Flag icon doesn't clutter video UI
- [ ] Actions are reversible (unblock, unmute)
- [ ] Confirmation dialogs prevent accidents
- [ ] Settings provide full control

### Technical Quality
- [ ] All features have widget tests
- [ ] Integration tests cover end-to-end flows
- [ ] No breaking changes to existing services
- [ ] Dark theme consistency maintained

## Future Enhancements (Out of Scope)

- Subscribe to external NIP-51 mute lists (backend supports, needs UI)
- Custom content filter rules (advanced users)
- Import/export blocklists
- Sync blocklists across devices via Nostr
- Report analytics (aggregated moderation stats)

## Rollout Plan

1. **Phase 1 (This Design)**: Expose existing moderation features
2. **Phase 2**: User feedback and refinement
3. **Phase 3**: Advanced features (external lists, sync)

---

**Generated with Claude Code** 🤖
