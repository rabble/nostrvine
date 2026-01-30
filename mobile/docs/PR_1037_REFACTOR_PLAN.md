# PR #1037 Refactoring Plan

## Overview

This document captures the comprehensive refactoring plan based on 19 review comments from 5 reviewers (omartinma, Chardot, ryzizub, marcossevilla, B0berman) on PR #1037 (Profile Screen Theming).

**Branch**: `theming-profile`
**PR**: https://github.com/divinevideo/divine-mobile/pull/1037

---

## Review Comments Summary

### 1. omartinma - Widget Extraction (ADDRESSED)
- **File**: `other_profile_screen.dart:395`
- **Issue**: Functions that return widgets not recommended
- **Link**: https://engineering.verygood.ventures/widgets/widgets/
- **Status**: DONE - Extracted `_BulletPoint`, `_BlockConfirmationView`, `_UnblockConfirmationView`, `_MoreSheetMenu`

### 2. ryzizub - BlocklistVersion Scope
- **File**: `app_providers.dart:369`
- **Issue**: `BlocklistVersion` provider causes unnecessary rebuilds for ALL places listening to blocklist
- **Suggestion**: Scope it so only places authored by blocked user rebuild
- **Status**: TODO

### 3. ryzizub - Redundant userIdHex Parameter
- **File**: `other_profile_screen.dart:78`
- **Issue**: `userIdHex` doesn't need to be passed as parameter since it's already available from `widget.npub`
- **Status**: TODO

### 4. marcossevilla - BlocSelector (my_followers_screen)
- **File**: `my_followers_screen.dart:92-95`
- **Issue**: Use `BlocSelector` instead of `BlocBuilder` when narrowing down to specific/computed property
- **Current Code**:
  ```dart
  BlocBuilder<MyFollowersBloc, MyFollowersState>(
    builder: (context, state) {
      final count = state.status == MyFollowersStatus.success
          ? state.followersPubkeys.length
          : 0;
  ```
- **Status**: TODO

### 5. marcossevilla - BlocSelector (others_followers_screen)
- **File**: `others_followers_screen.dart:101`
- **Issue**: Same BlocSelector suggestion
- **Status**: TODO

### 6. marcossevilla - BlocSelector (my_following_screen)
- **File**: `my_following_screen.dart:84`
- **Issue**: Same BlocSelector suggestion
- **Status**: TODO

### 7. ryzizub - Type-Safe Return Instead of String
- **File**: `other_profile_screen.dart:160`
- **Issue**: Return enum instead of string from bottom sheet for type safety
- **Current Code**:
  ```dart
  if (result == 'unblock_confirmed') {
  ```
- **Status**: TODO

### 8. ryzizub - Reuse Getters
- **File**: `other_profile_screen.dart:87`
- **Issue**: Same getters used in `_more()` method and `build()` - can be reused
- **Getters**: blocklistService, isBlocked, followRepository, isFollowing, profile, displayName
- **Status**: TODO

### 9. marcossevilla - Extract Copy-Pasted Widget
- **File**: `others_following_screen.dart:99`
- **Issue**: Widget (followers/following count title) copy-pasted in many places
- **Suggestion**: Extract into standalone widget
- **Status**: TODO

### 10. marcossevilla - Smaller Build Method
- **File**: `follow_from_profile_button.dart:91`
- **Issue**: Extract code to make build method smaller
- **Status**: TODO

### 11. ryzizub - Move More Sheet to Standalone Page
- **File**: `other_profile_screen.dart:288`
- **Issue**: Move `_MoreSheetContent` as standalone "page" similar to comments
- **Benefit**: Makes menu reusable for places where we want more options on profiles
- **Status**: TODO

### 12. marcossevilla - If vs Ternary
- **File**: `follow_from_profile_button.dart:131`
- **Issue**: Use if statement instead of ternary for readability
- **Current Code**:
  ```dart
  return isFollowing
      ? OutlinedButton(...)
      : ElevatedButton(...);
  ```
- **Status**: TODO

### 13. marcossevilla - context.mounted
- **File**: `follow_from_profile_button.dart:286`
- **Suggestion**: `if (result && context.mounted) {`
- **Status**: Already correct in current code

### 14. ryzizub - Move Nostr Auth Info to Own File
- **File**: `profile_setup_screen.dart:1497`
- **Issue**: Move nostr info to own file as `nostr_auth_info_page` with private bullet point widget
- **Status**: TODO

### 15. ryzizub - Extract Copy Pubkey Utility
- **File**: `profile_header_widget.dart:315`
- **Issue**: Copy functionality should be standalone widget/util for reuse
- **Current Code**:
  ```dart
  Future<void> _copyToClipboard(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(...);
    }
  }
  ```
- **Status**: TODO

### 16. marcossevilla - go_router Instead of nav_extensions (1)
- **File**: `vine_bottom_nav.dart:54`
- **Issue**: Based on #1025, use go_router directly instead of nav_extensions
- **Current Code**: `context.goHome(lastIndex ?? 0);`
- **Status**: TODO

### 17. marcossevilla - go_router Instead of nav_extensions (2)
- **File**: `vine_bottom_nav.dart:69`
- **Issue**: Same go_router suggestion
- **Current Code**: `context.goProfileGrid('me');`
- **Status**: TODO

### 18. B0berman - Helper Methods in vine_bottom_sheet
- **File**: `other_profile_screen.dart:395`
- **Issue**: Still seeing functions that return widgets in vine_bottom_sheet
- **Status**: TODO - Need to check VineBottomSheet for helper methods

---

## Categorized Themes

| Theme | Reviewers | Comment Numbers | Count |
|-------|-----------|-----------------|-------|
| Widget Extraction | omartinma, ryzizub, B0berman | 1, 11, 14, 18 | 4 |
| Type Safety | ryzizub | 7 | 1 |
| Performance/Rebuilds | ryzizub, marcossevilla | 2, 4, 5, 6 | 4 |
| Code Reuse/DRY | ryzizub, marcossevilla | 3, 8, 9, 15 | 4 |
| Navigation | marcossevilla | 16, 17 | 2 |
| Code Style | marcossevilla | 10, 12, 13 | 3 |

---

## Implementation Plan

### Phase 1: High-Impact Structural Changes

#### Task 1.1: Create Type-Safe MoreSheetResult Enum
**Addresses**: Comment #7 (ryzizub)
**Files to create**:
- `lib/widgets/profile/more_sheet/more_sheet_result.dart`

```dart
/// Type-safe result from the More sheet actions.
enum MoreSheetResult {
  /// User tapped copy public key.
  copy,

  /// User confirmed unfollow action.
  unfollow,

  /// User confirmed block action.
  blockConfirmed,

  /// User confirmed unblock action.
  unblockConfirmed,

  /// User cancelled/dismissed the sheet.
  cancelled,
}
```

**Files to modify**:
- `lib/screens/other_profile_screen.dart` - Change `VineBottomSheet.show<String>` to `VineBottomSheet.show<MoreSheetResult>`

---

#### Task 1.2: Extract FollowerCountTitle Widget
**Addresses**: Comments #4, #5, #6, #9 (marcossevilla)
**Files to create**:
- `lib/widgets/profile/follower_count_title.dart`

```dart
/// A title widget that shows a label with a count subtitle.
/// Uses BlocSelector for efficient rebuilds.
class FollowerCountTitle<B extends BlocBase<S>, S> extends StatelessWidget {
  const FollowerCountTitle({
    required this.title,
    required this.selector,
    super.key,
  });

  final String title;
  final int Function(S state) selector;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<B, S, int>(
      selector: selector,
      builder: (context, count) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: VineTheme.titleFont()),
            Text(
              '$count users',
              style: VineTheme.bodySmallFont(color: VineTheme.onSurfaceVariant),
            ),
          ],
        );
      },
    );
  }
}
```

**Files to modify**:
- `lib/screens/followers/my_followers_screen.dart`
- `lib/screens/followers/others_followers_screen.dart`
- `lib/screens/following/my_following_screen.dart`
- `lib/screens/following/others_following_screen.dart`

---

#### Task 1.3: Extract Copy Pubkey Utility
**Addresses**: Comment #15 (ryzizub)
**Files to create**:
- `lib/utils/clipboard_utils.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:divine_ui/divine_ui.dart';

/// Utility for clipboard operations with visual feedback.
class ClipboardUtils {
  /// Copies the given pubkey to clipboard and shows a snackbar.
  static Future<void> copyPubkey(
    BuildContext context,
    String pubkey, {
    String message = 'Unique ID copied to clipboard',
  }) async {
    await Clipboard.setData(ClipboardData(text: pubkey));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check, color: VineTheme.onPrimary),
              const SizedBox(width: 8),
              Text(
                message,
                style: VineTheme.bodyMediumFont(color: VineTheme.onPrimary),
              ),
            ],
          ),
          backgroundColor: VineTheme.vineGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
```

**Files to modify**:
- `lib/widgets/profile/profile_header_widget.dart` - Replace `_copyToClipboard()` with `ClipboardUtils.copyPubkey()`
- `lib/screens/other_profile_screen.dart` - Use `ClipboardUtils.copyPubkey()` for copy action

---

#### Task 1.4: Code Style Fixes in FollowFromProfileButton
**Addresses**: Comments #10, #12 (marcossevilla)
**File**: `lib/widgets/profile/follow_from_profile_button.dart`

**Changes**:
1. Replace ternary with if-else at line 131
2. Extract button variants into private widgets:
   - `_FollowingButton`
   - `_FollowButton`

---

### Phase 2: More Sheet Extraction

#### Task 2.1: Move More Sheet to Standalone File
**Addresses**: Comments #11, #18 (ryzizub, B0berman)
**Files to create**:
- `lib/widgets/profile/more_sheet/more_sheet_result.dart` (from Task 1.1)
- `lib/widgets/profile/more_sheet/more_sheet_page.dart`
- `lib/widgets/profile/more_sheet/more_sheet_menu.dart`
- `lib/widgets/profile/more_sheet/block_confirmation_view.dart`
- `lib/widgets/profile/more_sheet/unblock_confirmation_view.dart`
- `lib/widgets/profile/more_sheet/bullet_point.dart`

**Files to modify**:
- `lib/screens/other_profile_screen.dart` - Remove private widgets, import from new location

---

### Phase 3: Code Cleanup

#### Task 3.1: Clean Up OtherProfileScreen Parameters
**Addresses**: Comments #3, #8 (ryzizub)
**File**: `lib/screens/other_profile_screen.dart`

**Changes**:
1. Remove `userIdHex` parameter from `_more()` - derive from `widget.npub`
2. Create getter for common values:
   ```dart
   String get _userIdHex => npubToHexOrNull(widget.npub)!;
   ```
3. Extract common profile data access into a helper

---

#### Task 3.2: Move Nostr Auth Info to Own File
**Addresses**: Comment #14 (ryzizub)
**Files to create**:
- `lib/widgets/profile/nostr_auth_info_sheet.dart`

**Files to modify**:
- `lib/screens/profile_setup_screen.dart` - Import and use new widget

---

#### Task 3.3: Use go_router Directly
**Addresses**: Comments #16, #17 (marcossevilla)
**Reference**: PR #1025
**File**: `lib/widgets/vine_bottom_nav.dart`

**Changes**:
Replace:
```dart
context.goHome(lastIndex ?? 0);
context.goExplore(null);
context.goNotifications(lastIndex ?? 0);
context.goProfileGrid('me');
```

With direct go_router calls (need to check #1025 for exact pattern).

---

### Phase 4: Performance Improvements

#### Task 4.1: Refactor BlocklistVersion for Scoped Rebuilds
**Addresses**: Comment #2 (ryzizub)
**File**: `lib/providers/app_providers.dart`

**Current approach**:
```dart
@riverpod
class BlocklistVersion extends _$BlocklistVersion {
  @override
  int build() => 0;
  void increment() => state++;
}
```

**New approach options**:

Option A: Family provider keyed by pubkey
```dart
@riverpod
bool isUserBlocked(Ref ref, String pubkey) {
  final blocklistService = ref.watch(contentBlocklistServiceProvider);
  return blocklistService.isBlocked(pubkey);
}
```

Option B: Stream-based approach
```dart
@riverpod
Stream<bool> isUserBlockedStream(Ref ref, String pubkey) {
  // Return stream that emits when this specific user's block status changes
}
```

**Files to modify**:
- `lib/providers/app_providers.dart`
- `lib/screens/other_profile_screen.dart`
- Any other files watching `blocklistVersionProvider`

---

## Execution Checklist

### Phase 1: High-Impact Structural (Est. 1-1.5 hours)
- [ ] Task 1.1: Create MoreSheetResult enum
- [ ] Task 1.2: Extract FollowerCountTitle widget
- [ ] Task 1.3: Extract ClipboardUtils
- [ ] Task 1.4: FollowFromProfileButton style fixes
- [ ] Run tests after Phase 1

### Phase 2: More Sheet Extraction (Est. 45 min)
- [ ] Task 2.1: Create more_sheet/ directory and files
- [ ] Task 2.1: Update imports in other_profile_screen.dart
- [ ] Run tests after Phase 2

### Phase 3: Code Cleanup (Est. 45 min)
- [ ] Task 3.1: Clean up OtherProfileScreen
- [ ] Task 3.2: Extract Nostr Auth Info sheet
- [ ] Task 3.3: Update vine_bottom_nav.dart to use go_router
- [ ] Run tests after Phase 3

### Phase 4: Performance (Est. 30 min)
- [ ] Task 4.1: Refactor BlocklistVersion
- [ ] Run tests after Phase 4

### Final Steps
- [ ] Run full test suite
- [ ] Run `dart format`
- [ ] Run `flutter analyze`
- [ ] Commit and push
- [ ] Reply to all reviewer comments

---

## File Reference

### Files to Create
1. `lib/widgets/profile/more_sheet/more_sheet_result.dart`
2. `lib/widgets/profile/more_sheet/more_sheet_page.dart`
3. `lib/widgets/profile/more_sheet/more_sheet_menu.dart`
4. `lib/widgets/profile/more_sheet/block_confirmation_view.dart`
5. `lib/widgets/profile/more_sheet/unblock_confirmation_view.dart`
6. `lib/widgets/profile/more_sheet/bullet_point.dart`
7. `lib/widgets/profile/follower_count_title.dart`
8. `lib/widgets/profile/nostr_auth_info_sheet.dart`
9. `lib/utils/clipboard_utils.dart`

### Files to Modify
1. `lib/screens/other_profile_screen.dart`
2. `lib/screens/followers/my_followers_screen.dart`
3. `lib/screens/followers/others_followers_screen.dart`
4. `lib/screens/following/my_following_screen.dart`
5. `lib/screens/following/others_following_screen.dart`
6. `lib/screens/profile_setup_screen.dart`
7. `lib/widgets/profile/profile_header_widget.dart`
8. `lib/widgets/profile/follow_from_profile_button.dart`
9. `lib/widgets/vine_bottom_nav.dart`
10. `lib/providers/app_providers.dart`

---

## Notes

- Comment #1 (omartinma) was already addressed in commit `3277fb28`
- Comment #13 (marcossevilla) - code is already correct (`if (result == true && context.mounted)`)
- Need to check PR #1025 for exact go_router migration pattern before Task 3.3
- Consider creating tests for new widgets (FollowerCountTitle, ClipboardUtils)

---

## Implementation Status (Updated)

### Completed
- ✅ Phase 1: MoreSheetResult enum, FollowerCountTitle, ClipboardUtils, FollowFromProfileButton
- ✅ Phase 2: More Sheet widgets extracted to standalone files
- ✅ Phase 3.1: OtherProfileScreen params cleanup (userIdHex getter)
- ✅ Phase 3.2: NostrInfoSheetContent extracted to standalone widget

### Deferred
- ⏳ Phase 3.3: go_router migration - Deferred to PR #1025 which handles this codebase-wide
- ⏳ Phase 4.1: BlocklistVersion scoping - Performance optimization, deferred to follow-up PR if needed

---

*Document created: 2026-01-23*
*Last updated: 2026-01-23*
