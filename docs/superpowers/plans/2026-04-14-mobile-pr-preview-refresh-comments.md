# Mobile PR Preview Refresh Comments Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every mobile PR preview refresh create a new PR comment so reviewers can clearly see that a fresh preview was deployed for the latest push.

**Architecture:** Keep the existing build and deploy workflow structure, but move comment body generation into a small Python script. The deploy workflow will render the markdown body for either the deployed or blocked state, then always create a new PR comment instead of finding and updating an older one.

**Tech Stack:** GitHub Actions YAML, Python 3, unittest

---

## File Structure

**Create**
- `.github/scripts/mobile_pr_preview_comment.py`
- `.github/scripts/tests/test_mobile_pr_preview_comment.py`

**Modify**
- `.github/workflows/mobile_pr_preview_deploy.yml`

**Why this structure**
- Keep comment copy out of embedded workflow JavaScript so it is easier to test and review.
- Limit the behavior change to the deploy workflow that already owns preview comments.
- Add one focused regression test instead of introducing a larger workflow-testing framework.

## Chunk 1: Add A Failing Comment Renderer Test

### Task 1: Define the refreshed comment output before implementation

**Files:**
- Create: `.github/scripts/tests/test_mobile_pr_preview_comment.py`
- Use: `.github/workflows/mobile_pr_preview_deploy.yml`

- [ ] **Step 1: Write a failing unittest for successful deploy comments**

Add a test that executes the planned renderer script in `deployed` mode and expects:

- a line starting with `Preview refreshed for`
- the preview URL
- the workflow run link
- the preview branch, PR branch, and short SHA

- [ ] **Step 2: Write a failing unittest for blocked deploy comments**

Add a second test that executes the renderer in `blocked` mode and expects:

- a line starting with `Preview refresh blocked for`
- the missing secret names
- the preview branch, PR branch, and short SHA

- [ ] **Step 3: Run the test file to verify it fails**

Run:

```bash
python3 .github/scripts/tests/test_mobile_pr_preview_comment.py
```

Expected: FAIL because the renderer script does not exist yet.

## Chunk 2: Implement The Shared Renderer

### Task 2: Create the minimal script that renders both comment variants

**Files:**
- Create: `.github/scripts/mobile_pr_preview_comment.py`
- Test: `.github/scripts/tests/test_mobile_pr_preview_comment.py`

- [ ] **Step 1: Add a CLI renderer**

Implement a Python script that accepts:

- `--mode deployed|blocked`
- `--sha`
- `--updated-at`
- `--run-url`
- `--preview-branch`
- `--head-ref`
- `--deployment-url` for deployed mode

The script should print markdown to stdout.

- [ ] **Step 2: Run the unittest to verify it passes**

Run:

```bash
python3 .github/scripts/tests/test_mobile_pr_preview_comment.py
```

Expected: PASS.

## Chunk 3: Wire The Workflow To Always Create New Comments

### Task 3: Switch the deploy workflow to the shared renderer and `createComment`

**Files:**
- Modify: `.github/workflows/mobile_pr_preview_deploy.yml`
- Use: `.github/scripts/mobile_pr_preview_comment.py`

- [ ] **Step 1: Add a body-rendering step for blocked deploys**

Render the blocked markdown body into a temporary file with the shared Python script.

- [ ] **Step 2: Replace the blocked-path update logic**

Update the blocked comment step to read the rendered file and always call `github.rest.issues.createComment`.

- [ ] **Step 3: Add a body-rendering step for successful deploys**

Render the deployed markdown body into a temporary file with the shared Python script.

- [ ] **Step 4: Replace the deployed-path update logic**

Update the deployed comment step to read the rendered file and always call `github.rest.issues.createComment`.

- [ ] **Step 5: Verify the workflow no longer uses `updateComment`**

Run:

```bash
rg -n "updateComment|Mobile PR Preview" .github/workflows/mobile_pr_preview_deploy.yml .github/scripts/mobile_pr_preview_comment.py
```

Expected: no `updateComment` calls remain, and the new renderer owns the comment copy.

## Chunk 4: Final Verification And Commit

### Task 4: Verify the full change set and record the work

**Files:**
- Verify: `.github/workflows/mobile_pr_preview_deploy.yml`
- Verify: `.github/scripts/mobile_pr_preview_comment.py`
- Verify: `.github/scripts/tests/test_mobile_pr_preview_comment.py`
- Verify: `docs/superpowers/specs/2026-04-14-mobile-pr-preview-refresh-comments-design.md`
- Verify: `docs/superpowers/plans/2026-04-14-mobile-pr-preview-refresh-comments.md`

- [ ] **Step 1: Run the focused verification**

Run:

```bash
python3 .github/scripts/tests/test_mobile_pr_preview_comment.py
```

Expected: PASS.

- [ ] **Step 2: Review the task diff**

Run:

```bash
git status --short
git diff -- .github/workflows/mobile_pr_preview_deploy.yml .github/scripts/mobile_pr_preview_comment.py .github/scripts/tests/test_mobile_pr_preview_comment.py docs/superpowers/specs/2026-04-14-mobile-pr-preview-refresh-comments-design.md docs/superpowers/plans/2026-04-14-mobile-pr-preview-refresh-comments.md
```

Expected: only task-related files are changed.

- [ ] **Step 3: Commit the task**

```bash
git add .github/workflows/mobile_pr_preview_deploy.yml .github/scripts/mobile_pr_preview_comment.py .github/scripts/tests/test_mobile_pr_preview_comment.py docs/superpowers/specs/2026-04-14-mobile-pr-preview-refresh-comments-design.md docs/superpowers/plans/2026-04-14-mobile-pr-preview-refresh-comments.md
git commit -m "ci(mobile): post new preview comment for each refresh"
```
