# Golden Testing Guide for Divine

Status: Current
Validated against: current `mobile/scripts/golden.sh` workflow on 2026-03-19.

## Overview
Golden tests (screenshot tests) are integrated into Divine using the `golden_toolkit` and `alchemist` packages. These tests help ensure UI consistency across different devices and prevent visual regressions.

## Quick Start

### Running Golden Tests

```bash
# Update all golden images
./scripts/golden.sh update

# Verify golden tests pass
./scripts/golden.sh verify

# Update specific test
./scripts/golden.sh update test/goldens/widgets/user_avatar_golden_test.dart

# List all golden tests
./scripts/golden.sh list

# Show changes to golden images
./scripts/golden.sh diff

# Clean all golden images
./scripts/golden.sh clean
```

## Project Structure

```
test/
├── flutter_test_config.dart       # Auto-loads fonts for golden tests
├── helpers/
│   └── golden_test_devices.dart  # Device configuration matrix
└── goldens/
    ├── widgets/                  # Component golden tests
    │   ├── user_avatar_golden_test.dart
    │   ├── video_thumbnail_golden_test.dart
    │   └── upload_progress_golden_test.dart
    ├── screens/                  # Full screen golden tests
    │   └── settings_screen_golden_test.dart
    ├── flows/                    # Multi-screen flow tests
    └── ci/                       # CI-specific goldens
```

## Writing Golden Tests

### Basic Widget Golden Test

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import '../helpers/golden_test_devices.dart';

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

    testGoldens('MyWidget on multiple devices', (tester) async {
      await tester.pumpWidgetBuilder(const MyWidget());

      await multiScreenGolden(
        tester,
        'my_widget_devices',
        devices: GoldenTestDevices.defaultDevices,
      );
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

## Device Configuration

The project includes predefined device configurations in `golden_test_devices.dart`:

- **defaultDevices**: iPhone SE, iPhone 11, Android phone, iPad portrait
- **minimalDevices**: iPhone 11, Android phone (for quick tests)
- **comprehensiveDevices**: All device sizes including tablets
- **phoneDevices**: Phone-only configurations
- **tabletDevices**: Tablet-only configurations

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
1. **Use fixed timestamps** - Don't use `DateTime.now()` directly
2. **Mock network images** - Use local assets or placeholders
3. **Control text content** - Use consistent test data
4. **Test multiple states** - Cover all visual states in one test
5. **Name tests clearly** - Use descriptive golden file names

## CI/CD Integration

### GitHub Actions Setup
Golden tests are configured to run in CI with platform-specific handling:

```yaml
- name: Run Golden Tests
  run: |
    flutter test --update-goldens
    git diff --exit-code test/goldens/
```

### Handling Golden Updates in PRs
1. Developer updates code that affects UI
2. Run `./scripts/golden.sh update` locally
3. Review golden diffs with `./scripts/golden.sh diff`
4. Commit updated golden images with PR
5. Reviewers verify visual changes are intentional

## Troubleshooting

### Common Issues

**Tests fail on CI but pass locally**
- Platform-specific rendering differences
- Use CI-specific goldens in `test/goldens/ci/`

**Golden images too large**
- Reduce device count for non-critical components
- Use `minimalDevices` instead of `defaultDevices`

**Fonts not rendering**
- Ensure `loadAppFonts()` is called in `setUpAll()`
- Check `flutter_test_config.dart` is properly configured

**Image loading errors**
- Mock image providers or use test assets
- Avoid network-dependent images in tests

## Advanced Features

### Accessibility Testing
```dart
testGoldens('High contrast mode', (tester) async {
  debugHighContrastMode = true;
  await tester.pumpWidgetBuilder(MyWidget());
  await screenMatchesGolden(tester, 'high_contrast');
  debugHighContrastMode = false;
});
```

### Platform-Specific Goldens
```dart
testGoldens('iOS specific rendering', (tester) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  await tester.pumpWidgetBuilder(MyWidget());
  await screenMatchesGolden(tester, 'ios_rendering');
  debugDefaultTargetPlatformOverride = null;
});
```

## Performance Considerations

- Golden tests are slower than unit/widget tests
- Run targeted golden tests during development
- Full suite runs on CI/before releases
- Use `--tags=golden` to run only golden tests

## Migration from Existing Tests

To convert existing widget tests to golden tests:
1. Replace `testWidgets` with `testGoldens`
2. Add `await loadAppFonts()` in `setUpAll()`
3. Replace `expect(find.byType(...))` with `screenMatchesGolden()`
4. Generate initial goldens with `--update-goldens`
5. Review and commit golden images

## Resources

- [golden_toolkit documentation](https://pub.dev/packages/golden_toolkit)
- [alchemist documentation](https://pub.dev/packages/alchemist)
- [Flutter golden testing guide](https://flutter.dev/docs/cookbook/testing/widget/introduction#golden-tests)

## Summary

Golden testing is fully integrated into Divine with:
- ✅ Infrastructure setup complete
- ✅ Device configuration matrix defined
- ✅ Management scripts ready
- ✅ Example tests for widgets and screens
- ✅ CI/CD guidelines established

Start using golden tests for new UI components to maintain visual consistency!

## divine_ui package goldens

The `divine_ui` package has its own golden setup, separate from the app's
`golden.sh` flow, so component goldens run **inline in CI** under the VeryGood
`flutter_package.yml` workflow (no dart-define, no separate step).

**How it works**

- `packages/divine_ui/test/flutter_test_config.dart` applies
  `AlchemistConfig(platformGoldensConfig: PlatformGoldensConfig(enabled: false))`,
  so only the **platform-agnostic CI variant** runs. That variant obscures
  text (renders it as blocks), which makes goldens byte-identical on a dev's
  machine and on Ubuntu CI. It also sets `GoogleFonts.config.allowRuntimeFetching
  = false` (no network in tests).
- The package bundles the theme TTFs under `assets/fonts/` (declared in the
  package `pubspec.yaml`) because obscured text still needs font **metrics** —
  without them `google_fonts` throws. SIL OFL 1.1 licenses ship in
  `assets/licenses/`.
- Goldens are stored next to their test at `test/**/goldens/ci/<fileName>.png`
  and committed.

**Add / update a component golden**

```dart
// test/src/<area>/<component>_golden_test.dart
Future<void> main() async {
  await goldenTest(
    'DivineFoo — variants',
    fileName: 'divine_foo_variants',
    builder: () => GoldenTestGroup(
      columns: 2,
      children: [
        GoldenTestScenario(name: 'a', child: const DivineFoo()),
      ],
    ),
  );
}
```

```bash
# from mobile/packages/divine_ui
flutter test --update-goldens test/src/<area>/<component>_golden_test.dart
flutter test test/src/<area>/<component>_golden_test.dart   # verify compare
```

**Known limitations (tracked as a fast-follow)**

- Components that render SVGs via `DivineIcon` (icon buttons, the checkbox
  sprite, the field's error/password icons) render empty in package tests:
  `DivineIcon` loads `assets/icon/*.svg` by app-root path, which the package
  doesn't bundle. Fixing this needs `DivineIcon` to load via `package:`.
- `DivineSlider` goldens fail because Material `Slider`'s `OverlayPortal`
  asserts under alchemist's grid layout.
