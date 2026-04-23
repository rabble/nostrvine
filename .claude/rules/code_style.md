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

### Reuse Before Writing
Before writing a new helper, utility, or formatter, search `mobile/packages/` for an existing package that already provides the functionality. The monorepo contains shared packages (e.g., `count_formatter`, `divine_ui`) specifically to avoid duplication across features.

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

## No Hardcoded Values

Never hardcode relay URLs, port numbers, API endpoints, durations, or numeric thresholds directly in BLoCs, repositories, or widgets. Extract them into named constants grouped in a dedicated class or config object.

**Bad:**
```dart
class ShareSheetBloc extends Bloc<ShareSheetEvent, ShareSheetState> {
  Future<void> _onShare(...) async {
    await _client.publish(
      relays: ['wss://relay.example.com'],  // WRONG — hardcoded relay
      retries: 3,                            // WRONG — magic number
    );
  }
}
```

**Good:**
```dart
abstract class ShareConstants {
  static const defaultRelays = ['wss://relay.example.com'];
  static const maxRetries = 3;
}

// Or use environment config for environment-specific values
class ShareSheetBloc extends Bloc<ShareSheetEvent, ShareSheetState> {
  Future<void> _onShare(...) async {
    await _client.publish(
      relays: ShareConstants.defaultRelays,
      retries: ShareConstants.maxRetries,
    );
  }
}
```

Group related constants together so they are easy to find and update in one place.

---

## Latest Dependency Versions

When adding a new dependency to `pubspec.yaml`, always use the latest stable version. Don't copy version constraints from older packages without checking for updates.

```yaml
# Good — checked pub.dev for latest
very_good_analysis: ^10.2.0

# Bad — copied from another package without checking
very_good_analysis: ^6.0.0
```

---

## PR Scope

Pull requests should only include changes directly related to the task. Remove unrelated file modifications (stale lock files, unrelated docs, formatting changes in untouched files) before requesting review.

If you discover something unrelated that needs fixing, create a separate PR or issue for it.

---

## Temporary Code

Transitional or temporary code (feature flags, compatibility shims, workarounds for in-progress migrations) must include a `// TODO(#issue):` comment referencing a tracking issue for its removal. Code without a removal plan tends to become permanent.

```dart
// Good — linked to a tracking issue
// TODO(#2854): Remove this fallback after unified search ships
if (useOldSearch) {
  return _legacySearch(query);
}

// Bad — no indication this is temporary or when to remove it
if (useOldSearch) {
  return _legacySearch(query);
}
```

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

### Uniform Spacing in Row/Column
When all gaps between children are equal, use the `spacing` parameter instead of inserting `SizedBox` widgets between each child:

```dart
// Good - uniform spacing via parameter
Column(
  spacing: 8,
  children: [
    Text('Title'),
    Text('Subtitle'),
    Text('Body'),
  ],
);

// Bad - manual SizedBox for uniform gaps
Column(
  children: [
    Text('Title'),
    SizedBox(height: 8),
    Text('Subtitle'),
    SizedBox(height: 8),
    Text('Body'),
  ],
);
```

Use `SizedBox` only when gaps between children differ:

```dart
// SizedBox is fine here - gaps are not uniform
Column(
  children: [
    Text('Title'),
    SizedBox(height: 16),
    Text('Subtitle'),
    SizedBox(height: 8),
    Text('Body'),
  ],
);
```

This applies equally to `Row(spacing: ...)` for horizontal layouts.

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

Keep comments short. Prefer one line over a paragraph. Long comments are often a sign that the code itself needs to be clearer.

Multi-line comments (more than 2–3 lines) are only justified when the explanation is genuinely critical — for example: non-obvious protocol constraints, security invariants, known platform bugs, or algorithmic decisions that cannot be expressed in code. If you find yourself writing a long comment, ask first whether the code could be restructured to make the comment unnecessary.

**Comment rules:**
- Use `///` for doc comments (dartdoc); `//` for inline implementation notes
- Start doc comments with a single-sentence summary
- Comment the **why**, not the **what** — if the code is readable, it already shows what it does
- Avoid over-commenting obvious code
- Do **not** add section headers, `// --- Title ---` dividers, or step labels like `// Step 1:` to group lines within a function — extract to smaller functions instead

**Comments go stale.** An outdated comment is worse than no comment because it actively misleads. Rules for keeping comments accurate:
- When you change code, update or delete any comment that described the old behaviour
- Never leave a comment that contradicts the current implementation
- If a comment requires constant upkeep, the design is probably wrong — refactor so the code speaks for itself

**LLM-specific:** AI-generated code tends to over-comment. When reviewing AI output, strip comments that restate the code literally or add no new information:

```dart
// Bad — restates what the code already says
final user = await _repository.fetchUser(id); // fetch user by id
if (user == null) return; // return if user is null

// Good — explains non-obvious intent only
// Null means the account was deleted; skip silently to avoid error state.
if (user == null) return;
```

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
