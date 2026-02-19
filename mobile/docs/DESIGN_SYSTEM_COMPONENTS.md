# Divine UI — Design System Components

Package: `packages/divine_ui`

## Theme

### VineTheme
Complete dark-mode design system providing:
- **Colors**: 30+ named color constants (brand greens, surfaces, text, accents, navigation, utility)
- **Typography**: Google Fonts — Bricolage Grotesque (display, headline, title) and Inter (body, label)
- **ThemeData**: Pre-configured `ThemeData` for the app

## Components

### Buttons

| Component | Description |
|-----------|-------------|
| `DivineButton` | Primary button component with multiple variants (primary, secondary, tertiary, ghost, ghostSecondary, link, error). Supports leading/trailing icons, loading state, and expanded width. |
| `DivineIconButton` | Icon-only button with primary/secondary/tertiary variants and small/base sizes. |
| `DivineTextLink` | Inline text link for use within text flows. Provides both widget and `TextSpan` versions. |

**DivineButton Types:**
- `primary` — Green background, dark text (main actions)
- `secondary` — Dark background, green border, green text
- `tertiary` — White background, dark green text
- `ghost` — Semi-transparent dark background (65% black), white text
- `ghostSecondary` — Lighter scrim (15% black), white text
- `link` — No background, underlined text
- `error` — Red background, light text (destructive actions)

### Icons

| Component | Description |
|-----------|-------------|
| `DivineIcon` | SVG icon component using `DivineIconName` enum. Supports custom size and color. |
| `DivineIconName` | Enum with 170+ icon entries from Phosphor Icons (bold weight). Includes fill (`_fill`) and duotone (`_duo`) variants. |

### Checkboxes

| Component | Description |
|-----------|-------------|
| `DivineCheckbox` | Standalone checkbox with selected/unselected/indeterminate states. |
| `DivineRowCheckbox` | Checkbox with label, suitable for forms and settings. |

### Bottom Sheet

| Component | Description |
|-----------|-------------|
| `VineBottomSheet` | Base bottom sheet with drag handle and themed styling. Supports scrollable and fixed modes. |
| `VineBottomSheetActionMenu` | Action menu variant (list of tappable actions) |
| `VineBottomSheetDragHandle` | Reusable drag handle widget |
| `VineBottomSheetHeader` | Header with title/subtitle for bottom sheets |
| `VineBottomSheetSelectionMenu` | Selection menu variant (pick from options) |
| `VineBottomSheetTileMenu` | Tile-based menu variant |

### Text Field

| Component | Description |
|-----------|-------------|
| `DivineAuthTextField` | Text input field for auth screens (sign-in/sign-up) |
| `DivineTextField` | **Deprecated** — delegates to `DivineAuthTextField` |

### Feedback

| Component | Description |
|-----------|-------------|
| `DivineSnackbarContainer` | Themed snackbar container |

### Loading

| Component | Description |
|-----------|-------------|
| `PartialCircleSpinner` | Animated partial-circle loading indicator |

## Usage Examples

### DivineButton
```dart
// Primary button with icon
DivineButton(
  label: 'Continue with email',
  leadingIcon: DivineIconName.envelope,
  expanded: true,
  onPressed: () => doSomething(),
)

// Secondary button
DivineButton(
  label: 'Enter Nostr key',
  type: DivineButtonType.secondary,
  leadingIcon: DivineIconName.key,
  onPressed: () => importKey(),
)

// Button with loading state
DivineButton(
  label: 'Submit',
  isLoading: isSubmitting,
  onPressed: isSubmitting ? null : handleSubmit,
)
```

### DivineIconButton
```dart
// Back button
DivineIconButton(
  icon: DivineIconName.caretLeft,
  type: DivineIconButtonType.secondary,
  size: DivineIconButtonSize.small,
  onPressed: () => context.pop(),
)
```

### DivineTextLink
```dart
// Inline text link
Text.rich(
  TextSpan(
    children: [
      TextSpan(text: 'Have an account? '),
      DivineTextLink.span(
        text: 'Sign in',
        onTap: () => navigateToLogin(),
      ),
    ],
  ),
)
```

### DivineCheckbox
```dart
DivineRowCheckbox(
  state: isChecked
      ? DivineCheckboxState.selected
      : DivineCheckboxState.unselected,
  onChanged: (value) => setState(() => isChecked = value),
  label: Text('I agree to the terms'),
)
```
