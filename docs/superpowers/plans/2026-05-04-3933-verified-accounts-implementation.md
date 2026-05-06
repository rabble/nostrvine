# Edit profile npub demotion + external-account verifier — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Demote the npub on the edit-profile screen, render NIP-39 verified-account chips on profile screens (read path against the existing `https://verifier.divine.video` REST API), and add an in-app WebView entry point that hands off to the verifier service for the write path.

**Architecture:** Three PRs on a single feature branch (`feat/3933-verified-accounts`). Layered: UI → BLoC → Repository → Client. New `verifier_client` data-layer package wraps the verifier REST API; `profile_repository` gains an `IdentityClaimsRepository`; `MyProfileBloc` and `OtherProfileBloc` gain a `verifiedClaims` field on their `*Loaded` state; `ProfileEditorBloc` gains launch/dismiss events bridged to navigation by a UI-level `BlocListener`. No client-side caching, no retry, no rechecking — the verifier owns freshness via Cloudflare KV.

**Tech stack:** Flutter 3.x, Dart 3.x, `flutter_bloc`, `bloc_test`, `mocktail`, `http`, `webview_flutter`, `webview_flutter_wkwebview`, existing project libs (`divine_ui`, `models`, `nostr_client`, `profile_repository`, `funnelcake_api_client` pattern, `unified_logger`, `go_router`, l10n via `app_en.arb` + `flutter gen-l10n`).

**Spec:** `docs/superpowers/specs/2026-05-04-edit-profile-npub-and-verifier-design.md` (commit `610af1fcf`).

**Issue:** [divinevideo/divine-mobile#3933](https://github.com/divinevideo/divine-mobile/issues/3933).

---

## Working conventions for the implementer

Before starting any task in this plan, verify these once:

- [ ] You are in the worktree: `cd /Users/rabble/code/divine/divine-mobile/.worktrees/3933-verified-accounts`.
- [ ] You are on branch `feat/3933-verified-accounts` (`git branch --show-current`).
- [ ] Repo hooks installed: `ls .git/hooks/pre-commit .git/hooks/pre-push`. If missing, run `cd mobile && mise run setup_hooks`.
- [ ] All `flutter` / `dart` commands run from `mobile/` (e.g. `cd mobile && flutter analyze ...`).
- [ ] All new user-facing strings go through `context.l10n.xxx`. Add keys to `mobile/lib/l10n/app_en.arb` first, run `flutter gen-l10n`, then use them in widgets.
- [ ] Errors from the verifier (network, 4xx, 5xx, timeout) are EXPECTED domain failures — do **not** wrap with `Reportable`. Use plain `addError(e, stackTrace)` per `.claude/rules/error_handling.md` decision matrix.
- [ ] No error strings in BLoC state. Use status enums or sealed-state branches and `addError`.
- [ ] No methods returning `Widget`. Extract small private widget classes.
- [ ] Use `VineTheme.*` colors and `VineTheme.*Font()` text styles. No raw `Color(0x...)` or `TextStyle(...)`.
- [ ] Use `DivineIcon` not `Icons.*` / `SvgPicture.asset`.
- [ ] Each PR runs `dart format`, `flutter analyze lib test`, scoped `flutter test`, and `dart run build_runner build --delete-conflicting-outputs` if codegen inputs changed. The pre-commit hook enforces format+analyze on staged Dart files.
- [ ] Commit messages follow conventional-commit style and reference the issue. End with the `Co-Authored-By:` trailer used by the rest of the repo.
- [ ] At the end of each PR, push to `origin` and open a GitHub PR scoped to that PR's commits. Land PR1 before starting PR2; land PR2 before starting PR3 — they stack.

---

## Chunk 1: PR 1 — Demote npub on edit profile

**Goal:** Remove the labeled "Public key (npub)" `TextFormField` from edit profile, add a real npub display block at the top of the existing key management screen, and add a small "View your public key" link from edit profile to key management. No verifier dependencies in this PR.

**Files:**
- Modify: `mobile/lib/screens/profile_setup_screen.dart` (remove lines 721-763 npub block; add link to key management).
- Modify: `mobile/lib/screens/key_management_screen.dart` (insert npub display block at top of `ListView` body).
- Modify: `mobile/lib/l10n/app_en.arb` (new keys).
- Generate: `mobile/lib/l10n/generated/*.dart` via `flutter gen-l10n`.
- Test (modify): `mobile/test/screens/profile_setup_screen_test.dart` (existing).
- Test (modify or create): `mobile/test/screens/key_management_screen_test.dart`.
- Goldens: under `mobile/test/screens/goldens/` if convention there, otherwise per existing test placement (check what neighbours do).

### Task 1.1: Add l10n keys for the demoted-npub UI

**Files:**
- Modify: `mobile/lib/l10n/app_en.arb`

- [ ] **Step 1: Inventory existing keys you can reuse**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/3933-verified-accounts
grep -nE "publicKey|npub|copyKey|viewKey|keyManagement" mobile/lib/l10n/app_en.arb | head -40
```
Note any keys that already match the copy below — reuse rather than duplicate (per `.claude/rules/localization.md` "Check `app_en.arb` first").

- [ ] **Step 2: Add missing keys to `app_en.arb`**

Add (only those not already present from Step 1):

```json
"profileEditPublicKeyLink": "View your public key",
"@profileEditPublicKeyLink": {
  "description": "Secondary link on the edit profile screen that navigates to the key management screen where the user's npub lives."
},

"keyManagementYourPublicKeyLabel": "Your public key (npub)",
"@keyManagementYourPublicKeyLabel": {
  "description": "Label above the truncated npub display on the key management screen."
},

"keyManagementCopyPublicKeyTooltip": "Copy public key",
"@keyManagementCopyPublicKeyTooltip": {
  "description": "Tooltip / accessibility label for the copy-to-clipboard icon button next to the user's npub."
},

"keyManagementPublicKeyCopied": "Public key copied",
"@keyManagementPublicKeyCopied": {
  "description": "SnackBar shown after the user taps the copy icon next to their npub."
}
```

- [ ] **Step 3: Regenerate localizations**

```bash
cd mobile && flutter gen-l10n
```

Expected: no errors. Generated files updated under `mobile/lib/l10n/generated/`.

- [ ] **Step 4: Sanity grep**

```bash
grep -n "profileEditPublicKeyLink\|keyManagementYourPublicKeyLabel" mobile/lib/l10n/generated/app_localizations.dart | head
```

Expected: each new key appears as a getter on `AppLocalizations`.

- [ ] **Step 5: Stage but do NOT commit yet** (commit at end of Task 1.4 with the test).

### Task 1.2: Failing widget test — npub block on key management screen

**File (create or modify):** `mobile/test/screens/key_management_screen_test.dart`

- [ ] **Step 1: Locate or create the test file**

```bash
ls mobile/test/screens/key_management_screen_test.dart 2>/dev/null && echo "EXISTS" || echo "MISSING — create"
```

- [ ] **Step 2: Add a failing test**

Append (or write fresh, depending on Step 1) the group below. The test pumps the screen with a mocked `authServiceProvider` whose `currentNpub` returns a known value, asserts that the new label and a truncated form of the npub render, and that a copy icon button is reachable.

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/key_management_screen.dart';
// Import any existing fake/mock for AuthService used elsewhere in the
// test suite (e.g. test/helpers/mocks.dart). If none, create a private
// mock per `.claude/rules/testing.md`.

class _MockAuthService extends Mock implements AuthService {}

const _testNpub =
    'npub1abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz';

void main() {
  group(KeyManagementScreen, () {
    late _MockAuthService authService;

    setUp(() {
      authService = _MockAuthService();
      when(() => authService.currentNpub).thenReturn(_testNpub);
    });

    Widget buildSubject() {
      return ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const KeyManagementScreen(),
        ),
      );
    }

    testWidgets('renders the public key label', (tester) async {
      await tester.pumpWidget(buildSubject());
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        find.text(l10n.keyManagementYourPublicKeyLabel),
        findsOneWidget,
      );
    });

    testWidgets('renders the user npub somewhere on the screen', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      // The display is one-line truncated; the full string IS in the
      // widget tree (just clipped visually).
      expect(find.text(_testNpub), findsOneWidget);
    });

    testWidgets('copies npub to clipboard when copy button is tapped', (
      tester,
    ) async {
      String? clipboardPayload;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardPayload = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );

      await tester.pumpWidget(buildSubject());
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.tap(
        find.byTooltip(l10n.keyManagementCopyPublicKeyTooltip),
      );
      await tester.pumpAndSettle();

      expect(clipboardPayload, equals(_testNpub));
      expect(
        find.text(l10n.keyManagementPublicKeyCopied),
        findsOneWidget,
      );
    });
  });
}
```

If the existing project mocks `AuthService` differently, mirror that pattern instead of `_MockAuthService` above. Search `mobile/test/` for `MockAuthService` first.

- [ ] **Step 3: Run the test — confirm it FAILS**

```bash
cd mobile && flutter test test/screens/key_management_screen_test.dart
```

Expected: failures on all three tests (no label, no npub display, no copy button). This proves the test is wired correctly before we implement.

### Task 1.3: Implement the npub display block

**File:** `mobile/lib/screens/key_management_screen_test.dart` consumers + `mobile/lib/screens/key_management_screen.dart`

- [ ] **Step 1: Add a private widget for the npub block**

In `key_management_screen.dart`, add a private `_NpubDisplayBlock extends ConsumerWidget` at the bottom of the file (mirroring the file's existing private-widget style). It reads `ref.watch(authServiceProvider).currentNpub`, renders the label + truncated npub + a copy `IconButton` with the `keyManagementCopyPublicKeyTooltip` tooltip, and shows a `SnackBar` with `keyManagementPublicKeyCopied` on tap.

Follow these rules:

- Use `VineTheme.labelMediumFont(color: VineTheme.onSurfaceMuted)` for the label.
- Use `VineTheme.bodyMediumFont` (or whichever `*Font()` helper matches the existing screen's body text) on a `Text` with `overflow: TextOverflow.ellipsis` and `maxLines: 1` for the npub.
- Wrap the row in a `ConstrainedBox(minHeight: 48)` so the touch target on the copy button stays at the 48-dp minimum (`.claude/rules/accessibility.md`).
- Use `DivineIcon(icon: DivineIconName.copy)` (or `copyNpub` if the asset matches better visually) on the copy button.
- Wrap the whole block in `Padding` consistent with the screen's existing `EdgeInsets.fromLTRB(16, 16, 16, 16 + ...)` outer padding.
- The full npub MUST appear in the widget tree even when truncated — the existing test asserts `find.text(_testNpub)` — Flutter renders the full string and clips it visually.

Skeleton:

```dart
class _NpubDisplayBlock extends ConsumerWidget {
  const _NpubDisplayBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final npub = ref.watch(authServiceProvider).currentNpub ?? '';

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.keyManagementYourPublicKeyLabel,
                  style: VineTheme.labelMediumFont(
                    color: VineTheme.onSurfaceMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  npub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VineTheme.bodyMediumFont(),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.keyManagementCopyPublicKeyTooltip,
            icon: const DivineIcon(icon: DivineIconName.copy),
            onPressed: () => _onCopy(context, npub),
          ),
        ],
      ),
    );
  }

  Future<void> _onCopy(BuildContext context, String npub) async {
    final l10n = context.l10n;
    await Clipboard.setData(ClipboardData(text: npub));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.keyManagementPublicKeyCopied)),
    );
  }
}
```

- [ ] **Step 2: Insert the block into the screen body**

Inside `_KeyManagementScreenState.build`, add `const _NpubDisplayBlock()` as the FIRST child of the inner `ListView` (above the existing explanation card), followed by `const SizedBox(height: 24)`.

```dart
ListView(
  padding: ...,
  children: [
    const _NpubDisplayBlock(),
    const SizedBox(height: 24),
    _buildExplanationCard(),  // existing
    const SizedBox(height: 24),
    _buildImportSection(context, nostrService),
    const SizedBox(height: 24),
    _buildExportSection(context),
  ],
),
```

> Note: the existing screen uses `_build*Section` helper methods (returning `Widget`). They violate `.claude/rules/code_style.md`. **Do not refactor them in this PR** — out of scope. Only the new code (`_NpubDisplayBlock`) is required to follow the rule.

- [ ] **Step 3: Run the test — confirm it PASSES**

```bash
cd mobile && flutter test test/screens/key_management_screen_test.dart
```

Expected: all three tests in the new group pass. Existing tests unchanged.

- [ ] **Step 4: Run analyze + format**

```bash
cd mobile && dart format lib/screens/key_management_screen.dart \
  test/screens/key_management_screen_test.dart \
  lib/l10n/app_en.arb
flutter analyze lib/screens/key_management_screen.dart test/screens/key_management_screen_test.dart
```

Expected: no formatter changes after re-run, no analyzer errors / lints.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/l10n/app_en.arb \
        mobile/lib/l10n/generated \
        mobile/lib/screens/key_management_screen.dart \
        mobile/test/screens/key_management_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(profile): show npub on key management screen

Adds a "Your public key (npub)" display block with copy-to-clipboard at
the top of the key management screen. This is the canonical home for the
npub once edit profile stops displaying it. Refs #3933.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 1.4: Failing widget test — edit profile shows the link, hides the npub field

**File (modify):** `mobile/test/screens/profile_setup_screen_test.dart`

- [ ] **Step 1: Find the existing `'Public key (npub)'` assertion**

```bash
grep -n "Public key (npub)\|profileSetup\|currentNpub" mobile/test/screens/profile_setup_screen_test.dart | head -20
```

If an existing test asserts that the labeled npub field renders, that assertion must be **inverted** to assert the field is gone. If no such assertion exists, add fresh tests.

- [ ] **Step 2: Update / add tests**

Targeted assertions:

```dart
testWidgets('does not render the labeled npub field', (tester) async {
  await tester.pumpWidget(buildSubject());
  // The old labeled text:
  expect(find.text('Public key (npub)'), findsNothing);
});

testWidgets('renders a "View your public key" link', (tester) async {
  await tester.pumpWidget(buildSubject());
  final l10n = lookupAppLocalizations(const Locale('en'));
  expect(find.text(l10n.profileEditPublicKeyLink), findsOneWidget);
});

testWidgets(
  'navigates to key management when "View your public key" is tapped',
  (tester) async {
    await tester.pumpWidget(buildSubject());
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.tap(find.text(l10n.profileEditPublicKeyLink));
    await tester.pumpAndSettle();

    expect(find.byType(KeyManagementScreen), findsOneWidget);
  },
);
```

If `buildSubject()` does not already wire a `GoRouter` capable of navigating to `KeyManagementScreen`, lift the existing helper or use a `MaterialApp.router` with a small inline `GoRouter` whose routes are just `[ProfileSetupScreen.editPath]` and `[KeyManagementScreen.path]`. Mirror whatever helper neighbour widget tests already use (search `tester.pumpWidget` patterns under `mobile/test/screens`).

- [ ] **Step 3: Run — confirm FAIL**

```bash
cd mobile && flutter test test/screens/profile_setup_screen_test.dart
```

Expected: the three new assertions fail (label still present, link absent).

### Task 1.5: Implement — remove npub block, add link

**File:** `mobile/lib/screens/profile_setup_screen.dart`

- [ ] **Step 1: Delete the existing npub block**

Delete the comment + `Padding` + `TextFormField` + trailing `SizedBox` at lines 721-763. Keep the `SizedBox(height: 16)` immediately above (line 719) so the spacing above the next section is preserved.

- [ ] **Step 2: Add a new `_PublicKeyLink` private widget**

Add at the bottom of the file (after the existing private widgets):

```dart
class _PublicKeyLink extends StatelessWidget {
  const _PublicKeyLink();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        onPressed: () =>
            context.goNamed(KeyManagementScreen.routeName),
        child: Text(
          l10n.profileEditPublicKeyLink,
          style: VineTheme.labelMediumFont(color: VineTheme.primary),
        ),
      ),
    );
  }
}
```

Use `goNamed` per `.claude/rules/routing.md` ("Prefer Name Over Path"). Import `KeyManagementScreen` and `context.goNamed` extension.

- [ ] **Step 3: Insert the link where the npub block used to be**

At the position of the deleted block, insert:

```dart
const _PublicKeyLink(),
const SizedBox(height: 16),
```

- [ ] **Step 4: Run — confirm PASS**

```bash
cd mobile && flutter test test/screens/profile_setup_screen_test.dart
```

Expected: all assertions pass, including the new ones.

- [ ] **Step 5: Run analyze + format**

```bash
cd mobile && dart format lib/screens/profile_setup_screen.dart \
  test/screens/profile_setup_screen_test.dart
flutter analyze lib/screens/profile_setup_screen.dart \
  test/screens/profile_setup_screen_test.dart
```

Expected: clean.

- [ ] **Step 6: Run the full screens test directory**

```bash
cd mobile && flutter test test/screens
```

Expected: no regressions in other screen tests.

- [ ] **Step 7: Commit**

```bash
git add mobile/lib/screens/profile_setup_screen.dart \
        mobile/test/screens/profile_setup_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(profile): demote npub on edit profile

Removes the labeled "Public key (npub)" form field from the edit profile
screen and replaces it with a small "View your public key" link that
navigates to the existing key management screen, where the npub is now
displayed prominently. Refs #3933.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 1.6: Goldens for both surfaces

**Files:** existing golden directories under `mobile/test/screens` or wherever neighbour goldens for these screens live.

- [ ] **Step 1: Locate existing goldens for these two screens**

```bash
find mobile/test -path "*goldens*" -iname "*key_management*" -o -path "*goldens*" -iname "*profile_setup*" | head -20
```

If goldens exist, update them. If they don't, follow `mobile/docs/GOLDEN_TESTING_GUIDE.md` to add new golden tests using the `tags: TestTag.golden` convention.

- [ ] **Step 2: Update / add goldens**

Each golden test should pump the changed screen and call `expectLater(find.byType(...), matchesGoldenFile('...'))`. Tag with `tags: 'golden'`.

- [ ] **Step 3: Generate / regenerate goldens**

```bash
cd mobile && flutter test --tags golden --update-goldens \
  test/screens/key_management_screen_test.dart \
  test/screens/profile_setup_screen_test.dart
```

- [ ] **Step 4: Verify goldens pass without `--update-goldens`**

```bash
cd mobile && flutter test --tags golden \
  test/screens/key_management_screen_test.dart \
  test/screens/profile_setup_screen_test.dart
```

Expected: all golden tests pass.

- [ ] **Step 5: Commit**

```bash
git add mobile/test/screens/goldens \
        mobile/test/screens/key_management_screen_test.dart \
        mobile/test/screens/profile_setup_screen_test.dart
git commit -m "$(cat <<'EOF'
test(profile): goldens for npub demotion

Adds / updates goldens covering the new "Your public key" block on the
key management screen and the demoted edit-profile layout (no labeled
npub field, "View your public key" link in its place). Refs #3933.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 1.7: PR1 verification + push

- [ ] **Step 1: Full local verification**

```bash
cd mobile
dart format --output=none --set-exit-if-changed \
  lib/screens/profile_setup_screen.dart \
  lib/screens/key_management_screen.dart \
  test/screens/key_management_screen_test.dart \
  test/screens/profile_setup_screen_test.dart
flutter analyze lib test
flutter test test/screens
```

Expected: format clean, analyze clean, tests pass.

- [ ] **Step 2: Push branch**

```bash
git push -u origin feat/3933-verified-accounts
```

- [ ] **Step 3: Open PR1**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/3933-verified-accounts
gh pr create --repo divinevideo/divine-mobile \
  --title "feat(profile): demote npub on edit profile (1/3)" \
  --body "$(cat <<'EOF'
## Summary
- Removes the labeled "Public key (npub)" `TextFormField` from the edit
  profile screen.
- Adds a "Your public key (npub)" display block at the top of the
  existing key management screen with a copy-to-clipboard action.
- Adds a small "View your public key" link on edit profile that
  navigates to key management.

## Why
Edit profile should be about the things people actually edit (display
name, bio, avatar). The 60-character npub dominated the form for a
field most users don't recognize. Part 1 of 3 for #3933.

## Test plan
- [ ] Open Edit Profile — labeled npub field is gone, "View your public
  key" link is present.
- [ ] Tap link — lands on Key Management screen.
- [ ] Copy icon next to the npub on Key Management copies the full npub
  (verify via paste).
- [ ] Goldens for both screens render correctly.

Refs #3933.
EOF
)"
```

**STOP HERE — wait for PR1 review and merge before starting Chunk 2.**
PRs 2 and 3 stack on this branch but should be reviewed independently.

---

## Chunk 2: PR 2 — Read path: verifier client + verified chips

**Goal:** Add a new `verifier_client` package that calls `https://verifier.divine.video`'s REST API, extend `profile_repository` with an `IdentityClaimsRepository` that parses NIP-39 `i` tags off kind 0 and re-verifies them via the client, extend `MyProfileBloc` and `OtherProfileBloc` to expose `verifiedClaims`, and render a verified-chip row directly under the bio on both surfaces. Hide unverified claims entirely (see spec for rationale).

**Files (new):**
- Package: `mobile/packages/verifier_client/` (full package — `pubspec.yaml`, `analysis_options.yaml`, `lib/verifier_client.dart` barrel, `lib/src/verifier_client.dart`, `lib/src/exceptions.dart`, `lib/src/models/...`, `test/`).
- Repo addition: `mobile/packages/profile_repository/lib/src/identity_claim.dart`, `lib/src/identity_claims_repository.dart`, `test/identity_claims_repository_test.dart`.
- Widget: `mobile/lib/widgets/profile/verified_accounts_row.dart`, `verified_account_chip.dart`.

**Files (modify):**
- `mobile/packages/profile_repository/pubspec.yaml` (add `verifier_client` dep).
- `mobile/packages/profile_repository/lib/profile_repository.dart` (export new types).
- `mobile/packages/models/lib/src/user_profile.dart` (preserve raw event tags).
- `mobile/packages/models/test/src/user_profile_test.dart`.
- `mobile/lib/models/environment_config.dart` (add `verifierBaseUrl`).
- `mobile/lib/blocs/my_profile/my_profile_bloc.dart` + `_event.dart` + `_state.dart`.
- `mobile/lib/blocs/other_profile/other_profile_bloc.dart` + `_event.dart` + `_state.dart`.
- `mobile/lib/screens/other_profile_screen.dart` (insert chip row).
- `mobile/lib/screens/profile_setup_screen.dart` (insert chip row above the demoted-npub link area).
- Tests: corresponding test files for each modified bloc + screen + widget.
- `mobile/lib/l10n/app_en.arb` (chip semantic labels).
- `mobile/pubspec.yaml` (add `verifier_client` workspace dep).

### Task 2.1: Scaffold the `verifier_client` package

**File (create):** `mobile/packages/verifier_client/`

- [ ] **Step 1: Mirror an existing client package layout**

```bash
ls mobile/packages/funnelcake_api_client
```

Use `funnelcake_api_client` and `app_version_client` as references for `pubspec.yaml`, `analysis_options.yaml`, README pattern.

- [ ] **Step 2: Create `pubspec.yaml`**

```yaml
name: verifier_client
description: HTTP client for the Divine identity verification service (verifier.divine.video).
version: 0.1.0+1
publish_to: none

environment:
  sdk: ^3.11.0

resolution: workspace

dependencies:
  equatable: ^2.0.8
  http: ^1.2.2
  meta: ^1.16.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.4
  test: ^1.25.0
  very_good_analysis: ^10.0.0
```

- [ ] **Step 3: Create `analysis_options.yaml`**

Copy from `mobile/packages/funnelcake_api_client/analysis_options.yaml`.

- [ ] **Step 4: Create the barrel `lib/verifier_client.dart`**

```dart
// ABOUTME: Public surface for the verifier_client package.
// ABOUTME: HTTP client over https://verifier.divine.video.

export 'src/exceptions.dart';
export 'src/models/identity_claim.dart';
export 'src/models/verification_result.dart';
export 'src/verifier_client.dart';
```

- [ ] **Step 5: Add `verifier_client:` to `mobile/pubspec.yaml`**

Add the dep under `dependencies:`:

```yaml
verifier_client:
  path: packages/verifier_client
```

- [ ] **Step 6: `flutter pub get`**

```bash
cd mobile && flutter pub get
```

Expected: dependency resolution succeeds; new package appears in workspace.

### Task 2.2: Define models — `IdentityClaim`, `VerificationResult`, exceptions

**Files (create):**
- `mobile/packages/verifier_client/lib/src/models/identity_claim.dart`
- `mobile/packages/verifier_client/lib/src/models/verification_result.dart`
- `mobile/packages/verifier_client/lib/src/exceptions.dart`
- Tests under `mobile/packages/verifier_client/test/src/models/`

- [ ] **Step 1: Write failing tests first**

`test/src/models/identity_claim_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:verifier_client/verifier_client.dart';

void main() {
  group(IdentityClaim, () {
    test('encodes to verifier API JSON shape', () {
      const claim = IdentityClaim(
        pubkey: 'a' * 64,
        platform: 'github',
        identity: 'octocat',
        proof: 'abc123',
      );
      expect(claim.toJson(), {
        'pubkey': 'a' * 64,
        'platform': 'github',
        'identity': 'octocat',
        'proof': 'abc123',
      });
    });

    test('two claims with the same fields are equal', () {
      const a = IdentityClaim(
        pubkey: 'a' * 64,
        platform: 'github',
        identity: 'octocat',
        proof: 'abc123',
      );
      const b = IdentityClaim(
        pubkey: 'a' * 64,
        platform: 'github',
        identity: 'octocat',
        proof: 'abc123',
      );
      expect(a, equals(b));
    });
  });
}
```

`test/src/models/verification_result_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:verifier_client/verifier_client.dart';

void main() {
  group(VerificationResult, () {
    test('parses a verified result from JSON', () {
      final json = {
        'platform': 'github',
        'identity': 'octocat',
        'verified': true,
        'checked_at': 1700000000,
        'cached': true,
      };
      final result = VerificationResult.fromJson(json);
      expect(result.verified, isTrue);
      expect(result.platform, equals('github'));
      expect(result.identity, equals('octocat'));
      expect(result.cached, isTrue);
    });

    test('parses a failed result from JSON', () {
      final json = {
        'platform': 'twitter',
        'identity': 'fake',
        'verified': false,
        'error': 'proof not found',
        'checked_at': 1700000000,
        'cached': false,
      };
      final result = VerificationResult.fromJson(json);
      expect(result.verified, isFalse);
      expect(result.error, equals('proof not found'));
    });
  });
}
```

- [ ] **Step 2: Run tests — confirm FAIL**

```bash
cd mobile/packages/verifier_client && dart test
```

Expected: compilation errors (types don't exist).

- [ ] **Step 3: Implement models**

`lib/src/models/identity_claim.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// A single claim that a Nostr pubkey owns an external identity on a
/// supported platform.
///
/// Mirrors the verifier service's `VerifyClaim` shape in
/// `divine-identify-verification-service/src/types.ts`.
@immutable
class IdentityClaim extends Equatable {
  const IdentityClaim({
    required this.pubkey,
    required this.platform,
    required this.identity,
    required this.proof,
  });

  /// 64-character lowercase hex pubkey.
  final String pubkey;

  /// Platform identifier — one of `github | twitter | mastodon |
  /// telegram | bluesky | discord | youtube | tiktok` at the time of
  /// writing. Forward-compatible: the verifier may add platforms.
  final String platform;

  /// Platform-specific user identifier (handle, account ID).
  final String identity;

  /// Proof material (URL, post ID, OAuth token reference, …) — opaque
  /// to mobile.
  final String proof;

  Map<String, dynamic> toJson() => {
        'pubkey': pubkey,
        'platform': platform,
        'identity': identity,
        'proof': proof,
      };

  @override
  List<Object?> get props => [pubkey, platform, identity, proof];
}
```

`lib/src/models/verification_result.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// Result of asking the verifier to re-check a single [IdentityClaim].
@immutable
class VerificationResult extends Equatable {
  const VerificationResult({
    required this.platform,
    required this.identity,
    required this.verified,
    required this.checkedAt,
    required this.cached,
    this.error,
  });

  factory VerificationResult.fromJson(Map<String, dynamic> json) {
    return VerificationResult(
      platform: json['platform'] as String,
      identity: json['identity'] as String,
      verified: json['verified'] as bool,
      checkedAt: json['checked_at'] as int,
      cached: json['cached'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }

  final String platform;
  final String identity;
  final bool verified;
  final int checkedAt;
  final bool cached;
  final String? error;

  @override
  List<Object?> get props => [
        platform,
        identity,
        verified,
        checkedAt,
        cached,
        error,
      ];
}
```

`lib/src/exceptions.dart`:

```dart
/// Base class for all errors thrown by [VerifierClient].
sealed class VerifierClientException implements Exception {
  const VerifierClientException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// HTTP non-2xx response from the verifier.
final class VerifierApiException extends VerifierClientException {
  const VerifierApiException(this.statusCode, super.message);
  final int statusCode;
}

/// Request did not complete within the configured timeout.
final class VerifierTimeoutException extends VerifierClientException {
  const VerifierTimeoutException(super.message);
}

/// Network or transport error before a response could be read.
final class VerifierNetworkException extends VerifierClientException {
  const VerifierNetworkException(super.message);
}
```

- [ ] **Step 4: Run tests — confirm PASS**

```bash
cd mobile/packages/verifier_client && dart test
```

Expected: all four tests pass.

- [ ] **Step 5: Commit**

```bash
git add mobile/pubspec.yaml mobile/pubspec.lock \
        mobile/packages/verifier_client
git commit -m "$(cat <<'EOF'
feat(verifier_client): scaffold package + models

Adds the verifier_client package with IdentityClaim,
VerificationResult, and the typed exception hierarchy. Wraps
verifier.divine.video; the actual HTTP client lands in the next commit.
Refs #3933.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 2.3: Implement `VerifierClient`

**Files (create):**
- `mobile/packages/verifier_client/lib/src/verifier_client.dart`
- `mobile/packages/verifier_client/test/src/verifier_client_test.dart`

- [ ] **Step 1: Write failing client tests**

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:verifier_client/verifier_client.dart';

const _hex = 'a' * 64;

IdentityClaim _claim({String platform = 'github'}) => IdentityClaim(
      pubkey: _hex,
      platform: platform,
      identity: 'octocat',
      proof: 'abc',
    );

void main() {
  group(VerifierClient, () {
    group('verifyBatch', () {
      test('returns parsed results on 200', () async {
        final mock = MockClient((req) async {
          expect(req.method, equals('POST'));
          expect(
            req.url.toString(),
            equals('https://verifier.example/verify'),
          );
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          expect((body['claims'] as List), hasLength(1));
          return http.Response(
            jsonEncode({
              'results': [
                {
                  'platform': 'github',
                  'identity': 'octocat',
                  'verified': true,
                  'checked_at': 1,
                  'cached': true,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );

        final results = await client.verifyBatch([_claim()]);
        expect(results, hasLength(1));
        expect(results.single.verified, isTrue);
      });

      test('returns empty list when given empty input', () async {
        final mock = MockClient((req) async {
          fail('client should not hit the network for an empty batch');
        });
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );
        expect(await client.verifyBatch(const []), isEmpty);
      });

      test('throws VerifierApiException on 4xx', () async {
        final mock = MockClient((_) async => http.Response('bad', 400));
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );
        await expectLater(
          () => client.verifyBatch([_claim()]),
          throwsA(isA<VerifierApiException>()),
        );
      });

      test('throws VerifierApiException on 429', () async {
        final mock = MockClient((_) async => http.Response('rl', 429));
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );
        await expectLater(
          () => client.verifyBatch([_claim()]),
          throwsA(
            isA<VerifierApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              429,
            ),
          ),
        );
      });

      test('throws VerifierApiException on 5xx', () async {
        final mock = MockClient((_) async => http.Response('boom', 500));
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );
        await expectLater(
          () => client.verifyBatch([_claim()]),
          throwsA(isA<VerifierApiException>()),
        );
      });

      test('rejects batches over the server cap', () async {
        final mock = MockClient((_) async {
          fail('client should reject before hitting the network');
        });
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );
        final tooMany =
            List<IdentityClaim>.generate(11, (_) => _claim());
        await expectLater(
          () => client.verifyBatch(tooMany),
          throwsArgumentError,
        );
      });
    });

    group('verifySingle', () {
      test('posts a flat object to /verify/single', () async {
        final mock = MockClient((req) async {
          expect(
            req.url.toString(),
            equals('https://verifier.example/verify/single'),
          );
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          expect(body['platform'], equals('github'));
          expect(body['pubkey'], equals(_hex));
          return http.Response(
            jsonEncode({
              'platform': 'github',
              'identity': 'octocat',
              'verified': true,
              'checked_at': 1,
              'cached': true,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );
        final result = await client.verifySingle(_claim());
        expect(result.verified, isTrue);
      });
    });
  });
}
```

- [ ] **Step 2: Run — confirm FAIL**

```bash
cd mobile/packages/verifier_client && dart test
```

- [ ] **Step 3: Implement `VerifierClient`**

`lib/src/verifier_client.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:verifier_client/src/exceptions.dart';
import 'package:verifier_client/src/models/identity_claim.dart';
import 'package:verifier_client/src/models/verification_result.dart';

/// HTTP client for `https://verifier.divine.video`.
///
/// Stateless: every call hits the network. The verifier owns
/// freshness via Cloudflare KV; intentionally no client-side cache,
/// no retry, no rechecking.
class VerifierClient {
  VerifierClient({
    required String baseUrl,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 10),
  })  : _baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        _httpClient = httpClient ?? http.Client(),
        _timeout = timeout;

  /// Server-side cap from
  /// `divine-identify-verification-service/src/routes/verify.ts:12`.
  /// Keep this in sync if the service raises it.
  static const int maxBatchSize = 10;

  final String _baseUrl;
  final http.Client _httpClient;
  final Duration _timeout;

  /// Re-verifies a batch of claims. Returns one result per input claim
  /// in the order the verifier responds (typically input order).
  ///
  /// Returns an empty list when [claims] is empty without hitting the
  /// network.
  ///
  /// Throws:
  /// * [ArgumentError] if [claims] has more than [maxBatchSize] items.
  /// * [VerifierApiException] for any non-2xx response.
  /// * [VerifierTimeoutException] if the request does not complete
  ///   within the configured timeout.
  /// * [VerifierNetworkException] for transport-level failures.
  Future<List<VerificationResult>> verifyBatch(
    List<IdentityClaim> claims,
  ) async {
    if (claims.isEmpty) return const [];
    if (claims.length > maxBatchSize) {
      throw ArgumentError.value(
        claims.length,
        'claims',
        'must contain at most $maxBatchSize items',
      );
    }
    final body = jsonEncode({
      'claims': claims.map((c) => c.toJson()).toList(),
    });
    final json = await _post('/verify', body);
    final results = (json['results'] as List).cast<Map<String, dynamic>>();
    return results.map(VerificationResult.fromJson).toList();
  }

  /// Re-verifies a single claim via `/verify/single`.
  ///
  /// Throws the same exceptions as [verifyBatch].
  Future<VerificationResult> verifySingle(IdentityClaim claim) async {
    final body = jsonEncode(claim.toJson());
    final json = await _post('/verify/single', body);
    return VerificationResult.fromJson(json);
  }

  Future<Map<String, dynamic>> _post(String path, String body) async {
    final uri = Uri.parse('$_baseUrl$path');
    try {
      final res = await _httpClient
          .post(
            uri,
            headers: const {'content-type': 'application/json'},
            body: body,
          )
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw VerifierApiException(
          res.statusCode,
          'verifier returned ${res.statusCode}: ${res.body}',
        );
      }
      return jsonDecode(res.body) as Map<String, dynamic>;
    } on VerifierClientException {
      rethrow;
    } on TimeoutException catch (e) {
      throw VerifierTimeoutException(e.toString());
    } on SocketException catch (e) {
      throw VerifierNetworkException(e.toString());
    } on http.ClientException catch (e) {
      throw VerifierNetworkException(e.toString());
    }
  }

  @visibleForTesting
  http.Client get debugHttpClient => _httpClient;
}
```

- [ ] **Step 4: Run — confirm PASS**

```bash
cd mobile/packages/verifier_client && dart test
```

Expected: all tests pass.

- [ ] **Step 5: Format + analyze**

```bash
cd mobile/packages/verifier_client
dart format --output=none --set-exit-if-changed lib test
dart analyze
```

- [ ] **Step 6: Commit**

```bash
git add mobile/packages/verifier_client
git commit -m "$(cat <<'EOF'
feat(verifier_client): HTTP client with batch + single verify

Implements VerifierClient.verifyBatch and verifySingle against
verifier.divine.video. Stateless — server owns freshness via KV cache.
Maps timeouts and transport errors to typed exceptions; rejects
oversized batches client-side to match MAX_BATCH_SIZE on the worker.
Refs #3933.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 2.4: Add `verifierBaseUrl` to `EnvironmentConfig`

**File (modify):** `mobile/lib/models/environment_config.dart` + corresponding test.

- [ ] **Step 1: Find existing test**

```bash
ls mobile/test/models/environment_config_test.dart 2>/dev/null \
  || find mobile/test -name "environment_config*" | head
```

- [ ] **Step 2: Add a failing test**

```dart
test('verifierBaseUrl returns production URL by default', () {
  const config = EnvironmentConfig(environment: AppEnvironment.production);
  expect(config.verifierBaseUrl, equals('https://verifier.divine.video'));
});

test('verifierBaseUrl is the same across environments (no local stub)', () {
  // The verifier service is not part of local_stack; mobile points
  // every environment at the live verifier so the in-app WebView and
  // verification calls work consistently.
  for (final env in AppEnvironment.values) {
    final config = EnvironmentConfig(environment: env);
    expect(config.verifierBaseUrl, equals('https://verifier.divine.video'));
  }
});
```

If the second test feels wrong for the implementer (e.g. there's a staging verifier), update the spec and the implementation in lockstep — but the spec assumes production-only for v1.

- [ ] **Step 3: Run — confirm FAIL**

```bash
cd mobile && flutter test test/models/environment_config_test.dart
```

- [ ] **Step 4: Implement**

In `mobile/lib/models/environment_config.dart`, add:

```dart
/// Base URL for the Divine identity verification service
/// (verifier.divine.video). Single host across all environments — the
/// service is not part of local_stack.
String get verifierBaseUrl => 'https://verifier.divine.video';
```

- [ ] **Step 5: Run — confirm PASS**

```bash
cd mobile && flutter test test/models/environment_config_test.dart
```

- [ ] **Step 6: Format + analyze + commit**

```bash
cd mobile
dart format lib/models/environment_config.dart \
  test/models/environment_config_test.dart
flutter analyze lib/models/environment_config.dart \
  test/models/environment_config_test.dart
cd ..
git add mobile/lib/models/environment_config.dart \
        mobile/test/models/environment_config_test.dart
git commit -m "$(cat <<'EOF'
feat(env): expose verifierBaseUrl for verifier.divine.video

Refs #3933.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 2.5: Preserve raw event tags on `UserProfile`

**Why:** `UserProfile.fromNostrEvent` currently parses kind 0 `content` JSON but discards `event.tags`. NIP-39 `i` tags live on the event tags, so we need to preserve them to feed into `IdentityClaimsRepository.parseClaims`.

**Files (modify):**
- `mobile/packages/models/lib/src/user_profile.dart`
- `mobile/packages/models/test/src/user_profile_test.dart`

- [ ] **Step 1: Failing test**

```dart
test('UserProfile.fromNostrEvent preserves event tags', () {
  final event = Event(
    'pubhex',
    0,
    [
      ['i', 'github:octocat', 'abc123'],
      ['i', 'twitter:elonmusk', 'def456'],
      ['p', 'somepubkey'],
    ],
    '{"name":"alice"}',
  );
  final profile = UserProfile.fromNostrEvent(event);
  expect(profile.rawTags, hasLength(3));
  expect(profile.rawTags.first, equals(['i', 'github:octocat', 'abc123']));
});

test('UserProfile.fromNostrEvent defaults rawTags to const [] on bad JSON', () {
  final event = Event('pub', 0, const [], 'not-json');
  final profile = UserProfile.fromNostrEvent(event);
  expect(profile.rawTags, isEmpty);
});
```

(Adjust `Event(...)` constructor to whatever the test suite uses — search neighbour tests for the Event constructor pattern in models tests.)

- [ ] **Step 2: Run — confirm FAIL**

```bash
cd mobile && flutter test packages/models/test/src/user_profile_test.dart
```

- [ ] **Step 3: Implement**

In `lib/src/user_profile.dart`:

1. Add a `final List<List<String>> rawTags;` field to the constructor's required list, with a default of `const []`.
2. In `factory UserProfile.fromNostrEvent`, populate `rawTags: List<List<String>>.from(event.tags.map((t) => List<String>.from(t)))` in the success branch and `rawTags: const []` in the `FormatException` fallback.
3. Update `factory UserProfile.fromJson` to read `rawTags` from `json['raw_tags']` if present, defaulting to `const []`. Update the database row factory too if it serializes profiles.
4. Update `props` to include `rawTags`.

- [ ] **Step 4: Run — confirm PASS**

```bash
cd mobile && flutter test packages/models/test/src/user_profile_test.dart
```

- [ ] **Step 5: Run the full models package tests**

```bash
cd mobile/packages/models && dart test
```

Expected: no regressions in other UserProfile tests. If existing JSON / DB tests fail because they don't include the new field, update them to assert the default empty list (matching the constructor default).

- [ ] **Step 6: Format + analyze + commit**

```bash
cd mobile
dart format packages/models/lib/src/user_profile.dart \
  packages/models/test/src/user_profile_test.dart
flutter analyze packages/models
cd ..
git add mobile/packages/models
git commit -m "$(cat <<'EOF'
feat(models): preserve raw event tags on UserProfile

Adds UserProfile.rawTags so downstream consumers (NIP-39 identity claim
parsing) can inspect kind 0 tags without re-fetching the event. Refs
#3933.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 2.6: `IdentityClaimsRepository.parseClaims`

**Files (create):**
- `mobile/packages/profile_repository/lib/src/identity_claim.dart` — re-exports `IdentityClaim` from `verifier_client` so the repository's surface stays cohesive.
- `mobile/packages/profile_repository/lib/src/identity_claims_repository.dart`
- `mobile/packages/profile_repository/test/src/identity_claims_repository_test.dart`
- Modify: `mobile/packages/profile_repository/pubspec.yaml` (add `verifier_client:` dep).
- Modify: `mobile/packages/profile_repository/lib/profile_repository.dart` (export the new types).

- [ ] **Step 1: Add dep + run pub**

```bash
# In profile_repository/pubspec.yaml under dependencies:
#   verifier_client:
#     path: ../verifier_client
cd mobile && flutter pub get
```

- [ ] **Step 2: Failing parser tests**

```dart
import 'package:profile_repository/profile_repository.dart';
import 'package:test/test.dart';

void main() {
  group('IdentityClaimsRepository.parseClaims', () {
    const pubkey =
        '1111111111111111111111111111111111111111111111111111111111111111';

    test('extracts well-formed i tags', () {
      final tags = [
        ['i', 'github:octocat', 'abc'],
        ['i', 'twitter:elon', 'def'],
      ];
      final claims = IdentityClaimsRepository.parseClaims(pubkey, tags);
      expect(claims, hasLength(2));
      expect(claims.first.platform, equals('github'));
      expect(claims.first.identity, equals('octocat'));
      expect(claims.first.proof, equals('abc'));
    });

    test('skips tags whose name is not "i"', () {
      final tags = [
        ['p', 'somepubkey'],
        ['i', 'github:octocat', 'abc'],
      ];
      expect(
        IdentityClaimsRepository.parseClaims(pubkey, tags),
        hasLength(1),
      );
    });

    test('skips i tags without a platform:identity prefix', () {
      final tags = [
        ['i', 'no_colon_here', 'abc'],
        ['i', '', 'abc'],
      ];
      expect(
        IdentityClaimsRepository.parseClaims(pubkey, tags),
        isEmpty,
      );
    });

    test('skips i tags missing a proof', () {
      final tags = [
        ['i', 'github:octocat'],
      ];
      expect(
        IdentityClaimsRepository.parseClaims(pubkey, tags),
        isEmpty,
      );
    });

    test('dedupes by case-insensitive platform:identity, keeping first', () {
      final tags = [
        ['i', 'GitHub:Octocat', 'first'],
        ['i', 'github:octocat', 'second'],
      ];
      final claims = IdentityClaimsRepository.parseClaims(pubkey, tags);
      expect(claims, hasLength(1));
      expect(claims.single.proof, equals('first'));
    });

    test('caps the result at 10 to match server MAX_BATCH_SIZE', () {
      final tags = List<List<String>>.generate(
        15,
        (i) => ['i', 'github:user$i', 'p$i'],
      );
      final claims = IdentityClaimsRepository.parseClaims(pubkey, tags);
      expect(claims, hasLength(10));
    });

    test('attaches the pubkey to each claim', () {
      final tags = [
        ['i', 'github:octocat', 'abc'],
      ];
      expect(
        IdentityClaimsRepository.parseClaims(pubkey, tags).single.pubkey,
        equals(pubkey),
      );
    });
  });
}
```

- [ ] **Step 3: Run — confirm FAIL**

```bash
cd mobile/packages/profile_repository && dart test
```

- [ ] **Step 4: Implement**

`lib/src/identity_claims_repository.dart`:

```dart
import 'package:verifier_client/verifier_client.dart';

/// Composes [VerifierClient] with NIP-39 `i` tag parsing off kind 0
/// events.
class IdentityClaimsRepository {
  IdentityClaimsRepository({required VerifierClient verifierClient})
      : _verifierClient = verifierClient;

  final VerifierClient _verifierClient;

  /// Parses NIP-39 identity claims out of the given kind-0 event tag
  /// list.
  ///
  /// Filters to `['i', '<platform>:<identity>', '<proof>']` shape,
  /// skips malformed entries, dedupes case-insensitively on
  /// `<platform>:<identity>` (preferring the first occurrence — matches
  /// verifier UI behaviour at
  /// `divine-identify-verification-service/src/index.ts:1784`), caps at
  /// [VerifierClient.maxBatchSize] (10) so a single batch suffices.
  static List<IdentityClaim> parseClaims(
    String pubkey,
    List<List<String>> tags,
  ) {
    final seen = <String>{};
    final claims = <IdentityClaim>[];
    for (final tag in tags) {
      if (tag.isEmpty || tag[0] != 'i') continue;
      if (tag.length < 3) continue;
      final claimKey = tag[1];
      final colon = claimKey.indexOf(':');
      if (colon <= 0 || colon == claimKey.length - 1) continue;
      final platform = claimKey.substring(0, colon);
      final identity = claimKey.substring(colon + 1);
      final dedupeKey = '$platform:$identity'.toLowerCase();
      if (!seen.add(dedupeKey)) continue;
      claims.add(
        IdentityClaim(
          pubkey: pubkey,
          platform: platform,
          identity: identity,
          proof: tag[2],
        ),
      );
      if (claims.length >= VerifierClient.maxBatchSize) break;
    }
    return claims;
  }

  /// Parses claims from [tags] and asks the verifier to re-check them.
  /// Returns only the verified ones (preserving order).
  ///
  /// Throws [VerifierClientException] subtypes — callers should catch
  /// and emit empty / failure state without surfacing the message.
  Future<List<IdentityClaim>> verifiedClaims({
    required String pubkey,
    required List<List<String>> tags,
  }) async {
    final claims = parseClaims(pubkey, tags);
    if (claims.isEmpty) return const [];
    final results = await _verifierClient.verifyBatch(claims);
    final verifiedKeys = <String>{
      for (final r in results)
        if (r.verified)
          '${r.platform.toLowerCase()}:${r.identity.toLowerCase()}',
    };
    return claims
        .where(
          (c) =>
              verifiedKeys.contains('${c.platform.toLowerCase()}:${c.identity.toLowerCase()}'),
        )
        .toList();
  }
}
```

`lib/src/identity_claim.dart`:

```dart
// Re-export so callers of profile_repository have one cohesive surface.
export 'package:verifier_client/verifier_client.dart'
    show IdentityClaim, VerificationResult, VerifierClient,
        VerifierClientException, VerifierApiException,
        VerifierTimeoutException, VerifierNetworkException;
```

Then in `lib/profile_repository.dart` add:

```dart
export 'src/identity_claim.dart';
export 'src/identity_claims_repository.dart';
```

- [ ] **Step 5: Add `verifiedClaims` tests with a mock VerifierClient**

```dart
class _MockVerifierClient extends Mock implements VerifierClient {}

void main() {
  group(IdentityClaimsRepository, () {
    setUpAll(() {
      registerFallbackValue(<IdentityClaim>[]);
    });

    group('verifiedClaims', () {
      late _MockVerifierClient client;
      late IdentityClaimsRepository repo;

      setUp(() {
        client = _MockVerifierClient();
        repo = IdentityClaimsRepository(verifierClient: client);
      });

      test('returns only claims the verifier confirmed', () async {
        const pubkey = 'a' * 64;
        when(() => client.verifyBatch(any())).thenAnswer(
          (_) async => [
            VerificationResult(
              platform: 'github',
              identity: 'octocat',
              verified: true,
              checkedAt: 1,
              cached: true,
            ),
            VerificationResult(
              platform: 'twitter',
              identity: 'fake',
              verified: false,
              checkedAt: 1,
              cached: false,
            ),
          ],
        );
        final result = await repo.verifiedClaims(
          pubkey: pubkey,
          tags: [
            ['i', 'github:octocat', 'a'],
            ['i', 'twitter:fake', 'b'],
          ],
        );
        expect(result, hasLength(1));
        expect(result.single.platform, equals('github'));
      });

      test('returns empty when there are no i tags', () async {
        final result = await repo.verifiedClaims(
          pubkey: 'a' * 64,
          tags: const [
            ['p', 'someone'],
          ],
        );
        expect(result, isEmpty);
        verifyNever(() => client.verifyBatch(any()));
      });

      test('propagates VerifierApiException', () async {
        when(() => client.verifyBatch(any())).thenThrow(
          const VerifierApiException(500, 'boom'),
        );
        await expectLater(
          () => repo.verifiedClaims(
            pubkey: 'a' * 64,
            tags: [
              ['i', 'github:octocat', 'abc'],
            ],
          ),
          throwsA(isA<VerifierApiException>()),
        );
      });
    });
  });
}
```

- [ ] **Step 6: Run — confirm PASS**

```bash
cd mobile/packages/profile_repository && dart test
```

- [ ] **Step 7: Format + analyze + commit**

```bash
cd mobile/packages/profile_repository
dart format --output=none --set-exit-if-changed lib test
dart analyze
cd ../../..
git add mobile/packages/profile_repository
git commit -m "$(cat <<'EOF'
feat(profile_repository): IdentityClaimsRepository (NIP-39 i tags)

Adds parseClaims and verifiedClaims, composing VerifierClient over
kind-0 i tags. Returns only verifier-confirmed claims; propagates
VerifierClientException for the BLoC layer to map to empty state. Refs
#3933.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 2.7: Wire `IdentityClaimsRepository` into the app composition root

**Files (modify):**
- `mobile/lib/providers/app_providers.dart` (or wherever `profileRepositoryProvider` lives — verify with grep).

- [ ] **Step 1: Locate the existing repository wiring**

```bash
grep -rn "ProfileRepository(" mobile/lib/providers | head
grep -rn "profileRepositoryProvider" mobile/lib/providers | head
```

- [ ] **Step 2: Add a `verifierClientProvider` and `identityClaimsRepositoryProvider`**

Riverpod is the existing provider system. Add (functional providers, mirroring existing patterns):

```dart
final verifierClientProvider = Provider<VerifierClient>((ref) {
  final env = ref.watch(environmentConfigProvider);
  return VerifierClient(baseUrl: env.verifierBaseUrl);
});

final identityClaimsRepositoryProvider =
    Provider<IdentityClaimsRepository>((ref) {
  final client = ref.watch(verifierClientProvider);
  return IdentityClaimsRepository(verifierClient: client);
});
```

Place in the same file as `profileRepositoryProvider` (or a colocated provider file — match the surrounding convention).

- [ ] **Step 3: Add a `Provider` test if neighbour providers have one**

```bash
ls mobile/test/providers
```

If there's an existing test pattern, add one for the new provider (asserts construction with the default base URL).

- [ ] **Step 4: Format + analyze + commit**

```bash
cd mobile && dart format lib/providers && flutter analyze lib/providers
cd ..
git add mobile/lib/providers
git commit -m "$(cat <<'EOF'
feat(app): wire VerifierClient + IdentityClaimsRepository

Refs #3933.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 2.8: Extend `MyProfileBloc` with `verifiedClaims`

**Files (modify):**
- `mobile/lib/blocs/my_profile/my_profile_bloc.dart`
- `mobile/lib/blocs/my_profile/my_profile_event.dart`
- `mobile/lib/blocs/my_profile/my_profile_state.dart`
- `mobile/test/blocs/my_profile/my_profile_bloc_test.dart`

The existing state uses sealed classes with a `MyProfileLoaded` final class.

- [ ] **Step 1: Failing tests**

Add tests in the existing bloc test file (or create groups) covering:

```dart
blocTest<MyProfileBloc, MyProfileState>(
  'attaches verifiedClaims to MyProfileLoaded after VerifiedClaimsRequested',
  setUp: () {
    when(() => identityClaimsRepository.verifiedClaims(
          pubkey: any(named: 'pubkey'),
          tags: any(named: 'tags'),
        )).thenAnswer((_) async => [
          IdentityClaim(
            pubkey: 'a' * 64,
            platform: 'github',
            identity: 'octocat',
            proof: 'abc',
          ),
        ]);
  },
  build: () => MyProfileBloc(/* injected deps including identityClaimsRepository */),
  seed: () => MyProfileLoaded(
    profile: _profileWithITag(),
    isFresh: true,
  ),
  act: (bloc) => bloc.add(const VerifiedClaimsRequested()),
  expect: () => [
    isA<MyProfileLoaded>().having(
      (s) => s.verifiedClaims,
      'verifiedClaims',
      hasLength(1),
    ),
  ],
);

blocTest<MyProfileBloc, MyProfileState>(
  'leaves verifiedClaims empty when verifier throws',
  setUp: () {
    when(() => identityClaimsRepository.verifiedClaims(
          pubkey: any(named: 'pubkey'),
          tags: any(named: 'tags'),
        )).thenThrow(const VerifierApiException(500, 'boom'));
  },
  build: () => MyProfileBloc(/* deps */),
  seed: () => MyProfileLoaded(
    profile: _profileWithITag(),
    isFresh: true,
  ),
  act: (bloc) => bloc.add(const VerifiedClaimsRequested()),
  expect: () => [
    isA<MyProfileLoaded>().having(
      (s) => s.verifiedClaims,
      'verifiedClaims',
      isEmpty,
    ),
  ],
  errors: () => [isA<VerifierApiException>()],
);
```

(Match the bloc's existing constructor signature and seed-state helpers — read the existing tests in `my_profile_bloc_test.dart` first.)

- [ ] **Step 2: Run — confirm FAIL**

- [ ] **Step 3: Implement**

In `my_profile_state.dart`, add `final List<IdentityClaim> verifiedClaims` to `MyProfileLoaded` (default `const []`), update `props`, update any `copyWith`-equivalent helper, and re-export `IdentityClaim` (or import where needed).

In `my_profile_event.dart`:

```dart
final class VerifiedClaimsRequested extends MyProfileEvent {
  const VerifiedClaimsRequested();
}
```

In `my_profile_bloc.dart`:

1. Add `IdentityClaimsRepository` to the constructor (required, injected).
2. `on<VerifiedClaimsRequested>(_onVerifiedClaimsRequested)`.
3. Handler reads the current state if it's `MyProfileLoaded`, calls `_identityClaimsRepository.verifiedClaims(pubkey: state.profile.pubkey, tags: state.profile.rawTags)`, emits a copy of the loaded state with the new list. On error, `addError(e, st)` and emit a copy with `verifiedClaims: const []` to be explicit about the state.

> Per `.claude/rules/error_handling.md` decision matrix: verifier failures (network/4xx/5xx/timeout) are EXPECTED domain errors. Use plain `addError(e, stackTrace)` — do **not** wrap with `Reportable`.

- [ ] **Step 4: Run — confirm PASS**

- [ ] **Step 5: Format + analyze + commit**

```bash
cd mobile && dart format lib/blocs/my_profile test/blocs/my_profile
flutter analyze lib/blocs/my_profile test/blocs/my_profile
cd ..
git add mobile/lib/blocs/my_profile mobile/test/blocs/my_profile
git commit -m "$(cat <<'EOF'
feat(my_profile): expose verifiedClaims on MyProfileLoaded

Adds VerifiedClaimsRequested + IdentityClaimsRepository injection.
Verifier failures emit empty list and addError without Reportable
(expected domain failure). Refs #3933.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 2.9: Same extension for `OtherProfileBloc`

Mirror Task 2.8 against `mobile/lib/blocs/other_profile/`. Same shape: new `VerifiedClaimsRequested` event, new `verifiedClaims` field on `OtherProfileLoaded`, `IdentityClaimsRepository` injected.

- [ ] Add failing tests.
- [ ] Implement.
- [ ] Tests pass.
- [ ] Format + analyze.
- [ ] Commit:

```
feat(other_profile): expose verifiedClaims on OtherProfileLoaded
```

### Task 2.10: Auto-dispatch `VerifiedClaimsRequested` after a Loaded state

In each bloc, after a successful kind-0 fetch transitions to `*Loaded`, the bloc should emit a follow-up `VerifiedClaimsRequested` automatically so the UI doesn't have to.

- [ ] **Step 1: Add a test asserting two state emissions** — first the `Loaded` without `verifiedClaims`, then a `Loaded` with the verified list — for a single profile-fetch event.
- [ ] **Step 2: Implement** — at the end of each `on<...>` handler that emits `*Loaded`, `add(const VerifiedClaimsRequested())` (or call the handler directly inside the same emit chain — pick whichever matches the existing bloc's style).
- [ ] **Step 3: Run, format, analyze, commit:**

```
feat(profile blocs): auto-fetch verifiedClaims after kind 0 load
```

### Task 2.11: `_VerifiedAccountsRow` widget (chip row)

**Files (create):**
- `mobile/lib/widgets/profile/verified_accounts_row.dart`
- `mobile/lib/widgets/profile/verified_account_chip.dart`
- `mobile/test/widgets/profile/verified_accounts_row_test.dart`
- `mobile/test/widgets/profile/verified_account_chip_test.dart`
- `mobile/lib/l10n/app_en.arb` — add semantic-label keys.

- [ ] **Step 1: l10n keys**

```json
"verifiedAccountsSemanticLabel": "Verified {platform} account: {identity}",
"@verifiedAccountsSemanticLabel": {
  "description": "Screen reader label for a verified-account chip on a user's profile.",
  "placeholders": {
    "platform": { "type": "String" },
    "identity": { "type": "String" }
  }
}
```

Run `flutter gen-l10n`.

- [ ] **Step 2: Failing widget tests**

`verified_account_chip_test.dart`:

```dart
testWidgets('renders platform name and identity', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: VerifiedAccountChip(
          claim: IdentityClaim(
            pubkey: 'a' * 64,
            platform: 'github',
            identity: 'octocat',
            proof: 'abc',
          ),
        ),
      ),
    ),
  );
  expect(find.textContaining('octocat'), findsOneWidget);
});

testWidgets('opens external URL when tapped', (tester) async {
  String? launched;
  // Inject a launcher via constructor or a static seam — see existing
  // `urlLauncher`-style abstractions used in the project.
  ...
});

testWidgets('exposes a semantic label including platform and identity',
    (tester) async {
  ...
});
```

`verified_accounts_row_test.dart`:

```dart
testWidgets('renders nothing when claims is empty', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: VerifiedAccountsRow(claims: const []),
      ),
    ),
  );
  expect(find.byType(VerifiedAccountChip), findsNothing);
});

testWidgets('renders one chip per claim', (tester) async {
  ...
});
```

- [ ] **Step 3: Run — confirm FAIL**

- [ ] **Step 4: Implement**

`verified_account_chip.dart` — small `StatelessWidget` that takes an `IdentityClaim`, renders:
- `Container` with `VineTheme.surfaceBackground` background, rounded border, `EdgeInsets.symmetric(horizontal: 12, vertical: 6)`.
- `Row(spacing: 6, mainAxisSize: MainAxisSize.min, children: [DivineIcon(icon: DivineIconName.linkSimple, size: 14), Text('${claim.platform}/${claim.identity}', style: VineTheme.labelMediumFont())])`.
- Wrap in `Semantics(button: true, label: l10n.verifiedAccountsSemanticLabel(claim.platform, claim.identity))`.
- Wrap that in an `InkWell` whose `onTap` calls a `UrlLauncher` abstraction (use the existing `url_launcher` calls in the codebase — search `mobile/lib` for the pattern). Build the URL via a small private helper:

```dart
String _platformUrl(IdentityClaim claim) {
  switch (claim.platform.toLowerCase()) {
    case 'github':
      return 'https://github.com/${claim.identity}';
    case 'twitter':
      return 'https://twitter.com/${claim.identity}';
    case 'mastodon':
      // identity format is `instance/@user/<id>`; just hand off to verifier.
      return 'https://verifier.divine.video/u?platform=${claim.platform}&identity=${Uri.encodeComponent(claim.identity)}';
    case 'bluesky':
      return 'https://bsky.app/profile/${claim.identity}';
    case 'youtube':
      return 'https://youtube.com/@${claim.identity}';
    case 'tiktok':
      return 'https://tiktok.com/@${claim.identity}';
    case 'discord':
    case 'telegram':
    default:
      // No clean cross-platform deep link; route through the verifier
      // lookup page.
      return 'https://verifier.divine.video/u?platform=${claim.platform}&identity=${Uri.encodeComponent(claim.identity)}';
  }
}
```

If a more elegant abstraction already exists (a `PlatformLinks` util in models or similar), prefer that.

`verified_accounts_row.dart`:

```dart
class VerifiedAccountsRow extends StatelessWidget {
  const VerifiedAccountsRow({required this.claims, super.key});

  final List<IdentityClaim> claims;

  @override
  Widget build(BuildContext context) {
    if (claims.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in claims) VerifiedAccountChip(claim: c),
      ],
    );
  }
}
```

- [ ] **Step 5: Run — confirm PASS**

- [ ] **Step 6: Format + analyze + commit**

```
feat(profile): VerifiedAccountsRow chip widgets
```

### Task 2.12: Render the chip row on the public profile (`other_profile_screen.dart`)

- [ ] **Step 1: Locate the bio area in `other_profile_screen.dart`**

```bash
grep -n "about\|bio\|displayName\|UserProfile" mobile/lib/screens/other_profile_screen.dart | head -20
```

- [ ] **Step 2: Failing test** (in `mobile/test/screens/other_profile_screen_test.dart`):

```dart
testWidgets('renders verified account chips when present', (tester) async {
  // Pump the screen with an OtherProfileBloc seeded with a Loaded
  // state that has verifiedClaims = [<github>].
  ...
  expect(find.byType(VerifiedAccountChip), findsOneWidget);
});

testWidgets('renders no chip row when verifiedClaims is empty', (tester) async {
  ...
  expect(find.byType(VerifiedAccountsRow), findsOneWidget);
  expect(find.byType(VerifiedAccountChip), findsNothing);
});
```

- [ ] **Step 3: Run — confirm FAIL**

- [ ] **Step 4: Implement** — read state via `BlocSelector<OtherProfileBloc, OtherProfileState, List<IdentityClaim>>` (per `.claude/rules/state_management.md` granular rebuilds) and render `VerifiedAccountsRow(claims: ...)` directly under the bio.

- [ ] **Step 5: Run, format, analyze, commit:**

```
feat(profile): render verified chips on other profile
```

### Task 2.13: Render the chip row on edit profile

Mirror Task 2.12 against `mobile/lib/screens/profile_setup_screen.dart`. Insert the row between the bio and the demoted-`_PublicKeyLink`.

- [ ] Failing tests for present / empty cases.
- [ ] Implement.
- [ ] Tests + format + analyze.
- [ ] Commit:

```
feat(profile): render verified chips on edit profile
```

### Task 2.14: Goldens for the chip surfaces

- [ ] **Step 1: Update / add goldens** for `verified_account_chip_test.dart`, `verified_accounts_row_test.dart`, the `other_profile_screen` golden, and the `profile_setup_screen` golden.

- [ ] **Step 2: `flutter test --tags golden --update-goldens` then re-run without the flag.**

- [ ] **Step 3: Commit:**

```
test(profile): goldens for verified-account chips
```

### Task 2.15: PR2 verification + push

- [ ] **Step 1: Full local verification**

```bash
cd mobile
dart format --output=none --set-exit-if-changed lib test packages
flutter analyze lib test
# Targeted package tests
(cd packages/verifier_client && dart test)
(cd packages/profile_repository && dart test)
flutter test test/blocs/my_profile test/blocs/other_profile test/screens test/widgets/profile
```

Expected: clean across the board.

- [ ] **Step 2: Push branch (PR1 already on origin)**

```bash
git push origin feat/3933-verified-accounts
```

- [ ] **Step 3: Open PR2 (stacked on PR1)**

```bash
gh pr create --repo divinevideo/divine-mobile \
  --title "feat(profile): render verified accounts on profile (2/3)" \
  --body "$(cat <<'EOF'
## Summary
- New `verifier_client` package wraps `https://verifier.divine.video`'s
  REST API (`POST /verify`, `POST /verify/single`).
- `profile_repository` gains `IdentityClaimsRepository`, which parses
  NIP-39 `i` tags off kind 0 and re-verifies them via the client.
- `MyProfileBloc` and `OtherProfileBloc` expose a `verifiedClaims` list
  on their `Loaded` states; the BLoCs auto-fetch after a kind-0 load.
- New `VerifiedAccountsRow` + `VerifiedAccountChip` widgets render under
  the bio on both surfaces. Unverified claims are hidden in v1.

## Why
Lets users surface their identities on other platforms (GitHub, X,
Bluesky, Mastodon, …) on their Divine profile, with verification
re-checked through the verifier service. Part 2 of 3 for #3933.

## Test plan
- [ ] On a profile that has `i` tags whose verifier proof passes, chips
  render under the bio and tap-through opens the platform externally.
- [ ] On a profile with no `i` tags, no chip row appears.
- [ ] Killing the network (airplane mode) shows no chips, no error UI.
- [ ] Goldens cover both surfaces.

Refs #3933.
EOF
)"
```

**STOP HERE — wait for PR2 review and merge before starting Chunk 3.**

---

## Chunk 3: PR 3 — Write path: verifier WebView entry point

**Goal:** Add an in-app WebView screen that hosts `https://verifier.divine.video`, surface a "Verified accounts" section with a "Get verified" CTA tile on edit profile, and refresh the user's kind 0 (and therefore verified chips) when the WebView is dismissed.

**Files (new):**
- `mobile/lib/screens/profile/verifier_webview_screen.dart`
- `mobile/test/screens/profile/verifier_webview_screen_test.dart`

**Files (modify):**
- `mobile/lib/blocs/profile_editor/profile_editor_bloc.dart` (+ `_event.dart`, `_state.dart`)
- `mobile/lib/blocs/profile_editor/profile_editor_bloc_test.dart`
- `mobile/lib/screens/profile_setup_screen.dart` (add "Get verified" tile + BlocListener bridge)
- `mobile/lib/router/app_router.dart` (register new route)
- `mobile/lib/l10n/app_en.arb` (new keys)

### Task 3.1: l10n keys for the write path

- [ ] **Step 1: Add keys** to `mobile/lib/l10n/app_en.arb`:

```json
"profileEditVerifiedAccountsTitle": "Verified accounts",
"@profileEditVerifiedAccountsTitle": {
  "description": "Section header on the edit profile screen above the verified-accounts chip row and the Get verified CTA."
},
"profileEditGetVerifiedCta": "Get verified",
"@profileEditGetVerifiedCta": {
  "description": "Primary CTA tile on edit profile that opens the in-app verifier WebView."
},
"profileEditGetVerifiedSubtitle": "Link your social media accounts so people know it's really you.",
"@profileEditGetVerifiedSubtitle": {
  "description": "Subtitle under the Get verified tile, harmonized with verifier.divine.video landing copy."
},
"verifierWebViewTitle": "Get verified",
"@verifierWebViewTitle": {
  "description": "Title of the in-app WebView screen hosting verifier.divine.video."
}
```

- [ ] **Step 2: `flutter gen-l10n`**.

### Task 3.2: Extend `ProfileEditorBloc` with launch + dismiss events

**Files:**
- `mobile/lib/blocs/profile_editor/profile_editor_bloc.dart`
- `mobile/lib/blocs/profile_editor/profile_editor_event.dart`
- `mobile/lib/blocs/profile_editor/profile_editor_state.dart`
- `mobile/test/blocs/profile_editor/profile_editor_bloc_test.dart`

The BLoC's job here is to expose a *signal* that the UI listens to — actual navigation lives in the UI per `.claude/rules/state_management.md` (no BLoC-to-BLoC dispatch, no Flutter SDK in BLoC). Use a status field rather than a state-stream message.

- [ ] **Step 1: Failing tests**

```dart
blocTest<ProfileEditorBloc, ProfileEditorState>(
  'emits status verifierLaunchRequested when VerifierLaunchRequested is added',
  build: ProfileEditorBloc.new,
  act: (bloc) => bloc.add(const VerifierLaunchRequested()),
  expect: () => [
    isA<ProfileEditorState>().having(
      (s) => s.verifierStatus,
      'verifierStatus',
      VerifierStatus.launchRequested,
    ),
  ],
);

blocTest<ProfileEditorBloc, ProfileEditorState>(
  'resets to idle on VerifierWebViewDismissed',
  build: ProfileEditorBloc.new,
  seed: () => const ProfileEditorState(verifierStatus: VerifierStatus.launchRequested),
  act: (bloc) => bloc.add(const VerifierWebViewDismissed()),
  expect: () => [
    isA<ProfileEditorState>().having(
      (s) => s.verifierStatus,
      'verifierStatus',
      VerifierStatus.dismissed,
    ),
  ],
);
```

- [ ] **Step 2: Run — confirm FAIL.**

- [ ] **Step 3: Implement.**

In `_state.dart`, add:

```dart
enum VerifierStatus { idle, launchRequested, dismissed }
```

…and a `VerifierStatus verifierStatus` field on the state with `copyWith` support. Default `idle`.

In `_event.dart`:

```dart
final class VerifierLaunchRequested extends ProfileEditorEvent {
  const VerifierLaunchRequested();
}

final class VerifierWebViewDismissed extends ProfileEditorEvent {
  const VerifierWebViewDismissed();
}
```

In `_bloc.dart`, register handlers that just `emit(state.copyWith(verifierStatus: VerifierStatus.launchRequested))` and `…dismissed` respectively.

- [ ] **Step 4: Run — confirm PASS.**

- [ ] **Step 5: Commit:**

```
feat(profile_editor): launch + dismiss events for verifier
```

### Task 3.3: `VerifierWebViewScreen`

**File (create):** `mobile/lib/screens/profile/verifier_webview_screen.dart`

Reference pattern: `mobile/lib/screens/apps/nostr_app_sandbox_screen.dart`. Strip Nostr-app-specific concerns (permissions broker, postMessage bridge, app permission gating). The verifier doesn't need any of that — it's a normal web flow that publishes its own kind-0 update via the user's signer.

- [ ] **Step 1: Failing widget test**

```dart
testWidgets('loads the verifier base URL into a WebViewWidget',
    (tester) async {
  await tester.pumpWidget(_buildSubject());
  expect(find.byType(WebViewWidget), findsOneWidget);
});

testWidgets('shows the localized title in the app bar', (tester) async {
  await tester.pumpWidget(_buildSubject());
  final l10n = lookupAppLocalizations(const Locale('en'));
  expect(find.text(l10n.verifierWebViewTitle), findsOneWidget);
});
```

- [ ] **Step 2: Implement**

```dart
class VerifierWebViewScreen extends StatefulWidget {
  const VerifierWebViewScreen({required this.url, super.key});

  static const routeName = 'verifier-webview';
  static const path = '/profile/verifier';

  final Uri url;

  @override
  State<VerifierWebViewScreen> createState() =>
      _VerifierWebViewScreenState();
}

class _VerifierWebViewScreenState extends State<VerifierWebViewScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(VineTheme.backgroundColor)
      ..loadRequest(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: DiVineAppBar(
        title: l10n.verifierWebViewTitle,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      body: SafeArea(child: WebViewWidget(controller: _controller)),
    );
  }
}
```

Add a route in `app_router.dart`:

```dart
GoRoute(
  path: VerifierWebViewScreen.path,
  name: VerifierWebViewScreen.routeName,
  builder: (context, state) => VerifierWebViewScreen(
    url: Uri.parse(/* read EnvironmentConfig.verifierBaseUrl from a Riverpod provider */),
  ),
),
```

- [ ] **Step 3: Run — confirm PASS.**

- [ ] **Step 4: Format + analyze + commit:**

```
feat(profile): VerifierWebViewScreen
```

### Task 3.4: "Get verified" tile + BlocListener bridge on edit profile

**Files:**
- `mobile/lib/screens/profile_setup_screen.dart`
- `mobile/test/screens/profile_setup_screen_test.dart`

- [ ] **Step 1: Failing tests**

```dart
testWidgets('renders the "Get verified" CTA tile', (tester) async {
  await tester.pumpWidget(_buildSubject());
  final l10n = lookupAppLocalizations(const Locale('en'));
  expect(find.text(l10n.profileEditGetVerifiedCta), findsOneWidget);
});

testWidgets(
  'tapping "Get verified" navigates to the VerifierWebViewScreen',
  (tester) async {
    await tester.pumpWidget(_buildSubjectWithRouter());
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.tap(find.text(l10n.profileEditGetVerifiedCta));
    await tester.pumpAndSettle();
    expect(find.byType(VerifierWebViewScreen), findsOneWidget);
  },
);

testWidgets(
  'after the WebView is popped, the bloc emits VerifierWebViewDismissed '
  'and MyProfileBloc receives a refresh request',
  (tester) async {
    // Mock MyProfileBloc and assert it receives MyProfileRefreshRequested
    // (or whatever the existing refresh event is named) after pop.
    ...
  },
);
```

- [ ] **Step 2: Run — confirm FAIL.**

- [ ] **Step 3: Implement**

Insert a `_VerifiedAccountsSection` private widget in `profile_setup_screen.dart` between the bio and the existing form continuation:

```dart
class _VerifiedAccountsSection extends StatelessWidget {
  const _VerifiedAccountsSection();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final claims = context.select(
      (MyProfileBloc b) => switch (b.state) {
        MyProfileLoaded(:final verifiedClaims) => verifiedClaims,
        _ => const <IdentityClaim>[],
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(
            l10n.profileEditVerifiedAccountsTitle,
            style: VineTheme.labelMediumFont(
              color: VineTheme.onSurfaceMuted,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (claims.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: VerifiedAccountsRow(claims: claims),
          ),
          const SizedBox(height: 12),
        ],
        const _GetVerifiedTile(),
      ],
    );
  }
}

class _GetVerifiedTile extends StatelessWidget {
  const _GetVerifiedTile();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      title: Text(
        l10n.profileEditGetVerifiedCta,
        style: VineTheme.titleMediumFont(),
      ),
      subtitle: Text(
        l10n.profileEditGetVerifiedSubtitle,
        style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceMuted),
      ),
      trailing: const DivineIcon(icon: DivineIconName.arrowRight),
      onTap: () => context
          .read<ProfileEditorBloc>()
          .add(const VerifierLaunchRequested()),
    );
  }
}
```

Wrap the screen body's existing tree with a `BlocListener<ProfileEditorBloc, ProfileEditorState>` that:
- On `verifierStatus == VerifierStatus.launchRequested`: pushes `VerifierWebViewScreen` via `context.pushNamed(VerifierWebViewScreen.routeName)` and **awaits** the result.
- After the push returns: dispatches `VerifierWebViewDismissed` to `ProfileEditorBloc` AND dispatches the existing kind-0 refresh event on `MyProfileBloc` (search the bloc for the existing event name — likely `MyProfileRefreshRequested` or similar; reuse it, do not invent a new one).

- [ ] **Step 4: Run — confirm PASS.**

- [ ] **Step 5: Format + analyze + commit:**

```
feat(profile): Get verified tile + WebView launch bridge
```

### Task 3.5: Goldens

- [ ] Update goldens for the edit-profile screen to include the new "Verified accounts" section and tile.

- [ ] Commit:

```
test(profile): goldens for Get verified section
```

### Task 3.6: PR3 verification + push

- [ ] **Step 1: Full local verification**

```bash
cd mobile
dart format --output=none --set-exit-if-changed lib test packages
flutter analyze lib test
flutter test test/blocs test/screens test/widgets
(cd packages/verifier_client && dart test)
(cd packages/profile_repository && dart test)
```

- [ ] **Step 2: Push and open PR3**

```bash
git push origin feat/3933-verified-accounts
gh pr create --repo divinevideo/divine-mobile \
  --title "feat(profile): in-app verifier WebView entry (3/3)" \
  --body "$(cat <<'EOF'
## Summary
- New `VerifierWebViewScreen` hosts `https://verifier.divine.video` in
  an in-app WebKit/WebView. No postMessage bridge — verifier publishes
  the kind-0 update via the user's signer (login.divine.video, browser
  signer, bunker, NIP-46) directly to relays the app already reads from.
- New "Verified accounts" section + "Get verified" CTA tile on edit
  profile, copy harmonized with the verifier landing page.
- `ProfileEditorBloc` exposes `VerifierLaunchRequested` /
  `VerifierWebViewDismissed`. UI-level `BlocListener` bridges launch to
  navigation and dispatches a kind-0 refresh on `MyProfileBloc` after
  the WebView is dismissed, so newly verified chips appear immediately.

## Why
Closes the write side of #3933 — users can now go from edit profile to
the verifier and back without leaving the app.

## Test plan
- [ ] Open Edit Profile → "Get verified" tile is present.
- [ ] Tap tile → WebView opens at verifier.divine.video.
- [ ] Complete a verification (e.g. GitHub) → press back → newly
  verified chip appears under the bio.
- [ ] Repeat on another device — verified chip is still visible
  (verifier published the kind 0).

Refs #3933.
EOF
)"
```

---

## After all three PRs land

- [ ] Close issue #3933 on the merge commit of PR3 (or auto-close via "Closes #3933" trailer in PR3's body).
- [ ] Optionally prune the worktree:

```bash
git worktree remove .worktrees/3933-verified-accounts
```

(Only after PRs are merged. Do NOT prune while PRs are open — review fixes need the worktree.)
