# Code Style

Follow [Effective Dart](https://dart.dev/effective-dart) guidelines and [very_good_analysis](https://pub.dev/packages/very_good_analysis) linter rules.

---

## Core Principles

### SOLID Principles
Apply SOLID principles throughout the codebase.

### Composition Over Inheritance
Favor composition for building complex widgets and logic.

### Immutability
Prefer immutable data structures. Widgets (especially `StatelessWidget`) should be immutable.

### Simplicity
Write straightforward code. Clever or obscure code is difficult to maintain.

---

## Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Classes | `PascalCase` | `UserRepository` |
| Variables/Functions | `camelCase` | `getUserName()` |
| Files | `snake_case` | `user_repository.dart` |
| Enums | `camelCase` | `userStatus.active` |

**Rules:**
- Avoid abbreviations
- Use meaningful, consistent, descriptive names
- No trailing comments

---

## Code Quality

### Line Length
Lines should be 80 characters or fewer.

### Functions
- Keep functions short with a single purpose
- Strive for less than 20 lines per function
- Use arrow syntax for simple one-line functions

```dart
// Good - arrow function
String get fullName => '$firstName $lastName';

// Good - short, single purpose
void updateUser(User user) {
  _validateUser(user);
  _repository.save(user);
  _notifyListeners();
}
```

### Error Handling
- Anticipate and handle potential errors
- Don't let code fail silently
- Use `try-catch` blocks with appropriate exception types
- Use custom exceptions for domain-specific errors

---

## Dart Best Practices

### Null Safety
- Write soundly null-safe code
- Leverage Dart's null safety features
- Avoid `!` unless the value is guaranteed to be non-null

### Async/Await
- Use `Future`, `async`, and `await` for asynchronous operations
- Use `Stream` for sequences of asynchronous events
- Always handle errors in async code

### Pattern Matching
Use pattern matching features where they simplify code:

```dart
// Good - exhaustive switch expression
return switch (status) {
  Status.loading => const LoadingView(),
  Status.success => SuccessView(data),
  Status.error => ErrorView(message),
};
```

### Records
Use records when returning multiple values where a full class is cumbersome:

```dart
// Good - destructure for clarity
Future<(String, String)> getUserNameAndEmail() async => _fetchData();

final (username, email) = await getUserNameAndEmail();

if (email.isValid) {
  // Clear what's being validated
}

// Bad - positional access is unclear
final userData = await getUserNameAndEmail();
if (userData.$1.isValid) {
  // What is $1?
}
```

**Note:** For values used across multiple files, dedicated data models may be easier to maintain.

---

## Widget Composition

### Prefer Widgets Over Methods

**Never create methods that return `Widget`**. Extract to separate widget classes instead.

**Bad:**
```dart
class ParentWidget extends StatelessWidget {
  const ParentWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return _buildChildWidget(context);
  }

  Widget _buildChildWidget(BuildContext context) {
    return const Text('Hello World!');
  }
}
```

**Good:**
```dart
class ParentWidget extends StatelessWidget {
  const ParentWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ChildWidget();
  }
}

class _ChildWidget extends StatelessWidget {
  const _ChildWidget();

  @override
  Widget build(BuildContext context) {
    return const Text('Hello World!');
  }
}
```

**Also Good - inline simple expressions:**
```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        switch (type) {
          TypeA() => const Icon(Icons.a),
          TypeB() => const Icon(Icons.b),
        },
      ],
    );
  }
}
```

**Why:**
1. Avoids `BuildContext` errors - Flutter manages context via widget tree
2. Enables efficient rendering and DevTools inspection
3. Widgets can be tested in isolation
4. Widget classes can be `const` and benefit from Flutter's diffing algorithm

---

## Flutter Best Practices

### Const Constructors
Use `const` constructors for widgets whenever possible to reduce rebuilds:

```dart
// Good
const MyWidget();
const SizedBox(height: 16);
const EdgeInsets.all(8);

// In build methods
return const Column(
  children: [
    Text('Static content'),
    SizedBox(height: 8),
  ],
);
```

### List Performance
Use `ListView.builder` or `SliverList` for long lists (lazy loading):

```dart
// Good - items created on demand
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemWidget(items[index]),
);

// Bad for long lists - all items created immediately
ListView(
  children: items.map((item) => ItemWidget(item)).toList(),
);
```

### Build Method Performance
- Never perform expensive operations in `build()` methods
- No network calls in `build()`
- No complex computations in `build()`
- Use `compute()` for expensive calculations in a separate isolate

### General Performance
- Profile before optimizing - don't guess at bottlenecks
- Implement proper asset caching for images and network resources
- Use `const` constructors liberally to reduce rebuilds

### Private Widgets
Use small, private `Widget` classes instead of private helper methods:

```dart
// Good
class _Header extends StatelessWidget {
  const _Header();
  // ...
}

// Bad
Widget _buildHeader() {
  // ...
}
```

---

## Documentation

### Public APIs
Add documentation comments to all public APIs:

```dart
/// Fetches user data from the remote server.
///
/// Throws [NetworkException] if the request fails.
/// Returns `null` if the user is not found.
Future<User?> fetchUser(String id) async {
  // ...
}
```

### Comments
- Write clear comments for complex or non-obvious code
- Avoid over-commenting obvious code
- Use `///` for doc comments (dartdoc)
- Start with a single-sentence summary

---

## Logging

Use `dart:developer` for structured logging instead of `print`:

```dart
import 'dart:developer' as developer;

// Simple message
developer.log('User logged in successfully.');

// Structured error logging
try {
  // ...
} catch (e, s) {
  developer.log(
    'Failed to fetch data',
    name: 'myapp.network',
    level: 1000, // SEVERE
    error: e,
    stackTrace: s,
  );
}
```
