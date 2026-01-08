# Comments Sheet Migration - New Design

## Summary

Successfully migrated the comments sheet to use the new `VineBottomSheet` component with updated Figma design specifications.

## What Changed

### 1. **New VineBottomSheet Integration**
   - Replaced custom bottom sheet implementation with reusable `VineBottomSheet`
   - Automatic drag handle (48px × 5px, rounded)
   - Professional header with "Comments" title
   - Proper home indicator at bottom
   - 32px border radius on top corners

### 2. **Updated CommentInput Design**
   - **New circular send button**: 48px diameter, green (#27C58B)
   - **Icon changed**: From `Icons.send` to `Icons.arrow_upward`
   - **Hint text updated**: "Add a comment..." → "Add comment..."
   - **Styling improvements**:
     - Better padding (24px horizontal, 16px vertical)
     - Border color from Figma: `VineTheme.outlineVariant`
     - Background: `VineTheme.surfaceBackground`
     - Text styles using `VineTheme.bodyFont()`
     - Box shadow on send button

### 3. **Design Tokens Applied**
   All colors now use the new Figma design system:
   - `VineTheme.surfaceBackground` (#00150D)
   - `VineTheme.onSurface` (white 95%)
   - `VineTheme.onSurfaceMuted` (white 50%)
   - `VineTheme.outlineVariant` (#254136)
   - `VineTheme.tabIndicatorGreen` (#27C58B)

## Files Modified

### Core Implementation
- `lib/screens/comments/comments_screen.dart`
  - Wrapped content in `VineBottomSheet`
  - Removed old drag handle and header
  - Simplified structure

- `lib/screens/comments/widgets/comment_input.dart`
  - Complete redesign matching Figma
  - New circular green button with arrow icon
  - Updated colors, padding, and typography

### Tests Updated
- `test/screens/comments/comment_input_test.dart`
  - Updated expectations for new hint text
  - Updated icon expectations (send → arrow_upward)
  - All tests passing ✅

## Visual Comparison

### Before
- Gray background (#1A1A1A / Colors.black87)
- Small drag handle (40px × 4px)
- Simple header with close button
- Gray send button with send icon
- 20px border radius

### After
- Dark surface background (#00150D)
- Professional drag handle (48px × 5px)
- Clean header (no close button needed - draggable)
- **Green circular send button** (48px) with arrow icon
- 32px border radius
- Home indicator bar at bottom

## Breaking Changes

None - the public API remains the same:

```dart
// Usage unchanged
CommentsScreen.show(context, videoEvent);
```

## Next Steps

The `VineBottomSheet` is now ready to be used across the app for any bottom sheet needs:

```dart
VineBottomSheet.show(
  context: context,
  title: 'Your Title',
  trailing: VineBottomSheetBadge(text: '3 new'), // Optional
  bottomInput: YourInputWidget(), // Optional
  children: [
    // Your content
  ],
);
```

See `lib/widgets/bottom_sheets/USAGE.md` for complete documentation.
