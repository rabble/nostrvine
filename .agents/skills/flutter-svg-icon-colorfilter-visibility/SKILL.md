---
name: flutter-svg-icon-colorfilter-visibility
description: |
  Fix invisible or poorly visible SVG icons in Flutter when using flutter_svg package.
  Use when: (1) SVG icons appear invisible despite correct colors in the SVG file,
  (2) Using Opacity widget to change icon visibility/state but icons don't render properly,
  (3) Tab bar or navigation icons disappear or have wrong colors,
  (4) Icons with fill="white" don't show on dark backgrounds.
  The fix is to use ColorFilter.mode() instead of Opacity widget for SVG icon state styling.
author: Claude Code
version: 1.0.0
date: 2026-01-30
---

# Flutter SVG Icon ColorFilter vs Opacity

## Problem

SVG icons rendered with `flutter_svg` appear invisible or have incorrect visibility
when using the `Opacity` widget to indicate selected/unselected states. This commonly
occurs in bottom navigation bars, tab bars, or any UI with icon state changes.

## Context / Trigger Conditions

- Using `flutter_svg` package with `SvgPicture.asset()`
- SVG files have explicit fill colors (e.g., `fill="white"`)
- Icons wrapped in `Opacity` widget for selected/unselected states
- Icons appear invisible or barely visible despite correct SVG content
- Background color should provide sufficient contrast (e.g., white on dark green)

## Solution

Replace `Opacity` widget with `ColorFilter` on the SvgPicture:

**Before (problematic):**
```dart
Widget _buildTabButton(String iconPath, bool isSelected) {
  return Opacity(
    opacity: isSelected ? 1.0 : 0.5,
    child: SvgPicture.asset(iconPath, width: 32, height: 32),
  );
}
```

**After (correct):**
```dart
Widget _buildTabButton(String iconPath, bool isSelected) {
  final iconColor = isSelected ? Colors.white : Colors.grey;

  return SvgPicture.asset(
    iconPath,
    width: 32,
    height: 32,
    colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
  );
}
```

### Key Points

1. **ColorFilter.mode with BlendMode.srcIn** replaces the SVG's fill color with the
   specified color wherever the SVG has opaque pixels

2. **Don't rely on Opacity for color changes** - Opacity affects transparency but
   doesn't change the actual rendered color, which can cause visibility issues

3. **SVG fill attribute is overridden** - Even if your SVG has `fill="white"`, the
   ColorFilter will replace it with your specified color

## Verification

After applying the fix:
1. Selected icons should render in the selected color (e.g., white)
2. Unselected icons should render in the unselected color (e.g., grey)
3. Both states should be clearly visible against the background

## Example

Bottom navigation with proper icon coloring:

```dart
Widget _buildNavIcon(String assetPath, int tabIndex, int currentIndex) {
  final isSelected = tabIndex == currentIndex;
  final iconColor = isSelected ? Colors.white : const Color(0xFF8A9A94);

  return GestureDetector(
    onTap: () => _onTabTap(tabIndex),
    child: Container(
      width: 48,
      height: 48,
      padding: const EdgeInsets.all(8),
      child: SvgPicture.asset(
        assetPath,
        width: 32,
        height: 32,
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
      ),
    ),
  );
}
```

## Notes

- This applies to `flutter_svg` package specifically; other SVG rendering solutions
  may behave differently
- If you need both color change AND opacity, apply ColorFilter first, then wrap in
  Opacity if truly needed
- For icons that should maintain their original multi-color appearance, don't use
  ColorFilter - but then Opacity alone may work fine
- BlendMode.srcIn specifically means "show source color where destination (SVG) is opaque"

## References

- [flutter_svg package documentation](https://pub.dev/packages/flutter_svg)
- [Flutter ColorFilter class](https://api.flutter.dev/flutter/dart-ui/ColorFilter-class.html)
- [BlendMode.srcIn documentation](https://api.flutter.dev/flutter/dart-ui/BlendMode.html)
