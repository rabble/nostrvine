# Content Policy Layer Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace three overlapping moderation services with a single pure-Dart `ContentPolicyEngine` that gates every repository and relay-dispatch ingress boundary, so blocked/muted content never reaches app state on any feed.

**Architecture:** A new `content_policy` package exposes a stateless engine composed of ordered `PolicyRule`s, plus an immutable `ContentPolicyState` value type. `ContentBlocklistRepository` gains `currentState` / `stateStream` accessors. The engine is injected into repository parse boundaries, REST model-construction paths, relay-event dispatch seams, and affordance-gate call sites (Follow, DM, mention, share/tag pickers). Ships behind a `content_policy_v2` feature flag until Phase 3.

**Tech Stack:** Dart 3 sealed classes, `flutter_riverpod` (legacy glue), existing `FeatureFlag` enum, `shared_preferences`, `bloc_test`, `mocktail`.

**Spec:** `docs/superpowers/specs/2026-04-23-content-policy-layer-design.md`

---

## Orientation for the implementer

You likely do not have context for this codebase. Before starting any task:

- **Monorepo layout** — the app lives at `mobile/`. Feature-level code is in `mobile/lib/`. Shared packages live at `mobile/packages/<name>/` and are referenced from `mobile/pubspec.yaml` using implicit path deps (e.g. `  count_formatter:` with no version — the workspace `resolution: workspace` setting handles pathing). Use `mobile/packages/count_formatter/` as your template for any new package in this plan.
- **All Flutter commands run from `mobile/`**, never from the repo root. `cd mobile && flutter test …`.
- **Mise pinning** — the repo uses `mise exec --` for pinned Flutter. If you hit tool-version drift, prefix with `mise exec -- flutter …`.
- **Codegen** — if you touch Riverpod, Freezed, JSON, Mockito, or Drift annotations, you must run `cd mobile && dart run build_runner build --delete-conflicting-outputs` and commit the generated files.
- **Never truncate Nostr IDs** anywhere — code, logs, tests, analytics, debug output. Full hex pubkeys always.
- **Disclosure invariant is a hard rule** — the app must never tell a user they have been blocked by another user. No ruleId string, no pubkey, no "MutualMute" token in any user-visible copy, snackbar, release log, analytics event, or Crashlytics breadcrumb. This affects test design (negative assertions) and logging choices throughout the plan.
- **Existing feature flags** live at `mobile/lib/features/feature_flags/`. The enum is `mobile/lib/features/feature_flags/models/feature_flag.dart`; the service is `mobile/lib/features/feature_flags/services/feature_flag_service.dart`. Defaults are declared in `build_configuration.dart` in the same directory.
- **Current naming** — the blocklist rename has already landed. Use `ContentBlocklistRepository` from `mobile/packages/content_blocklist_repository/lib/src/content_blocklist_repository.dart` and the Riverpod provider `contentBlocklistRepositoryProvider` in `mobile/lib/providers/app_providers.dart`.
- **Existing block-filter hook** — `mobile/packages/videos_repository/lib/src/video_content_filter.dart` defines `typedef BlockedVideoFilter = bool Function(String pubkey);` and `videos_repository.dart` already calls it at four parse points (lines 787, 826, 860, 900 of the current file). The engine-injection work in Phase 1 preserves this callback shape — we replace the callback's **implementation** with `engine.evaluate(...) is Block`, not the callback's position in the code. Equivalent hooks already exist for comments, profile, and notifications; the remaining new hook work is for hashtag, likes, and reposts.

---

## Chunk 1: Phase 0 — Build the engine package

Everything in this chunk is pure Dart, no Flutter, no IO, trivially unit-testable. When this chunk is done, the engine exists and has 100% unit coverage; nothing in the app calls it yet.

### Task 0.1: Scaffold the `content_policy` package

**Files:**
- Create: `mobile/packages/content_policy/pubspec.yaml`
- Create: `mobile/packages/content_policy/analysis_options.yaml`
- Create: `mobile/packages/content_policy/lib/content_policy.dart`
- Modify: `mobile/pubspec.yaml` (add to `workspace:` list and as implicit dep)

- [ ] **Step 1: Create the package pubspec**

Write `mobile/packages/content_policy/pubspec.yaml`:

```yaml
name: content_policy
description: Pure Dart content policy engine. Ingress filter + affordance gate.
version: 0.1.0+1
publish_to: none
resolution: workspace

environment:
  sdk: ^3.11.0

dev_dependencies:
  test: ^1.26.3
  very_good_analysis: ^10.0.0
```

- [ ] **Step 2: Create the analysis_options**

Write `mobile/packages/content_policy/analysis_options.yaml`:

```yaml
include: package:very_good_analysis/analysis_options.yaml
```

- [ ] **Step 3: Create the barrel file**

Write `mobile/packages/content_policy/lib/content_policy.dart`:

```dart
// Content policy engine — ingress filter + affordance gate.
export 'src/content_policy_engine.dart';
export 'src/content_policy_state.dart';
export 'src/policy_decision.dart';
export 'src/policy_input.dart';
export 'src/policy_rule.dart';
export 'src/rules/mutual_mute_rule.dart';
export 'src/rules/pubkey_block_rule.dart';
export 'src/rules/pubkey_mute_rule.dart';
export 'src/rules/self_reference_rule.dart';
```

- [ ] **Step 4: Register the package in the monorepo**

Modify `mobile/pubspec.yaml`. In the `workspace:` block (around line 26–57, alphabetical after `comments_repository`), add:

```yaml
  - packages/content_policy
```

And in the `dependencies:` block (near other implicit path deps like `videos_repository:`), add:

```yaml
  # Content Policy — parse-gate ingress filter
  content_policy:
```

- [ ] **Step 5: Verify the package resolves**

Run: `cd mobile && flutter pub get`
Expected: no errors, `content_policy` listed in resolved packages.

- [ ] **Step 6: Commit**

```bash
git add mobile/packages/content_policy mobile/pubspec.yaml
git commit -m "feat(content_policy): scaffold pure-Dart policy engine package"
```

### Task 0.2: Define `PolicyInput`

**Files:**
- Create: `mobile/packages/content_policy/lib/src/policy_input.dart`
- Create: `mobile/packages/content_policy/test/src/policy_input_test.dart`

- [ ] **Step 1: Write the failing test**

Write `mobile/packages/content_policy/test/src/policy_input_test.dart`:

```dart
import 'package:content_policy/content_policy.dart';
import 'package:test/test.dart';

void main() {
  group(PolicyInput, () {
    test('constructs with only pubkey', () {
      const input = PolicyInput(pubkey: 'abc');
      expect(input.pubkey, equals('abc'));
      expect(input.kind, isNull);
      expect(input.content, isNull);
      expect(input.tags, isNull);
    });

    test('constructs with all fields', () {
      const input = PolicyInput(
        pubkey: 'abc',
        kind: 34236,
        content: 'hello',
        tags: [
          ['d', 'video-1'],
        ],
      );
      expect(input.pubkey, equals('abc'));
      expect(input.kind, equals(34236));
      expect(input.content, equals('hello'));
      expect(input.tags, hasLength(1));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile/packages/content_policy && dart test test/src/policy_input_test.dart`
Expected: compile error — `PolicyInput` is undefined.

- [ ] **Step 3: Implement `PolicyInput`**

Write `mobile/packages/content_policy/lib/src/policy_input.dart`:

```dart
/// Minimal input the policy engine needs to evaluate a single event.
///
/// Parsers construct this from the raw JSON envelope of a Nostr event
/// (or a REST response row that carries the same fields). Only [pubkey]
/// is consulted by the Phase 1 rules; the remaining fields are part of
/// the contract so future rules (hashtag, keyword) can be added without
/// changing every call site.
class PolicyInput {
  const PolicyInput({
    required this.pubkey,
    this.kind,
    this.content,
    this.tags,
  });

  /// Event author's hex pubkey. Required.
  final String pubkey;

  /// Event kind (NIP-01 integer). Optional — not all REST responses carry it.
  final int? kind;

  /// Event content string. Optional.
  final String? content;

  /// Event tags, as the standard `List<List<String>>` NIP-01 shape. Optional.
  final List<List<String>>? tags;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile/packages/content_policy && dart test test/src/policy_input_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 5: Commit**

```bash
git add mobile/packages/content_policy/lib/src/policy_input.dart mobile/packages/content_policy/test/src/policy_input_test.dart
git commit -m "feat(content_policy): add PolicyInput value type"
```

### Task 0.3: Define `PolicyDecision` sealed hierarchy

**Files:**
- Create: `mobile/packages/content_policy/lib/src/policy_decision.dart`
- Create: `mobile/packages/content_policy/test/src/policy_decision_test.dart`

- [ ] **Step 1: Write the failing test**

Write `mobile/packages/content_policy/test/src/policy_decision_test.dart`:

```dart
import 'package:content_policy/content_policy.dart';
import 'package:test/test.dart';

void main() {
  group(PolicyDecision, () {
    test('Allow is a PolicyDecision', () {
      const decision = Allow();
      expect(decision, isA<PolicyDecision>());
    });

    test('Block carries a ruleId', () {
      const decision = Block(ruleId: 'PubkeyMuteRule');
      expect(decision.ruleId, equals('PubkeyMuteRule'));
      expect(decision, isA<PolicyDecision>());
    });

    test('pattern matches exhaustively', () {
      PolicyDecision decision = const Allow();
      final label = switch (decision) {
        Allow() => 'allow',
        Block() => 'block',
      };
      expect(label, equals('allow'));

      decision = const Block(ruleId: 'r');
      final label2 = switch (decision) {
        Allow() => 'allow',
        Block() => 'block',
      };
      expect(label2, equals('block'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile/packages/content_policy && dart test test/src/policy_decision_test.dart`
Expected: compile error — `Allow`, `Block`, `PolicyDecision` undefined.

- [ ] **Step 3: Implement the sealed hierarchy**

Write `mobile/packages/content_policy/lib/src/policy_decision.dart`:

```dart
/// Outcome of evaluating a single [PolicyInput] against the engine.
///
/// The sealed hierarchy lets callers pattern-match exhaustively without
/// default cases. New decision variants (SoftHide, Warn) can be added
/// later; Phase 1 ships only Allow and Block.
sealed class PolicyDecision {
  const PolicyDecision();
}

/// Content is permitted to be parsed into an in-app model.
final class Allow extends PolicyDecision {
  const Allow();
}

/// Content must be dropped. [ruleId] is for local diagnostics only —
/// it must never appear in user-visible copy, release logs, remote
/// telemetry, Crashlytics breadcrumbs, or analytics events.
final class Block extends PolicyDecision {
  const Block({required this.ruleId});

  /// Identifier of the rule that produced this decision. Debug-only.
  final String ruleId;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile/packages/content_policy && dart test test/src/policy_decision_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add mobile/packages/content_policy/lib/src/policy_decision.dart mobile/packages/content_policy/test/src/policy_decision_test.dart
git commit -m "feat(content_policy): add PolicyDecision sealed hierarchy"
```

### Task 0.4: Define `ContentPolicyState`

**Files:**
- Create: `mobile/packages/content_policy/lib/src/content_policy_state.dart`
- Create: `mobile/packages/content_policy/test/src/content_policy_state_test.dart`

- [ ] **Step 1: Write the failing test**

Write `mobile/packages/content_policy/test/src/content_policy_state_test.dart`:

```dart
import 'package:content_policy/content_policy.dart';
import 'package:test/test.dart';

void main() {
  group(ContentPolicyState, () {
    const me = 'me-pubkey';

    test('empty state has no filtered authors', () {
      final state = ContentPolicyState.empty();
      expect(state.currentUserPubkey, isNull);
      expect(state.isAuthorFiltered('anyone'), isFalse);
      expect(state.isBlockedBy('anyone'), isFalse);
    });

    test('mutedPubkeys filters author', () {
      final state = ContentPolicyState(
        currentUserPubkey: me,
        mutedPubkeys: const {'muted'},
        blockedPubkeys: const {},
        pubkeysBlockingUs: const {},
        pubkeysMutingUs: const {},
      );
      expect(state.isAuthorFiltered('muted'), isTrue);
      expect(state.isAuthorFiltered('other'), isFalse);
    });

    test('blockedPubkeys filters author', () {
      final state = ContentPolicyState(
        currentUserPubkey: me,
        mutedPubkeys: const {},
        blockedPubkeys: const {'blocked'},
        pubkeysBlockingUs: const {},
        pubkeysMutingUs: const {},
      );
      expect(state.isAuthorFiltered('blocked'), isTrue);
    });

    test('pubkeysBlockingUs filters author and reports blockedBy', () {
      final state = ContentPolicyState(
        currentUserPubkey: me,
        mutedPubkeys: const {},
        blockedPubkeys: const {},
        pubkeysBlockingUs: const {'blocker'},
        pubkeysMutingUs: const {},
      );
      expect(state.isAuthorFiltered('blocker'), isTrue);
      expect(state.isBlockedBy('blocker'), isTrue);
      expect(state.isBlockedBy('someone-else'), isFalse);
    });

    test('pubkeysMutingUs filters author and reports blockedBy', () {
      final state = ContentPolicyState(
        currentUserPubkey: me,
        mutedPubkeys: const {},
        blockedPubkeys: const {},
        pubkeysBlockingUs: const {},
        pubkeysMutingUs: const {'muter'},
      );
      expect(state.isAuthorFiltered('muter'), isTrue);
      expect(state.isBlockedBy('muter'), isTrue);
    });

    test('isBlockedBy excludes authors that we muted/blocked but not vice versa', () {
      final state = ContentPolicyState(
        currentUserPubkey: me,
        mutedPubkeys: const {'someone-we-muted'},
        blockedPubkeys: const {'someone-we-blocked'},
        pubkeysBlockingUs: const {},
        pubkeysMutingUs: const {},
      );
      expect(state.isBlockedBy('someone-we-muted'), isFalse);
      expect(state.isBlockedBy('someone-we-blocked'), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile/packages/content_policy && dart test test/src/content_policy_state_test.dart`
Expected: compile error — `ContentPolicyState` undefined.

- [ ] **Step 3: Implement `ContentPolicyState`**

Write `mobile/packages/content_policy/lib/src/content_policy_state.dart`:

```dart
/// Immutable snapshot of all state the policy engine needs to evaluate.
///
/// Rebuilt by [ContentBlocklistRepository] whenever the underlying source
/// data changes. The engine never mutates it; it is replaced wholesale.
class ContentPolicyState {
  const ContentPolicyState({
    required this.currentUserPubkey,
    required this.mutedPubkeys,
    required this.blockedPubkeys,
    required this.pubkeysBlockingUs,
    required this.pubkeysMutingUs,
  });

  /// Empty state — used pre-hydration or when no user is authenticated.
  ///
  /// With an empty state, every rule short-circuits to Allow. This is
  /// the documented startup window; the bootstrap sequence is responsible
  /// for hydrating before any parse-gate call fires.
  factory ContentPolicyState.empty() => const ContentPolicyState(
        currentUserPubkey: null,
        mutedPubkeys: {},
        blockedPubkeys: {},
        pubkeysBlockingUs: {},
        pubkeysMutingUs: {},
      );

  /// The hex pubkey of the currently authenticated user, or null.
  final String? currentUserPubkey;

  /// Authors the user muted via their own kind 10000 event.
  final Set<String> mutedPubkeys;

  /// Authors the user blocked via their own kind 30000 d=block event.
  final Set<String> blockedPubkeys;

  /// Authors whose kind 30000 d=block event names the current user.
  final Set<String> pubkeysBlockingUs;

  /// Authors whose kind 10000 event names the current user.
  final Set<String> pubkeysMutingUs;

  /// True when content from [pubkey] must be filtered from feeds.
  bool isAuthorFiltered(String pubkey) =>
      mutedPubkeys.contains(pubkey) ||
      blockedPubkeys.contains(pubkey) ||
      pubkeysBlockingUs.contains(pubkey) ||
      pubkeysMutingUs.contains(pubkey);

  /// True when [pubkey] has a mute/block entry naming the current user.
  ///
  /// This is the query that [ContentPolicyEngine.canTarget] uses — it
  /// answers "does the recipient want to hear from us?" without leaking
  /// the reason. Callers MUST NOT surface the return value as copy.
  bool isBlockedBy(String pubkey) =>
      pubkeysBlockingUs.contains(pubkey) ||
      pubkeysMutingUs.contains(pubkey);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile/packages/content_policy && dart test test/src/content_policy_state_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add mobile/packages/content_policy/lib/src/content_policy_state.dart mobile/packages/content_policy/test/src/content_policy_state_test.dart
git commit -m "feat(content_policy): add immutable ContentPolicyState"
```

### Task 0.5: Define `PolicyRule` interface

**Files:**
- Create: `mobile/packages/content_policy/lib/src/policy_rule.dart`

- [ ] **Step 1: Write the interface**

Write `mobile/packages/content_policy/lib/src/policy_rule.dart`:

```dart
import 'package:content_policy/src/content_policy_state.dart';
import 'package:content_policy/src/policy_decision.dart';
import 'package:content_policy/src/policy_input.dart';

/// A single, pure, synchronous check in the policy pipeline.
///
/// Rules must be deterministic: same input + same state always produces
/// the same decision. No IO, no async, no mutation.
abstract interface class PolicyRule {
  /// Stable identifier used in [Block.ruleId] and in the engine's
  /// ordering assertion. Must match the class name by convention.
  String get id;

  /// Evaluate the rule. Return [Allow] to let the pipeline continue,
  /// [Block] to short-circuit with a drop decision.
  PolicyDecision evaluate(PolicyInput input, ContentPolicyState state);
}
```

- [ ] **Step 2: Run analyzer on the package**

Run: `cd mobile/packages/content_policy && dart analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add mobile/packages/content_policy/lib/src/policy_rule.dart
git commit -m "feat(content_policy): add PolicyRule interface"
```

### Task 0.6: Implement `SelfReferenceRule`

**Files:**
- Create: `mobile/packages/content_policy/lib/src/rules/self_reference_rule.dart`
- Create: `mobile/packages/content_policy/test/src/rules/self_reference_rule_test.dart`

- [ ] **Step 1: Write the failing test**

Write `mobile/packages/content_policy/test/src/rules/self_reference_rule_test.dart`:

```dart
import 'package:content_policy/content_policy.dart';
import 'package:test/test.dart';

void main() {
  group(SelfReferenceRule, () {
    const rule = SelfReferenceRule();
    const me = 'me-pubkey';

    final stateWithMeInEveryList = ContentPolicyState(
      currentUserPubkey: me,
      mutedPubkeys: const {me},
      blockedPubkeys: const {me},
      pubkeysBlockingUs: const {me},
      pubkeysMutingUs: const {me},
    );

    test('id matches class name', () {
      expect(rule.id, equals('SelfReferenceRule'));
    });

    test('allows the current user even if every list contains them', () {
      final decision = rule.evaluate(
        const PolicyInput(pubkey: me),
        stateWithMeInEveryList,
      );
      expect(decision, isA<Allow>());
    });

    test('allows any author when no user is authenticated', () {
      final decision = rule.evaluate(
        const PolicyInput(pubkey: 'anyone'),
        ContentPolicyState.empty(),
      );
      expect(decision, isA<Allow>());
    });

    test('returns Allow (not short-circuit Block) for a different pubkey', () {
      // Self rule only handles the self case. Other rules decide for others.
      final decision = rule.evaluate(
        const PolicyInput(pubkey: 'someone-else'),
        stateWithMeInEveryList,
      );
      expect(decision, isA<Allow>());
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile/packages/content_policy && dart test test/src/rules/self_reference_rule_test.dart`
Expected: compile error — `SelfReferenceRule` undefined.

- [ ] **Step 3: Implement `SelfReferenceRule`**

Write `mobile/packages/content_policy/lib/src/rules/self_reference_rule.dart`:

```dart
import 'package:content_policy/src/content_policy_state.dart';
import 'package:content_policy/src/policy_decision.dart';
import 'package:content_policy/src/policy_input.dart';
import 'package:content_policy/src/policy_rule.dart';

/// Guarantees the user's own content is never filtered, even if a
/// malformed mute/block list contains the user's own pubkey.
///
/// Must be first in the rule pipeline — the engine asserts this.
///
/// Why: a self-referential mute list reproduced issue #2192 where the
/// user's own events disappeared from their feed.
class SelfReferenceRule implements PolicyRule {
  const SelfReferenceRule();

  @override
  String get id => 'SelfReferenceRule';

  @override
  PolicyDecision evaluate(PolicyInput input, ContentPolicyState state) {
    // This rule only handles the self case. For any other pubkey, we
    // return Allow and let the subsequent rules decide.
    return const Allow();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile/packages/content_policy && dart test test/src/rules/self_reference_rule_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add mobile/packages/content_policy/lib/src/rules/self_reference_rule.dart mobile/packages/content_policy/test/src/rules/self_reference_rule_test.dart
git commit -m "feat(content_policy): add SelfReferenceRule"
```

### Task 0.7: Implement `PubkeyMuteRule`

**Files:**
- Create: `mobile/packages/content_policy/lib/src/rules/pubkey_mute_rule.dart`
- Create: `mobile/packages/content_policy/test/src/rules/pubkey_mute_rule_test.dart`

- [ ] **Step 1: Write the failing test**

Write `mobile/packages/content_policy/test/src/rules/pubkey_mute_rule_test.dart`:

```dart
import 'package:content_policy/content_policy.dart';
import 'package:test/test.dart';

void main() {
  group(PubkeyMuteRule, () {
    const rule = PubkeyMuteRule();

    test('id is stable', () {
      expect(rule.id, equals('PubkeyMuteRule'));
    });

    test('blocks authors present in mutedPubkeys', () {
      final state = ContentPolicyState(
        currentUserPubkey: 'me',
        mutedPubkeys: const {'muted'},
        blockedPubkeys: const {},
        pubkeysBlockingUs: const {},
        pubkeysMutingUs: const {},
      );
      final decision = rule.evaluate(
        const PolicyInput(pubkey: 'muted'),
        state,
      );
      expect(decision, isA<Block>());
      expect((decision as Block).ruleId, equals('PubkeyMuteRule'));
    });

    test('allows authors not in mutedPubkeys', () {
      final state = ContentPolicyState(
        currentUserPubkey: 'me',
        mutedPubkeys: const {'muted'},
        blockedPubkeys: const {},
        pubkeysBlockingUs: const {},
        pubkeysMutingUs: const {},
      );
      final decision = rule.evaluate(
        const PolicyInput(pubkey: 'not-muted'),
        state,
      );
      expect(decision, isA<Allow>());
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile/packages/content_policy && dart test test/src/rules/pubkey_mute_rule_test.dart`
Expected: compile error.

- [ ] **Step 3: Implement `PubkeyMuteRule`**

Write `mobile/packages/content_policy/lib/src/rules/pubkey_mute_rule.dart`:

```dart
import 'package:content_policy/src/content_policy_state.dart';
import 'package:content_policy/src/policy_decision.dart';
import 'package:content_policy/src/policy_input.dart';
import 'package:content_policy/src/policy_rule.dart';

/// Blocks content from authors the user muted via kind 10000.
class PubkeyMuteRule implements PolicyRule {
  const PubkeyMuteRule();

  @override
  String get id => 'PubkeyMuteRule';

  @override
  PolicyDecision evaluate(PolicyInput input, ContentPolicyState state) {
    if (state.mutedPubkeys.contains(input.pubkey)) {
      return Block(ruleId: id);
    }
    return const Allow();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile/packages/content_policy && dart test test/src/rules/pubkey_mute_rule_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add mobile/packages/content_policy/lib/src/rules/pubkey_mute_rule.dart mobile/packages/content_policy/test/src/rules/pubkey_mute_rule_test.dart
git commit -m "feat(content_policy): add PubkeyMuteRule"
```

### Task 0.8: Implement `PubkeyBlockRule`

**Files:**
- Create: `mobile/packages/content_policy/lib/src/rules/pubkey_block_rule.dart`
- Create: `mobile/packages/content_policy/test/src/rules/pubkey_block_rule_test.dart`

- [ ] **Step 1: Write the failing test**

Write `mobile/packages/content_policy/test/src/rules/pubkey_block_rule_test.dart`:

```dart
import 'package:content_policy/content_policy.dart';
import 'package:test/test.dart';

void main() {
  group(PubkeyBlockRule, () {
    const rule = PubkeyBlockRule();

    test('id is stable', () {
      expect(rule.id, equals('PubkeyBlockRule'));
    });

    test('blocks authors present in blockedPubkeys', () {
      final state = ContentPolicyState(
        currentUserPubkey: 'me',
        mutedPubkeys: const {},
        blockedPubkeys: const {'blocked'},
        pubkeysBlockingUs: const {},
        pubkeysMutingUs: const {},
      );
      final decision = rule.evaluate(
        const PolicyInput(pubkey: 'blocked'),
        state,
      );
      expect(decision, isA<Block>());
      expect((decision as Block).ruleId, equals('PubkeyBlockRule'));
    });

    test('allows authors not in blockedPubkeys', () {
      final state = ContentPolicyState.empty();
      final decision = rule.evaluate(
        const PolicyInput(pubkey: 'anyone'),
        state,
      );
      expect(decision, isA<Allow>());
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile/packages/content_policy && dart test test/src/rules/pubkey_block_rule_test.dart`
Expected: compile error.

- [ ] **Step 3: Implement `PubkeyBlockRule`**

Write `mobile/packages/content_policy/lib/src/rules/pubkey_block_rule.dart`:

```dart
import 'package:content_policy/src/content_policy_state.dart';
import 'package:content_policy/src/policy_decision.dart';
import 'package:content_policy/src/policy_input.dart';
import 'package:content_policy/src/policy_rule.dart';

/// Blocks content from authors the user blocked via kind 30000 d=block.
class PubkeyBlockRule implements PolicyRule {
  const PubkeyBlockRule();

  @override
  String get id => 'PubkeyBlockRule';

  @override
  PolicyDecision evaluate(PolicyInput input, ContentPolicyState state) {
    if (state.blockedPubkeys.contains(input.pubkey)) {
      return Block(ruleId: id);
    }
    return const Allow();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile/packages/content_policy && dart test test/src/rules/pubkey_block_rule_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add mobile/packages/content_policy/lib/src/rules/pubkey_block_rule.dart mobile/packages/content_policy/test/src/rules/pubkey_block_rule_test.dart
git commit -m "feat(content_policy): add PubkeyBlockRule"
```

### Task 0.9: Implement `MutualMuteRule`

**Files:**
- Create: `mobile/packages/content_policy/lib/src/rules/mutual_mute_rule.dart`
- Create: `mobile/packages/content_policy/test/src/rules/mutual_mute_rule_test.dart`

- [ ] **Step 1: Write the failing test**

Write `mobile/packages/content_policy/test/src/rules/mutual_mute_rule_test.dart`:

```dart
import 'package:content_policy/content_policy.dart';
import 'package:test/test.dart';

void main() {
  group(MutualMuteRule, () {
    const rule = MutualMuteRule();

    test('id is stable', () {
      expect(rule.id, equals('MutualMuteRule'));
    });

    test('blocks authors in pubkeysBlockingUs', () {
      final state = ContentPolicyState(
        currentUserPubkey: 'me',
        mutedPubkeys: const {},
        blockedPubkeys: const {},
        pubkeysBlockingUs: const {'blocker'},
        pubkeysMutingUs: const {},
      );
      final decision = rule.evaluate(
        const PolicyInput(pubkey: 'blocker'),
        state,
      );
      expect(decision, isA<Block>());
      expect((decision as Block).ruleId, equals('MutualMuteRule'));
    });

    test('blocks authors in pubkeysMutingUs', () {
      final state = ContentPolicyState(
        currentUserPubkey: 'me',
        mutedPubkeys: const {},
        blockedPubkeys: const {},
        pubkeysBlockingUs: const {},
        pubkeysMutingUs: const {'muter'},
      );
      final decision = rule.evaluate(
        const PolicyInput(pubkey: 'muter'),
        state,
      );
      expect(decision, isA<Block>());
    });

    test('allows authors not in either mutual-mute set', () {
      final state = ContentPolicyState.empty();
      final decision = rule.evaluate(
        const PolicyInput(pubkey: 'stranger'),
        state,
      );
      expect(decision, isA<Allow>());
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile/packages/content_policy && dart test test/src/rules/mutual_mute_rule_test.dart`
Expected: compile error.

- [ ] **Step 3: Implement `MutualMuteRule`**

Write `mobile/packages/content_policy/lib/src/rules/mutual_mute_rule.dart`:

```dart
import 'package:content_policy/src/content_policy_state.dart';
import 'package:content_policy/src/policy_decision.dart';
import 'package:content_policy/src/policy_input.dart';
import 'package:content_policy/src/policy_rule.dart';

/// Blocks content from authors whose own mute/block list names the
/// current user. Enforces the mutual-mute guarantee: if they don't
/// want our content, we don't show theirs.
class MutualMuteRule implements PolicyRule {
  const MutualMuteRule();

  @override
  String get id => 'MutualMuteRule';

  @override
  PolicyDecision evaluate(PolicyInput input, ContentPolicyState state) {
    if (state.isBlockedBy(input.pubkey)) {
      return Block(ruleId: id);
    }
    return const Allow();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile/packages/content_policy && dart test test/src/rules/mutual_mute_rule_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add mobile/packages/content_policy/lib/src/rules/mutual_mute_rule.dart mobile/packages/content_policy/test/src/rules/mutual_mute_rule_test.dart
git commit -m "feat(content_policy): add MutualMuteRule"
```

### Task 0.10: Implement `ContentPolicyEngine`

The engine composes rules, short-circuits on first `Block`, and asserts `SelfReferenceRule` is at position 0 when constructed from the default rule set. It also exposes `canTarget`, a simple wrapper over `state.isBlockedBy` that does not run the rule pipeline.

**Files:**
- Create: `mobile/packages/content_policy/lib/src/content_policy_engine.dart`
- Create: `mobile/packages/content_policy/test/src/content_policy_engine_test.dart`

- [ ] **Step 1: Write the failing test**

Write `mobile/packages/content_policy/test/src/content_policy_engine_test.dart`:

```dart
import 'package:content_policy/content_policy.dart';
import 'package:test/test.dart';

void main() {
  group(ContentPolicyEngine, () {
    const me = 'me';

    group('evaluate', () {
      test('returns Allow when no rule blocks', () {
        final engine = ContentPolicyEngine.defaultRules();
        final decision = engine.evaluate(
          const PolicyInput(pubkey: 'stranger'),
          ContentPolicyState.empty(),
        );
        expect(decision, isA<Allow>());
      });

      test('returns Block when the first applicable rule blocks', () {
        final engine = ContentPolicyEngine.defaultRules();
        final state = ContentPolicyState(
          currentUserPubkey: me,
          mutedPubkeys: const {'muted'},
          blockedPubkeys: const {},
          pubkeysBlockingUs: const {},
          pubkeysMutingUs: const {},
        );
        final decision = engine.evaluate(
          const PolicyInput(pubkey: 'muted'),
          state,
        );
        expect(decision, isA<Block>());
        expect((decision as Block).ruleId, equals('PubkeyMuteRule'));
      });

      test('short-circuits on first Block — later rules do not run', () {
        var secondRuleRan = false;
        final engine = ContentPolicyEngine([
          const SelfReferenceRule(),
          _AlwaysBlockRule('first'),
          _SpyRule(() => secondRuleRan = true),
        ]);
        final decision = engine.evaluate(
          const PolicyInput(pubkey: 'x'),
          ContentPolicyState.empty(),
        );
        expect(decision, isA<Block>());
        expect((decision as Block).ruleId, equals('first'));
        expect(secondRuleRan, isFalse);
      });

      test(
          'SelfReferenceRule short-circuits even when a later rule would block',
          () {
        final engine = ContentPolicyEngine.defaultRules();
        // The user's own pubkey is in every filter list (malformed state).
        final state = ContentPolicyState(
          currentUserPubkey: me,
          mutedPubkeys: const {me},
          blockedPubkeys: const {me},
          pubkeysBlockingUs: const {me},
          pubkeysMutingUs: const {me},
        );
        final decision = engine.evaluate(
          const PolicyInput(pubkey: me),
          state,
        );
        expect(decision, isA<Allow>());
      });
    });

    group('construction invariants', () {
      test('defaultRules places SelfReferenceRule first', () {
        final engine = ContentPolicyEngine.defaultRules();
        expect(engine.rules.first, isA<SelfReferenceRule>());
      });

      test('asserts when SelfReferenceRule is not first', () {
        expect(
          () => ContentPolicyEngine([
            const PubkeyMuteRule(),
            const SelfReferenceRule(),
          ]),
          throwsA(isA<AssertionError>()),
        );
      });

      test('allows custom rule lists so long as SelfReferenceRule leads', () {
        expect(
          () => ContentPolicyEngine([
            const SelfReferenceRule(),
            _AlwaysBlockRule('custom'),
          ]),
          returnsNormally,
        );
      });
    });

    group('canTarget', () {
      test('returns true when pubkey is not in isBlockedBy', () {
        final engine = ContentPolicyEngine.defaultRules();
        expect(
          engine.canTarget('stranger', ContentPolicyState.empty()),
          isTrue,
        );
      });

      test('returns false when pubkey blocks us', () {
        final engine = ContentPolicyEngine.defaultRules();
        final state = ContentPolicyState(
          currentUserPubkey: me,
          mutedPubkeys: const {},
          blockedPubkeys: const {},
          pubkeysBlockingUs: const {'blocker'},
          pubkeysMutingUs: const {},
        );
        expect(engine.canTarget('blocker', state), isFalse);
      });

      test('returns false when pubkey muted us', () {
        final engine = ContentPolicyEngine.defaultRules();
        final state = ContentPolicyState(
          currentUserPubkey: me,
          mutedPubkeys: const {},
          blockedPubkeys: const {},
          pubkeysBlockingUs: const {},
          pubkeysMutingUs: const {'muter'},
        );
        expect(engine.canTarget('muter', state), isFalse);
      });

      test('does not run the full rule pipeline', () {
        // canTarget must not invoke custom rules at all. Using a rule
        // that would throw if called proves it's bypassed.
        final engine = ContentPolicyEngine([
          const SelfReferenceRule(),
          _ExplodingRule(),
        ]);
        expect(
          () => engine.canTarget('anyone', ContentPolicyState.empty()),
          returnsNormally,
        );
      });
    });
  });
}

class _AlwaysBlockRule implements PolicyRule {
  const _AlwaysBlockRule(this._id);
  final String _id;
  @override
  String get id => _id;
  @override
  PolicyDecision evaluate(PolicyInput input, ContentPolicyState state) =>
      Block(ruleId: id);
}

class _SpyRule implements PolicyRule {
  _SpyRule(this.onEvaluate);
  final void Function() onEvaluate;
  @override
  String get id => 'SpyRule';
  @override
  PolicyDecision evaluate(PolicyInput input, ContentPolicyState state) {
    onEvaluate();
    return const Allow();
  }
}

class _ExplodingRule implements PolicyRule {
  @override
  String get id => 'ExplodingRule';
  @override
  PolicyDecision evaluate(PolicyInput input, ContentPolicyState state) {
    throw StateError('should not run');
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile/packages/content_policy && dart test test/src/content_policy_engine_test.dart`
Expected: compile error — `ContentPolicyEngine` undefined.

- [ ] **Step 3: Implement the engine**

Write `mobile/packages/content_policy/lib/src/content_policy_engine.dart`:

```dart
import 'package:content_policy/src/content_policy_state.dart';
import 'package:content_policy/src/policy_decision.dart';
import 'package:content_policy/src/policy_input.dart';
import 'package:content_policy/src/policy_rule.dart';
import 'package:content_policy/src/rules/mutual_mute_rule.dart';
import 'package:content_policy/src/rules/pubkey_block_rule.dart';
import 'package:content_policy/src/rules/pubkey_mute_rule.dart';
import 'package:content_policy/src/rules/self_reference_rule.dart';

/// Evaluates content against an ordered pipeline of [PolicyRule]s and
/// answers interaction-gating queries via [canTarget].
///
/// The engine is stateless. [evaluate] takes a fresh [ContentPolicyState]
/// snapshot on every call; rebuild the snapshot upstream, don't mutate.
class ContentPolicyEngine {
  /// Construct with an explicit rule list. [SelfReferenceRule] must be
  /// at position 0 or an [AssertionError] is thrown.
  ContentPolicyEngine(this.rules)
      : assert(
          rules.isNotEmpty && rules.first is SelfReferenceRule,
          'SelfReferenceRule must be first in the pipeline. '
          'It guarantees the user is never filtered by a malformed list.',
        );

  /// The canonical Phase 1 rule set.
  factory ContentPolicyEngine.defaultRules() => ContentPolicyEngine(const [
        SelfReferenceRule(),
        PubkeyMuteRule(),
        PubkeyBlockRule(),
        MutualMuteRule(),
      ]);

  final List<PolicyRule> rules;

  /// Runs [input] through the pipeline and returns the first [Block]
  /// decision, or [Allow] if no rule blocks.
  ///
  /// Short-circuits on first [Block]; later rules do not run.
  PolicyDecision evaluate(PolicyInput input, ContentPolicyState state) {
    for (final rule in rules) {
      final decision = rule.evaluate(input, state);
      if (decision is Block) return decision;
    }
    return const Allow();
  }

  /// Answers: should the UI offer an interaction that targets [pubkey]?
  ///
  /// Returns `false` when [pubkey] has a mute/block entry naming the
  /// current user. Callers MUST translate this to *absence* of the
  /// affordance, not a disabled state with explanation.
  ///
  /// This query bypasses the full rule pipeline. It's a specific
  /// question with a specific answer; routing it through `evaluate`
  /// would give the caller a `ruleId` they must not expose.
  bool canTarget(String pubkey, ContentPolicyState state) {
    return !state.isBlockedBy(pubkey);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile/packages/content_policy && dart test test/src/content_policy_engine_test.dart`
Expected: PASS, all tests.

- [ ] **Step 5: Run the full package test suite**

Run: `cd mobile/packages/content_policy && dart test`
Expected: PASS, all tests across all files.

- [ ] **Step 6: Run package analyzer**

Run: `cd mobile/packages/content_policy && dart analyze`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add mobile/packages/content_policy/lib/src/content_policy_engine.dart mobile/packages/content_policy/test/src/content_policy_engine_test.dart
git commit -m "feat(content_policy): add ContentPolicyEngine with rule-order assertion"
```

### Task 0.11: Coverage verification

- [ ] **Step 1: Run package tests with coverage**

Run:
```bash
cd mobile/packages/content_policy
dart pub global run coverage:test_with_coverage
```

(If `coverage` is not installed globally, install: `dart pub global activate coverage`.)

- [ ] **Step 2: Verify coverage is 100%**

Inspect `coverage/lcov.info`. Every line of every `lib/src/**` file should be hit. If not, add a targeted test for the uncovered branch before proceeding. This package ships the invariant-bearing logic of the whole feature — coverage gaps here are invariant gaps.

- [ ] **Step 3: Commit coverage config (if added)**

```bash
git add -A mobile/packages/content_policy
git commit -m "test(content_policy): verify 100% coverage on engine package"
```

---

## Chunk 2: Phase 1 — Parse-gate integration

This chunk wires the engine into the app, under the `content_policy_v2` feature flag. When the flag is OFF the app behaves exactly as before. When ON, the engine gates every parse boundary.

### Task 1.1: Add `contentPolicyV2` feature flag

**Files:**
- Modify: `mobile/lib/features/feature_flags/models/feature_flag.dart`
- Modify: `mobile/lib/features/feature_flags/services/build_configuration.dart`
- Test: `mobile/test/models/feature_flag_state_test.dart` (pattern exists; add coverage)

- [ ] **Step 1: Add the enum entry**

Modify `mobile/lib/features/feature_flags/models/feature_flag.dart`. Add before the closing `;`:

```dart
  contentPolicyV2(
    'Content Policy v2',
    'Parse-gated policy engine — filter blocked/muted authors at ingress',
  )
```

Remove the trailing `,` from the previous entry (`integratedApps`) and ensure syntax remains valid.

- [ ] **Step 2: Wire the default**

Modify `mobile/lib/features/feature_flags/services/build_configuration.dart`. Inspect the file — it has a `getDefault(FeatureFlag flag)` method. Add a case:

```dart
case FeatureFlag.contentPolicyV2:
  return false; // Off in Phase 1; flipped to true in Phase 3.
```

- [ ] **Step 3: Run existing feature-flag tests**

Run: `cd mobile && flutter test test/models/feature_flag_state_test.dart test/services/feature_flag_service_test.dart test/screens/feature_flag_screen_test.dart`
Expected: PASS (or one adjustment needed for the exhaustive enum assertion — fix by adding the new flag to expected test inputs).

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/features/feature_flags
git commit -m "feat(feature_flags): add contentPolicyV2 flag (default off)"
```

### Task 1.2: Extend `ContentBlocklistRepository` to expose `ContentPolicyState`

`ContentBlocklistRepository` (at `mobile/packages/content_blocklist_repository/lib/src/content_blocklist_repository.dart`) already holds four sets internally: `_runtimeBlocklist` + `_internalBlocklist` (= user's blocks), `_mutualMuteBlocklist` (= users muting us), `_blockedByOthers` (= users blocking us via kind 30000). This task adds the mapping to `ContentPolicyState` without changing the existing sets or publishing paths.

We introduce two new accessors: `currentState` (synchronous snapshot) and `stateStream` (broadcast stream that emits when `_notifyChanged()` fires). Phase 1 has no separate `mutedPubkeys` set in the repository — kind 10000 of *our own* mute list is not yet read locally. We surface an empty `mutedPubkeys` set for now; the spec's `PubkeyMuteRule` will simply never block from this path until a later PR plumbs own-kind-10000 reading. The `MutualMuteRule` and `PubkeyBlockRule` paths do all current work.

> **Note for the implementer:** the spec assumes kind 10000 personal-mute reading exists. Today the repository only reads kind 10000 events that *name us*. Do not introduce personal-mute reading in this task — that is a follow-up PR (out of scope per the spec's "Deferred" section's own-profile mute list tracking). Just leave `mutedPubkeys` empty in the mapping and add a `TODO(#XXXX)` comment naming the follow-up.

**Files:**
- Modify: `mobile/packages/content_blocklist_repository/lib/src/content_blocklist_repository.dart`
- Test: `mobile/packages/content_blocklist_repository/test/src/content_blocklist_repository_test.dart`

- [ ] **Step 1: Write the failing test**

Add to `mobile/packages/content_blocklist_repository/test/src/content_blocklist_repository_test.dart` (inside the existing `main() { group(...) }`):

```dart
group('ContentPolicyState exposure', () {
  test('currentState reflects blocked, mutual-mute and blocked-by sets',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = ContentBlocklistRepository(prefs: prefs);

    const me = 'my-full-hex-pubkey';
    const blockedByUs = 'blocked-by-us-hex';
    await service.blockUser(blockedByUs, ourPubkey: me);

    final state = service.currentState;
    expect(state.blockedPubkeys, contains(blockedByUs));
    expect(state.mutedPubkeys, isEmpty); // Phase 1: own-kind-10000 not wired
    expect(state.pubkeysBlockingUs, isEmpty);
    expect(state.pubkeysMutingUs, isEmpty);
  });

  test('stateStream emits a new snapshot after block/unblock', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = ContentBlocklistRepository(prefs: prefs);

    const blocked = 'some-hex';
    final snapshots = <ContentPolicyState>[];
    final sub = service.stateStream.listen(snapshots.add);

    await service.blockUser(blocked, ourPubkey: 'me');
    await Future<void>.delayed(Duration.zero);

    expect(snapshots, hasLength(greaterThanOrEqualTo(1)));
    expect(snapshots.last.blockedPubkeys, contains(blocked));

    await sub.cancel();
  });
});
```

Make sure to add the import at the top of the file if not present:

```dart
import 'package:content_policy/content_policy.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test packages/content_blocklist_repository/test/src/content_blocklist_repository_test.dart -n "ContentPolicyState exposure"`
Expected: FAIL — `currentState` and `stateStream` undefined on `ContentBlocklistRepository`.

- [ ] **Step 3: Add dep and implement**

Modify `mobile/packages/content_blocklist_repository/lib/src/content_blocklist_repository.dart`:

3a. Add import:
```dart
import 'package:content_policy/content_policy.dart';
```

3b. Add a field (near the other subscription fields, ~line 70):
```dart
final _stateController = StreamController<ContentPolicyState>.broadcast();
```

3c. Add methods (after `blockingStats` ~line 424):
```dart
/// Synchronous snapshot of the current policy state.
///
/// Safe to call from any context, including build methods. Reads the
/// repository's internal sets and projects them into the immutable
/// [ContentPolicyState] shape the engine consumes.
ContentPolicyState get currentState => ContentPolicyState(
      currentUserPubkey: _ourPubkey,
      // TODO(#content-policy-own-mute): wire own kind 10000 reading so
      // we can populate this set. Until then, PubkeyMuteRule is dormant.
      mutedPubkeys: const {},
      blockedPubkeys: Set.unmodifiable({
        ..._internalBlocklist,
        ..._runtimeBlocklist,
      }),
      pubkeysBlockingUs: Set.unmodifiable(_blockedByOthers),
      pubkeysMutingUs: Set.unmodifiable(_mutualMuteBlocklist),
    );

/// Broadcast stream of [ContentPolicyState] snapshots.
///
/// Emits whenever the underlying sets change. The first event is not
/// the initial state — call [currentState] for that and use this
/// stream for subsequent updates.
Stream<ContentPolicyState> get stateStream => _stateController.stream;
```

3d. Modify `_notifyChanged` to emit:
```dart
void _notifyChanged() {
  _onChanged?.call();
  if (!_stateController.isClosed) {
    _stateController.add(currentState);
  }
}
```

3e. Modify `dispose()` to close the controller:
```dart
void dispose() {
  _mutualMuteSyncStarted = false;
  _mutualMuteSubscriptionId = null;
  _blockListSyncStarted = false;
  _stateController.close();
}
```

3f. Update `mobile/packages/content_blocklist_repository/pubspec.yaml` to ensure `content_policy:` is a dependency if it is not already inherited via workspace config.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test packages/content_blocklist_repository/test/src/content_blocklist_repository_test.dart`
Expected: PASS (full file).

- [ ] **Step 5: Commit**

```bash
git add mobile/packages/content_blocklist_repository/lib/src/content_blocklist_repository.dart mobile/packages/content_blocklist_repository/test/src/content_blocklist_repository_test.dart
git commit -m "feat(blocklist): expose ContentPolicyState snapshot and stream"
```

### Task 1.3: Add `contentPolicyEngineProvider` Riverpod provider

**Files:**
- Modify: `mobile/lib/providers/app_providers.dart`
- Test: `mobile/test/providers/app_providers_test.dart` (or create if absent)

- [ ] **Step 1: Write the failing test**

Create or append to `mobile/test/providers/content_policy_engine_provider_test.dart`:

```dart
import 'package:content_policy/content_policy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/app_providers.dart';

void main() {
  test('contentPolicyEngineProvider exposes the default rule set', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final engine = container.read(contentPolicyEngineProvider);
    expect(engine.rules.first, isA<SelfReferenceRule>());
    expect(engine.rules, hasLength(4));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/providers/content_policy_engine_provider_test.dart`
Expected: FAIL — `contentPolicyEngineProvider` undefined.

- [ ] **Step 3: Implement the provider**

Modify `mobile/lib/providers/app_providers.dart`. Near the `contentBlocklistRepository` provider (around line 800), add:

```dart
import 'package:content_policy/content_policy.dart';

/// The singleton policy engine. Stateless — safe to share across the app.
@Riverpod(keepAlive: true)
ContentPolicyEngine contentPolicyEngine(Ref ref) {
  return ContentPolicyEngine.defaultRules();
}
```

- [ ] **Step 4: Run codegen**

Run: `cd mobile && dart run build_runner build --delete-conflicting-outputs`
Expected: `app_providers.g.dart` updated with `contentPolicyEngineProvider`.

- [ ] **Step 5: Run test to verify it passes**

Run: `cd mobile && flutter test test/providers/content_policy_engine_provider_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/providers/app_providers.dart mobile/lib/providers/app_providers.g.dart mobile/test/providers/content_policy_engine_provider_test.dart
git commit -m "feat(providers): add contentPolicyEngineProvider"
```

### Task 1.4: Bootstrap hydration — block state ready before first subscription

The spec's "State hydration" section requires the policy state to be fully hydrated from local storage before the parse-gate accepts its first call. Today, `ContentBlocklistRepository`'s constructor already loads from `SharedPreferences` synchronously (see `_loadBlockedUsers` called from the constructor). What's missing is an explicit assertion: the `blocklistSyncBridge` (app_providers.dart:832) must not start relay subscriptions until the repository's local hydration is done.

Local hydration is synchronous today. This task adds a test that asserts `currentState` is populated from prefs *before* any `syncBlockListsInBackground` call, so future refactors can't regress the order.

**Files:**
- Test: `mobile/packages/content_blocklist_repository/test/src/content_blocklist_repository_hydration_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Write `mobile/packages/content_blocklist_repository/test/src/content_blocklist_repository_hydration_test.dart`:

```dart
import 'package:content_policy/content_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ContentBlocklistRepository hydration', () {
    test('currentState reflects persisted blocks before any sync call',
        () async {
      // Simulate an app restart with persisted state.
      SharedPreferences.setMockInitialValues({
        'blocked_users_list': '["persisted-pubkey-hex"]',
      });
      final prefs = await SharedPreferences.getInstance();

      final service = ContentBlocklistRepository(prefs: prefs);

      // No relay sync has happened — currentState must already include
      // the persisted block.
      final state = service.currentState;
      expect(state.blockedPubkeys, contains('persisted-pubkey-hex'));
    });

    test('empty prefs yields empty state (Allow-by-default window)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final service = ContentBlocklistRepository(prefs: prefs);

      final state = service.currentState;
      expect(state.blockedPubkeys, isEmpty);
      expect(state.pubkeysBlockingUs, isEmpty);
      expect(state.pubkeysMutingUs, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails or passes**

Run: `cd mobile && flutter test packages/content_blocklist_repository/test/src/content_blocklist_repository_hydration_test.dart`
Expected: likely PASSES already because constructor hydration exists. The value of this test is documenting the invariant — future refactors that break synchronous hydration will fail here.

- [ ] **Step 3: Commit**

```bash
git add mobile/packages/content_blocklist_repository/test/src/content_blocklist_repository_hydration_test.dart
git commit -m "test(blocklist): pin synchronous prefs hydration invariant"
```

### Task 1.5: Parse-gate at `videos_repository` — engine behind flag

The repository already accepts a `BlockedVideoFilter` callback. We replace its *source* (still a callback — `BlockedVideoFilter`'s shape doesn't change), so the repository stays decoupled from the engine. The provider factory at `app_providers.dart` is the injection seam. When `contentPolicyV2` is ON, the callback consults the engine; when OFF, it consults `shouldFilterFromFeeds` exactly as before.

This task also covers the Funnelcake REST paths that `videos_repository` already funnels through `BlockedVideoFilter` (for example `getVideosByAuthor`, feed/search transformations, and other REST response loops inside the repository). No separate Funnelcake task is needed for video content as long as those paths keep using the same filter seam.

**Files:**
- Modify: `mobile/lib/services/blocklist_content_filter.dart`
- Modify: `mobile/lib/providers/app_providers.dart` (the provider that constructs the filter)
- Test: `mobile/test/services/blocklist_content_filter_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Write `mobile/test/services/blocklist_content_filter_test.dart`:

```dart
import 'package:content_policy/content_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/blocklist_content_filter.dart';

void main() {
  group('createPolicyEngineFilter', () {
    test('blocks pubkey when engine.evaluate returns Block', () {
      final engine = ContentPolicyEngine.defaultRules();
      ContentPolicyState state() => ContentPolicyState(
            currentUserPubkey: 'me',
            mutedPubkeys: const {},
            blockedPubkeys: const {'blocked-hex'},
            pubkeysBlockingUs: const {},
            pubkeysMutingUs: const {},
          );

      final filter = createPolicyEngineFilter(engine, state);
      expect(filter('blocked-hex'), isTrue);
      expect(filter('allowed-hex'), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/services/blocklist_content_filter_test.dart`
Expected: FAIL — `createPolicyEngineFilter` undefined.

- [ ] **Step 3: Implement the new factory**

Modify `mobile/lib/services/blocklist_content_filter.dart`. Append (do not remove `createBlocklistFilter` — we keep both until Phase 3):

```dart
import 'package:content_policy/content_policy.dart';

/// Creates a [BlockedVideoFilter] backed by [engine].
///
/// [stateProvider] is invoked on every call so the filter always reads
/// the freshest [ContentPolicyState] snapshot without capturing a stale
/// copy.
BlockedVideoFilter createPolicyEngineFilter(
  ContentPolicyEngine engine,
  ContentPolicyState Function() stateProvider,
) {
  return (String pubkey) {
    final decision = engine.evaluate(
      PolicyInput(pubkey: pubkey),
      stateProvider(),
    );
    return decision is Block;
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/services/blocklist_content_filter_test.dart`
Expected: PASS.

- [ ] **Step 5: Route the repository provider through the flag**

Find where `videos_repository` is constructed — in `mobile/lib/providers/app_providers.dart` there is a provider that constructs `VideosRepository` with a `blockFilter:` argument. Locate by searching for `blockFilter:` in that file. Update the provider to switch based on the flag:

```dart
import 'package:content_policy/content_policy.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';

// Inside the videos_repository provider:
final flagService = ref.watch(featureFlagServiceProvider);
final useV2 = flagService.isEnabled(FeatureFlag.contentPolicyV2);

final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);

final blockFilter = useV2
    ? createPolicyEngineFilter(
        ref.watch(contentPolicyEngineProvider),
        () => blocklistRepository.currentState,
      )
    : createBlocklistFilter(blocklistRepository);

// Pass blockFilter into the VideosRepository constructor as before.
```

> **Pre-flight**: exact provider path in `app_providers.dart` varies — search for the `VideosRepository(` constructor call. The line numbers shift across commits. If a `videos_repository:` provider doesn't exist in `app_providers.dart`, search for the constructor across `mobile/lib/` with `rg "VideosRepository\(" mobile/lib`.

- [ ] **Step 6: Run affected tests**

Run: `cd mobile && flutter test test/providers/video_events_provider_blocklist_test.dart`
Expected: PASS. The flag defaults OFF, so behavior is unchanged.

- [ ] **Step 7: Write a flag-ON test for the provider wiring**

Create `mobile/test/providers/video_events_provider_policy_engine_test.dart` that overrides `featureFlagServiceProvider` to return `contentPolicyV2: true`, seeds a blocked pubkey via the blocklist service, and asserts the engine-backed filter drops its events. Pattern-match existing tests (`video_events_provider_blocklist_test.dart`) for setup.

- [ ] **Step 8: Run the new test**

Run: `cd mobile && flutter test test/providers/video_events_provider_policy_engine_test.dart`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add mobile/lib/services/blocklist_content_filter.dart \
        mobile/lib/providers/app_providers.dart \
        mobile/test/services/blocklist_content_filter_test.dart \
        mobile/test/providers/video_events_provider_policy_engine_test.dart
git commit -m "feat(videos_repository): route block filter through engine when flag on"
```

### Task 1.6: Parse-gate at other repositories (comments, profile, hashtag, likes, reposts, notifications)

Each repository under `mobile/packages/<name>_repository/` that converts relay events or REST rows into app models needs the same hook. Pattern:

1. Add (if missing) a `BlockedAuthorFilter = bool Function(String pubkey)` typedef in that repository's `lib/src/`, mirroring `video_content_filter.dart`.
2. Accept an optional filter in the repository constructor.
3. At every `fromJson` / `fromEvent` / row-to-model conversion, return `null` or skip when the filter returns `true`.
4. Wire the filter at the repository's Riverpod provider in `mobile/lib/providers/app_providers.dart`, routing through the flag exactly as Task 1.5.

> **Important**: not every repository here starts from the same place. Comments, profile, and notifications already have pubkey-filter hooks; hashtag, likes, and reposts still need new ones. This task closes the remaining leak surfaces one repository at a time, each as its own test-first sub-commit.

**Repository sub-tasks** (each its own TDD cycle and commit):

- [ ] **Sub-task 1.6.a — `comments_repository`**
  - Files: `mobile/packages/comments_repository/lib/src/{comments_repository.dart, blocked_comment_filter.dart}`, corresponding test file.
  - The hook already exists. Replace the provider wiring so `BlockedCommentFilter` is engine-backed when `contentPolicyV2` is ON, then add a regression test proving blocked authors never surface through the repository.
  - Commit: `feat(comments_repository): engine-gate comment parsing`.

- [ ] **Sub-task 1.6.b — `profile_repository`**
  - Files: `mobile/packages/profile_repository/lib/src/{profile_repository.dart, blocked_profile_filter.dart}` + test.
  - The hook already exists. Replace the provider wiring so `BlockedProfileFilter` is engine-backed when `contentPolicyV2` is ON, then verify the current user's own profile still survives via `SelfReferenceRule`.
  - Commit: `feat(profile_repository): engine-gate profile parsing`.

- [ ] **Sub-task 1.6.c — `hashtag_repository`**
  - Files: `mobile/packages/hashtag_repository/lib/src/*.dart` + test.
  - Add a new pubkey-based filter hook at the hashtag search / hashtag-feed response parse boundary, then wire it from the provider layer.
  - Commit: `feat(hashtag_repository): engine-gate hashtag feed parsing`.

- [ ] **Sub-task 1.6.d — `likes_repository`** / `reposts_repository`
  - Files: `mobile/packages/likes_repository/lib/src/*.dart`, `mobile/packages/reposts_repository/lib/src/*.dart`, plus tests.
  - Each produces events authored by third parties. Add a new pubkey-based filter hook and gate at parse.
  - Commits: `feat(likes_repository): engine-gate like parsing`, `feat(reposts_repository): engine-gate repost parsing`.

- [ ] **Sub-task 1.6.e — `notification_repository`**
  - Files: `mobile/packages/notification_repository/lib/src/{notification_repository.dart, blocked_notification_filter.dart}`, `mobile/lib/notifications/providers/notification_repository_provider.dart`, plus test.
  - The hook already exists. Replace the provider wiring so `BlockedNotificationFilter` is engine-backed when `contentPolicyV2` is ON, then verify a blocked author cannot generate a notification.
  - Commit: `feat(notification_repository): engine-gate notification parsing`.

Each sub-task follows the exact TDD structure shown in Task 1.5 (failing test, minimal implementation, passing test, commit). The reviewing agent should verify that after each sub-task, the file's existing tests still pass.

### Task 1.7: Parse-gate at the Nostr envelope — `relay_pool.dart`

The videos repository already has a parse seam at the event level. Other surfaces route through the Nostr SDK's `Event.fromJson` (at `mobile/packages/nostr_sdk/lib/event.dart:46`) and downstream handlers in `relay_pool.dart` (line 268), `nostr_connect_session.dart` (line 373), and `relay_isolate_worker.dart` (line 90). A blocked author's event gets to `Event.fromJson`, then flows through the relay pool to every subscriber.

The spec's ingress invariant says: no Dart object for blocked content. Perfect enforcement requires gating at `Event.fromJson` or at every relay subscription delivery point. Gating inside `Event.fromJson` is invasive and couples the Nostr SDK package to the app-level policy engine — unacceptable. Instead, we gate at each subscription delivery seam.

The existing videos-repo seam handles the highest-volume path. This task adds a second seam at the relay-pool dispatcher that is used by the Nostr client's low-level subscribers (used by `ContentBlocklistRepository` itself and other services that don't go through repositories).

**Files:**
- Modify: `mobile/packages/nostr_client/lib/src/nostr_client.dart`
- Test: `mobile/packages/nostr_client/test/src/nostr_client_test.dart`

- [ ] **Step 1: Audit the subscribe pathway**

Read `mobile/packages/nostr_client/lib/src/nostr_client.dart` end-to-end and identify the single point where incoming events are dispatched to subscribers (likely a `.map` or `_emit` on the returned `Stream<Event>`). Record the line number.

- [ ] **Step 2: Add an optional filter hook**

Extend `NostrClient`'s constructor (or its `subscribe` method — whichever is least disruptive) to accept an optional `bool Function(String pubkey)? authorFilter`. Skip emission when the filter returns `true`.

Mirror `BlockedVideoFilter`'s shape so the wiring at the app_providers layer is identical.

- [ ] **Step 3: Write failing tests**

Add to `mobile/packages/nostr_client/test/src/nostr_client_test.dart`:

```dart
test('subscribe drops events whose author the filter blocks', () async {
  // Use the existing mock NostrClient test harness (see file's setUp).
  // Arrange: filter blocks 'blocked-hex'.
  // Act: push two events through the mock relay — one from 'blocked-hex',
  //   one from 'allowed-hex'.
  // Assert: only the 'allowed-hex' event is delivered to the subscriber.
});
```

- [ ] **Step 4: Implement minimal change and verify test passes**

Run: `cd mobile/packages/nostr_client && dart test`
Expected: PASS.

- [ ] **Step 5: Wire the filter at the provider**

In `mobile/lib/providers/app_providers.dart`, the `NostrClient` / `NostrService` provider: pass the engine-backed filter (behind the flag). Keep OFF-path behavior unchanged.

- [ ] **Step 6: Run the full relay integration test suite**

Run: `cd mobile && flutter test test/integration/`
Expected: existing integration tests still pass (flag is off in those tests).

- [ ] **Step 7: Commit**

```bash
git add mobile/packages/nostr_client mobile/lib/providers/app_providers.dart
git commit -m "feat(nostr_client): author filter hook at subscription dispatcher"
```

### Task 1.8: Surface regression tests under flag-ON

These are the regression tests that would have caught #948 staying fixed. Each mirrors a content surface; each seeds a muted/blocked pubkey into the blocklist service, pushes events or REST rows through the repository, and asserts the resulting BLoC/Provider state never contains the blocked author.

Create under `mobile/test/content_policy/surfaces/` (new directory):

- [ ] **Sub-task 1.8.a — `home_feed_blocked_author_test.dart`** — blocked author never reaches `video_events_provider` state.
- [ ] **Sub-task 1.8.b — `search_blocked_author_test.dart`** — video search results filter blocked authors.
- [ ] **Sub-task 1.8.c — `hashtag_feed_blocked_author_test.dart`** — hashtag feeds filter blocked authors.
- [ ] **Sub-task 1.8.d — `other_profile_feed_blocked_author_test.dart`** — a third party's profile grid filters blocked-by-us content.
- [ ] **Sub-task 1.8.e — `comments_blocked_author_test.dart`** — comments from blocked authors are absent.
- [ ] **Sub-task 1.8.f — `notifications_blocked_author_test.dart`** — no notification is generated from a blocked author.

Each test:
1. Overrides `featureFlagServiceProvider` to enable `contentPolicyV2`.
2. Seeds a blocked pubkey via `contentBlocklistRepositoryProvider`.
3. Pumps the relevant BLoC/Provider.
4. Asserts the blocked author's content/event/notification is absent from the final state.

Commit each as: `test(content_policy): assert <surface> filters blocked authors`.

### Task 1.9: Disclosure tests — negative assertions

The spec requires: (a) no user-visible copy reveals a block relationship, (b) release-build logs must not contain `MutualMuteRule` or pubkey literals.

**Files:**
- Test: `mobile/test/content_policy/disclosure/copy_grep_test.dart` (new)
- Test: `mobile/test/content_policy/disclosure/logging_test.dart` (new)

- [ ] **Step 1: Copy-grep CI guard**

Write `mobile/test/content_policy/disclosure/copy_grep_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no user-visible copy reveals block relationship', () async {
    final forbidden = [
      RegExp(r'blocked you', caseSensitive: false),
      RegExp(r'blocked by', caseSensitive: false),
      RegExp(r'not accepting', caseSensitive: false),
      RegExp(r'user has muted you', caseSensitive: false),
    ];

    final libDir = Directory('lib');
    final arb = Directory('lib/l10n'); // Adjust to actual l10n path
    final dirs = [libDir, if (arb.existsSync()) arb];

    for (final dir in dirs) {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        if (!entity.path.endsWith('.dart') && !entity.path.endsWith('.arb')) {
          continue;
        }
        final content = await entity.readAsString();
        for (final pattern in forbidden) {
          final match = pattern.firstMatch(content);
          expect(
            match,
            isNull,
            reason: '${entity.path} contains forbidden copy '
                'matching ${pattern.pattern}',
          );
        }
      }
    }
  });
}
```

- [ ] **Step 2: Logging assertion**

Write `mobile/test/content_policy/disclosure/logging_test.dart` that pumps a widget tree with the engine enabled, routes a blocked event through it, and asserts no logger output contains `'MutualMuteRule'` or the blocked pubkey literal. Use `dart:developer` log capture via `debugPrint` override.

- [ ] **Step 3: Run both tests**

Run: `cd mobile && flutter test test/content_policy/disclosure/`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add mobile/test/content_policy/disclosure/
git commit -m "test(content_policy): disclosure invariant guards (copy + logs)"
```

### Task 1.10: Cache invalidation on mute/unmute

When `blockUser` / `unblockUser` is called, the state stream emits; any session cache holding content from the now-blocked pubkey must invalidate so next reads go through the parse-gate.

For Riverpod: watch the blocklist version counter (already exists: `blocklistVersionProvider`) in the relevant feed providers, so they rebuild on change. This is the *existing* pattern — we verify it still holds under the engine path. Audit each feed provider identified in Chunk 1 Task 1.5/1.6 to confirm it invalidates when `blocklistVersionProvider` bumps.

For BLoCs: each feed BLoC that holds its own cache (e.g. `VideoFeedBloc`, `CommentsBloc`) must subscribe to `contentBlocklistRepository.stateStream` and dispatch a refresh event.

**Files:**
- Modify: BLoCs in `mobile/lib/blocs/*/` that cache third-party content.

- [ ] **Step 1: Audit**

Run a grep: `rg "contentBlocklistRepositoryProvider|contentBlocklistRepository" mobile/lib/blocs` and list every hit.

- [ ] **Step 2: Add stream subscription + refresh for each identified BLoC**

Pattern (example for `VideoFeedBloc`):

```dart
VideoFeedBloc(..., ContentBlocklistRepository blocklist) : ... {
  _stateSub = blocklist.stateStream.listen(
    (_) => add(const VideoFeedPolicyStateChanged()),
  );
}

@override
Future<void> close() async {
  await _stateSub.cancel();
  return super.close();
}
```

And add an event handler that re-runs the current fetch via the engine-gated repository.

- [ ] **Step 3: Write bloc_tests**

For each BLoC that got the new subscription, add a `blocTest` that seeds blocked data, adds a block, and expects a refreshed state without the blocked content.

- [ ] **Step 4: Commit each BLoC change separately**

Commits like `feat(video_feed_bloc): refresh on policy state change`.

### Task 1.11: Phase 1 end-of-chunk verification

- [ ] **Step 1: Run the full Flutter test suite**

Run: `cd mobile && flutter test`
Expected: all tests pass. Any failures block chunk close.

- [ ] **Step 2: Run analyzer**

Run: `cd mobile && flutter analyze lib test integration_test`
Expected: `No issues found!`

- [ ] **Step 3: Integration smoke test, flag OFF (default)**

Boot the app against the local Docker stack and confirm feeds, search, comments, profile grids all still work.

- [ ] **Step 4: Integration smoke test, flag ON**

Toggle `contentPolicyV2` on in the feature flag screen. Block a test user. Confirm their content disappears from every surface audited. Record a short manual-QA checklist in the PR description.

- [ ] **Step 5: Commit**

```bash
git commit --allow-empty -m "chore(content_policy): Phase 1 ready for review"
```

---

## Chunk 3: Phase 2 — Interaction gating (`canTarget`)

All affordances targeting a specific pubkey consult `engine.canTarget(pubkey, state)`. When it returns `false`, the affordance is **absent** — no disabled state, no tooltip, no copy.

### Task 2.1: Provider helpers for `canTarget`

**Files:**
- Modify: `mobile/lib/providers/app_providers.dart`
- Test: `mobile/test/providers/can_target_provider_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Write `mobile/test/providers/can_target_provider_test.dart` that uses `ProviderContainer` with overrides for engine + blocklist, asserts `canTargetProvider('target-hex')` returns expected bool for various states.

- [ ] **Step 2: Add the provider**

Inside `app_providers.dart`:

```dart
/// Reactive bool provider that answers canTarget for a given pubkey.
///
/// Rebuilds when the blocklist state stream emits.
@riverpod
bool canTarget(CanTargetRef ref, String pubkey) {
  final flagService = ref.watch(featureFlagServiceProvider);
  final engine = ref.watch(contentPolicyEngineProvider);
  final blocklist = ref.watch(contentBlocklistRepositoryProvider);
  // Also re-read on state changes:
  ref.watch(blocklistVersionProvider);

  if (!flagService.isEnabled(FeatureFlag.contentPolicyV2)) return true;
  return engine.canTarget(pubkey, blocklist.currentState);
}
```

- [ ] **Step 3: Codegen + test pass**

Run: `cd mobile && dart run build_runner build --delete-conflicting-outputs`
Run: `cd mobile && flutter test test/providers/can_target_provider_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/providers/app_providers.dart mobile/lib/providers/app_providers.g.dart mobile/test/providers/can_target_provider_test.dart
git commit -m "feat(providers): canTargetProvider for affordance gating"
```

### Task 2.2: Gate Follow/Unfollow affordance

**Files:**
- Modify: `mobile/lib/widgets/profile/follow_from_profile_button.dart`
- Modify: `mobile/lib/widgets/video_feed_item/video_follow_button.dart`
- Test: widget tests at `mobile/test/widgets/profile/follow_from_profile_button_test.dart` and analogue for `video_follow_button`.

- [ ] **Step 1: Write failing widget tests**

For each follow-button widget, write a widget test that pumps the widget inside a `ProviderScope` with an override making `canTargetProvider(targetPubkey)` return `false`, and asserts `find.byType(FollowFromProfileButton)` / analogue renders nothing visible (zero-sized, or conditional to not build). Add a positive-case test with `true`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd mobile && flutter test test/widgets/profile/follow_from_profile_button_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement gating**

Convert the widget to `ConsumerWidget`; early-return `const SizedBox.shrink()` when `ref.watch(canTargetProvider(targetPubkey))` is `false`. No text, no icon, no tooltip.

- [ ] **Step 4: Run tests to verify they pass**

Run again — PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/widgets/profile/follow_from_profile_button.dart \
        mobile/lib/widgets/video_feed_item/video_follow_button.dart \
        mobile/test/widgets/profile/follow_from_profile_button_test.dart \
        mobile/test/widgets/video_feed_item/video_follow_button_test.dart
git commit -m "feat(ui): hide follow affordance when target blocks us"
```

### Task 2.3: Gate Send DM affordance

**Files:**
- Find the send-DM entry point (profile screen, conversation screen). Search: `rg "sendDm\|SendDirectMessage\|DmComposer" mobile/lib`.
- Modify each entry point.
- Add widget tests asserting absence.

Pattern identical to Task 2.2: early return shrink when `canTarget` is false. One commit per site.

### Task 2.4: Gate reply compose

**Files:** `mobile/lib/screens/comments/widgets/comment_input.dart` and reply flows under `mobile/lib/blocs/comments/`.

If the event is reachable in the UI (filtering may miss a transient), reply compose must still be hidden. Gate the compose button's build.

### Task 2.5: Gate @-mention autocomplete

**Files:**
- Modify: `mobile/lib/screens/comments/widgets/mention_overlay.dart`
- Modify: the underlying suggestion source (grep for `mentionAutocomplete` / `@` handling in the feature flags widget list).

- [ ] **Step 1:** Filter the suggestion list to exclude pubkeys for which `canTarget == false`.
- [ ] **Step 2:** Widget test: seed one target that blocks us + one that does not, confirm only one appears in suggestions.
- [ ] **Step 3:** Commit: `feat(mentions): exclude blocked-by targets from autocomplete`.

### Task 2.6: Gate share-to-user and tag-in-video pickers

**Files:** search `rg "share.*user.*picker\|TagInVideoPicker" mobile/lib`.

Filter the candidate list in the picker view. Widget tests and per-picker commits.

### Task 2.7: Phase 2 verification

- [ ] **Step 1:** Run all widget tests.
- [ ] **Step 2:** Manual QA walkthrough: for every affordance (Follow, DM, reply, mention, share, tag) seed a pubkey that blocks us, open the UI, confirm the affordance does not render. Confirm there is no tooltip, no disabled state, no copy, no snackbar.
- [ ] **Step 3:** Disclosure test pass: re-run the copy-grep and logging tests from Task 1.9.
- [ ] **Step 4:** Commit: `chore(content_policy): Phase 2 ready for review`.

---

## Chunk 4: Phase 3 & 4 — Flag flip, removal of scattered filters, cleanup

This chunk is the actual behavior change. Up to this point, the app runs unchanged for all users (flag is off by default). Here we flip the flag, remove the per-surface `.where(!shouldFilterFromFeeds(...))` calls, and delete dead code.

### Task 3.1: Flip `contentPolicyV2` default to `true`

**Files:** `mobile/lib/features/feature_flags/services/build_configuration.dart`

- [ ] **Step 1:** Change the default for `FeatureFlag.contentPolicyV2` from `false` to `true`.
- [ ] **Step 2:** Run full test suite — expect some tests to fail because they rely on flag-off behavior. Migrate them to the flag-on expectation (or delete if redundant with Phase 1 surface tests).
- [ ] **Step 3:** Commit: `feat(content_policy): enable v2 engine by default`.

### Task 3.2: Remove scattered `.where(!shouldFilterFromFeeds(...))` calls

Per the audit in Chunk 1, callers live at (from the earlier grep):

- `mobile/lib/providers/for_you_provider.dart:127, 192`
- `mobile/lib/providers/classic_vines_provider.dart:92, 131, 182, 233`
- `mobile/lib/providers/popular_now_feed_provider.dart:111, 247, 407, 491`
- `mobile/lib/providers/popular_videos_feed_provider.dart:223`
- `mobile/lib/providers/video_events_providers.dart:312, 410`
- `mobile/lib/services/video_event_service.dart:2113, 2403, 4053`
- `mobile/lib/screens/video_detail_screen.dart:202`

For each:

- [ ] Delete the `.where(...)` call (or the `if (...shouldFilterFromFeeds)` branch).
- [ ] Delete any now-dead `final blocklistRepository = ref.read(contentBlocklistRepositoryProvider);` locals.
- [ ] Re-run the surface regression test from Task 1.8 for that surface. It must still pass — the engine is doing the filtering now.
- [ ] Commit per file: `refactor(<surface>): remove redundant blocklist filter, engine owns it`.

### Task 3.3: Remove the `BlockedVideoFilter` "legacy" factory

**Files:** `mobile/lib/services/blocklist_content_filter.dart`

- [ ] **Step 1:** Delete `createBlocklistFilter` (the legacy factory). All callers now use `createPolicyEngineFilter`.
- [ ] **Step 2:** Run: `rg "createBlocklistFilter" mobile/` — should be empty.
- [ ] **Step 3:** Run full test suite.
- [ ] **Step 4:** Commit: `chore(blocklist): remove legacy filter factory`.

### Task 3.4: Mark `ContentBlocklistRepository.shouldFilterFromFeeds` deprecated

**Files:** `mobile/packages/content_blocklist_repository/lib/src/content_blocklist_repository.dart`

- [ ] **Step 1:** Annotate `shouldFilterFromFeeds` with `@Deprecated('Use ContentPolicyEngine. Removal tracked in #<issue>.')`.
- [ ] **Step 2:** Run analyzer — tests that still call it will get deprecation warnings. Migrate or suppress the warning in each test.
- [ ] **Step 3:** Commit: `chore(blocklist): deprecate shouldFilterFromFeeds`.

### Task 3.5: Delete dead code — `mute_service.dart` and `content_moderation_service.dart`

**Files:**
- Delete: `mobile/lib/services/mute_service.dart`
- Delete: `mobile/lib/services/content_moderation_service.dart`
- Delete: corresponding Riverpod providers in `mobile/lib/providers/app_providers.dart` / `.g.dart`.
- Keep `ContentBlocklistRepository` in `mobile/packages/content_blocklist_repository/`; it is the long-term state source and is not part of this cleanup.

- [ ] **Step 1:** Run: `rg "MuteService|ContentModerationService" mobile/lib` — list every usage. Confirm every site is either (a) dead code itself, or (b) a no-op path. If any active caller remains, stop and surface to the implementer.
- [ ] **Step 2:** Delete the files.
- [ ] **Step 3:** Codegen: `cd mobile && dart run build_runner build --delete-conflicting-outputs`.
- [ ] **Step 4:** Run full test suite.
- [ ] **Step 5:** File a follow-up issue: "Add `SubscribedListRule` to port ContentModerationService's subscribe-to-external-mute-list intent". Link to the spec's deferred section.
- [ ] **Step 6:** Commit: `chore: remove dead MuteService and ContentModerationService`.

### Task 3.6: Remove the feature flag

Once Phase 3 has been in production for one release cycle and no rollback has been needed, the flag is safe to remove. Treat this as a separate small PR after verification.

**Files:**
- Modify: `mobile/lib/features/feature_flags/models/feature_flag.dart` — delete `contentPolicyV2`.
- Modify: `mobile/lib/features/feature_flags/services/build_configuration.dart` — delete the case.
- Modify: every provider that checks `flagService.isEnabled(FeatureFlag.contentPolicyV2)` — delete the branch, keep the ON-path unconditionally.

- [ ] **Step 1:** Grep for `contentPolicyV2` and migrate every site.
- [ ] **Step 2:** Delete the enum entry and default case.
- [ ] **Step 3:** Delete any tests that toggle the flag explicitly (the engine path is now the only path).
- [ ] **Step 4:** Run full test suite + analyzer.
- [ ] **Step 5:** Commit: `chore(content_policy): remove v2 feature flag`.

### Task 3.7: Close the loop

- [ ] **Step 1:** Close #948 with a link to the surface regression tests from Task 1.8 — those are the tests that enforce the fix stays fixed.
- [ ] **Step 2:** Update the umbrella Content Moderation epic (#604) with the completed scope.
- [ ] **Step 3:** Post the disclosure test (Task 1.9) behavior as a CI gate, so future copy changes that try to reveal a block relationship fail the build.

---

## Verification before declaring done

Before the plan is considered complete, the implementing agent must be able to answer **yes** to each:

1. Does `cd mobile && flutter test` pass with zero failures on `main`?
2. Does `cd mobile && flutter analyze lib test integration_test` report zero issues?
3. Does `cd mobile/packages/content_policy && dart test` pass with 100% line coverage on every `lib/src/**` file?
4. Is there a surface regression test (Task 1.8) for every content surface named in the spec's audit (home, explore/for-you, popular, search, hashtag, profile-by-others, comments, notifications)?
5. Do the disclosure tests (Task 1.9) pass, and do they run on every CI build?
6. Does a manual QA pass with the flag ON confirm: (a) blocked author's content absent from every surface, (b) affordances absent for blockees, (c) no copy or tooltip reveals the block relationship?
7. Is the `content_policy_v2` flag removed after one release's worth of bake-in, per Task 3.6?

When every answer is yes, the Content Policy Layer is complete and #948 is closed for good.

---

## Task index (for reviewers)

**Chunk 1 — Phase 0, engine package:** 0.1 scaffold; 0.2 PolicyInput; 0.3 PolicyDecision; 0.4 ContentPolicyState; 0.5 PolicyRule; 0.6 SelfReferenceRule; 0.7 PubkeyMuteRule; 0.8 PubkeyBlockRule; 0.9 MutualMuteRule; 0.10 ContentPolicyEngine; 0.11 coverage.

**Chunk 2 — Phase 1, parse-gate:** 1.1 flag; 1.2 ContentPolicyState exposure; 1.3 engine provider; 1.4 hydration pin; 1.5 videos_repository; 1.6 comments/profile/hashtag/likes/reposts/notifications; 1.7 nostr_client; 1.8 surface regression tests; 1.9 disclosure tests; 1.10 cache invalidation; 1.11 chunk verification.

**Chunk 3 — Phase 2, interaction gating:** 2.1 canTarget provider; 2.2 follow; 2.3 DM; 2.4 reply compose; 2.5 mention autocomplete; 2.6 share/tag pickers; 2.7 chunk verification.

**Chunk 4 — Phase 3 & 4, flag flip + cleanup:** 3.1 flip default; 3.2 remove scattered filters; 3.3 remove legacy factory; 3.4 deprecate shouldFilterFromFeeds; 3.5 delete dead services; 3.6 remove flag; 3.7 close issue.
