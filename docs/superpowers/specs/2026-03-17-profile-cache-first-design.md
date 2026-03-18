# Profile Cache-First Design

**Problem**

Other-user profile routes render quickly, but the first meaningful content is still network-backed. `ProfileFeed` goes straight to `analyticsService.getVideosByAuthor(...)` on first open, and the profile header has split ownership between `OtherProfileBloc` and `fetchUserProfileProvider`.

**Goals**

- Render profile header data immediately from cached or seeded data.
- Preserve profile feed data on revisit and refresh within the same session.
- Remove split ownership of other-user profile data where practical.
- Make classic-Viner seeded data usable without waiting for REST.

**Non-Goals**

- Bundle profile video grids as assets.
- Rebuild the whole profile architecture around a single mega-bloc.
- Change follow/follower fetch semantics in this worktree.

**Current Code References**

- `mobile/lib/providers/profile_feed_provider.dart`
- `mobile/lib/screens/other_profile_screen.dart`
- `mobile/lib/blocs/other_profile/other_profile_bloc.dart`
- `mobile/lib/widgets/profile/profile_header_widget.dart`
- `mobile/test/providers/profile_feed_provider_test.dart`
- `mobile/test/providers/profile_feed_providers_test.dart`
- `mobile/test/blocs/other_profile/other_profile_bloc_test.dart`

**Proposed Design**

1. Add a session cache for first-page profile feed snapshots keyed by pubkey.
   - Reuse cached profile feed state when reopening a profile in the same session.
   - Preserve visible feed data during refreshes.

2. Make header rendering cache-first and seed-aware.
   - Other-user profile routes should prefer `OtherProfileBloc` or seeded/cached profile rows for display.
   - `ProfileHeaderWidget` should not trigger a second “real owner” fetch when the screen already owns that profile.

3. Use archived counts when profile videos are not yet loaded.
   - If the seed-manifest project has populated cached stats, the header should use those instead of `0` while the feed grid is still loading.

4. Keep fresh fetches in the background.
   - Existing REST and relay refresh behavior remains.
   - The worktree changes *when* cached data is surfaced, not *whether* freshness checks run.

**File Boundaries**

- New session cache:
  - `mobile/lib/providers/profile_feed_session_cache.dart`
- Existing profile flow:
  - `mobile/lib/providers/profile_feed_provider.dart`
  - `mobile/lib/screens/other_profile_screen.dart`
  - `mobile/lib/blocs/other_profile/other_profile_bloc.dart`
  - `mobile/lib/widgets/profile/profile_header_widget.dart`

**Verification**

- Provider tests for cached-first first page and refresh preservation.
- Bloc tests for cache+fresh profile load behavior.
- Widget/profile screen tests where header data is available before REST completes.

**Risks**

- Header and feed can disagree if seeded counts are not clearly marked as archived.
- Retaining per-pubkey feed snapshots can grow memory if not bounded.
- Partial migration can leave `ProfileHeaderWidget` still double-fetching in a corner path.
