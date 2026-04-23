# Testing

Goal: 100% test coverage on all projects. Tests reduce bugs, encourage clean code, and provide confidence when shipping.

---

## New and Extracted Packages Must Ship with Tests

When extracting code into a new package (client, repository, utility), include test coverage in the same PR. Do not defer tests to a follow-up — the extraction PR is incomplete without them.

At minimum, cover:
- All public methods on the main class
- Error/edge cases for network or I/O operations
- Model serialization if the package defines models

### Preserving Test Behavior During Package Extraction

When extracting a package, keep the branch up to date with `main` during the work — merge from `main` frequently, and again just before requesting review. This surfaces recent edits to files you're moving (e.g. test fixes added to the original location while extraction was in progress) so they aren't silently dropped when the file is relocated.

Known precedent: PR #2985 (extract `follow_repository`) silently dropped a `fakeAsync` wrap added two days earlier by PR #2986; restored by PR #3210. See `tasks/lessons.md` → "CI & Chain Hygiene" → "Package extractions can silently regress sibling fixes".

---

## Test Organization

### File Structure
Test files should mirror the `lib/` folder structure:

```
lib/screens/login/login_page.dart
→ test/screens/login/login_page_test.dart

lib/services/user_service.dart
→ test/services/user_service_test.dart
```

**Note:** Barrel files (`models.dart`, `widgets.dart`) do not need tests.

### Group Structure
Split tests into groups for readability:
- **Widget tests:** Group by "renders", "navigation", "interactions"
- **BLoC tests:** Group by event name
- **Repositories/Clients:** Group by method name

```dart
void main() {
  group(ShoppingCart, () {
    group('addItem', () {
      test('increases item count', () {});
      test('updates total price', () {});
    });

    group('calculateTotal', () {
      test('returns sum of all item prices', () {});
      test('returns zero when cart is empty', () {});
    });
  });
}
```

---

## Writing Tests

### Always Assert Results
Every test must have `expect` or `verify` statements:

**Good:**
```dart
testWidgets('calls [onTap] on tapping widget', (tester) async {
  var isTapped = false;
  await tester.pumpWidget(
    SomeTappableWidget(onTap: () => isTapped = true),
  );
  await tester.tap(find.byType(SomeTappableWidget));
  await tester.pumpAndSettle();

  expect(isTapped, isTrue);  // Actual assertion
});
```

**Bad:**
```dart
testWidgets('can tap widget', (tester) async {
  await tester.pumpWidget(SomeTappableWidget());
  await tester.tap(find.byType(SomeTappableWidget));
  // No assertion - test is useless!
});
```

### Use Matchers
Matchers provide better error messages:

```dart
// Good
expect(name, equals('Hank'));
expect(people, hasLength(3));
expect(valid, isTrue);

// Bad
expect(name, 'Hank');
expect(people.length, 3);
expect(valid, true);
```

### Single Purpose Tests
One scenario per test:

```dart
// Good
testWidgets('renders $WidgetA', (tester) async {});
testWidgets('renders $WidgetB', (tester) async {});

// Bad
testWidgets('renders $WidgetA and $WidgetB', (tester) async {});
```

### Test Behavior, Not Properties
Test what widgets DO, not how they're configured:

**Good - Testing behavior:**
```dart
testWidgets('navigates to settings when button is tapped', (tester) async {
  await tester.pumpWidget(MyApp());
  await tester.tap(find.byType(SettingsButton));
  await tester.pumpAndSettle();

  expect(find.byType(SettingsPage), findsOneWidget);
});

testWidgets('displays error message when login fails', (tester) async {
  await tester.pumpWidget(LoginPage());
  await tester.enterText(find.byType(TextField), 'invalid@email.com');
  await tester.tap(find.byType(LoginButton));
  await tester.pumpAndSettle();

  expect(find.text('Invalid credentials'), findsOneWidget);
});
```

**Bad - Testing static properties:**
```dart
testWidgets('button has correct padding', (tester) async {
  final button = tester.widget<Button>(find.byType(Button));
  expect(button.padding, EdgeInsets.all(16)); // Useless test
});
```

---

## Test Naming

### Descriptive Names
Be verbose - readability matters:

```dart
// Good
testWidgets('renders $YourView', (tester) async {});
testWidgets('renders $YourView for $YourState', (tester) async {});
test('given an [input] is returning the [output] expected', () async {});
blocTest<YourBloc, State>('emits $StateA when $EventB is added');

// Bad
testWidgets('renders', (tester) async {});
test('works', () async {});
```

### Use String Expressions for Types
Easier refactoring when types are renamed:

```dart
// Good
testWidgets('renders $YourView', (tester) async {});

// Bad
testWidgets('renders YourView', (tester) async {});

// For group names with only a type:
group(YourView, () {});  // Preferred
group('$YourView', () {}); // Avoid
```

---

## Test Isolation

### Initialize Shared Objects Per Test
Use `setUp` to avoid test interdependence:

```dart
// Good
group(_MySubject, () {
  late _MySubjectDependency myDependency;

  setUp(() {
    myDependency = _MySubjectDependency();  // Fresh instance each test
  });

  test('value starts at 0', () {
    final subject = _MySubject(myDependency);
    expect(subject.value, equals(0));
  });
});

// Bad
group(_MySubject, () {
  final myDependency = _MySubjectDependency();  // Shared - tests affect each other!
  // ...
});
```

### Keep Setup Inside Groups
Avoid side effects from test optimization:

```dart
// Good
void main() {
  group(UserRepository, () {
    late ApiClient apiClient;

    setUp(() {
      apiClient = _MockApiClient();
    });

    // Tests...
  });
}

// Bad
void main() {
  late ApiClient apiClient;

  setUp(() {  // Outside group - can cause issues!
    apiClient = _MockApiClient();
  });

  group(UserRepository, () {
    // Tests...
  });
}
```

### Use Private Mocks
Avoid shared mocks between files:

```dart
// Good - private mock, scoped to file
class _MockYourClass extends Mock implements YourClass {}

// Bad - public mock, can be accidentally shared
class MockYourClass extends Mock implements YourClass {}
```

---

## Finding Widgets

### Prefer Type Over Key
Keys are harder to maintain:

```dart
// Good
expect(find.byType(HomePage), findsOneWidget);

// Bad
expect(find.byKey(Key('homePageKey')), findsOneWidget);
```

---

## BLoC Testing

### Test with Event Order
Handle concurrent event processing:

```dart
blocTest<MyBloc, MyState>(
  'change value',
  build: () => MyBloc(),
  act: (bloc) async {
    bloc.add(ChangeValue(add: 1));
    await Future<void>.delayed(Duration.zero);  // Ensure order
    bloc.add(ChangeValue(remove: 1));
  },
  expect: () => const [
    MyState(value: 1),
    MyState(value: 0),
  ],
);
```

---

## Golden File Testing

Golden tests compare widget rendering against master images.

### Tag Golden Tests
Run them separately:

```dart
testWidgets(
  'render matches golden file',
  tags: TestTag.golden,
  (WidgetTester tester) async {
    await tester.pumpWidget(MyWidget());

    await expectLater(
      find.byType(MyWidget),
      matchesGoldenFile('my_widget.png'),
    );
  },
);
```

### Configure Tags
In `dart_test.yaml`:

```yaml
tags:
  golden:
    description: "Tests that compare golden files."
```

### Running Golden Tests

```bash
# Run only golden tests
flutter test --tags golden

# Update golden files
flutter test --tags golden --update-goldens
```

### Define Tag Constants

```dart
abstract class TestTag {
  static const golden = 'golden';
}
```

---

## Random Test Ordering

Run tests in random order to catch flaky tests:

```bash
flutter test --test-randomize-ordering-seed random
dart test --test-randomize-ordering-seed random
```

---

## Coverage

Aim for 100% coverage. Use:

```bash
flutter test --coverage
```

### Strict-coverage packages

Some packages enforce **100% line coverage as a CI gate** — not a
target, a gate. The PR fails with a very specific message:

> `Expected coverage >= 100.00% but actual is 99.xx%.`
> `Lines not covered: lib/…: N, M, …`

Current strict-coverage packages in this repo:

- `mobile/packages/divine_ui`

When adding a new public method / getter / constructor on a strict
package (e.g. a new `VineTheme.xxxFont()` helper, a new enum case
surfaced by a public method, a new widget variant), **add a matching
test in the same PR**. Mirror the style of neighbouring tests —
typically an assertion on the returned style / computed size.

If a line is genuinely unreachable, exclude it from coverage with a
justified `// coverage:ignore-line` (or block) comment rather than
leaving the gate red.

---

## Widget tests that use `context.l10n`

Any widget test that pumps a widget which calls `context.l10n.xxx` (or
its generated getters) must include the localization delegates on the
test's `MaterialApp`, or the l10n lookup fails at runtime:

```dart
MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: ...
)
```

A common symptom of the missing setup is an assertion that passes when
the string is hardcoded but fails after an l10n migration with
`Found 0 widgets with text "…"`. The widget tree built correctly; only
the text child failed to resolve.

---

## Absolute timing bounds flake on shared CI runners

Tests that assert a benchmark runs in under N nanoseconds /
microseconds / milliseconds fail intermittently in CI because
GitHub-hosted runners are shared, noisy, and substantially slower
than a dev laptop. Two failures seen on this repo:

- `NativeProofData isComplete` expected `<100 ns/op` but ran at
  `443 ns/op` on CI.
- `StartupCoordinator FastService` used `Future.delayed(50 ms)` and
  asserted `<100 ms` — flaked at `114 ms` on CI.

There are three valid responses:

1. **Relative comparison**, when the benchmark's real contract is
   ordering between two measured things:
   ```dart
   final fastMs = metrics.serviceTimings['FastService']!.inMilliseconds;
   final slowMs = metrics.serviceTimings['SlowService']!.inMilliseconds;
   expect(fastMs, lessThan(slowMs));
   expect(slowMs, greaterThanOrEqualTo(200));
   ```
2. **Skip with `skip: true`** and a `TODO(any):` referencing the
   flakiness, for benchmarks that exist as regression alarms rather
   than correctness checks. Follow the precedent of the already-
   skipped sibling in the same file:
   ```dart
   test('X should be fast', () {
     // ...
     expect(avgNanoseconds, lessThan(100), reason: '...');
     // TODO(any): Fix and enable — 100 ns target is unreachable on
     // shared GitHub-runner hardware (seen 443 ns on CI, <100 ns
     // locally).
   }, skip: true);
   ```
3. **Wrap in `fakeAsync`** if the goal was to verify logical
   durations (e.g. "feedback fades after 500 ms") rather than wall-
   clock performance. See the `fakeAsync` pattern already used in
   `follow_repository` tests.

Never bump the threshold "a little" to make the flake go away — that
just delays the next flake. Pick one of the three above.

---

## `tester.takeException(), isNotNull` is fragile under test-suite optimization

`very_good test --optimization` merges many test files into one
generated `main()` for CI. Leaked provider state (Riverpod
`keepAlive`, registered fallbacks, singletons) from a previously-run
test can make a partial dependency resolve "successfully" in a later
test, silencing the exception that the test was relying on as a
side-effect signal.

If a test's description is "does X, and also throws because the test
harness lacks dependency Y," that **incidental** throw is not a
durable assertion. Drop it and assert only what the description
names:

```dart
// Bad — depends on provider ordering luck
await tester.tap(find.byType(ShareButton));
await tester.pump();
expect(shareCalled, isTrue);
expect(tester.takeException(), isNotNull); // flakes under CI merging

// Good — asserts the contract and drains any incidental error
await tester.tap(find.byType(ShareButton));
await tester.pump();
expect(shareCalled, isTrue);
tester.takeException(); // drain any incidental error, no assertion
```

If the test legitimately needs to verify an error path, **set up the
conditions that cause the error explicitly** (e.g. override the
provider to return a failure, or pre-throw in a test double) so the
exception is deterministic.

---

## Coordinate-based `tapAt` is sensitive to modal layout

`tester.tapAt(Offset(200, 20))` depends on what actually occupies that
pixel — a `DraggableScrollableSheet(expand: false)` has **transparent
empty space above** its content that delegates to the widget tree
under it (the modal barrier), whereas `expand: true` fills the same
rectangle with the sheet's own hit-testing. That's enough of a
layout detail to flip the test between "dismissal via barrier" and
"dismissal via our custom gesture detector" — and CI may see a
different layout than your laptop if the test viewport differs.

**Prefer:**
- `find.text(...)`, `find.byType(...)`, `find.bySemanticsIdentifier(...)`
  — stable across layout changes.
- `tester.tap(find.byKey(...))` when you need a specific sub-region.

When you must use `tapAt`, document the layout assumption inline and
keep the offset well inside the intended region (don't tap on the
boundary of a sheet/barrier split):

```dart
// Sheet covers the bottom 50% of an 800-high test viewport. Tapping
// at y=20 lands squarely in the barrier area, not on any sheet
// content.
await tester.tapAt(const Offset(200, 20));
```

Also note: modal controls often have two "dismiss on outside tap"
mechanisms (the Flutter `ModalBarrier` via `isDismissible`, and any
custom tap-catcher in the sheet's own widget tree). If your wrapper
exposes a `tapOutsideToDismiss` parameter, make sure it links to the
underlying `isDismissible` so the two mechanisms can't disagree —
otherwise tests that pass `tapOutsideToDismiss: false` still see the
barrier dismiss the sheet.

---

## Inject `package:clock` for time-sensitive logic

`tester.pump(Duration)` advances the Flutter test clock — which drives
`SchedulerBinding`, `Timer`, animation controllers, etc. It does
**not** advance `DateTime.now()` / `Stopwatch.elapsed` / anything else
that reads the host machine's wall clock. If your code compares
wall-clock timestamps (e.g. "did the pause last longer than 150 ms?"),
`pump` gives you no way to make that comparison deterministic.

**Fix:** read time through `package:clock`'s `clock.now()` in the code
under test, and wrap the test body in `withClock(...)` with a
manually-advanced time source.

```dart
// Code under test (e.g. paused_video_play_overlay.dart):
import 'package:clock/clock.dart';

if (!isPlaying && wasPlaying) {
  _pausedAt = clock.now();
} else if (isPlaying && !wasPlaying && _pausedAt != null) {
  final pauseDuration = clock.now().difference(_pausedAt!);
  if (pauseDuration >= _minPauseForFeedback) {
    _triggerUnpauseFeedback();
  }
}

// Test:
testWidgets('triggers feedback for pauses > 150 ms', (tester) async {
  var now = DateTime(2026);
  await withClock(Clock(() => now), () async {
    await tester.pumpWidget(buildSubject());
    // ... set up "playing" state ...

    playingController.add(false);
    await tester.pump();

    // Advance BOTH clocks so timers and wall-clock agree.
    now = now.add(const Duration(milliseconds: 220));
    await tester.pump(const Duration(milliseconds: 220));

    playingController.add(true);
    await tester.pump();

    expect(find.byType(UnpauseFeedback), findsOneWidget);
  });
});
```

`clock` is already a transitive dependency in this repo, so no
`pubspec.yaml` change is needed to start using it.
