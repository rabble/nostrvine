---
name: tests-guard-intentional-workarounds
description: |
  Before removing code that looks redundant, wasteful, or "wrong" based on log
  observations or code review instinct, grep the test suite for tests whose
  names describe the exact behavior you're about to remove. A test whose title
  literally describes the "weird" thing (e.g. "calls play() even when player
  reports playing", "retries even when first call succeeded", "skips cache
  even when fresh") is a load-bearing workaround, and the production log
  you're reacting to is probably the workaround working as designed — not a
  bug. Use when: (1) Tempted to remove a function call that "looks redundant"
  based on a production log, (2) About to "simplify" a conditional that seems
  to always take the same branch, (3) Reviewing code and thinking "why would
  anyone write this?", (4) A log line shows a state that seems impossible or
  contradictory (e.g. playing=true but positionMs=0 for seconds), (5) CI
  surfaces a failing test whose name describes exactly what your fix removed.
author: Claude Code
version: 1.0.0
date: 2026-04-05
---

# Tests Guard Intentional Workarounds

## Problem

You observe a production log line that looks clearly wrong — a function being
called when its precondition already appears satisfied, a retry firing when
the first attempt seemed to work, state being set to the value it already
holds. Instinct says "this is a redundant no-op, I'll remove it." You remove
it, run local tests (which may even pass if coverage is thin), push to CI,
and a test fails with a title that describes **exactly the behavior you just
removed**. The comment on that test explains a subtle platform bug or race
condition that required the "redundant" call as a workaround.

The log line you reacted to wasn't evidence of a bug. It was evidence of the
workaround executing correctly for the exact scenario it was designed for.

## Context / Trigger Conditions

Apply this skill's caution when ANY of these hold:

1. **Redundant-looking call**: You're about to wrap a call in `if (!already_X)`
   or delete it outright because logs show it firing when `X` is already true.
2. **Impossible state in logs**: Logs show a state combination that seems
   logically impossible or contradictory (`playing=true` + `positionMs=0` for
   seconds, `isLoading=false` + data still empty, etc.).
3. **"Why would anyone write this?"**: Reading code and you can't imagine a
   reason for a defensive check, extra await, or secondary call.
4. **Simplifying a conditional**: A branch looks dead because you believe the
   condition can't be reached, or both branches look identical to you.
5. **Receiving a failing test**: CI returns a failure with a test title that
   names exactly the behavior your change removed or modified.

## Solution

Before touching the "redundant" code, run this five-step check:

### Step 1: Grep for tests that assert the exact behavior

Search the test suite for the function name, the state you think is
redundant, and any synonyms:

```bash
# Example: considering removing player.play() on rebuffer complete
grep -rn "player.play" test/ | grep -iE "already|even when|still|twice|redundant"
grep -rn "rebuffer.*play\|playing.*true.*play" test/
```

Look specifically for test names containing phrases like:
- `"even when X"` / `"even if X"`
- `"still calls Y when Z"`
- `"twice on Y"` / `"idempotent"`
- `"after Y"` (especially `"after seek"`, `"after error"`, `"after reconnect"`)
- `"recovers from"` / `"nudges"` / `"resumes"`
- The specific state word from your log (`stalled`, `frozen`, `orphan`, `race`)

### Step 2: Read the test comment, not just the assertion

If you find a matching test, **read the comment above the assertion**, not
just the `expect()` call. The comment almost always explains *why* the
otherwise-redundant behavior is required. Look for phrases like:
- "mpv/iOS/Chrome/Safari can X even when Y"
- "nudge", "kick", "wake up", "unstick"
- "workaround for", "due to", "race with"
- Bug tracker references, commit SHAs, PR numbers

### Step 3: Correlate with your production log

Re-read the log line that prompted the "fix" through the lens of the test
comment. Does the log state match the bug scenario the test describes?

- If the test says "mpv reports playing=true while stalled at positionMs=0"
  and your log shows `playing=true, positionMs=0`, you are looking at the bug
  the workaround exists to handle. The workaround is **working**.
- If the log state doesn't match the test's stated scenario, you may have
  found a new bug OR a genuinely redundant branch. Proceed carefully.

### Step 4: Preserve behavior, improve observability

If the workaround is load-bearing, don't remove it. Instead:
- Add or improve the log message so future-you understands the intent
  (`nudge_stalled_decoder` is clearer than `redundant_play`).
- Add a code comment referencing the test that guards this behavior
  (`// See test: "rebuffer recovery calls play() even when playing=true"`).
- If the volume is noisy, consider downgrading the log level or sampling it,
  but keep the behavior.

### Step 5: If CI already caught you, revert and learn

If you've already pushed and CI surfaced the guarding test:

1. **Don't "fix" the test to match the new behavior.** The test is the spec.
2. Revert just the behavior change — keep any unrelated improvements
   (logging, comments, etc.).
3. Read the test comment carefully and update your mental model of the system.
4. Commit the revert with a message that captures the lesson so the next
   engineer reading git blame understands why the "redundant" call is there.

## Verification

After applying this skill, you should be able to answer:

- [ ] Is there a test whose name describes the behavior I'm about to remove?
- [ ] If yes, does its comment explain a bug/race/platform quirk that justifies it?
- [ ] Does the production log I'm reacting to match that bug's scenario?
- [ ] Can I explain in one sentence *why* the "redundant" behavior exists,
      with enough detail that a reviewer would agree?

If you can't answer all four, you don't yet know enough to remove the code.

## Example

**Scenario** (real, Flutter + media_kit video player):

Production log from iOS:
```
STUTTER_DEBUG rebuffer_auto_play index=48 positionMs=0 playing=true
```

Instinct: "Why call `player.play()` when `player.state.playing` is already
true? That's a no-op at best. Let me add `if (!player.state.playing)`."

**Wrong fix applied.** CI fails:
```
 - [FAILED] VideoFeedController post-seek rebuffer recovery
   rebuffer recovery calls play() even when player reports playing
```

Reading the test (which was already in the repo):
```dart
test(
  'rebuffer recovery calls play() even when player reports playing',
  () async {
    // ...
    // Simulate rebuffer completes while player reports playing=true.
    // mpv can stall (no frame output) even when playing=true after a
    // seek, so we always call play() to nudge the decoder.
    when(() => setup.state.playing).thenReturn(true);
    // ...
    verify(setup.player.play).called(greaterThanOrEqualTo(1));
  },
);
```

The test comment documents the exact bug: **mpv's `playing=true` does not
guarantee frame output after a seek or network hiccup**. The "redundant"
`play()` call is specifically to unstick the decoder in that state. The
production log showing `positionMs=0, playing=true` for seconds is the bug
happening in production — and the workaround is the reason videos recover
instead of staying frozen.

**Correct response**: Revert the `if (!playing)` guard. Keep it calling
`play()` unconditionally. If the log is noisy, rename the log tag from
`rebuffer_auto_play` to `decoder_nudge` to reflect the actual purpose, and
add a source comment pointing at the test.

## Notes

- This skill is about **code you didn't write**. Your own recent code is
  unlikely to have a hidden workaround you forgot about.
- Particularly common in: video/audio playback, network retry paths, browser
  quirks, GPU/driver workarounds, filesystem race conditions, distributed
  systems idempotency, animation/layout pipelines.
- A test whose name contains the phrase *"even when"* or *"even if"* is the
  single strongest signal that you're looking at a guarded workaround.
- Conversely, if you *add* a workaround, write the test with a name that
  literally describes the surprising behavior, so the next engineer (or
  future-you) gets the warning you wish you'd gotten.
- Related: `superpowers:verification-before-completion` (don't claim a fix
  works until you've actually run the test that guards the behavior) and
  `simplify` (which should also respect this rule — don't simplify away
  code that a test explicitly asserts).

## References

- Original session: Divine Mobile PR #2737, iOS video stutter debugging,
  2026-04-05.
- Related skill: `mock-call-count-retry-fallback` — for the inverse case
  where adding retry logic breaks test call counts.
