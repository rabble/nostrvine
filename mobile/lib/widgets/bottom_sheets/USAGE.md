# VineBottomSheet Usage Guide

Reusable bottom sheet components following the new Figma design system.

## Components

### 1. VineBottomSheet
Main bottom sheet container with drag handle, header, scrollable content, and optional input.

### 2. VineBottomSheetHeader
Header component with title and optional trailing widgets (badges, buttons).

### 3. VineBottomSheetDragHandle
Visual drag indicator at the top of sheets.

### 4. VineBottomSheetBadge
Badge component for showing counts (e.g., "3 new", "12 unread").

## Quick Start

```dart
import 'package:openvine/widgets/bottom_sheets/bottom_sheets.dart';

// Show a basic bottom sheet
VineBottomSheet.show(
  context: context,
  title: 'My Sheet',
  children: [
    Text('Content goes here'),
    Text('More content'),
  ],
);
```

## Examples

###Example 1: Basic Sheet

```dart
VineBottomSheet.show(
  context: context,
  title: 'Settings',
  children: [
    ListTile(title: Text('Option 1')),
    ListTile(title: Text('Option 2')),
    ListTile(title: Text('Option 3')),
  ],
);
```

### Example 2: Sheet with Badge

```dart
VineBottomSheet.show(
  context: context,
  title: 'Notifications',
  trailing: VineBottomSheetBadge(text: '5 new'),
  children: [
    NotificationTile(notification: notification1),
    NotificationTile(notification: notification2),
  ],
);
```

### Example 3: Sheet with Input

```dart
VineBottomSheet.show(
  context: context,
  title: 'Add Comment',
  bottomInput: CommentInputWidget(),
  children: [
    CommentTile(comment: comment1),
    CommentTile(comment: comment2),
  ],
);
```

### Example 4: Custom Sizes

```dart
VineBottomSheet.show(
  context: context,
  title: 'Full Height Sheet',
  initialChildSize: 0.9,  // Start at 90% height
  minChildSize: 0.5,      // Minimum 50% height
  maxChildSize: 0.95,     // Maximum 95% height
  children: [
    // Your content
  ],
);
```

### Example 5: Manual Usage (Advanced)

```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => DraggableScrollableSheet(
    initialChildSize: 0.6,
    builder: (context, scrollController) => VineBottomSheet(
      title: 'Custom Sheet',
      scrollController: scrollController,
      trailing: IconButton(
        icon: Icon(Icons.settings),
        onPressed: () {
          // Custom action
        },
      ),
      bottomInput: TextField(
        decoration: InputDecoration(hintText: 'Type here...'),
      ),
      showHomeIndicator: true,
      children: [
        // Your widgets
      ],
    ),
  ),
);
```

## Styling

All components use the new design tokens from `VineTheme`:

- `VineTheme.surfaceBackground` - Sheet background color
- `VineTheme.onSurface` - Primary text color (95% white)
- `VineTheme.onSurfaceMuted` - Secondary text color (50% white)
- `VineTheme.tabIndicatorGreen` - Accent color for badges
- `VineTheme.outlineVariant` - Border color

### Typography

- **Header Title**: Bricolage Grotesque Bold, 24px
- **Badge Text**: Bricolage Grotesque ExtraBold, 14px
- Both use design system line heights and letter spacing

## Design Specifications

Based on Figma design:
- **Border radius**: 32px (top corners)
- **Drag handle**: 48px wide, 5px height, 100px border radius
- **Header padding**: 24px horizontal, 16px vertical
- **Badge**: 26px height, 12px border radius, 10px horizontal padding
- **Home indicator**: 144px wide, 5px height

## Migration from Old Comments Sheet

The old comments implementation can be migrated to use these components:

```dart
// Old
showModalBottomSheet(
  context: context,
  builder: (_) => CommentsScreen(video: video),
);

// New
VineBottomSheet.show(
  context: context,
  title: 'Comments',
  trailing: hasNewComments ? VineBottomSheetBadge(text: '$count new') : null,
  bottomInput: CommentInputWidget(),
  children: commentsList.map((c) => CommentTile(comment: c)).toList(),
);
```

## Testing Note

When writing tests for components that use `VineBottomSheet`, ensure you call `await loadAppFonts()` in `setUpAll`:

```dart
void main() {
  setUpAll(() async {
    await loadAppFonts();
  });

  testWidgets('my test', (tester) async {
    // Your test
  });
}
```

This loads the Google Fonts (Bricolage Grotesque) required by the components.
