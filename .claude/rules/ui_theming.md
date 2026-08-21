# UI & Theming

Flutter uses Material Design with Material 3 enabled by default (since Flutter 3.16).

---

## ThemeData

### Use ThemeData, Not Conditional Logic
Widgets should inherit styles from the theme, not use conditional brightness checks:

**Bad:**
```dart
class BadWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      // Conditional logic - hard to maintain!
      color: Theme.of(context).brightness == Brightness.light
          ? Colors.white
          : Colors.black,
      child: Text(
        'Bad',
        style: TextStyle(
          fontSize: 16,
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.black
              : Colors.white,
        ),
      ),
    );
  }
}
```

**Good:**
```dart
class GoodWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return ColoredBox(
      color: colorScheme.surface,
      child: Text(
        'Good',
        style: textTheme.bodyLarge,
      ),
    );
  }
}
```

Design updates now only require changing `ThemeData`, not every widget.

---

## Typography

### Custom Text Styles
Centralize text styles:

```dart
abstract class AppTextStyle {
  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    height: 1.3,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w400,
  );
}
```

### TextTheme Integration
Connect custom styles to `ThemeData`:

```dart
ThemeData(
  textTheme: TextTheme(
    titleLarge: AppTextStyle.titleLarge,
    bodyMedium: AppTextStyle.bodyMedium,
  ),
);
```

### Usage
```dart
Text(
  'Title',
  style: Theme.of(context).textTheme.titleLarge,
);
```

---

## Colors

### Custom Colors Class
```dart
abstract class AppColors {
  static const primaryColor = Color(0xFF4F46E5);
  static const secondaryColor = Color(0xFF9C27B0);
  static const errorColor = Color(0xFFDC2626);
}
```

### ColorScheme Integration
```dart
ThemeData(
  colorScheme: ColorScheme(
    primary: AppColors.primaryColor,
    secondary: AppColors.secondaryColor,
    error: AppColors.errorColor,
    // ... other required colors
  ),
);
```

### Usage
```dart
Container(
  color: Theme.of(context).colorScheme.primary,
);
```

---

## Spacing

### Centralized Spacing System
```dart
abstract class AppSpacing {
  static const double spaceUnit = 16;
  static const double xs = 0.375 * spaceUnit;  // 6
  static const double sm = 0.5 * spaceUnit;    // 8
  static const double md = 0.75 * spaceUnit;   // 12
  static const double lg = spaceUnit;          // 16
  static const double xl = 1.5 * spaceUnit;    // 24
}
```

### Usage
```dart
Padding(
  padding: const EdgeInsets.all(AppSpacing.md),
  child: Column(
    children: [
      const Text('Title'),
      const SizedBox(height: AppSpacing.sm),
      const Text('Subtitle'),
    ],
  ),
);
```

---

## Component Theming

Customize Material components via `ThemeData` rather than inline styles:

```dart
ThemeData(
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(72, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(),
    contentPadding: EdgeInsets.all(12),
  ),
);
```

---

## Appearance modes: which colors adapt

Divine ships **two** appearances — `VineTheme.theme` (dark, the default) and
`VineTheme.lightTheme`. Users choose System / Light / Dark in
Settings → General → Appearance. There is no feature flag.

Two color systems coexist, and picking the wrong one is the most common
light-mode bug:

| Use | For | Example |
|---|---|---|
| `context.vineColors.<token>` | Anything drawn on an **app surface** — page backgrounds, cards, sheets, list rows, body text, dividers, form fields | `context.vineColors.primaryText` |
| `VineTheme.<const>` | **Brand** colors and **fixed media chrome** — anything whose ground is a video frame, a scrim, a gradient, or a saturated brand fill | `VineTheme.vineGreen`, `VineTheme.scrim50` |

The test is **what is underneath**, not what the widget is. The same white
text is correct over a video thumbnail and invisible on a warm off-white page.

Fixed-by-design surfaces: fullscreen playback chrome, the camera and video
editor canvas, scrims and gradients, ink on a filled brand button, and the
database-failure screen (it runs before the appearance preference is
readable).

### Three traps

1. **Equal dark values, different light values.** `iconButtonBackground`,
   `surfaceContainer` and `skeletonBase` are all `#FF032017` in dark but map
   to three different light colors. Choose the token by what the surface
   *means*, never by matching the hex.
2. **Name collisions that invert.** `VineTheme.primaryContainer` (pale mint)
   is not `vineColors.primaryContainer` (dark green);
   `VineTheme.onErrorContainer` (near-white) is not
   `vineColors.onErrorContainer` (red). Never auto-map by name.
3. **Alpha carriers and shadows are not colors.** A `whiteText` inside a
   `ShaderMask` with `BlendMode.dstIn` is an alpha channel, and
   `backgroundColor.withValues(alpha: 0.2)` used as a `BoxShadow` would
   become a *white* shadow in light mode. Leave both static.

### Verify dark did not change

Any migration from a static constant to a token must leave dark mode
pixel-identical. Prove it mechanically rather than by reading the diff:

```bash
cd mobile && dart run scripts/check_dark_value_parity.dart --base origin/main
```

It pairs each removed reference with its replacement per hunk and compares
**dark** values. It cannot catch a wrong pick among tokens that share a dark
value (trap 1) — that part still needs eyes, and a light-mode contrast check.

**Shallow clones need an explicit base.** Isolating your branch's own changes
needs a merge base, and a `--depth` clone or worktree may not have one against
`origin/main`. The script refuses rather than guessing — an earlier version
silently fell back to a two-dot diff, which reads every commit `main` has and
your branch lacks as a *removal* and reports unrelated work as your dark
mismatches. If it exits with `No merge base`, either `git fetch --unshallow`,
or pass the commit your branch started from:

```bash
dart run scripts/check_dark_value_parity.dart --base <branch-point-sha>
```

### Adding a token

If the semantically right token would change dark, do **not** accept the
shift — add a token whose dark value is the constant you are replacing.
`onIconButton` exists for exactly this: `vineGreenLight` is 15:1 on the dark
container and 1.01:1 on the light one, so the token keeps the pale mint in
dark and substitutes a darkened green in light. Every new token needs an
entry in `VineThemeColors`' constructor, field, `copyWith`, `lerp`, `==`,
`hashCode`, `darkColors`, and `lightColors` — plus the token maps in
`packages/divine_ui/test/src/divine_ui_test.dart`, which fail the build if
you miss one.

---

## Icons

### Use DivineIcon
Use `DivineIcon` from `divine_ui` instead of raw `SvgPicture.asset` or Material `Icon` widgets:

**Good:**
```dart
const DivineIcon(icon: .search, color: VineTheme.lightText)
```

**Bad:**
```dart
SvgPicture.asset(DivineIconName.search.assetPath, ...)
Icon(Icons.search, color: VineTheme.lightText)
```

---

## Typography

### Use VineTheme Font Methods
Use `VineTheme` font methods (e.g. `titleMediumFont()`, `bodyMediumFont()`) instead of raw `TextStyle` constructors. VineTheme methods apply the correct font family, weight, line height, and letter spacing from the design system.

**Good:**
```dart
Text('Display name', style: VineTheme.titleMediumFont())
Text('Secondary info', style: VineTheme.bodyMediumFont(color: VineTheme.secondaryText))
```

**Bad:**
```dart
Text('Display name', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))
Text('Secondary info', style: const TextStyle(color: VineTheme.secondaryText, fontSize: 14))
```

---

## Text Fields

Every `TextField` / `TextFormField` / `DivineAuthTextField` sets its input
traits explicitly. Flutter's defaults — `TextInputType.text`,
`TextCapitalization.none`, and a blanket `TextInputAction.done` — are rarely
what the field actually wants, and the damage only shows up on a real device: a
keyboard with no `@` key, an auto-capitalized email address, a "done" key that
dead-ends in the middle of a form. No widget test catches any of it, so this
has to be part of writing the field rather than a later polish pass.

### `textInputAction`: chain the single-line fields, skip the multiline ones

**Single-line fields** form a chain: each one except the last uses
`TextInputAction.next`, and the last one uses `TextInputAction.done`. A
single-field form uses `done` — or `search` / `send` when that is the real
action.

`next` is a promise that focus moves, so wire it up: give each field a
`FocusNode` and move focus in `onSubmitted` / `onFieldSubmitted`, and let the
last field's `done` submit. A `next` key that goes nowhere is worse than no
configuration at all.

**A multiline field is not part of that chain.** Its return key has to insert
a line break, so it keeps `TextInputAction.newline` — which `EditableText`
already picks by itself once `keyboardType` is `.multiline`. Never give it
`next`, and never give it `done`: both replace the return key and cost the user
the ability to type a second line. So in a form that contains one:

- The single-line field *above* it still uses `next` — focus lands in the
  multiline field and stops there. That is the intended end of the chain.
- Fields *after* it start a fresh chain.
- If the multiline field is last, **no field carries `done`**, and the form is
  submitted by its button. That is correct — do not force `done` onto the
  multiline field to complete the pattern.

Name (`next`) → bio (`newline`) → website (`done`) is the shape to aim for.

**When adding a field to an existing screen, re-check the field above it** —
a form that was correct with one field is wrong the moment it has two.

**Good — two fields, chained:**
```dart
DivineAuthTextField(
  controller: _emailController,
  focusNode: _emailFocus,
  keyboardType: .emailAddress,
  textCapitalization: .none,
  textInputAction: .next,
  autocorrect: false,
  autofillHints: const [AutofillHints.email],
  onSubmitted: (_) => _passwordFocus.requestFocus(),
),
DivineAuthTextField(
  controller: _passwordController,
  focusNode: _passwordFocus,
  obscureText: true,
  keyboardType: .text,
  textCapitalization: .none,
  textInputAction: .done,
  autocorrect: false,
  autofillHints: const [AutofillHints.password],
  onSubmitted: (_) => _submit(),
),
```

**Bad — defaults everywhere:**
```dart
// Capitalizes and autocorrects the email, and the keyboard offers
// no way to reach the password field or submit the form.
DivineAuthTextField(controller: _emailController),
DivineAuthTextField(controller: _passwordController, obscureText: true),
```

### `keyboardType` and `textCapitalization`

Pick both from what the field holds:

| Field | `keyboardType` | `textCapitalization` |
|---|---|---|
| Email | `.emailAddress` | `.none` |
| Username, handle, npub, hex key, NIP-05 | `.text` | `.none` |
| URL, relay address | `.url` | `.none` |
| Password, invite code | `.text` (+ `obscureText`) | `.none` |
| One-time code, amount, sat count | `.number` | `.none` |
| Display name, list title, badge name | `.text` | `.words` |
| Bio, comment, message, report reason | `.multiline` | `.sentences` |

The `.multiline` row is also the one that keeps `textInputAction: newline` — see
above.

Turn `autocorrect` off for identifiers — email, username, npub, URL, code.
Autocorrect on a hex key or a relay URL silently corrupts what the user typed.

Add `autofillHints` wherever the platform can help (email, password, username,
one-time code). It is one line and removes a whole typing step.

---

## Widget Structure

### Page/View Pattern
Separate routing concerns from UI implementation:

```dart
// Page - handles dependencies and routing
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final authRepository = context.read<AuthenticationRepository>();
        return LoginBloc(authenticationRepository: authRepository);
      },
      child: const LoginView(),
    );
  }
}

// View - UI implementation (testable in isolation)
class LoginView extends StatelessWidget {
  @visibleForTesting
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    // UI implementation
  }
}
```

**Why `@visibleForTesting`?** Prevents accidental use of View without Page's dependencies.

### Testing the View
```dart
void main() {
  group('LoginView', () {
    late LoginBloc loginBloc;

    setUp(() {
      loginBloc = _MockLoginBloc();
    });

    testWidgets('renders correctly', (tester) async {
      await tester.pumpWidget(
        BlocProvider<LoginBloc>.value(
          value: loginBloc,
          child: const LoginView(),
        ),
      );

      expect(find.byType(LoginView), findsOneWidget);
    });
  });
}
```

---

## Widget Composition

### Widgets Over Methods
Always create separate widget classes instead of methods returning widgets.

**Good:**
```dart
class MyWidget extends StatelessWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MyText('Hello World!');
  }
}

class _MyText extends StatelessWidget {
  const _MyText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text);
  }
}
```

**Bad:**
```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _getText('Hello World!');
  }

  // Don't do this!
  Text _getText(String text) {
    return Text(text);
  }
}
```

**Benefits:**
- **Testability:** Test widgets in isolation
- **Maintainability:** Smaller widgets, own BuildContext
- **Reusability:** Easy to compose larger widgets
- **Performance:** Only rebuilt widget updates, not entire parent

---

## Layout Best Practices

### Row/Column Sizing

| Property | Purpose |
|----------|---------|
| `MainAxisSize.min` | Shrink to fit children |
| `MainAxisSize.max` | Expand to fill available space |
| `mainAxisAlignment` | Position children along main axis |
| `crossAxisAlignment` | Position children along cross axis |

### Flexible vs Expanded

| Widget | Behavior |
|--------|----------|
| `Flexible` | Child can be smaller than available space |
| `Expanded` | Child must fill available space |

```dart
Row(
  children: [
    Expanded(child: TextField()),  // Fill remaining space
    const SizedBox(width: 8),
    ElevatedButton(onPressed: () {}, child: Text('Submit')),
  ],
);
```

### Handling Overflow
Use `SingleChildScrollView` or `ListView.builder`:

```dart
// For dynamic lists
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemWidget(items[index]),
);

// For fixed content that might overflow
SingleChildScrollView(
  child: Column(
    children: [...],
  ),
);
```

---

## NestedScrollView edge-to-edge and pinned headers

When building a screen with an edge-to-edge layout (banner extends
behind the status bar, no outer `SafeArea`) plus a
`NestedScrollView` with a pinned `SliverPersistentHeader`, the pinned
header will sit **under the status bar** by default — icons/labels get
clipped by the notch / Dynamic Island.

**Fix:** the delegate must take a `topInset` that contributes to both
`minExtent` and `maxExtent`, and render a matching `Padding(top:
topInset)` above its content:

```dart
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar, {required this.topInset});

  final TabBar _tabBar;
  final double topInset;

  @override
  double get minExtent => _tabBar.preferredSize.height + topInset;

  @override
  double get maxExtent => _tabBar.preferredSize.height + topInset;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool _) =>
      DecoratedBox(
        decoration: const BoxDecoration(color: VineTheme.surfaceBackground),
        child: Padding(
          padding: EdgeInsets.only(top: topInset),
          child: _tabBar,
        ),
      );

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) =>
      topInset != oldDelegate.topInset || _tabBar != oldDelegate._tabBar;
}
```

### Prefer a dynamic topInset over a static one

Setting `topInset = safeAreaTop` unconditionally leaves a permanent
safe-area-sized gap above the pinned header when the user is at scroll
offset 0 — visually loose. Drive the inset from scroll position so it
only grows when the header is actually about to pin under the status
bar:

```dart
// In the enclosing State (scroll listener):
void _onScroll() {
  final safeAreaTop = MediaQuery.paddingOf(context).top;
  final triggerScroll = _headerHeight + _spacerHeight - safeAreaTop;
  final newInset =
      (scrollOffset - triggerScroll).clamp(0.0, safeAreaTop);
  if (newInset != _tabBarTopInset) {
    setState(() => _tabBarTopInset = newInset);
  }
}
```

### Pitfall: pinned-header height inflates outer maxScrollExtent

`NestedScrollView` includes the pinned header's height in the outer
`maxScrollExtent`. After the header and any scrolling action-buttons
row are fully scrolled off, the outer can still scroll past that point
by `pinnedHeaderHeight` before the inner scroll takes over — producing
a visible "dead zone" at the top when scrolling back up (action
buttons or other overlay widgets remain offscreen for that extra
distance before reappearing). Options:

1. Accept the gap and document it as a known issue.
2. Use `SliverOverlapAbsorber`/`SliverOverlapInjector` (standard
   Flutter pattern — doesn't fully solve, adjusts where the transition
   happens).
3. Restructure to a non-`NestedScrollView` architecture
   (e.g. a single `CustomScrollView` whose pinned header is the only
   scroll coordinator).

### Pitfall: body subtree is rendered under pinned headers

`NestedScrollView`'s body is laid out from y=0 of its own viewport, not
from the pinned header's bottom edge. Decorations on the body's top
edge (top borders, top-rounded `ClipRRect`, foreground `BorderSide`)
are painted **behind** the pinned header and invisible. Put such
decorations **inside the pinned header's delegate**, not on the body,
so they live in the always-visible sliver region.

---

## Accessibility

See `accessibility.md` for the full accessibility guide (semantic labels, announcements, traversal order, contrast, font responsiveness, motion, and testing).
