# Golden Testing Guide for Divine

Status: A small image-comparison golden suite ships and runs in CI. Broader
component coverage for `divine_ui` is still tracked in **#6235**.

## Overview

Golden tests (screenshot tests) compare a rendered widget against a
committed reference image to catch visual regressions. Divine runs a
deliberately small suite — a handful of high-value, deterministic images —
through `scripts/golden.sh` and the `Goldens` CI job.

## Current State

`test/goldens/` holds two files:

- `widgets/design_system_gallery_golden_test.dart` — three image goldens
  (`divine_button_types`, `divine_button_sizes`, `divine_snackbars`)
  rendering `divine_ui` components on the dark app surface. They render from
  the *app's* test context because `DivineIcon` resolves `assets/icon/*.svg`
  by root path and the app bundles both those assets and the theme fonts;
  the package cannot render them in isolation yet (#6235).
- `widgets/notification_rows_golden_test.dart` — a layout/geometry test
  (`tester.getTopLeft`), **not** an image comparison. It lives here because
  the `Goldens` job owns the directory, not because it diffs pixels.

Mechanics:

- Golden setup (real fonts + `AlchemistConfig`) runs only under
  `-D DIVINE_GOLDEN_TESTS=true` (see `test/flutter_test_config.dart`); a
  plain `flutter test` skips it so the default suite stays fast.
  `scripts/golden.sh` sets that dart-define for you.
- CI runs `scripts/golden.sh verify` in a dedicated **`Goldens`** job.
  `scripts/ci/select_test_shard.sh` removes `test/goldens/` from every shard
  of the `Tests` job, so goldens never run inside the merged
  `very_good test --optimization` isolate and never run twice.
- **Reference images are generated on the Ubuntu runner**, not on a
  developer machine — see [Regenerating references](#regenerating-references).

What these goldens do *not* cover: light mode, and any component whose
render is time- or network-dependent. Adding a light-mode counterpart to the
button gallery is the cheapest next win.

## The font-determinism rule

**Every image golden must drain google_fonts before it asserts.** This is
the single thing that makes a Divine golden reproducible, and getting it
wrong produces a reference that looks plausible and is wrong.

`VineTheme` renders through `google_fonts`, which resolves the bundled
`assets/fonts/` files **asynchronously and per variant**. `loadAppFonts()`
in `flutter_test_config.dart` does not cover it, and neither does warming
the theme's own text styles — a widget can be the first to ask for a weight
the theme never uses. Left alone, the first test in an isolate captures Ahem
blocks and a later one captures real glyphs. Both "pass" when regenerated;
they simply disagree about what the component looks like.

```dart
await tester.pumpWidget(...);
// runAsync is required — this is real file I/O that the widget tester's
// fake async would otherwise never complete.
await tester.runAsync(GoogleFonts.pendingFonts);
await tester.pumpAndSettle();
```

Two related traps:

- **Put the surface inside the captured boundary.** A `Scaffold`
  `backgroundColor` outside the `RepaintBoundary` you match against leaves
  the golden transparent, which renders as white and makes dark-theme
  foregrounds look broken.
- **Pin `tester.view.physicalSize` and `devicePixelRatio`** (with
  `addTearDown` resets), so the image does not depend on whose machine ran
  it.

## Quick Start

### Running Golden Tests

```bash
# Update all golden images
./scripts/golden.sh update

# Verify golden tests pass
./scripts/golden.sh verify

# Update a specific test file
./scripts/golden.sh update test/goldens/widgets/notification_rows_golden_test.dart

# List all golden test files
./scripts/golden.sh list

# Show changes to golden images
./scripts/golden.sh diff

# Run golden tests in CI mode (fails on uncommitted golden drift)
./scripts/golden.sh ci

# Clean all golden images
./scripts/golden.sh clean
```

### Regenerating references

Reference PNGs are compared byte-for-byte, and Skia does not render
identically across operating systems — so a reference generated on macOS
will not match the Ubuntu runner that checks it. **Always regenerate on
CI:**

1. Push the branch.
2. Run the `Mobile CI` workflow via `workflow_dispatch` against it with
   **`update_goldens: true`** (`gh workflow run "Mobile CI" --ref <branch>
   -f update_goldens=true`).
3. Download the `goldens` artifact from that run.
4. Unpack it over `mobile/test/goldens/`, inspect the images, and commit.

`./scripts/golden.sh update` locally is still useful for *iterating* on a
new golden — just don't commit what it produces.

When the job fails, it uploads a `golden-failures` artifact containing the
master / test / diff images, which is how you tell a real regression from
rendering drift without an Ubuntu machine.

## Project Structure

```
test/
├── flutter_test_config.dart        # Golden font + Alchemist setup, opt-in
│                                    # via -D DIVINE_GOLDEN_TESTS=true
└── goldens/                        # owned by the `Goldens` CI job; excluded
    └── widgets/                    # from every shard of the `Tests` job
        ├── design_system_gallery_golden_test.dart
        ├── notification_rows_golden_test.dart   # layout test, not an
        │                                          # image-comparison golden
        └── goldens/                # committed references, generated on CI
            ├── divine_button_sizes.png
            ├── divine_button_types.png
            └── divine_snackbars.png
```

Failure diffs land in `test/goldens/**/failures/`, which is gitignored
(`test/**/failures/`). They are debug output from a red run — never commit
them.

## Writing Golden Tests

**Start from `design_system_gallery_golden_test.dart`** — it is the shipped
example and already handles the font drain, the captured surface, and the
pinned view config. The `golden_toolkit` / `alchemist` APIs below are
reference material; no test currently uses them for image diffing.

### Basic Widget Golden Test

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

void main() {
  group('MyWidget Golden Tests', () {
    setUpAll(() async {
      await loadAppFonts();
    });

    testGoldens('MyWidget renders correctly', (tester) async {
      await tester.pumpWidgetBuilder(
        const MyWidget(),
        wrapper: materialAppWrapper(),
      );

      await screenMatchesGolden(tester, 'my_widget_default');
    });
  });
}
```

### Using GoldenBuilder for Multiple States

```dart
testGoldens('Widget states', (tester) async {
  final builder = GoldenBuilder.grid(columns: 3)
    ..addScenario('Loading', MyWidget(state: WidgetState.loading))
    ..addScenario('Success', MyWidget(state: WidgetState.success))
    ..addScenario('Error', MyWidget(state: WidgetState.error));

  await tester.pumpWidgetBuilder(builder.build());
  await screenMatchesGolden(tester, 'widget_states');
});
```

## Best Practices

### When to Use Golden Tests
- **Critical UI components** that must maintain visual consistency
- **Complex layouts** that could break with changes
- **Theme-dependent widgets** to verify dark/light mode
- **Multi-state components** (loading, error, success states)

### When NOT to Use Golden Tests
- Components with **dynamic content** that changes frequently
- **Animated widgets** (use widget tests instead)
- Simple widgets with minimal visual complexity

### Tips for Stable Golden Tests
1. **Use fixed timestamps** - Don't use `DateTime.now()` directly; use
   `package:clock`'s `withClock` (see `notification_rows_golden_test.dart`
   for the current pattern)
2. **Mock network images** - Use local assets or placeholders
3. **Control text content** - Use consistent test data
4. **Test multiple states** - Cover all visual states in one test
5. **Name tests clearly** - Use descriptive golden file names
6. **Drain async font loading** - mandatory, and the most common way to
   produce a wrong-but-passing reference. See
   [The font-determinism rule](#the-font-determinism-rule).

## Troubleshooting

### Common Issues

**Tests fail on CI but pass locally**
- Almost always means the reference was generated locally. Skia renders
  differently per OS; regenerate on the runner
  ([Regenerating references](#regenerating-references)).

**Text renders as solid blocks instead of glyphs**
- The google_fonts drain is missing or ran too early. See
  [The font-determinism rule](#the-font-determinism-rule). Note that
  `loadAppFonts()` alone does **not** fix this, and it only runs under
  `-D DIVINE_GOLDEN_TESTS=true` at all.

**A golden is transparent / the background is white**
- The surface is outside the `RepaintBoundary` being matched. Move it in.

**Image loading errors**
- Mock image providers or use test assets
- Avoid network-dependent images in tests

## Performance Considerations

- Golden tests are slower than unit/widget tests
- Run targeted golden tests during development
- Selection is by **directory**, not by tag: everything under
  `test/goldens/` runs in the `Goldens` job and nowhere else. The `golden`
  tag in `dart_test.yaml` is not used for this and applies to no file.

## Resources

- [golden_toolkit documentation](https://pub.dev/packages/golden_toolkit)
- [alchemist documentation](https://pub.dev/packages/alchemist)
- [Flutter golden testing guide](https://flutter.dev/docs/cookbook/testing/widget/introduction#golden-tests)

## divine_ui package goldens (deferred — #6235)

Goldens that live *inside* the `divine_ui` package are still **not in
place**. Two package-isolation limits block them, neither of which is the
font race solved above: `DivineIcon` loads `assets/icon/*.svg` by root path
so icons render empty in package tests, and Material `Slider`'s
`OverlayPortal` asserts under alchemist's grid layout. Both are tracked in
**#6235**.

The gallery goldens described in [Current State](#current-state) are the
interim answer — they render the same components from the app, where the
assets and fonts exist. Beyond that, `divine_ui` relies on widget-behaviour
and `meetsGuideline` accessibility tests.
