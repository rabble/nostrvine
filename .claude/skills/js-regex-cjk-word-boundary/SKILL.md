---
name: js-regex-cjk-word-boundary
description: |
  Fix JavaScript regex failures when matching CJK (Chinese/Japanese/Korean) text using \b word
  boundaries. Use when: (1) Regex pattern with \b silently fails to match Japanese, Chinese, or
  Korean text, (2) Pattern works for Latin/ASCII text but not CJK, (3) hasDriverLicenceCue or
  similar text-detection function returns false for CJK input despite correct characters,
  (4) inferIssuerFromTitleText or pattern-matching functions fail on non-Latin scripts.
  Root cause: JavaScript \b only recognizes [a-zA-Z0-9_] as "word characters" — CJK characters
  are classified as \W (non-word), so \b before/after CJK always sees a non-word/non-word
  boundary and fails to match.
author: Claude Code
version: 1.0.0
date: 2026-03-09
---

# JavaScript Regex: \b Word Boundary Fails with CJK Characters

## Problem

JavaScript's `\b` (word boundary) assertion silently fails when used with CJK
(Chinese/Japanese/Korean) characters. The regex compiles without error and runs without
throwing, but it simply never matches CJK text that should match. This is particularly
insidious because:

1. No error is thrown — the regex just returns `false`
2. The same pattern works perfectly for Latin/ASCII text
3. The CJK characters in the pattern are correct (verified by direct string comparison)

## Context / Trigger Conditions

- Regex pattern like `/\b\u904B\u8EE2\u514D\u8A31\u8A3C\b/` (Japanese: 運転免許証) returns `false`
  on text containing the exact characters
- Pattern like `/\b\uC6B4\uC804\uBA74\uD5C8\uC99D\b/` (Korean: 운전면허증) fails similarly
- Text-detection functions (e.g., `hasDriverLicenceCue()`, `inferIssuerFromTitleText()`) return
  incorrect results for CJK input while working correctly for all Latin-script patterns
- Any regex using `\b` boundaries around non-ASCII Unicode characters (also affects Cyrillic,
  Arabic, Thai, etc.)

## Root Cause

JavaScript's `\b` matches the boundary between a "word character" (`\w` = `[a-zA-Z0-9_]`) and
a "non-word character" (`\W`). CJK characters are classified as `\W` (non-word characters).

When `\b` appears before a CJK character, it looks for a `\w`-to-`\W` or `\W`-to-`\w`
transition. But if the preceding character is also `\W` (whitespace, punctuation, start of
string, or another CJK character), the boundary condition is `\W`-to-`\W`, which `\b` does
NOT match.

```javascript
// This FAILS — \b doesn't work with CJK
/\b\u904B\u8EE2\u514D\u8A31\u8A3C\b/.test("運転免許証")  // false!

// This WORKS — no word boundaries
/\u904B\u8EE2\u514D\u8A31\u8A3C/.test("運転免許証")  // true
```

## Solution

### Quick Fix: Remove `\b` from CJK patterns

Simply remove `\b` assertions from any regex pattern that matches CJK characters:

```javascript
// Before (broken):
[/\b\u904B\u8EE2\u514D\u8A31\u8A3C\b/, "JAPAN"],      // 運転免許証
[/\b\uC6B4\uC804\uBA74\uD5C8\uC99D\b/, "KOREA"],      // 운전면허증

// After (working):
[/\u904B\u8EE2\u514D\u8A31\u8A3C/, "JAPAN"],            // 運転免許証
[/\uC6B4\uC804\uBA74\uD5C8\uC99D/, "KOREA"],           // 운전면허증
```

### Better Fix: Use Unicode-aware boundaries (if available)

For environments supporting the `v` flag (ES2024+), you can use Unicode property escapes:

```javascript
// Unicode-aware approach (requires /v flag support):
/(?<=^|[\s\p{P}])\u904B\u8EE2\u514D\u8A31\u8A3C(?=$|[\s\p{P}])/v
```

### Alternative: Manual boundary with lookbehind/lookahead

```javascript
// Manual boundary that works with CJK:
/(?<!\p{L})\u904B\u8EE2\u514D\u8A31\u8A3C(?!\p{L})/u
```

### For mixed Latin/CJK pattern arrays

When you have an array of patterns where some are Latin and some are CJK, use `\b` only for
Latin patterns:

```javascript
const patterns = [
  [/\bDRIVER'?S?\s+LICEN[CS]E\b/, "match"],   // Latin — \b works
  [/\bFÜHRERSCHEIN\b/, "match"],               // Latin+diacritics — \b works (Ü is \W but context helps)
  [/\u904B\u8EE2\u514D\u8A31\u8A3C/, "match"], // CJK — no \b needed
  [/\uC6B4\uC804\uBA74\uD5C8\uC99D/, "match"], // CJK — no \b needed
];
```

## Verification

```javascript
// Test that CJK matching works:
console.log(/\u904B\u8EE2\u514D\u8A31\u8A3C/.test("運転免許証"));  // true
console.log(/\uC6B4\uC804\uBA74\uD5C8\uC99D/.test("운전면허증"));  // true

// Verify it doesn't false-match substrings you don't want:
console.log(/\u904B\u8EE2\u514D\u8A31\u8A3C/.test("別の運転免許証テスト"));  // true (substring match is usually fine for CJK)
```

## Example

Real-world case from a document-type detection function:

```javascript
function hasDriverLicenceCue(text) {
  const combined = text.toUpperCase();
  return (
    /\bDRIVER'?S?\s+LICEN[CS]E\b/.test(combined) ||   // English
    /\bFÜHRERSCHEIN\b/.test(combined) ||               // German
    /\bPERMIS DE CONDUIRE\b/.test(combined) ||          // French
    /\u904B\u8EE2\u514D\u8A31\u8A3C/.test(combined) || // Japanese (no \b!)
    /\uC6B4\uC804\uBA74\uD5C8\uC99D/.test(combined)    // Korean (no \b!)
  );
}
```

## Notes

- This affects ALL non-ASCII Unicode scripts, not just CJK: Cyrillic, Arabic, Thai, Devanagari, etc.
- The `u` (unicode) flag does NOT fix this — `\b` behavior with `\w`/`\W` is unchanged.
- Removing `\b` from CJK patterns is generally safe because CJK characters are unlikely to
  appear as substrings within other words in unrelated contexts.
- The `regexp-cjk` npm package provides CJK-aware regex utilities if you need more sophisticated matching.
- When debugging: if a regex works for "DRIVER'S LICENCE" but not "運転免許証", suspect `\b` first.

## References

- [MDN: Word boundary assertion \b](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Regular_expressions/Word_boundary_assertion)
- [TC39 Issue #1020: Regexp with word boundaries do not match cyrillic string](https://github.com/tc39/ecma262/issues/1020)
- [Word boundaries in JavaScript's regular expressions with UTF-8 strings](https://breakthebit.org/post/3446894238/word-boundaries-in-javascripts-regular)
- [regexp-cjk npm package](https://www.npmjs.com/package/regexp-cjk)
