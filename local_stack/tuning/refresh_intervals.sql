-- Shorten the refreshable-materialized-view intervals that local development
-- and the e2e suite depend on.
--
-- WHY
--
-- funnelcake serves several read models out of snapshot tables fed by
-- refreshable MVs rather than querying live. On production cadences those
-- snapshots rebuild every 5-30 minutes, which is correct there and useless
-- locally: a video published now is invisible to `GET /api/users/{pubkey}/videos`
-- until the next rebuild.
--
-- Measured on a stack built from funnelcake main (2026-08-07): 110 kind-34236
-- events sat in `nostr.events_local` while `SELECT count() FROM nostr.video_stats`
-- returned 0, with `next_refresh_time` 4.5 minutes out. `video_stats` stopped
-- being a live view at migration 000160 and its MV settled at
-- `REFRESH EVERY 15 MINUTE OFFSET 3 MINUTE` (000182, then 000184).
--
-- integration_test/helpers/http_helpers.dart polls that endpoint with
-- `maxSeconds = 30`, so deleted_video_visible_to_other_users_test.dart fails at
-- its first phase without this. After the ALTER below a freshly published video
-- appeared within ~10 seconds.
--
-- SCOPE
--
-- Only the MVs local development actually reads. A schema-200 database has 38
-- refreshable MVs; blanket-shortening all of them would make a laptop churn on
-- recomputes for read models nothing here touches.
--
-- Statements are applied one at a time and failures are ignored, because none
-- of these MVs exist on the pinned 2026-02-24 schema (which has 6 refreshable
-- MVs, none of them these). On that schema this file is a no-op.

-- The read model behind GET /api/users/{pubkey}/videos. Required by the e2e.
ALTER TABLE nostr.video_stats_snapshot_refresh_mv MODIFY REFRESH EVERY 10 SECOND;

-- Feed read models, so a developer poking at the app sees their own writes.
ALTER TABLE nostr.recent_videos_snapshot_refresh_mv MODIFY REFRESH EVERY 10 SECOND;
ALTER TABLE nostr.popular_videos_snapshot_refresh_mv MODIFY REFRESH EVERY 30 SECOND;
ALTER TABLE nostr.trending_videos_snapshot_refresh_mv MODIFY REFRESH EVERY 30 SECOND;
ALTER TABLE nostr.video_event_card_snapshot_refresh_mv MODIFY REFRESH EVERY 10 SECOND;
ALTER TABLE nostr.relay_feed_cache_refresh_mv MODIFY REFRESH EVERY 10 SECOND;
ALTER TABLE nostr.user_feed_video_candidates_refresh_mv MODIFY REFRESH EVERY 30 SECOND;
