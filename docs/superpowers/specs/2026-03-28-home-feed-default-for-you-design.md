# Home Feed Default To For You Design

## Goal

Make Home default to `For You` when the user has never picked a Home feed mode, while preserving the existing behavior that remembers the user's last selected Home mode across app restarts and route re-creation.

## Current Behavior

- `VideoFeedBloc` already persists the selected Home feed mode in `SharedPreferences` under `selected_feed_mode`.
- On startup, the bloc restores that saved mode when present.
- The defaults are inconsistent:
  - `VideoFeedStarted` defaults to `FeedMode.forYou`
  - `VideoFeedPage` defaults to `FeedMode.following`
  - `VideoFeedState` defaults to `FeedMode.following`

This mismatch makes Home feel inconsistent when there is no saved preference.

## Proposed Change

- Treat `For You` as the single default Home mode when `selected_feed_mode` is absent.
- Keep using the existing persisted `selected_feed_mode` value when it exists.
- Do not introduce new routing state, providers, or storage keys.

## Implementation Notes

- Update the Home screen entry point so `VideoFeedPage` starts with `FeedMode.forYou` by default.
- Align `VideoFeedState`'s default mode with `FeedMode.forYou` so the UI and bloc state agree before the first load completes.
- Leave `VideoFeedBloc` persistence logic intact. It already restores the saved mode on `VideoFeedStarted` and writes changes on `VideoFeedModeChanged`.

## Testing

- Add a bloc test proving that `VideoFeedStarted()` with no saved preference resolves to `FeedMode.forYou`.
- Add a bloc test proving that a saved `selected_feed_mode` still wins over the default.
- Update any expectations that still assume the initial state defaults to `FeedMode.following`.
