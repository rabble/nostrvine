# Mobile PR Preview Refresh Comments Design

**Date:** 2026-04-14
**Status:** Approved

## Problem

The mobile PR preview deploy reuses a single bot comment and edits it in place on each push. That keeps the PR thread tidy, but it makes fresh preview deploys easy to miss because:

- the preview URL stays the same for the whole PR
- the deploy workflow is triggered through `workflow_run`, so it is less obvious in the checks UI
- the PR conversation does not show a new entry when a preview refreshes

People reviewing the PR can reasonably conclude that the preview did not rebuild even when it did.

## Decision

Post a brand-new PR comment for every preview refresh.

- Each successful preview deploy creates a new comment instead of updating an older one.
- The comment starts with a clear status line that includes the short commit SHA.
- The same create-new-comment behavior applies to the "preview deployment is not configured" path so the workflow is consistent in both cases.

This deliberately trades extra bot comments for clarity. The goal is not a tidy thread; the goal is making refreshes impossible to miss.

## Comment Behavior

### Successful deploy

Each successful deploy posts a comment with:

- a first line like `Preview refreshed for 212fe33`
- the stable preview URL
- the refresh timestamp
- a link to the deploy workflow run
- the preview branch, PR branch, and commit SHA

The preview URL remains stable per PR because Cloudflare Pages still deploys to the same `pr-<number>` branch.

### Missing configuration

If preview deployment secrets are missing, the workflow still posts a new comment for that refresh with:

- a first line like `Preview refresh blocked for 212fe33`
- the refresh timestamp
- the workflow run link
- the missing secret names
- the preview branch, PR branch, and commit SHA

This avoids silently rewriting an older warning comment.

## Implementation Shape

- Extract preview comment rendering into a small Python script so comment copy is generated in one place.
- Have the workflow write the rendered comment body to a temporary markdown file.
- Update both comment-posting branches of `mobile_pr_preview_deploy.yml` to always call `createComment`.
- Remove the old logic that searched for and updated an existing `## Mobile PR Preview` comment.

## Files In Scope

| File | Change |
|------|--------|
| `.github/workflows/mobile_pr_preview_deploy.yml` | Always create a new preview comment and use the shared renderer |
| `.github/scripts/mobile_pr_preview_comment.py` | Render deploy and blocked comment bodies |
| `.github/scripts/tests/test_mobile_pr_preview_comment.py` | Verify the rendered output includes the new refresh wording and key metadata |

## Out Of Scope

- Changing the preview URL format
- Changing Cloudflare Pages branch naming
- Reworking the `workflow_run` deploy trigger model
- Adding commit statuses or check-run annotations separate from the PR comments

## Testing

- Unit test the comment renderer for both `deployed` and `blocked` modes
- Verify the workflow references the renderer and no longer calls `updateComment`
- Run the focused Python unittest locally before pushing
