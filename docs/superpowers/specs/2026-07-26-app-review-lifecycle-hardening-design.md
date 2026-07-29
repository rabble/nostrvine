# App Review Lifecycle Hardening Design

## Goal

Keep an in-app review evaluation bound to the authenticated account and
provider container that started it, and use refreshed profile statistics when
deciding eligibility.

## Design

The existing `AppReviewCoordinator` and `AppReviewCoordinatorCubit` split stays
in place. The widget will pass an `isActive` callback that checks all
UI/account preconditions together: the widget is mounted, the app is in the
foreground, authentication is still settled, and the active pubkey still
matches the evaluation's pubkey. The Cubit will call that predicate after every
async boundary and will also stop cleanly when its provider container closes.

Profile-stat loading moves into a small feature-local loader. It will await the
repository refresh before subscribing to Drift's current stats row, with one
timeout around the combined operation. This prevents an existing cached row
from winning the race against the refresh while preserving the bounded,
fail-closed behavior.

## Error Handling

- A changed account, sign-out, background transition, or closed Cubit cancels
  the evaluation without writing cooldown state or opening the native prompt.
- Cubit shutdown never emits a final state after `close()`.
- Profile refresh errors, stream errors, and timeouts return no stats, leaving
  the user ineligible for that foreground cycle.

## Tests

- Close the Cubit while its frame wait is pending and verify the evaluation
  completes without a platform request or post-close emit.
- Change the active-context predicate while platform availability is pending
  and verify no cooldown or native request occurs.
- Verify the stats loader does not subscribe until refresh completes and then
  returns the refreshed row.
- Verify loader errors and timeouts fail closed.

