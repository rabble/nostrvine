# Merge Plan: theming-d0.1 into main (after main merge)

**Date:** 2026-01-09
**Branch:** theming-d0.1
**Target:** main (already merged into theming-d0.1, resolving conflicts)

## Overview

This document captures the context for resolving merge conflicts between `theming-d0.1` and `main`. The key challenge is that both branches modified `video_feed_item.dart` significantly but in different ways.

## Summary of Changes by Branch

### theming-d0.1 Branch Changes

1. **Follow Button Redesign** (`video_follow_button.dart`)
   - Changed from pill-shaped text button to 20x20 circular button
   - Added SVG icons: `Icon-Follow.svg` (green bg) and `Icon-Following.svg` (white bg)
   - Added `hideIfFollowing` parameter to conditionally hide when already following
   - Positioned on avatar corner (bottom-right, offset by 3px)

2. **Hide Follow Button Feature**
   - Added `hideFollowButtonIfFollowing` parameter to `VideoFeedItem`
   - Added `hideFollowButtonIfFollowing` parameter to `VideoOverlayActions`
   - Passes through to `VideoFollowButton.hideIfFollowing`
   - Set to `true` in:
     - `home_screen_router.dart` (Home feed)
     - `video_feed_screen.dart` (Home feed alternate)
     - `profile_video_feed_view.dart` (Profile videos)

3. **Edit Button Redesign**
   - Changed from `Icons.edit` to `pencil.svg` from `assets/icon/content-controls/`
   - Styled to match other action buttons (same IconButton styling)
   - Inlined as Consumer widget instead of separate `_VideoEditButton` class

4. **Layout Adjustments**
   - Changed `Positioned` bottom from 22 to 14 for author info overlay
   - Changed description spacing from 12px to 2px (accounts for 10px avatar container overflow)
   - Added 8px bottom margin after description (only when description exists)

5. **New Assets**
   - `assets/icon/Icon-Follow.svg`
   - `assets/icon/Icon-Following.svg`
   - `assets/icon/content-controls/pencil.svg`
   - `assets/icon/retro-camera.svg`

### main Branch Changes

1. **VideoFeedItem Restructure**
   - Added `isActiveOverride` parameter for video playback control
   - Added `isFullscreen` parameter
   - Added `listSources` and `showListAttribution` parameters
   - Added `disableTapNavigation` parameter
   - Uses `VideoInteractionsBloc` for like/comment state
   - New `VideoAuthorRow` widget (extracted from inline code)
   - New `VideoRepostHeader` widget
   - New `_CommentActionButton` widget
   - Uses `CircularIconButton` widget for action buttons

2. **VideoOverlayActions Restructure**
   - Complete redesign of overlay layout
   - Description now in a styled container with background
   - Action buttons use `CircularIconButton`
   - Added list attribution chip support
   - Added audio attribution row support

3. **VideoFollowButton in main**
   - Simple version WITHOUT `hideIfFollowing` parameter
   - Still uses old styling (not circular 20x20 with SVG)

4. **New Features in main**
   - Audio attribution for videos
   - List attribution chips
   - Sounds/audio screens
   - Curated list improvements

## Conflict Resolution Strategy

### File 1: `app_shell.dart` ✅ RESOLVED
- Comment-only conflict
- Kept theming-d0.1 version: "camera button in bottom nav"

### File 2: `home_screen_router.dart` 🔄 IN PROGRESS
**Conflict:** Line 323 - VideoFeedItem parameters
- theming-d0.1: `hideFollowButtonIfFollowing: true`
- main: `isActiveOverride: isActive`

**Resolution:** Keep BOTH parameters:
```dart
return VideoFeedItem(
  key: ValueKey('video-${videos[index].id}'),
  video: videos[index],
  index: index,
  hasBottomNavigation: false,
  contextTitle: '', // Home feed has no context title
  hideFollowButtonIfFollowing: true, // Home feed only shows followed users
  isActiveOverride: isActive,
);
```

### File 3: `video_feed_screen.dart` 🔲 PENDING
- Likely similar to home_screen_router.dart
- Need to keep `hideFollowButtonIfFollowing: true` and merge with main's changes

### File 4: `vine_theme.dart` 🔲 PENDING
- Need to examine conflict

### File 5: `video_feed_item.dart` 🔲 PENDING (COMPLEX)
This is the most complex conflict. Need to:

1. **Keep main's structure** (VideoAuthorRow, VideoRepostHeader, CircularIconButton, etc.)

2. **Re-add `hideFollowButtonIfFollowing` parameter** to:
   - `VideoFeedItem` widget class
   - `VideoOverlayActions` widget class
   - Pass through to `VideoFollowButton`

3. **Update `VideoFollowButton`** to support `hideIfFollowing`:
   - Add parameter to constructor
   - Add early return when `hideIfFollowing && isFollowing`

4. **Apply theming changes** to VideoFollowButton:
   - 20x20 circular button
   - SVG icons (Icon-Follow.svg, Icon-Following.svg)
   - Green background for Follow state
   - White background for Following state
   - Position on avatar corner

5. **Update Edit button** to use pencil.svg instead of Icons.edit

6. **Apply layout adjustments**:
   - Bottom positioning changes
   - Description spacing changes

### File 6: `pubspec.yaml` ✅ RESOLVED
- Kept theming-d0.1 asset additions

## Detailed Code Changes for video_feed_item.dart

### Step 1: Add hideFollowButtonIfFollowing to VideoFeedItem

In the `VideoFeedItem` class, add parameter:
```dart
class VideoFeedItem extends ConsumerStatefulWidget {
  const VideoFeedItem({
    // ... existing params
    this.hideFollowButtonIfFollowing = false, // ADD THIS
  });

  // ... existing fields
  final bool hideFollowButtonIfFollowing; // ADD THIS
}
```

### Step 2: Add hideFollowButtonIfFollowing to VideoOverlayActions

```dart
class VideoOverlayActions extends ConsumerWidget {
  const VideoOverlayActions({
    // ... existing params
    this.hideFollowButtonIfFollowing = false, // ADD THIS
  });

  // ... existing fields
  final bool hideFollowButtonIfFollowing; // ADD THIS
}
```

### Step 3: Pass parameter from VideoFeedItem to VideoOverlayActions

In `_VideoFeedItemState.build()`, find where VideoOverlayActions is created:
```dart
VideoOverlayActions(
  video: video,
  isVisible: overlayVisible,
  isActive: isActive,
  hasBottomNavigation: widget.hasBottomNavigation,
  contextTitle: widget.contextTitle,
  isFullscreen: widget.isFullscreen,
  listSources: widget.listSources,
  showListAttribution: widget.showListAttribution,
  hideFollowButtonIfFollowing: widget.hideFollowButtonIfFollowing, // ADD THIS
),
```

### Step 4: Update VideoFollowButton

In `video_follow_button.dart`:

```dart
class VideoFollowButton extends ConsumerWidget {
  const VideoFollowButton({
    super.key,
    required this.pubkey,
    this.hideIfFollowing = false, // ADD THIS
  });

  final String pubkey;
  final bool hideIfFollowing; // ADD THIS

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followRepository = ref.watch(followRepositoryProvider);
    final nostrClient = ref.watch(nostrServiceProvider);

    // Don't show follow button for own videos
    if (nostrClient.publicKey == pubkey) {
      return const SizedBox.shrink();
    }

    // ADD THIS: Check follow state directly for immediate hide
    final isFollowing = followRepository.isFollowing(pubkey);
    if (hideIfFollowing && isFollowing) {
      return const SizedBox.shrink();
    }

    return BlocProvider(
      // ... rest of implementation
    );
  }
}
```

### Step 5: Update VideoFollowButton styling (circular 20x20 with SVG)

Replace the button rendering in `VideoFollowButtonView`:
```dart
return GestureDetector(
  onTap: () {
    // ... tap handler
  },
  child: Container(
    width: 20,
    height: 20,
    decoration: BoxDecoration(
      color: isFollowing ? Colors.white : VineTheme.cameraButtonGreen,
      shape: BoxShape.circle,
    ),
    child: Center(
      child: SvgPicture.asset(
        isFollowing
            ? 'assets/icon/Icon-Following.svg'
            : 'assets/icon/Icon-Follow.svg',
        width: 13,
        height: 13,
        colorFilter: isFollowing
            ? null // Icon-Following.svg has its own green color
            : const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      ),
    ),
  ),
);
```

### Step 6: Pass hideIfFollowing to VideoFollowButton in VideoAuthorRow

In the `VideoAuthorRow` widget, update the VideoFollowButton call:
```dart
VideoFollowButton(
  pubkey: video.pubkey,
  hideIfFollowing: hideFollowButtonIfFollowing, // Need to pass this down
),
```

This means `VideoAuthorRow` also needs the parameter:
```dart
class VideoAuthorRow extends ConsumerWidget {
  const VideoAuthorRow({
    super.key,
    required this.video,
    this.isFullscreen = false,
    this.hideFollowButtonIfFollowing = false, // ADD THIS
  });

  final VideoEvent video;
  final bool isFullscreen;
  final bool hideFollowButtonIfFollowing; // ADD THIS
}
```

### Step 7: Update Edit button to use pencil.svg

In `_VideoEditButton`, change:
```dart
// FROM:
icon: const Icon(Icons.edit, color: Colors.white, size: 32),

// TO:
icon: SvgPicture.asset(
  'assets/icon/content-controls/pencil.svg',
  width: 32,
  height: 32,
  colorFilter: const ColorFilter.mode(
    Colors.white,
    BlendMode.srcIn,
  ),
),
```

## Testing Checklist

After resolving conflicts:

- [ ] Run `flutter analyze` - no errors
- [ ] Run tests for video_feed_item
- [ ] Manual test: Home feed - follow button should be hidden
- [ ] Manual test: Profile videos - follow button should be hidden for followed users
- [ ] Manual test: Explore feed - follow button should show
- [ ] Manual test: Edit button shows pencil icon on own videos
- [ ] Manual test: Video playback works correctly (only active video plays)

## Files Modified Summary

1. `pubspec.yaml` - Asset additions ✅
2. `app_shell.dart` - Comment only ✅
3. `home_screen_router.dart` - Add both parameters
4. `video_feed_screen.dart` - Add both parameters
5. `vine_theme.dart` - TBD
6. `video_feed_item.dart` - Major merge (see detailed steps above)
7. `video_follow_button.dart` - Re-add hideIfFollowing + SVG styling
8. `profile_video_feed_view.dart` - Verify hideFollowButtonIfFollowing passed
