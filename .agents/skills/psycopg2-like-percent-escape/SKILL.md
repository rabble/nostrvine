---
name: psycopg2-like-percent-escape
description: |
  Fix psycopg2 "IndexError: tuple index out of range" when using LIKE with parameterized queries.
  Use when: (1) cursor.execute() fails with IndexError on a query containing LIKE '%pattern%',
  (2) SQL LIKE wildcards conflict with psycopg2 %s parameter placeholders, (3) Query works
  in psql but fails in Python. The % character has dual meaning: SQL LIKE wildcard AND
  psycopg2's parameter substitution marker.
author: Claude Code
version: 1.0.0
date: 2026-01-29
---

# psycopg2 LIKE Clause Percent Sign Escaping

## Problem

When using psycopg2 with parameterized queries containing SQL LIKE patterns, the `%` character
causes conflicts. The `%` is used both as:
1. SQL LIKE wildcard (e.g., `'%pattern%'`)
2. psycopg2's parameter placeholder marker (e.g., `%s`)

This results in confusing errors like `IndexError: tuple index out of range` because psycopg2
interprets `%c` in `%cdn` as a format specifier.

## Context / Trigger Conditions

- `IndexError: tuple index out of range` from `cursor.execute()`
- Query contains hardcoded LIKE pattern: `WHERE column LIKE '%something%'`
- Query also uses `%s` parameters for other values
- Query works in psql or pgAdmin but fails in Python

Example failing code:
```python
cursor.execute("""
    SELECT * FROM vines
    WHERE url LIKE '%cdn.vine.co%'
    LIMIT %s OFFSET %s
""", (1000, 0))
# IndexError: tuple index out of range
```

## Solution

### Option 1: Escape `%` with `%%` (for static patterns)

Double the percent signs in hardcoded LIKE patterns:

```python
cursor.execute("""
    SELECT * FROM vines
    WHERE url LIKE '%%cdn.vine.co%%'
    LIMIT %s OFFSET %s
""", (1000, 0))
```

### Option 2: Pass LIKE pattern as parameter (recommended)

The cleaner approach - pass the entire LIKE pattern as a parameter:

```python
pattern = '%cdn.vine.co%'
cursor.execute("""
    SELECT * FROM vines
    WHERE url LIKE %s
    LIMIT %s OFFSET %s
""", (pattern, 1000, 0))
```

This is the recommended approach because:
- No escaping confusion
- Pattern can be dynamically constructed
- Follows parameterized query best practices

### Option 3: Use psycopg2.sql module for complex cases

For dynamic SQL construction:

```python
from psycopg2 import sql

query = sql.SQL("""
    SELECT * FROM {table}
    WHERE url LIKE %s
""").format(table=sql.Identifier('vines'))

cursor.execute(query, ('%cdn.vine.co%',))
```

## Verification

After applying the fix:
1. Query executes without IndexError
2. Results correctly match the LIKE pattern
3. Other `%s` parameters are still substituted correctly

## Example

Before (broken):
```python
def get_vines_by_cdn(db, limit, offset):
    cursor = db.cursor()
    cursor.execute("""
        SELECT vine_id, url FROM discovered_vines
        WHERE url LIKE '%cdn.vine.co%'
        ORDER BY created_at
        LIMIT %s OFFSET %s
    """, (limit, offset))
    return cursor.fetchall()
```

After (fixed with Option 1):
```python
def get_vines_by_cdn(db, limit, offset):
    cursor = db.cursor()
    cursor.execute("""
        SELECT vine_id, url FROM discovered_vines
        WHERE url LIKE '%%cdn.vine.co%%'
        ORDER BY created_at
        LIMIT %s OFFSET %s
    """, (limit, offset))
    return cursor.fetchall()
```

After (fixed with Option 2 - recommended):
```python
def get_vines_by_cdn(db, limit, offset):
    cursor = db.cursor()
    cdn_pattern = '%cdn.vine.co%'
    cursor.execute("""
        SELECT vine_id, url FROM discovered_vines
        WHERE url LIKE %s
        ORDER BY created_at
        LIMIT %s OFFSET %s
    """, (cdn_pattern, limit, offset))
    return cursor.fetchall()
```

## Notes

- This issue only affects parameterized queries with `%s` placeholders
- Raw SQL strings without parameters don't have this problem
- The `%%` escape only works when the query uses psycopg2's parameter substitution
- Django's ORM handles this automatically; this is a raw SQL issue
- psycopg3 uses `$1, $2` style placeholders, avoiding this conflict entirely

## Related Issues

- Searching for literal `%` in data requires additional escaping with `ESCAPE` clause
- Similar issues can occur with `_` (single character wildcard) if using `%_` pattern

## References

- [psycopg2 Basic Module Usage](https://www.psycopg.org/docs/usage.html)
- [psycopg2 sql Module Documentation](https://www.psycopg.org/docs/sql.html)
- [PostgreSQL Pattern Matching](https://www.postgresql.org/docs/current/functions-matching.html)
- [psycopg2 Issue #825 - Percent sign escaping](https://github.com/psycopg/psycopg2/issues/825)
