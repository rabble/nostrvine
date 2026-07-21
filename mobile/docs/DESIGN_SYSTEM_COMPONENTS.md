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

## Accessibility & Visual Contract

`divine_ui` is the canonical accessibility + visual contract for the core
reusable controls. App-layer reviewers can point at the package tests instead
of re-checking these guarantees per screen.

### Guaranteed accessibility (enforced by `meetsGuideline` / semantics tests)

| Component | Guarantee |
|-----------|-----------|
| `DivineButton` | `base` (48px) and `small` (40px visible / 48dp tap target) meet the 48dp Android / 44pt iOS tap-target minimum — `small` keeps pressed ink clipped to the 40px chip while its pre-existing 4px outer halo is tappable. `tiny` (32px) deliberately keeps a 32px tap target (it sits flush next to 32px avatars / type icons; expanding it would bleed into that neighbor's hit area) — tracked as a known gap in #6235 pending design input. Optional `semanticLabel` for icon-only buttons (a disabled labelled button announces `enabled: false`). Error-button label/icon contrast against the red background is tracked as a known gap in #6235 pending design sign-off on the tone. |
| `DivineIconButton` | Tap target ≥ 48dp (small pill centred in a 48px InkWell). Pass `semanticLabel` (or `tooltip`) for an accessible name. |
| `DivineRowCheckbox` | Exposes a checkbox semantics node with checked / mixed / enabled state. A `disabled` checkbox is non-interactive (no tap, no `onChanged`). |
| `DivineSlider` | Optional `semanticLabel` describing what it controls. Touch-target height is unchanged (32px) — growing it shifts adjacent widgets in real screens (storage settings, video editor sheets); tracked as a known gap in #6235 pending Figma-fit confirmation. |
| `DivineAuthTextField` | Password toggle and the editable field both meet the 48dp / 44pt tap-target minimum. The editable field fills the 76px control, while animated content padding places the input text row at 26px when centered and 36px below a floating label. |

**Icon-only interactive controls need an accessible name.** Enforcing this at
every call site (and labelling the app's unlabeled `DivineIconButton`
usages) is tracked as a fast-follow; the components already accept the label.

### Visual (golden) coverage

Component gallery goldens for `divine_ui` are tracked as a fast-follow
(**#6235**): alchemist obscured-text goldens are non-deterministic under the
package's `very_good test --optimization` merged isolate (google_fonts loads
asynchronously, so the block-text metrics vary), and would need a CI-side
generation workflow. Behaviour and accessibility are already covered by the
widget + `meetsGuideline` tests above.
