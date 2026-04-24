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

### Document Design-System Divergence

If a bespoke widget deliberately diverges from a `divine_ui` component (different size, different structure, bypassed variant), the class's docstring **must** say why — specifically, which design-system component it's close to and what forced the divergence. Without that note, the next reviewer (or the next you, six months later) will re-raise the "why not just use `DivineIconButton`?" question, and you'll have to re-litigate the decision.

**Good — explains the divergence inline:**
```dart
/// Shared Figma-matched center control used for transient play/pause states.
///
/// Visually equivalent to a [DivineIconButton] in ghost style (scrim65
/// background + white glyph) but sized 64×64 with a 32 icon instead of
/// DivineIconButton's 40×40 (small) / 56×56 (base) presets, because the
/// Figma spec for the paused-video affordance (node 15314:53971) calls
/// for a larger tap target than any standard DivineIconButton size. Kept
/// as a bespoke widget rather than extending DivineIconButton with a
/// third size enum that only this surface would use.
class CenterPlaybackControl extends StatelessWidget { ... }
```

**Bad — no hint that the bespoke widget is intentional:**
```dart
/// Center play/pause control.
class CenterPlaybackControl extends StatelessWidget { ... }
```

The rule is satisfied by a 2–4 sentence note in the docstring. No separate ADR required — but a link to the Figma node that forced the divergence (when applicable) saves a round-trip.

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

## No Speculative Parameters on Reusable Widgets

Before adding a parameter to a reusable widget or utility (anything in
`divine_ui` or `lib/utils/`), trace the caller flow end-to-end and
confirm the branch it unlocks is actually reachable. "Future-proof" or
anticipatory parameters tend to sit unused, inflate the API surface,
and confuse the next reader — the parameter's only documentation is
the dead branch.

**Smell: parameter name includes "Builder" / "Callback" / "Resolver"
and there is exactly one caller, which always supplies it.** That's a
named-parameter closure being used as a late-binding for behavior
that could live in the caller's code. Ask whether the caller can
compute the value directly and pass the resolved value in.

**Example (from review on #3224):**

```dart
// Bad — caller computes an initial size based on keyboard state,
// but the sheet is only ever opened from a surface that has no text
// input (feed), so the keyboard is never open at show time. The
// parameter's entire body is dead.
static Future<T?> show<T>({
  double initialChildSize = 0.6,
  double Function(BuildContext)? initialChildSizeBuilder,
  // ...
}) {
  final size = initialChildSizeBuilder?.call(context) ?? initialChildSize;
  // ...
}

// Good — the speculative branch is deleted; callers pass a plain
// number, and there's nothing to miss-configure.
static Future<T?> show<T>({
  double initialChildSize = 0.6,
  // ...
}) { /* ... */ }
```

Bias toward **removing** a parameter that has one caller and one
code path — adding it back later is cheap; living with a
never-exercised branch is not. If a parameter genuinely must exist
for one forced scenario, assert that scenario at the top of the
function so the invariant is explicit:

```dart
assert(
  initialChildSizeBuilder == null || someScenarioHolds,
  'initialChildSizeBuilder is only valid when ...',
);
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

### Don't Hide Ancestors Inside a One-Off `Widget Function` Closure

When a call site needs to inject an **ancestor** (a `BlocProvider`,
`InheritedWidget`, `Theme`, etc.) above a widget's whole subtree, do
**not** reach for a one-off `Widget Function(BuildContext, Widget)`
closure at the call site — that's a `_buildFoo` in disguise, just
lifted into an argument. Instead, add a `contentWrapper` (or similarly
named) parameter to the target widget/utility and let each call site
supply the wrapper declaratively.

**Smell: the call site invents a named closure that takes `(context,
child)` and wraps `child` in a provider / inherited widget.** That
call site is asking for a `contentWrapper` parameter.

**Bad — the wrapping is a builder closure baked into a single call
site. It's easy to miss that the provider must wrap the *entire*
sheet, and if the target widget ever gains a new slot, the closure
silently won't apply there:**

```dart
// In a utility that shows a sheet:
Future<void> showMySheet(BuildContext context, {
  required Widget Function(BuildContext, Widget) builder,
  required Widget body,
}) {
  return showModalBottomSheet(
    context: context,
    builder: (ctx) => builder(ctx, MySheet(body: body)),
  );
}

// At the call site:
showMySheet(
  context,
  builder: (ctx, child) => BlocProvider<MyBloc>(
    create: (_) => MyBloc(),
    child: child,
  ),
  body: ...,
);
```

**Good — the target exposes a `contentWrapper` parameter that
participates in its own API. The wrapping is declarative and the
target can guarantee it applies across every slot:**

```dart
Future<void> showMySheet(BuildContext context, {
  Widget Function(BuildContext, Widget)? contentWrapper,
  required Widget body,
}) {
  return showModalBottomSheet(
    context: context,
    builder: (ctx) {
      final Widget sheet = MySheet(body: body);
      return contentWrapper?.call(ctx, sheet) ?? sheet;
    },
  );
}

showMySheet(
  context,
  contentWrapper: (ctx, child) => BlocProvider<MyBloc>(
    create: (_) => MyBloc(),
    child: child,
  ),
  body: ...,
);
```

The cue is almost always a `BlocProvider` / `InheritedWidget` that
needs to sit **above** every slot of the target — not beside one of
them. The `contentWrapper` parameter turns that intent into part of
the widget's contract instead of a call-site pattern.

See the companion rule in
[`state_management.md`](state_management.md#scoping-blocprovider-to-a-modal-route)
for why this matters specifically for `BlocProvider` lifecycle.

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

**Don't write long design-rationale comments just for Claude.** AI
tools happily cite inline comments as if they were specs — and when
the code changes and the comment doesn't, the stale citation carries
forward as bad authority. A reviewer on #3202 described seeing Claude
refer to "a comment of nonsense" as its source when asked for
references. Two corollaries:

1. **Document design decisions in the code, not around it.** A
   well-named widget, a named constant, a typed enum, or a focused
   doc under `.claude/rules/` or `docs/` survives rename refactors
   and grep; an inline paragraph doesn't.
2. **Use inline comments as pointers, not homes.** If you need more
   than a sentence to explain a design decision, write the full
   explanation in the PR description (or a rule file) and leave a
   brief `// See PR #N / rules/foo.md` pointer inline — not a
   paragraph the next change will quietly outdate.

```dart
// Bad — design rationale as a paragraph above the code. Will drift
// the first time the 30 or 32 changes.
// ┌────────────────────────────────────────────────────────────────┐
// │ The outer shell uses 30 px bottom corners and the inner tabs  │
// │ container uses 32 px top corners so that the inner surface    │
// │ visibly nests inside the outer shell. We picked these values  │
// │ from Figma node 12345:67 and they should stay in sync …       │
// └────────────────────────────────────────────────────────────────┘
ClipRRect(borderRadius: .vertical(bottom: .circular(30)), ...);

// Good — the rationale is carried by the named constants.
// (If you still need a pointer, one line is enough.)
// Inner radius is 2 px larger so the tabs container visibly nests
// inside the nav-rounded shell.
ClipRRect(
  borderRadius: .vertical(
    bottom: .circular(VineTheme.shellCornerRadius),
  ),
  ...
);
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
