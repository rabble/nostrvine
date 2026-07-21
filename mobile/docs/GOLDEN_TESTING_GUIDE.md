# Golden Testing Guide for Divine

Status: Partially implemented — infrastructure exists, no live image-comparison
golden ships in the app yet. See [Current State](#current-state) below.
Real image-diff goldens for `divine_ui` and the app gallery are tracked in
**#6235**.

## Overview

Golden tests (screenshot tests) compare a rendered widget against a
committed reference image to catch visual regressions. Divine's test
tooling includes `golden_toolkit` and `alchemist` as dev dependencies and a
management script (`scripts/golden.sh`), but as of this writing no test in
the app performs real image comparison — see
[Current State](#current-state).

## Current State

- `test/goldens/` contains exactly one file,
  `test/goldens/widgets/notification_rows_golden_test.dart`. It is a plain
  `testWidgets` layout/geometry test (asserts positions and text via
  `tester.getTopLeft` etc.), **not** an image-comparison golden — it was
  rewritten off `matchesGoldenFile` because the underlying golden was
  flaky. The `screens/`, `flows/`, and `ci/` golden subdirectories
  described in earlier revisions of this guide no longer exist.
- Golden setup (real fonts + `AlchemistConfig`) only runs when tests are
  invoked with `-D DIVINE_GOLDEN_TESTS=true` (see
  `test/flutter_test_config.dart`); a plain `flutter test` skips it
  entirely so the default suite stays fast. `scripts/golden.sh` sets that
  dart-define for you.
- No GitHub Actions workflow currently runs golden tests or checks golden
  images for drift.
- `divine_ui` package goldens are deferred — see
  [divine_ui package goldens (deferred — #6235)](#divine_ui-package-goldens-deferred--6235)
  below.

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

## Project Structure

```
test/
├── flutter_test_config.dart        # Golden font + Alchemist setup, opt-in
│                                    # via -D DIVINE_GOLDEN_TESTS=true
└── goldens/
    └── widgets/
        └── notification_rows_golden_test.dart   # layout test, not an
                                                   # image-comparison golden
```

## Writing Golden Tests

The APIs below are reference material for adding a *real* image-comparison
golden — none are currently exercised by a test in this repo (the
`golden_toolkit`/`alchemist` dependencies are wired but unused for image
diffing today; see [Current State](#current-state)). When #6235 lands the
first real golden, prefer following that example over this guide.

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
6. **Watch for async font loading** - `google_fonts`/Alchemist's obscured-text
   rendering sizes itself from font metrics that can load asynchronously
   under a merged test-runner isolate (`very_good test --optimization`),
   making the same golden render at different widths across runs. This is
   the specific blocker tracked in #6235 for `divine_ui`'s goldens.

## Troubleshooting

### Common Issues

**Tests fail on CI but pass locally**
- Platform-specific rendering differences — Alchemist's
  `platformGoldensConfig` controls whether OS-specific variants render

**Fonts not rendering**
- Ensure `loadAppFonts()` runs before pumping (only happens under
  `-D DIVINE_GOLDEN_TESTS=true`, see [Current State](#current-state))

**Image loading errors**
- Mock image providers or use test assets
- Avoid network-dependent images in tests

## Performance Considerations

- Golden tests are slower than unit/widget tests
- Run targeted golden tests during development
- A `golden` tag is declared in `dart_test.yaml`, but no test file applies
  it yet — tag new goldens with it as they're added so `--tags=golden`
  becomes a meaningful filter

## Resources

- [golden_toolkit documentation](https://pub.dev/packages/golden_toolkit)
- [alchemist documentation](https://pub.dev/packages/alchemist)
- [Flutter golden testing guide](https://flutter.dev/docs/cookbook/testing/widget/introduction#golden-tests)

## divine_ui package goldens (deferred — #6235)

Component gallery goldens for the `divine_ui` package are **not yet in place**.
Alchemist's obscured-text CI goldens size their text blocks from font metrics,
and under the package's `very_good test --optimization` merged isolate
google_fonts loads asynchronously — so the same golden renders at different
widths across runs, and the committed image would also need to be generated on
the Ubuntu CI runner. A CI-side golden-generation workflow (and bundling the
theme fonts as package assets) is tracked in **#6235**. Until then, divine_ui
relies on widget-behaviour and `meetsGuideline` accessibility tests.
