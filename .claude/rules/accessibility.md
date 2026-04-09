# Accessibility

Divine is used by a diverse audience. Accessible UI is not optional — it ensures screen reader users, keyboard navigators, and users with visual or motor impairments can use every feature.

---

## Semantic Labels

### Interactive Elements Must Have Labels
Every interactive widget (button, tap target, slider) needs a semantic label that describes its **action**, not its appearance:

```dart
// Good — describes the action
IconButton(
  icon: const DivineIcon(icon: .share),
  tooltip: 'Share video',
  onPressed: _onShare,
)

// Bad — describes the icon
IconButton(
  icon: const DivineIcon(icon: .share),
  tooltip: 'Arrow icon',
  onPressed: _onShare,
)

// Bad — no label at all
IconButton(
  icon: const DivineIcon(icon: .share),
  onPressed: _onShare,
)
```

### Use `Semantics` for Custom Widgets
When a widget has no built-in semantic support, wrap it:

```dart
Semantics(
  label: 'Play video',
  button: true,
  child: GestureDetector(
    onTap: _onPlay,
    child: const PlayIcon(),
  ),
)
```

### Images and Thumbnails
Meaningful images need `semanticLabel`. Decorative images must be excluded:

```dart
// Meaningful — user content
VineCachedImage(
  imageUrl: thumbnailUrl,
  semanticLabel: 'Video thumbnail for $title',
)

// Decorative — background, gradients, dividers
ExcludeSemantics(
  child: Image.asset('assets/gradient_bg.png'),
)
```

### Semantic Identifiers for Testing
Use `Semantics(identifier: ...)` for integration test anchors. Use constants, not magic strings:

```dart
// Good — constant identifier
Semantics(
  identifier: SemanticIds.videoThumbnail(index),
  child: thumbnailWidget,
)

// Bad — inline magic string
Semantics(
  identifier: 'video_thumbnail_$index',
  child: thumbnailWidget,
)
```

---

## Dynamic Announcements

When the UI changes asynchronously (upload complete, error, navigation), announce the change to screen readers using `SemanticsService.announce`:

```dart
import 'package:flutter/semantics.dart';

// After async operation completes
SemanticsService.announce(
  'Video uploaded successfully',
  TextDirection.ltr,
);

// After error
SemanticsService.announce(
  'Upload failed. Please try again.',
  TextDirection.ltr,
);
```

**When to announce:**
- After async operations that change visible content (uploads, deletes, fetches)
- When a snackbar or toast appears
- After navigation that doesn't move focus automatically
- When a list updates from a background event (e.g., new relay data)

**When NOT to announce:**
- Normal page transitions (Flutter handles these)
- Every BLoC state change (only announce user-relevant outcomes)

---

## Traversal Order

By default, Flutter reads the semantics tree top-to-bottom, left-to-right. Override only when the visual layout doesn't match the logical reading order:

```dart
// Custom sort order for a non-linear layout
Semantics(
  sortKey: const OrdinalSortKey(0), // Read first
  child: const HeaderWidget(),
)

Semantics(
  sortKey: const OrdinalSortKey(1), // Read second
  child: const ActionBar(),
)
```

Use sparingly — most layouts don't need custom sort keys.

---

## Merge and Exclude

### MergeSemantics
Combine related widgets into one screen reader node when they form a single logical unit:

```dart
// Good — "Username, 5 followers" read as one item
MergeSemantics(
  child: Column(
    children: [
      Text(username),
      Text('$followerCount followers'),
    ],
  ),
)
```

### ExcludeSemantics
Remove decorative or redundant elements from the semantics tree:

```dart
// Decorative background
ExcludeSemantics(
  child: AnimatedGradient(),
)

// Redundant — parent already has the label
ExcludeSemantics(
  child: Icon(Icons.check),
)
```

---

## Touch Targets

Minimum touch target size is **48x48 dp**. Use `ConstrainedBox` or Material's built-in sizing:

```dart
// Good — guaranteed minimum size
ConstrainedBox(
  constraints: const BoxConstraints(
    minWidth: 48,
    minHeight: 48,
  ),
  child: IconButton(
    icon: const DivineIcon(icon: .close),
    onPressed: _onClose,
  ),
)
```

---

## Font Size Responsiveness

Never use fixed heights on text-bearing widgets. Use `minHeight` so containers grow with system font scaling:

```dart
// Good — grows with large font
ConstrainedBox(
  constraints: const BoxConstraints(minHeight: 48),
  child: TextField(...),
)

// Bad — clips at large font sizes
SizedBox(
  height: 48,
  child: TextField(...),
)
```

### Fixed Overlay Badges
Small badges overlaid on images (e.g. video count, duration) should **not** scale with system text size — scaling breaks the fixed layout. Wrap badge content with `MediaQuery.withNoTextScaling`:

```dart
// Good — badge stays fixed size regardless of system text scale
MediaQuery.withNoTextScaling(
  child: DecoratedBox(
    decoration: BoxDecoration(...),
    child: Text('3', style: VineTheme.labelSmallFont()),
  ),
)

// Bad — badge grows with system font size, overflows container
DecoratedBox(
  decoration: BoxDecoration(...),
  child: Text('3', style: VineTheme.labelSmallFont()),
)
```

---

## Motion and Animations

Respect the user's reduced-motion preference:

```dart
final reduceMotion = MediaQuery.of(context).disableAnimations;

// Skip or shorten animations
AnimatedContainer(
  duration: reduceMotion
      ? Duration.zero
      : const Duration(milliseconds: 300),
  // ...
)
```

For hero animations, video auto-play, and parallax effects — check `disableAnimations` and provide a static alternative.

---

## Color Contrast

- **Normal text (< 18pt):** Minimum **4.5:1** contrast ratio against background
- **Large text (≥ 18pt or 14pt bold):** Minimum **3:1** contrast ratio
- **Interactive elements:** Minimum **3:1** contrast ratio against adjacent colors

Since Divine is dark-mode only, verify contrast against `VineTheme` dark backgrounds. Don't rely on Material defaults — custom overlays and gradients on video content need manual checking.

---

## Testing Accessibility

### Widget Tests
Assert that semantic labels exist on interactive elements:

```dart
testWidgets('share button has semantic label', (tester) async {
  await tester.pumpWidget(buildTestWidget());

  final semantics = tester.getSemantics(
    find.byType(ShareButton),
  );
  expect(semantics.label, equals('Share video'));
});
```

### Integration Tests
Use `find.bySemanticsIdentifier()` for stable test anchors instead of fragile widget finders:

```dart
// Good — survives refactors
await tester.tap(find.bySemanticsIdentifier('share_button'));

// Fragile — breaks when widget tree changes
await tester.tap(find.byType(ShareButton));
```

### Manual Testing Checklist
Before shipping UI changes:
1. Enable TalkBack (Android) or VoiceOver (iOS) and navigate the changed screen
2. Verify all interactive elements are reachable and announced
3. Increase system font size to largest and verify no clipping
4. Verify focus order follows logical reading order

---

## Code Review Checklist (Agent-Enforceable)

When writing or reviewing code, flag these accessibility issues.

### Must Fix
- **Interactive element (button, tap target, slider) without any label or tooltip** — completely invisible to screen readers
- **`GestureDetector` or `InkWell` without `Semantics` wrapper** — tap target with no screen reader context

### Should Fix
- **Meaningful image or thumbnail without `semanticLabel`** — screen reader announces nothing useful
- **Decorative image not wrapped in `ExcludeSemantics`** — clutters the semantics tree
- **Fixed `SizedBox(height:)` around text-bearing widget** → suggest `ConstrainedBox(minHeight:)` for font scaling
- **Missing `SemanticsService.announce()` after async state change** that updates visible content (upload, delete, error)
- **Semantic identifier as inline magic string** → suggest constant from `SemanticIds`

### Nitpick
- **Related widgets that could be grouped with `MergeSemantics`** — cleaner screen reader experience
- **Custom layout without `OrdinalSortKey`** where reading order doesn't match visual order
- **Animation without `disableAnimations` check** — reduced-motion preference ignored
