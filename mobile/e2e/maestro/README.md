# Maestro E2E tests

This folder contains end-to-end UI tests written with **Maestro**.

The purpose of these tests is to provide **fast, high-signal regression detection** for user flows from critical to normal. They are not intended to replace unit tests or widget tests. Camera features are out of scope for this tests.

These tests are:
- **Black-box by design**, do not expect BE calls for validations.
- Focused on **navigation** and **functionality**

---

## What Maestro is used for

Maestro is used to:
- Validate user flows (**P0 / P1 / P2**)
- Detect navigation regressions early
- Assert expected screens and UI states
- Act as a release gate to filter unwanted results
- Provide fast feedback during development

Maestro is **not** used for:
- Full functional regression
- Debugging through logs or console output
- White-box testing or internal state validation
- Verifying business logic
- Replacing unit or widget tests
- Camera and recording features

---

## Folder structure

```
e2e/maestro
├── flows/
├── tests/
├── asserts/
├── utils/
├── scripts/
└── README.md
```

---

## Flow tiers

The scope of the changes performed on a PR will determine which tests to run.

---

## Prerequisites

Install Maestro using Homebrew:

```bash
brew install maestro
```

Verify installation:

```bash
maestro --version
```

---

## Running tests

### Full regression

```bash
maestro test e2e/maestro/flows/
```

This is the default command to run to validate all flows before pushing or merging changes.

---

## Environments

Maestro tests can run:
- Against a **locally running app**
- On a **devices cloud**, depending on parameters passed to the scripts

There is currently **no dedicated development environment**.  
Tests are **safe to run against production builds**.

---

## Debugging philosophy

Maestro tests are **black-box** by design.

Limitations:
- No console logging
- No debug or verbose CLI mode

Debugging relies on:
- Clear and explicit UI assertions
- Screen-level validation
- Screenshots on failure
- Small, deterministic flows
- Isolated steps executions

---

## Navigation contract

One of the primary goals of these tests is to enforce a **navigation contract**.

Navigation behavior (including back actions) must be:
- Explicit
- Agreed upon
- Stable

Navigation is validated using visual flow diagrams and product or founder confirmation.

Maestro flows should only be written **after** navigation behavior has been confirmed.  
If navigation changes intentionally, related tests must be updated as part of the same change.

---

## Ownership and contributions

Maestro tests are **owned by QA**.

Developers are encouraged to:
- Run tests locally
- Report failures
- Propose improvements

Changes to any of the automated flows should be made carefully, as they act as release alarms.

---

## Guiding principle

If a Maestro test fails, something important broke — even if the app still appears to work.

Keep tests **small**, **deterministic**, and **high-signal**.
