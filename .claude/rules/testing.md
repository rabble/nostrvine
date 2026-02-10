# Testing

Goal: 100% test coverage on all projects. Tests reduce bugs, encourage clean code, and provide confidence when shipping.

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
