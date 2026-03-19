# Classic Viner Seed Manifest Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship static classic-Viner headers, archived counts, and avatar images with the app and hydrate them into the existing profile and image caches.

**Architecture:** Add a versioned classic-Viner manifest plus bundled avatar assets, import metadata and archived counts into Drift, and populate the existing image cache with bundled avatar bytes under canonical URLs. Keep metadata import in the seed preload path and defer avatar unpacking to a post-first-frame or on-demand phase.

**Tech Stack:** Flutter assets, Drift/DAOs, `flutter_cache_manager`, service tests, widget tests

---

## Chunk 1: Seed Manifest and Metadata Import

### Task 1: Define the manifest format and import metadata/stats into Drift

**Files:**
- Create: `mobile/assets/seed_data/classic_viner_profiles.json`
- Create: `mobile/lib/services/classic_viner_seed_preload_service.dart`
- Modify: `mobile/lib/main.dart`
- Modify: `mobile/lib/services/seed_data_preload_service.dart`
- Modify: `mobile/packages/profile_repository/lib/src/profile_repository.dart`
- Modify: `mobile/packages/profile_repository/test/src/profile_repository_test.dart`
- Modify: `mobile/packages/db_client/test/src/database/daos/profile_stats_dao_test.dart`

- [ ] **Step 1: Write the failing import tests**

```dart
test('imports classic-viner profile rows from the bundled seed manifest', () async {
  // assert cached profile exists after import
});

test('imports archived profile stats idempotently', () async {
  // run import twice and verify stats rows are updated, not duplicated
});
```

- [ ] **Step 2: Run the targeted tests to verify they fail**

Run from `mobile/packages/profile_repository`: `flutter test test/src/profile_repository_test.dart`

Expected: FAIL because no classic-viner seed import exists yet.

- [ ] **Step 3: Implement the manifest importer**

```dart
class ClassicVinerSeedPreloadService {
  Future<void> loadProfileSeedsIfNeeded({
    required AppDatabase db,
    required ProfileRepository profileRepository,
    required String seedVersion,
  }) async { ... }
}
```

- [ ] **Step 4: Upsert archived stats during import**

Run from `mobile/packages/profile_repository`: `flutter test test/src/profile_repository_test.dart`

Expected: PASS for metadata import coverage.

- [ ] **Step 5: Commit the metadata importer**

```bash
git add mobile/assets/seed_data/classic_viner_profiles.json mobile/lib/services/classic_viner_seed_preload_service.dart mobile/lib/main.dart mobile/lib/services/seed_data_preload_service.dart mobile/packages/profile_repository/lib/src/profile_repository.dart mobile/packages/profile_repository/test/src/profile_repository_test.dart
git commit -m "feat(seed): import classic viner profile metadata"
```

## Chunk 2: Avatar Image Seeding

### Task 2: Seed bundled avatar bytes into the existing image cache

**Files:**
- Create: `mobile/assets/seed_media/classic_viner_avatars/*`
- Modify: `mobile/lib/services/seed_media_preload_service.dart`
- Modify: `mobile/lib/services/image_cache_manager.dart`
- Modify: `mobile/lib/widgets/user_avatar.dart`
- Create: `mobile/test/widgets/classic_viners_slider_test.dart`
- Create: `mobile/test/widgets/user_avatar_test.dart`

- [ ] **Step 1: Write the failing avatar-cache tests**

```dart
testWidgets('seeded classic-viner avatar renders without network fetch', (tester) async {
  // seed image cache for canonical URL and assert UserAvatar resolves locally
});
```

- [ ] **Step 2: Run the targeted tests to verify they fail**

Run from `mobile`: `flutter test test/widgets/user_avatar_test.dart`

Expected: FAIL because no seed-to-image-cache path exists.

- [ ] **Step 3: Implement avatar-byte hydration**

```dart
await openVineImageCache.putFile(
  canonicalUrl,
  avatarBytes,
  fileExtension: 'jpg',
);
```

- [ ] **Step 4: Defer avatar unpacking off the critical startup path**

Run from `mobile`: `flutter test test/widgets/user_avatar_test.dart`

Expected: PASS for local-avatar resolution.

- [ ] **Step 5: Run the focused suite**

Run from `mobile`: `flutter test test/widgets/user_avatar_test.dart test/widgets/classic_viners_slider_test.dart`

Expected: PASS

- [ ] **Step 6: Commit the avatar seeding work**

```bash
git add mobile/assets/seed_media/classic_viner_avatars mobile/lib/services/seed_media_preload_service.dart mobile/lib/services/image_cache_manager.dart mobile/lib/widgets/user_avatar.dart
git commit -m "feat(seed): preload classic viner avatar images"
```
