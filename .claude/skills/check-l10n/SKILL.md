---
name: check-l10n
description: |
  Run before pushing a PR that touched UI to find untranslated keys in
  any of the 16 non-English locales and to catch user-visible English
  strings that bypass context.l10n. Reports findings as a checklist;
  refuses to declare clean until all are addressed or explicitly waived.
  Invoke with /check-l10n.
author: Claude Code
version: 1.0.0
date: 2026-05-02
user_invocable: true
invocation_hint: /check-l10n
arguments: |
  Optional: Scope to specific paths under mobile/lib/.
  Example: /check-l10n
  Example: /check-l10n mobile/lib/screens/auth
---

# Check L10n Skill

## Purpose

Catch the two ways localization breaks in this repo before users see English
in a non-English build:

1. **Untranslated keys.** A key added to `app_en.arb` but never translated
   into one of the 16 non-English locales (`ar`, `am`, `bg`, `de`, `es`,
   `fr`, `id`, `it`, `ja`, `ko`, `nl`, `pl`, `pt`, `ro`, `sv`, `tr`).
2. **Hardcoded user-visible English.** Strings rendered straight to the user
   from widget code without going through `context.l10n.<key>`. These never
   show up in `.arb` files because they were never extracted, so no amount
   of translation work fixes them.

Run this before every PR push that touches `mobile/lib/`.

## Workflow

### Step 1: Determine scope

If the user passed paths after `/check-l10n`, scan those. Otherwise scan the
union of staged + unstaged changes vs the working tree.

```bash
# Default: changed files
git -C mobile status --porcelain | awk '{print $NF}' | grep '\.dart$'

# Or explicit: argument paths
```

### Step 2: Run the arb consistency test (if present)

```bash
cd mobile && flutter test test/l10n/arb_consistency_test.dart
```

This test compares every `.arb` file against `app_en.arb` and fails if any
locale is missing keys that aren't on the explicit `_knownUntranslatedDebt`
allow-list.

If the test file does not exist on this branch, skip this step and rely
entirely on Step 3 plus the inline check below. Note in the report that
arb consistency was not verified.

#### Inline fallback when the test doesn't exist

If `mobile/test/l10n/arb_consistency_test.dart` is missing, do the
equivalent check by hand:

```bash
cd mobile/lib/l10n
python3 - <<'PY'
import json, glob
en = json.load(open('app_en.arb'))
en_keys = {k for k in en if not k.startswith('@') and k != '@@locale'}
for f in sorted(glob.glob('app_*.arb')):
    if f == 'app_en.arb':
        continue
    other = json.load(open(f))
    other_keys = {k for k in other if not k.startswith('@') and k != '@@locale'}
    missing = en_keys - other_keys
    if missing:
        print(f"{f}: {len(missing)} missing key(s)")
        for k in sorted(missing)[:20]:
            print(f"  - {k}")
PY
```

### Step 3: Scan for hardcoded English in changed files

```bash
python3 .claude/skills/check-l10n/scan_strings.py
```

Or with explicit paths:

```bash
python3 .claude/skills/check-l10n/scan_strings.py mobile/lib/screens/auth/foo.dart
```

The scanner emits one line per candidate, formatted
`<path>:<line>:<col>  [<rule>]  '<literal>'`. Exit code is `1` when there
are findings, `0` otherwise.

The scanner only inspects files under `mobile/lib/`. It excludes generated
files (`*.g.dart`, `*.freezed.dart`, `*.mocks.dart`), the `l10n/` directory,
and any `test/` or `integration_test/` tree. It also skips lines inside
`Log.*()`, `developer.log()`, `print()`, `assert()`, `throw <Type>Exception()`,
and route-name constants — those literals are not user-visible.

### Step 4: Report as a checklist

Output one section per category. Use the literal output of the underlying
tools rather than paraphrasing — the user should be able to copy a path and
jump straight to the line.

```
## Localization check — <branch>

### 1. ARB consistency
- ✅ All 17 locales have every key in app_en.arb
  (or)
- ❌ app_de.arb missing 7 keys: authConfirmPasswordLabel, ...
  (or)
- ⚠️  arb_consistency_test.dart not present on this branch — used inline
     fallback. Verify before merge.

### 2. Hardcoded English in changed UI files
- ✅ No likely user-visible English literals found.
  (or)
- ❌ 5 candidate(s):
  mobile/lib/screens/auth/login_options_screen.dart
    L147:26  [Text-literal]  'Amber app is not installed'
    L316:27  [label-arg]  'Sign in'
  ...
```

End with one of:

- ✅ **OK to push** — both checks passed.
- ❌ **Do not push** — list the actions required.
- ⚠️ **Push with caveat** — only after the user explicitly waives a finding,
  documenting why in the report.

## Fixing findings

### Untranslated keys

If the missing locale is one we ship to native speakers (the user can confirm
the current launch list), translate. Otherwise, add the key to the
`_knownUntranslatedDebt` set in `mobile/test/l10n/arb_consistency_test.dart`
with a comment naming which locales still need a pass. Don't expand the debt
set silently — it should always be reviewable as "the list of stuff that
isn't translated yet, on purpose".

### Hardcoded English

Each finding has three resolutions, in order of preference:

1. **Add an l10n key** to `mobile/lib/l10n/app_en.arb`, then route the
   widget through `context.l10n.<key>`. If the value already exists under a
   slightly different name, reuse it instead of creating a duplicate.
2. **Mark as not user-visible.** If the literal really isn't reaching the
   user (e.g., a debug-only widget, a developer-only flag, semantic test
   identifier), consider whether the scanner needs an additional skip line
   pattern. A skip rule should be earned by at least 3 distinct examples;
   one-offs aren't worth the regex maintenance.
3. **Waive with reason.** Brand strings that should NEVER be translated
   ("OpenVine", "Divine") are legitimate hardcoded English. Note the waiver
   in the PR description rather than silencing the scanner — future readers
   should be able to see why this finding was accepted.

## Common rule meanings

| Rule | Catches |
|------|---------|
| `Text-literal` | `Text('Foo')` and `const Text("Bar")` |
| `AppBar-title-Text` | `title: Text('Foo')` (specialization of Text-literal) |
| `label-arg` | `label: 'Foo'` named param to any widget |
| `title-arg` | `title: 'Foo'` named param to any widget |
| `hintText-arg` | `hintText: 'Foo'` (form fields) |
| `helperText-arg` | `helperText: 'Foo'` (form fields) |
| `tooltip-arg` / `Tooltip-message` | tooltip text |
| `semanticLabel-arg` / `semanticsLabel-arg` | accessibility labels |
| `user-message-call` | first positional arg of a method whose name includes Error/Message/Snackbar/Toast/Dialog/Banner/Notification |

## Limitations

- The scanner is regex-based and will miss heavily templated code (string
  builders, `.padLeft(...)`, `'$prefix - $suffix'` constructions). Treat a
  clean run as "no obvious leaks", not "all leaks ruled out".
- Brand strings ("Divine", "OpenVine", "Vine") will sometimes trip the
  user-visible heuristic. Waive them in the PR description rather than
  trying to silence them in the scanner.
- The scanner only flags strings starting with a capital letter and
  containing a space — purely lowercase or single-word UI copy
  ("ok", "submit") will not be caught. This is a deliberate trade-off
  for signal-to-noise; manual review remains necessary for short labels.
