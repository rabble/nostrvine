# Classic Viner Seed Manifest Design

**Problem**

Classic Viner profile identity data is effectively static for this product, but the app still treats it like live data. That creates unnecessary delay for headers, archived counts, and avatar rendering even though this dataset can be shipped ahead of time.

**Goals**

- Bundle static classic-Viner profile header data with the app.
- Bundle avatar image files for those classic Viners.
- Hydrate seeded metadata and archived counts into existing caches.
- Make avatar images available locally through the existing image-loading path.

**Non-Goals**

- Bundle every classic profile video grid.
- Replace live profile fetching for non-classic users.
- Force heavy avatar extraction onto the critical startup path.

**Current Code References**

- `mobile/lib/main.dart`
- `mobile/lib/services/seed_data_preload_service.dart`
- `mobile/lib/services/seed_media_preload_service.dart`
- `mobile/lib/services/image_cache_manager.dart`
- `mobile/lib/widgets/user_avatar.dart`
- `mobile/packages/profile_repository/lib/src/profile_repository.dart`
- `mobile/packages/db_client/lib/src/database/daos/profile_stats_dao.dart`

**Proposed Design**

1. Add a bundled manifest for classic-Viner metadata.
   - Fields: `pubkey`, `displayName`, `pictureUrl`, optional `bannerUrl`, optional `about`, archived `videoCount`, archived `totalViews`/`totalLoops`.
   - Treat the manifest as versioned seed data.

2. Bundle avatar image files separately.
   - Include avatar file names in the manifest.
   - Keep metadata and bytes distinct so imports are easier to stage.

3. Hydrate seeded metadata into existing caches.
   - Upsert `UserProfile` rows into Drift.
   - Upsert archived stats into `ProfileStatsDao`.
   - Use an idempotent version marker so the import can run once per seed version.

4. Hydrate avatar bytes into the existing image cache.
   - Keep canonical avatar URLs in the seeded profile rows.
   - Populate `openVineImageCache` with the bundled bytes under those URLs so `CachedNetworkImage` remains the read path.

5. Use two phases for speed.
   - Metadata/count import can happen in the seed preload path.
   - Avatar-byte hydration should happen after first frame or on first classic/profile access to avoid growing startup tax further.

**File Boundaries**

- Asset files:
  - `mobile/assets/seed_data/classic_viner_profiles.json`
  - `mobile/assets/seed_media/classic_viner_avatars/*`
- Import services:
  - `mobile/lib/services/classic_viner_seed_preload_service.dart`
  - `mobile/lib/services/seed_data_preload_service.dart`
  - `mobile/lib/services/seed_media_preload_service.dart`
- Cache consumers:
  - `mobile/lib/services/image_cache_manager.dart`
  - `mobile/lib/widgets/user_avatar.dart`
  - `mobile/packages/profile_repository/lib/src/profile_repository.dart`

**Verification**

- Service tests for idempotent metadata/stats import.
- Cache tests or widget tests proving seeded avatar bytes are served locally.
- Smoke tests for classic-profile header render from seeded data.

**Risks**

- Asset size can grow quickly if the avatar pack is too large.
- Canonical URL mismatches would make seeded bytes invisible to `CachedNetworkImage`.
- Seed versioning errors can cause duplicate import work or stale data after app upgrades.
