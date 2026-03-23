# Very Good AI Flutter Plugin — divine-mobile Usage Guide

A practical guide for using the [Very Good AI Flutter Plugin](https://github.com/VeryGoodOpenSource/very_good_ai_flutter_plugin) with the divine-mobile project. This guide maps VGV skills to our existing conventions, flags compatibility issues, and provides divine-mobile-specific usage patterns.

---

## 1. Quick Setup

### Prerequisites

| Requirement | Check | Install |
|---|---|---|
| Dart SDK | `dart --version` | Bundled with Flutter |
| jq | `jq --version` | `brew install jq` |
| Very Good CLI | `very_good --version` | `dart pub global activate very_good_cli` |

### Install the Plugin

Follow the installation instructions in the [plugin README](https://github.com/VeryGoodOpenSource/very_good_ai_flutter_plugin#readme).

The plugin hooks complement our existing pre-commit hooks (format, analyze, codegen verification) by catching issues **during** Claude's work, not just at commit time.

---

## 2. Skill Priority Matrix

### Tier 1 — High Value (fills gaps in divine-mobile)

| Skill | Why It Matters | Current Gap |
|---|---|---|
| `/vgv-accessibility` | WCAG 2.1 audit for semantics, touch targets, contrast, screen readers | Minimal a11y coverage — only scattered `semanticLabel` usage |
| `/vgv-internationalization` | Flutter l10n with ARB files, `context.l10n`, RTL support | No l10n system — English-only, hardcoded strings |
| `/vgv-license-compliance` | Audits 120+ dependency licenses, flags GPL/unknown | No license auditing in place |
| `/vgv-static-security` | Static security review against OWASP Mobile Top 10 | Good practices exist but no formal audit tool |

### Tier 2 — Reinforcing (validates existing patterns)

| Skill | What It Adds | Current State |
|---|---|---|
| `/vgv-bloc` | VGV event naming, sealed classes, Page/View pattern | 26 BLoCs/Cubits already follow these patterns |
| `/vgv-testing` | VGV test naming, `pumpApp`, golden test patterns | 685+ tests with mocktail, bloc_test, Patrol |
| `/vgv-navigation` | Type-safe GoRouter patterns, redirect strategies | GoRouter with `@TypedGoRoute` already in use |
| `/vgv-layered-architecture` | Validates 4-layer package structure | 21 packages already follow Data → Repo → BLoC → UI |
| `/vgv-material-theming` | Material 3 theming patterns and spacing system | Aligned with architecture — just note divine is **dark-mode only** |
| `/vgv-create-project` | Scaffolds from VGV templates | Useful for new packages — adapt to existing monorepo workspace |

---

## 3. Critical Compatibility Rules

**Read this section before using any VGV skill.** These are areas where VGV defaults conflict with divine-mobile's rules in `.claude/rules/`.

### Rule 1: No Error Strings in BLoC State

VGV's `bloc` skill may generate state classes with `String? errorMessage` or `Exception? error` fields.

**divine-mobile forbids this.** Error handling uses `addError()` + a status enum:

```dart
// WRONG — VGV default that violates our rules
class ProfileState {
  final String? errorMessage;  // NEVER do this
}

// CORRECT — divine-mobile pattern
class ProfileState {
  final ProfileStatus status;  // enum: initial, loading, success, failure
}

// In the Bloc:
try {
  final user = await _userRepository.getUser(event.userId);
  emit(state.copyWith(status: ProfileStatus.success, user: user));
} catch (e, st) {
  addError(e, st);  // Uses BLoC error stream
  emit(state.copyWith(status: ProfileStatus.failure));
}
```

**Source:** `.claude/rules/state_management.md`

### Rule 2: No GoRouter `extra` Parameter

VGV's `navigation` skill may suggest passing objects via `extra:`:

```dart
// WRONG — breaks deep linking
context.go('/profile', extra: userObject);

// CORRECT — pass IDs, let the page fetch data
context.go('/profile/${user.id}');
```

**Source:** `.claude/rules/routing.md`

### Rule 3: Fallback Logic Lives in Repository

VGV's `layered-architecture` skill may place fallback/cache logic in BLoCs or UI.

**divine-mobile requires fallback logic in the repository layer:**

```dart
// CORRECT — repository owns fallback strategy
class VideosRepository {
  Future<List<Video>> getVideos() async {
    try {
      final videos = await _apiClient.fetchVideos();
      await _localCache.saveVideos(videos);
      return videos;
    } catch (_) {
      return _localCache.getVideos();  // Fallback here, NOT in BLoC
    }
  }
}
```

**Source:** `.claude/rules/architecture.md`

### Rule 4: No Widget Helper Methods

VGV code examples may generate `Widget _buildSomething()` methods.

**divine-mobile forbids this.** Extract to separate widget classes:

```dart
// WRONG
class ProfileView extends StatelessWidget {
  Widget _buildHeader() => ...;  // NEVER do this
}

// CORRECT
class ProfileView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(children: [ProfileHeader(), ProfileContent()]);
  }
}

class ProfileHeader extends StatelessWidget { ... }
```

**Source:** `.claude/rules/code_style.md`

### Rule 5: No Hardcoded Values

VGV examples may include inline URLs, durations, or magic numbers:

```dart
// WRONG
final dio = Dio(BaseOptions(baseUrl: 'https://api.divine.com'));
await Future.delayed(Duration(seconds: 3));

// CORRECT
final dio = Dio(BaseOptions(baseUrl: AppConstants.apiBaseUrl));
await Future.delayed(AppConstants.defaultRetryDelay);
```

**Source:** `.claude/rules/code_style.md`

### Rule 6: Dark Mode Only

VGV's `material-theming` skill generates light + dark theme variants.

**Divine is dark-mode only.** When the skill suggests `AppTheme.light` and `AppTheme.dark`, only use the dark variant. Reference `VineTheme` and `divine_ui` components before adding custom styling.

**Source:** `.claude/rules/ui_theming.md`

### Rule 7: Riverpod is Legacy Only

VGV skills should **never** generate new Riverpod providers or `@riverpod` annotations. All new state management must use BLoC/Cubit via `flutter_bloc`.

**Source:** `.claude/rules/state_management.md`

### Rule 8: Never Truncate Nostr IDs

VGV skills generating test data or debug output must use full Nostr IDs (npub, nsec, event IDs). Never shorten or abbreviate them.

**Source:** `.claude/rules/e2e_testing.md`

---

## 4. Recommended Workflows

### Workflow 1: Adding a New Feature

A complete feature touches all four architecture layers. Use skills in this order:

1. **`/vgv-create-project`** — Scaffold the data client and repository packages
2. **`/vgv-layered-architecture`** — Validate the package structure and dependency graph
3. **`/vgv-bloc`** — Create the BLoC with events, states, and event transformers
4. **`/vgv-navigation`** — Add the route with `@TypedGoRoute`
5. **`/vgv-testing`** — Write tests for each layer (unit → widget → golden)
6. **`/vgv-accessibility`** — Audit the new UI for WCAG AA compliance

### Workflow 2: Accessibility Audit

Run this before major releases:

1. **`/vgv-accessibility`** — Audit target screens (start with Level AA, mobile)
2. Fix identified issues (semantics, touch targets, contrast)
3. **`/vgv-testing`** — Add golden tests to lock in accessible layouts
4. Verify with TalkBack (Android) and VoiceOver (iOS)

### Workflow 3: Pre-Release Checklist

Run these checks before cutting a release build:

1. **`/vgv-license-compliance`** — Audit all dependency licenses
2. **`/vgv-static-security`** — Static security review (secrets, storage, network)
3. Review results against `docs/RELEASE_CHECKLIST.md`

### Workflow 4: Adding Internationalization

One-time setup, then incremental string extraction:

1. **`/vgv-internationalization`** — Set up ARB infrastructure, `l10n.yaml`, `context.l10n` extension
2. Extract strings from `divine_ui` first (shared widgets)
3. Extract strings from screens feature-by-feature
4. Add new locales as ARB files are translated

### Workflow 5: New Package Creation

When adding a new domain to the data layer:

1. **`/vgv-create-project`** — Scaffold `<name>_api_client` (data) and `<name>_repository` (repo)
2. **`/vgv-layered-architecture`** — Wire into `App` bootstrap with `RepositoryProvider`
3. **`/vgv-testing`** — Unit tests for both packages
4. Add to workspace `pubspec.yaml` and CI workflows

---

## 5. What NOT to Do

| Mistake | Why It's Wrong | What to Do Instead |
|---|---|---|
| Accept VGV `errorMessage` in BLoC state | Violates state_management rules | Use `addError()` + status enum |
| Use `extra:` in GoRouter | Breaks deep linking and web support | Pass resource IDs via path parameters |
| Let VGV generate Riverpod providers | Riverpod is legacy-only | Insist on BLoC/Cubit for all new code |
| Accept light theme from material-theming | Divine is dark-mode only | Only use dark theme variant |
| Use `Widget _buildX()` methods | Violates code_style rules | Extract to separate widget classes |
| Accept hardcoded URLs or magic numbers | Violates code_style constants rule | Extract to `Constants`/`Config` class |
| Run `/vgv-create-project` without updating workspace | New package won't be found | Add to `pubspec.yaml` workspace section |
| Use `mockito` in generated tests | Project uses `mocktail` exclusively | Specify mocktail in prompts if needed |
| Truncate Nostr IDs in test fixtures | Violates e2e_testing rules | Always use full npub/nsec/event IDs |
| Accept `print()` in generated code | Must use `dart:developer` `log()` | Replace with structured logging |

---

## Reference

### Slash Commands

| Command | Skill |
|---|---|
| `/vgv-create-project` | Scaffold new Dart/Flutter projects |
| `/vgv-accessibility` | WCAG 2.1 accessibility audit |
| `/vgv-bloc` | BLoC/Cubit state management |
| `/vgv-testing` | Unit, widget, and golden testing |
| `/vgv-navigation` | GoRouter routing patterns |
| `/vgv-internationalization` | i18n/l10n with ARB files |
| `/vgv-material-theming` | Material 3 theming |
| `/vgv-layered-architecture` | 4-layer package architecture |
| `/vgv-static-security` | OWASP Mobile Top 10 security review |
| `/vgv-license-compliance` | Dependency license auditing |

### Key Project Files

| File | Purpose |
|---|---|
| `.claude/rules/architecture.md` | Layered architecture rules |
| `.claude/rules/state_management.md` | BLoC patterns and error handling |
| `.claude/rules/routing.md` | GoRouter conventions |
| `.claude/rules/testing.md` | Test organization and coverage |
| `.claude/rules/code_style.md` | Dart style, constants, widget composition |
| `.claude/rules/ui_theming.md` | Theme system and accessibility basics |
| `.claude/rules/error_handling.md` | Exception strategy and security |
| `mobile/packages/divine_ui/lib/src/theme/vine_theme.dart` | VineTheme dark theme definition |
| `mobile/packages/divine_ui/` | 29 exported UI components |

### Links

- [VGV Plugin Repository](https://github.com/VeryGoodOpenSource/very_good_ai_flutter_plugin)
- [VGV Claude Marketplace](https://github.com/VeryGoodOpenSource/very_good_claude_marketplace)
- [Very Good Ventures Blog Post](https://verygood.ventures/blog/very-good-ai-flutter-plugin/)
