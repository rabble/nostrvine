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
-- being a live view at migration 000143 (`DROP VIEW nostr.video_stats` ->
-- `CREATE VIEW ... FROM nostr.video_stats_snapshot`, initially 60s) and its MV
-- was widened to `REFRESH EVERY 15 MINUTE OFFSET 3 MINUTE` by 000182/000184.
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
ALTER TABLE nostr.relay_feed_cache_refresh_mv MODIFY REFRESH EVERY 10 SECOND;
ALTER TABLE nostr.user_feed_video_candidates_refresh_mv MODIFY REFRESH EVERY 30 SECOND;

-- DELIBERATELY NOT SHORTENED: video_event_card_snapshot_refresh_mv.
--
-- Shortening it buys nothing. It reads `nostr.classic_videos_snapshot`
-- (000170:642), whose only writer is classic_videos_snapshot_refresh_mv at
-- 10 minutes (000182:47), which is not in the list above. Setting the card MV
-- to 10s would just make it free-run against a source that still rebuilds
-- every 10 minutes. Nothing in local dev reads it either — the e2e polls
-- `/api/users/{pubkey}/videos`, which is the video_stats path.
--
-- It is also the one MV that was given an ordering guarantee:
-- `DEPENDS ON nostr.classic_videos_snapshot_refresh_mv` (000170:620), the only
-- DEPENDS ON in the schema. 000184 warns that "MODIFY REFRESH replaces ALL
-- refresh parameters, so touching it would silently drop that dependency."
-- Worth knowing that upstream already tripped this: 000182:50 ran exactly that
-- ALTER, so the clause is gone by schema 210 — `SELECT create_table_query`
-- shows `REFRESH EVERY 10 MINUTE TO ...` with no DEPENDS ON, and nothing after
-- 000182 restores it. Re-altering it here would not restore it either, and
-- would only add churn, so leave it alone.
--
-- 000184:80 confirms none of the six MVs above declare RANDOMIZE, OFFSET,
-- DEPENDS ON or refresh SETTINGS, so `MODIFY REFRESH` is lossless for them.
