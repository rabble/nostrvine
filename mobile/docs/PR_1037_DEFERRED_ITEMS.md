# PR #1037 Deferred Items

This document tracks review comments from PR #1037 (Profile Screen Theming) that were intentionally deferred to avoid conflicts with other in-flight PRs or to be addressed in follow-up work.

---

## 1. BlocklistVersion Scoping

**Reviewer:** ryzizub
**File:** `lib/providers/app_providers.dart:369`
**Original Comment:**
> I would actually changed it differently. This will make all the places listening to block to rebuild, but that is unnecessary, since only places that are authored by blocked one needs to rebuild. It can be scoped so it does not trigger unnecessary rebuilds.

### Current Implementation

```dart
@riverpod
class BlocklistVersion extends _$BlocklistVersion {
  @override
  int build() => 0;

  void increment() => state++;
}
```

**Problem:** Global counter triggers ALL watchers to rebuild when ANY user is blocked/unblocked.

**Affected files:**
- `lib/screens/other_profile_screen.dart` - watches version in `build()`
- `lib/widgets/profile/follow_from_profile_button.dart` - watches version for button state

### Proposed Solution

Create a family provider keyed by pubkey for scoped rebuilds:

```dart
@riverpod
class UserBlockStatus extends _$UserBlockStatus {
  @override
  bool build(String pubkey) {
    final blocklistService = ref.watch(contentBlocklistServiceProvider);
    return blocklistService.isBlocked(pubkey);
  }

  void refresh() => ref.invalidateSelf();
}
```

Then update block/unblock calls:
```dart
// Instead of:
ref.read(blocklistVersionProvider.notifier).increment();

// Use:
ref.invalidate(userBlockStatusProvider(userIdHex));
```

### Why Deferred

- Requires architectural changes to blocklist notification system
- Performance optimization only - current code is functionally correct
- Low priority unless performance issues are observed in production

### Action Plan

1. Monitor app performance after PR #1037 merges
2. If rebuilds cause noticeable lag, create follow-up PR with family provider approach
3. Update all call sites to use scoped provider

---

## 2 & 3. go_router Migration

**Reviewer:** marcossevilla
**Files:**
- `lib/widgets/vine_bottom_nav.dart:54`
- `lib/widgets/vine_bottom_nav.dart:69`

**Original Comments:**
> this should use go_router instead

> based on #1025, can you use go_router directly instead of nav_extensions?

### Current Implementation

```dart
// vine_bottom_nav.dart uses nav_extensions:
import 'package:openvine/router/nav_extensions.dart';

// Navigation calls:
context.goHome(lastIndex ?? 0);
context.goExplore(null);
context.goNotifications(lastIndex ?? 0);
context.goProfileGrid('me');
context.pushCamera();
```

### Why Deferred

**PR #1025** ("refactor(router): remove nav extensions and route utils") is actively handling the codebase-wide migration from `nav_extensions.dart` to direct go_router usage.

Making changes now would:
- Duplicate effort already in progress
- Cause merge conflicts with PR #1025
- Create inconsistency until #1025 merges

### Action Plan

1. **Wait for PR #1025 to merge** - This PR removes `nav_extensions.dart` and `route_utils.dart` entirely
2. **After merge:** Rebase `theming-profile` branch if needed
3. **Verify:** `vine_bottom_nav.dart` should be updated as part of #1025's changes
4. **If not updated in #1025:** Create follow-up PR with direct go_router calls:

```dart
// Replace nav_extensions with direct go_router:
import 'package:go_router/go_router.dart';

// Example direct calls (exact API TBD based on #1025):
context.go('/home/$lastIndex');
context.go('/explore');
context.go('/notifications/$lastIndex');
context.go('/profile/me');
context.push('/camera');
```

---

## Tracking

| Item | Blocked By | Status | Follow-up PR |
|------|------------|--------|--------------|
| BlocklistVersion scoping | None (low priority) | Deferred | TBD if needed |
| go_router in vine_bottom_nav | PR #1025 | Waiting | Part of #1025 |

---

## References

- **PR #1037:** Profile Screen Theming (this PR)
- **PR #1025:** refactor(router): remove nav extensions and route utils
- **PR #1037 Refactor Plan:** `docs/PR_1037_REFACTOR_PLAN.md`

---

*Created: 2026-01-23*
