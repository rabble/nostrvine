-- ABOUTME: The ClickHouse query that produced og_beta_testers.dart.
-- ABOUTME: Kept for review; the roster is frozen and will not be re-run.
--
-- Produced 2,947 pubkeys. The committed roster holds 2,941: six QA accounts
-- (handles `_@testaccount`, `_@testprofile`, `_@testsanti`, `_@tester`,
-- `_@testuserhere`, and `teste556@divine.video`) were removed in review.
-- Note the handles are not a single pattern: `teste556@divine.video` does
-- not match `_@test*`, so neither a handle sweep nor a display-name sweep
-- finds all six on its own.
--
-- This is NOT re-derivable. NIP-05 is mutable, so membership drifts after the
-- fact: 3 members no longer hold a Divine handle, and 154 have no kind-0
-- profile in funnelcake at all. The query records how the roster was built,
-- not a check that can be re-run against it.

WITH divine_handles AS (
  SELECT DISTINCT pubkey
  FROM nostr.user_profiles_latest_data
  WHERE endsWith(nip05_lower, '@openvine.co')
     OR endsWith(nip05_lower, 'divine.video')
), viners AS (
  -- `platform` is relay metadata set by Funnelcake for genuine archive
  -- imports, so it cannot be spoofed by a crafted event. Excluding these
  -- here is what makes the OG Viner chit take precedence without a
  -- runtime check.
  SELECT DISTINCT pubkey FROM nostr.events_local WHERE platform = 'vine'
)
SELECT DISTINCT lower(CAST(e.pubkey AS String)) AS pk
FROM nostr.events_local AS e
INNER JOIN divine_handles AS d ON d.pubkey = e.pubkey
WHERE e.kind = 34236
  AND e.platform != 'vine'
  -- Half-open: the beta window closed at the end of 2026-08-17.
  AND e.created_at >= toDateTime('2025-01-01 00:00:00')
  AND e.created_at <  toDateTime('2026-08-18 00:00:00')
  AND e.pubkey NOT IN (SELECT pubkey FROM viners)
ORDER BY pk
