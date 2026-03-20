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

In Claude Code, run:

```
/plugin marketplace add VeryGoodOpenSource/very_good_claude_marketplace
/plugin install very-good-ai-flutter-plugin@very_good_claude_marketplace
```

This installs:
- **10 skills** — best-practice guidance activated by context or slash commands
- **2 hooks** — auto `dart analyze` (blocking) + `dart format` (non-blocking) on every file edit
- **MCP server** — Very Good CLI tools for scaffolding, testing, and license auditing

### What the Hooks Do

The plugin adds PostToolUse hooks that run after every `Edit` or `Write` on `.dart` files:

| Hook | Behavior | Blocking? |
|---|---|---|
| `dart analyze` | Catches lint errors immediately | Yes — Claude must fix before continuing |
| `dart format` | Auto-formats the file | No — applied silently |

These complement our existing pre-commit hooks (format, analyze, codegen verification). The plugin hooks catch issues **during** Claude's work, not just at commit time.

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
| `/vgv-bloc` | VGV event naming, sealed classes, Page/View pattern | 43+ BLoCs/Cubits already follow these patterns |
| `/vgv-testing` | VGV test naming, `pumpApp`, golden test patterns | 685+ tests with mocktail, bloc_test, Patrol |
| `/vgv-navigation` | Type-safe GoRouter patterns, redirect strategies | GoRouter with `@TypedGoRoute` already in use |
| `/vgv-layered-architecture` | Validates 4-layer package structure | 23 packages already follow Data → Repo → BLoC → UI |

### Tier 3 — Use with Caution (conflicts with project constraints)

| Skill | Issue | Guidance |
|---|---|---|
| `/vgv-material-theming` | Assumes light + dark themes | Divine is **dark-mode only** — skip light theme suggestions |
| `/vgv-create-project` | Scaffolds from VGV templates | Useful for new packages, but must adapt to existing monorepo structure |

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

## 4. Per-Skill Usage Guide

### `/vgv-accessibility`

**Priority: Tier 1 — High Value**

**When to use:** Before any release, during UI reviews, or when building new screens.

**What it does:** Runs a WCAG 2.1 audit across six categories — semantics, touch targets, focus management, color contrast, text scaling, and motion sensitivity. It will ask you which WCAG level (A, AA, or AAA) and which platforms to target.

**divine-mobile adaptations:**
- Start with **Level AA** for mobile — this covers 4.5:1 contrast and 48x48dp touch targets
- Focus on `divine_ui` widgets first — fixing shared components fixes the whole app
- divine uses dark backgrounds (true black `0xFF000000`) — contrast checks against dark surfaces are critical
- Many screens use video overlays — ensure text over video has sufficient contrast or background scrim

**Example prompts:**
```
Audit the comments section for WCAG AA accessibility on mobile.
Target: mobile/lib/screens/comments/

Run an accessibility audit on the divine_ui package widgets.
Target: mobile/packages/divine_ui/
```

---

### `/vgv-internationalization`

**Priority: Tier 1 — High Value**

**When to use:** When preparing the app for multi-language support.

**What it does:** Sets up Flutter's built-in l10n system with ARB files, `context.l10n` extensions, pluralization, and RTL layout support.

**divine-mobile adaptations:**
- Start by creating the ARB infrastructure in `mobile/lib/l10n/arb/`
- Extract hardcoded strings from `divine_ui` first (shared widgets = widest impact)
- RTL support matters for directional widgets — use `EdgeInsetsDirectional` instead of `EdgeInsets`
- Brand voice strings (tone from `brand-guidelines/`) should be preserved exactly in the English ARB template
- The `intl` package is already a dependency (used for date formatting) — l10n builds on top of it

**Example prompts:**
```
Set up i18n infrastructure for divine-mobile following VGV patterns.
Start with the English template ARB file.

Extract all hardcoded strings from mobile/lib/screens/profile/ into ARB keys.
```

---

### `/vgv-license-compliance`

**Priority: Tier 1 — High Value**

**When to use:** Before releases, after adding new dependencies, or during security reviews.

**What it does:** Runs Very Good CLI's `packages_check_licenses` to audit all dependency licenses. Categorizes them as permissive (MIT, BSD, Apache), weak copyleft (LGPL, MPL), strong copyleft (GPL, AGPL), or unknown. Produces a structured compliance report.

**divine-mobile adaptations:**
- Run from `mobile/` directory (workspace root)
- Pay attention to Nostr-related packages — some may have non-standard licenses
- C2PA (`c2pa_flutter`) is a git dependency — verify its license separately
- The 23 local packages are all internal, but their transitive dependencies matter

**Example prompts:**
```
Run a license compliance audit on the divine-mobile project at mobile/

Check licenses for all dependencies in mobile/packages/nostr_sdk/
```

---

### `/vgv-static-security`

**Priority: Tier 1 — High Value**

**When to use:** During code reviews, before releases, or after touching auth/crypto/storage code.

**What it does:** Static analysis against OWASP Mobile Top 10 — checks for hardcoded secrets, insecure storage (`SharedPreferences` for tokens), plain HTTP, weak crypto (`Random()`, MD5), sensitive data in logs, disabled cert validation, and more.

**divine-mobile adaptations:**
- divine already uses `flutter_secure_storage` for auth tokens — the skill validates this
- Nostr key management (`nostr_key_manager`) handles cryptographic keys — ensure the skill checks this package
- Check for `Random()` vs `Random.secure()` in Nostr event ID generation
- Verify `android:allowBackup="false"` in AndroidManifest
- Check that `--dart-define` secrets are not logged or exposed in crash reports
- Verify encrypted bug reporting (NIP-17) doesn't leak sensitive data

**Example prompts:**
```
Run a static security review on mobile/lib/services/auth/
Focus on token storage, key management, and API communication.

Review mobile/packages/nostr_key_manager/ for cryptographic security issues.
```

---

### `/vgv-bloc`

**Priority: Tier 2 — Reinforcing**

**When to use:** When creating new BLoCs/Cubits or reviewing existing ones.

**What it does:** Enforces VGV BLoC patterns — sealed events, Page/View separation, `blocTest()` testing, event transformers, `BlocSelector` for granular rebuilds.

**divine-mobile adaptations:**
- **Error handling:** If the skill generates `String? errorMessage` in state, reject it. Use `addError()` + status enum (see Rule 1 above)
- **Status pattern:** divine-mobile uses enum status when data persists across states, sealed classes when state is fresh. The skill may default to one pattern — choose based on context
- **Event transformers:** divine-mobile already uses `sequential()`, `droppable()`, `restartable()` from `bloc_concurrency` — ensure the skill applies the right one for the use case
- **Naming:** Follow divine-mobile's convention: `BlocSubject` + `Noun` + `VerbPastTense` (e.g., `VideoFeedSubscriptionRequested`)

**Example prompts:**
```
Create a new Bloc for the bookmarks feature with subscribe, add, and remove events.
Follow the Page/View pattern. Repository: BookmarksRepository.

Review mobile/lib/blocs/video_feed/ for VGV bloc best practices.
```

---

### `/vgv-testing`

**Priority: Tier 2 — Reinforcing**

**When to use:** When writing tests for new features or reviewing test quality.

**What it does:** Enforces VGV test structure — descriptive names with string interpolation for types, hierarchical groups, `setUp` isolation, `pumpApp` helpers, golden file tagging, `mocktail` mocking patterns.

**divine-mobile adaptations:**
- divine-mobile targets **100% test coverage** — the skill should generate comprehensive tests, not just happy paths
- Golden file tests must be tagged with `TestTag.golden` and run separately
- Use `mocktail` (never `mockito`) — already enforced project-wide
- BLoC tests use `blocTest` with event ordering verification
- E2E tests use Patrol + local Docker stack — the skill covers unit/widget tests only, not E2E
- Test files mirror `lib/` structure — maintain this 1:1 mapping

**Example prompts:**
```
Write comprehensive tests for mobile/lib/blocs/likes/likes_bloc.dart
including all events and error scenarios. Target 100% coverage.

Generate widget tests for mobile/lib/screens/profile/profile_view.dart
using the pumpApp pattern and mocktail mocks.
```

---

### `/vgv-navigation`

**Priority: Tier 2 — Reinforcing**

**When to use:** When adding new routes, deep links, or refactoring navigation.

**What it does:** GoRouter patterns — `@TypedGoRoute` annotations, type-safe routes, redirect strategies, `go()` vs `push()` guidance, shell routes for tab persistence.

**divine-mobile adaptations:**
- **Never use `extra:`** — pass IDs via path/query parameters (see Rule 2)
- divine-mobile uses `ShellRoute` for bottom navigation with per-tab state preservation — new routes must integrate with this pattern
- Route observer integration is critical for video pause/resume on navigation
- Auth redirects are global — new routes automatically inherit auth gating
- Firebase Analytics observer tracks page views — new routes are automatically tracked

**Example prompts:**
```
Add a new route for /settings/notifications with a sub-route for /settings/notifications/:id
using @TypedGoRoute. Integrate with the existing ShellRoute bottom nav.

Review mobile/lib/router/ for navigation anti-patterns.
```

---

### `/vgv-layered-architecture`

**Priority: Tier 2 — Reinforcing**

**When to use:** When creating new data packages, repositories, or reviewing layer boundaries.

**What it does:** Validates VGV's 4-layer architecture — Data (API clients) → Repository → Business Logic (BLoC) → Presentation.

**divine-mobile adaptations:**
- **Fallback logic in repository only** (see Rule 3)
- New packages go in `mobile/packages/` — follow existing naming: `<domain>_repository`, `<domain>_api_client`
- No Flutter SDK imports in data/repository packages
- Use path dependencies for local packages (never `git:` or pub versions)
- Barrel exports at every boundary — never import `src/` directly
- Use `RepositoryProvider` for DI in the widget tree — constructor injection in packages
- Run `melos bootstrap` after adding new packages

**Example prompts:**
```
Create a new notifications data layer following the layered architecture:
- packages/notifications_api_client/ (data layer)
- packages/notifications_repository/ (repository layer)

Review the dependency graph of mobile/packages/ for layer violations.
```

---

### `/vgv-material-theming`

**Priority: Tier 3 — Use with Caution**

**When to use:** When adding new themed components or reviewing theme consistency.

**What it does:** Material 3 theming with `ColorScheme`, `TextTheme`, component themes, and spacing systems.

**divine-mobile adaptations:**
- **Dark mode only** — ignore any light theme suggestions (see Rule 6)
- Reference `VineTheme` (`mobile/lib/theme/app_theme.dart`) before creating new theme data
- Use `divine_ui` components (38 widgets) before building custom styled widgets
- divine-mobile uses custom fonts (Pacifico, BricolageGrotesque, Inter via Google Fonts) — don't override with system fonts
- Color system: purple accent (`0xFF8B5CF6`), true black backgrounds (`0xFF000000`)
- The skill's spacing system pattern (`AppSpacing`) could fill a gap — divine-mobile doesn't have centralized spacing constants yet

**Example prompts:**
```
Review mobile/lib/theme/app_theme.dart for Material 3 best practices.
Note: divine is dark-mode only, ignore light theme suggestions.

Add a centralized spacing system (AppSpacing) following VGV patterns
to the divine_ui package.
```

---

### `/vgv-create-project`

**Priority: Tier 3 — Use with Caution**

**When to use:** When scaffolding new packages within the monorepo.

**What it does:** Uses Very Good CLI to scaffold from templates (dart_package, flutter_package, etc.).

**divine-mobile adaptations:**
- Use `dart_package` template for data/repository packages (not `flutter_package`)
- After scaffolding, add the package to the root `pubspec.yaml` workspace
- Update `melos.yaml` if using melos commands
- Add CI workflow in `.github/workflows/` for the new package
- Ensure the scaffolded package uses `very_good_analysis` (already the project standard)

**Example prompts:**
```
Scaffold a new dart_package called "search_api_client" in mobile/packages/
for the search feature data layer. Organization: com.divine
```

---

## 5. Recommended Workflows

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

## 6. What NOT to Do

| Mistake | Why It's Wrong | What to Do Instead |
|---|---|---|
| Accept VGV `errorMessage` in BLoC state | Violates state_management rules | Use `addError()` + status enum |
| Use `extra:` in GoRouter | Breaks deep linking and web support | Pass resource IDs via path parameters |
| Let VGV generate Riverpod providers | Riverpod is legacy-only | Insist on BLoC/Cubit for all new code |
| Accept light theme from material-theming | Divine is dark-mode only | Only use dark theme variant |
| Use `Widget _buildX()` methods | Violates code_style rules | Extract to separate widget classes |
| Accept hardcoded URLs or magic numbers | Violates code_style constants rule | Extract to `Constants`/`Config` class |
| Run `/vgv-create-project` without updating workspace | New package won't be found | Add to `pubspec.yaml` workspace + melos |
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
| `mobile/lib/theme/app_theme.dart` | VineTheme dark theme definition |
| `mobile/packages/divine_ui/` | 38 shared UI components |

### Links

- [VGV Plugin Repository](https://github.com/VeryGoodOpenSource/very_good_ai_flutter_plugin)
- [VGV Claude Marketplace](https://github.com/VeryGoodOpenSource/very_good_claude_marketplace)
- [Very Good Ventures Blog Post](https://verygood.ventures/blog/very-good-ai-flutter-plugin/)
