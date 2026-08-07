---
name: sqlite-fts5-corruption-rebuild
description: |
  Fix SQLite "database disk image is malformed" errors caused by corrupted FTS5 indexes.
  Use when: (1) UPDATE/INSERT fails with "stepping, database disk image is malformed" but
  PRAGMA integrity_check returns "ok", (2) Only specific records fail to update while others
  succeed, (3) Records contain dirty text with tabs, newlines, or unusual characters that
  were inserted into FTS5-indexed columns. The misleading error message suggests disk
  corruption, but the actual issue is FTS5 index corruption from malformed text content.
author: Claude Code
version: 1.0.0
date: 2026-01-23
---

# SQLite FTS5 Index Corruption from Dirty Data

## Problem
SQLite returns "database disk image is malformed" (error code 11) when trying to
UPDATE or INSERT records, even though `PRAGMA integrity_check` reports the database
as "ok". The error only affects specific records, not all writes.

## Context / Trigger Conditions
- Error message: `Error: stepping, database disk image is malformed (11)`
- `PRAGMA integrity_check` returns `ok` (misleading!)
- SELECT queries on the same records work fine
- Only certain records fail to update; other records in the same table update successfully
- The affected records contain text with embedded tabs (`\t`), newlines (`\n`), or other
  control characters in columns that are indexed by FTS5
- A concurrent process (like a Node.js server) may have the database open

## Solution

1. **Identify FTS5 tables** linked to the affected table:
   ```sql
   SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '%fts%';
   ```

2. **Stop any processes** holding the database open (the rebuild requires exclusive access):
   ```bash
   kill $(lsof -ti :PORT)  # Kill the server process
   ```

3. **Rebuild the FTS5 index**:
   ```sql
   INSERT INTO table_fts(table_fts) VALUES('rebuild');
   ```
   Replace `table_fts` with your actual FTS5 table name (e.g., `people_fts`).

4. **Retry the failed operation** - it should now succeed.

5. **Restart your application server**.

## Verification
- The previously failing UPDATE/INSERT statement now succeeds
- Full-text search queries still return correct results
- No more "malformed" errors on subsequent writes

## Example

```bash
# Error occurs:
sqlite3 data/tracker.db "UPDATE people SET name = 'More' WHERE id = 11;"
# Error: stepping, database disk image is malformed (11)

# But integrity check passes:
sqlite3 data/tracker.db "PRAGMA integrity_check;"
# ok

# And SELECT works fine:
sqlite3 data/tracker.db "SELECT id, name FROM people WHERE id = 11;"
# 11|More Masajes\t\n\t\tEscort 23 años...

# Fix: Stop server, rebuild FTS5 index
kill $(lsof -ti :3001)
sqlite3 data/tracker.db "INSERT INTO people_fts(people_fts) VALUES('rebuild');"

# Now the update works:
sqlite3 data/tracker.db "UPDATE people SET name = 'More' WHERE id = 11;"
# Success!
```

## Prevention
- Sanitize text before inserting into FTS5-indexed columns:
  ```javascript
  const cleanName = rawName.replace(/[\t\n\r]+/g, ' ').trim();
  ```
- Strip control characters from scraped data before database insertion
- Consider using `content=` (external content) FTS5 tables that can be rebuilt
  independently without affecting the main table

## Notes
- The error code 11 (`SQLITE_CORRUPT`) is the same as actual disk corruption,
  making this hard to diagnose
- The corruption is in the FTS5 shadow tables (`_data`, `_idx`, `_docsize`),
  not the main table, which is why `integrity_check` passes
- If `rebuild` fails with "database is locked", ensure no other process has
  the database open (check with `lsof` or `fuser`)
- This can also happen when records are deleted or updated externally
  (e.g., via sqlite3 CLI) while a WAL-mode connection is active

## References
- [SQLite FTS5 Documentation - rebuild command](https://www.sqlite.org/fts5.html#the_rebuild_command)
- [SQLite Error Codes](https://www.sqlite.org/rescode.html#corrupt)
