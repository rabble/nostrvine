---
name: bash-herestring-newline-secrets
description: |
  Fix password/secret authentication failures caused by trailing newlines when creating
  Google Cloud secrets (or similar) with bash here-strings. Use when: (1) Password
  authentication fails with correct password, (2) Secret created with `<<< "value"` syntax,
  (3) Error like "password authentication failed" or "invalid token" despite correct value.
  Bash here-strings (`<<<`) add a trailing newline that corrupts secrets.
author: Claude Code
version: 1.0.0
date: 2026-01-31
---

# Bash Here-String Newline in Secrets

## Problem
When creating secrets using bash here-strings (`<<<`), a trailing newline is silently
appended to the value. This causes authentication failures with misleading error messages
that suggest the password/token is wrong when it's actually correct—just with an extra
newline character.

## Context / Trigger Conditions
- Secret created with: `gcloud secrets create NAME --data-file=- <<< "value"`
- Or similar: `echo "value" | gcloud secrets create...` (echo adds newline by default)
- Error messages like:
  - "password authentication failed for user X"
  - "invalid token"
  - "authentication failed"
- The secret value appears correct when viewed
- Works locally but fails when secret is used

## Solution

**Wrong (adds newline):**
```bash
gcloud secrets create my-secret --data-file=- <<< "mypassword"
echo "mypassword" | gcloud secrets create my-secret --data-file=-
```

**Correct (no newline):**
```bash
echo -n "mypassword" | gcloud secrets create my-secret --data-file=-
printf '%s' "mypassword" | gcloud secrets create my-secret --data-file=-
```

**To fix an existing secret:**
```bash
echo -n "correct-value" | gcloud secrets versions add my-secret --data-file=-
```

## Verification

Check the secret length to detect trailing newline:
```bash
# Get secret and count bytes
gcloud secrets versions access latest --secret=my-secret | wc -c
# Compare to expected length (password length, not password length + 1)
```

Or use `xxd` to see the actual bytes:
```bash
gcloud secrets versions access latest --secret=my-secret | xxd | tail -1
# Look for '0a' (newline) at the end
```

## Example

**Symptom:**
```
Database connection test failed: password authentication failed for user "crawler"
```

**Investigation:**
```bash
$ gcloud secrets versions access latest --secret=my-db-password
mypassword
$ gcloud secrets versions access latest --secret=my-db-password | wc -c
11  # But password is only 10 characters!
```

**Fix:**
```bash
$ echo -n "mypassword" | gcloud secrets versions add my-db-password --data-file=-
Created version [2] of the secret [my-db-password].
```

## Notes
- This affects any system that uses secrets: databases, APIs, tokens, etc.
- The `<<<` here-string is a bash feature that ALWAYS adds a newline
- `echo` also adds a newline by default; use `echo -n` or `printf '%s'`
- Some systems trim whitespace from secrets, but many (like PostgreSQL) don't
- When debugging auth failures, always check for trailing whitespace first

## References
- Bash manual on here-strings: https://www.gnu.org/software/bash/manual/bash.html#Here-Strings
