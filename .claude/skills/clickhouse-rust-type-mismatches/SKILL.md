---
name: clickhouse-rust-type-mismatches
description: |
  Fix ClickHouse query errors in Rust when using clickhouse-rs crate. Use when:
  (1) "string is not valid utf8" errors - typically FixedString columns need CAST to String,
  (2) "tag for enum is not valid" errors - typically Option<T> fields receiving non-NULL values,
  (3) Sum/count aggregations returning Float64 but Rust expects u64,
  (4) LEFT JOIN results with empty strings where Rust expects Option::None,
  (5) "not enough data, probably a row type mismatches a database schema" - query SELECT
  returns fewer columns than the Rust Row struct expects (common when multiple query functions
  share the same struct but one function is missing columns added later),
  (6) Garbled/corrupted data when INSERTing to FixedString(N) columns using String Rust type -
  silently corrupts data (no error!) because String adds a length prefix but FixedString expects
  exactly N raw bytes. Fix: use [u8; N] with #[serde(with = "BigArray")] from serde-big-array,
  (7) "the trait bound `[u8; 64]: serde::Serialize` is not satisfied" when using [u8; N] arrays
  in Row structs - need #[serde(with = "BigArray")] annotation from serde-big-array crate.
author: Claude Code
version: 1.2.0
date: 2026-03-01
---

# ClickHouse-Rust Type Mismatches

## Problem
When using the `clickhouse-rs` Rust crate with ClickHouse, deserialization errors
occur due to type mismatches between the database schema and Rust struct definitions.

## Context / Trigger Conditions
- Error: "string is not valid utf8" when querying String columns
- Error: "tag for enum is not valid" when deserializing rows
- Error: "not enough data, probably a row type mismatches a database schema" when deserializing rows
- Using `#[derive(Row)]` from `clickhouse` crate
- Views that use LEFT JOIN or aggregate functions
- Multiple query functions sharing the same Row struct but with different SELECT lists

## Root Causes

### 0. Column Count Mismatch ("not enough data")
When multiple query functions share the same `#[derive(Row)]` struct, adding new fields
to the struct and some queries but forgetting to update OTHER queries that use the same
struct causes "not enough data" deserialization errors. The query returns fewer columns
than the struct expects.

**Symptoms:**
- Error: "not enough data, probably a row type mismatches a database schema"
- One query function works, another fails, both using the same Row struct
- Error is misleading — suggests DB schema issue but is actually a code bug

**Debugging:**
1. Count the fields in the Rust `Row` struct
2. Count the SELECT columns in the failing query
3. Compare with the working query — look for missing columns
4. Often caused by adding fields (like subtitle/text-track columns) to the struct and
   one query but forgetting to update a secondary query (e.g., `get_by_id` updated but
   `get_by_d_tag` forgotten)

**Fix:** Add the missing SELECT columns to the failing query to match the struct:
```rust
// Both queries must select the SAME columns in the SAME order as the struct
// If struct has 17 fields, every query using it must SELECT 17 columns
```

### 1a. FixedString vs String (SELECT / Deserialization)
ClickHouse `FixedString(N)` pads with null bytes. These don't deserialize cleanly
as UTF-8 strings in Rust.

**Fix:** Cast to String in the SQL view:
```sql
SELECT CAST(pubkey AS String) AS pubkey FROM ...
```

### 1b. FixedString vs String (INSERT / Serialization) — SILENT DATA CORRUPTION
**This is the most dangerous variant because there is NO error message.** When using
`String` in a Rust `#[derive(Row, Serialize)]` struct for a ClickHouse `FixedString(N)`
column, the clickhouse-rs binary protocol serializes `String` with a varint length prefix,
but `FixedString(N)` expects exactly N raw bytes with no prefix. The extra length byte(s)
shift all subsequent column data, producing garbled rows where data bleeds across columns.

**Symptoms:**
- No error during INSERT — data appears to write successfully
- Querying the table shows garbled data with columns shifted/mixed together
- Materialized views built on the table contain garbled aggregations
- Often discovered only when downstream queries return nonsensical results

**Fix:** Use `[u8; N]` with `#[serde(with = "BigArray")]` from the `serde-big-array` crate:
```rust
use serde_big_array::BigArray;

#[derive(Row, Serialize)]
pub struct MyInsertRow {
    #[serde(with = "BigArray")]
    pub event_id: [u8; 64],   // FixedString(64)
    #[serde(with = "BigArray")]
    pub pubkey: [u8; 64],     // FixedString(64)
    pub name: String,          // String column — fine as-is
}

/// Helper to convert hex strings to fixed byte arrays
pub fn hex_string_to_fixed64(hex: &str) -> [u8; 64] {
    let mut buf = [0u8; 64];
    let bytes = hex.as_bytes();
    let len = bytes.len().min(64);
    buf[..len].copy_from_slice(&bytes[..len]);
    buf
}
```

**IMPORTANT:** Using `[u8; 64]` without `#[serde(with = "BigArray")]` will fail with:
```
error[E0277]: the trait bound `[u8; 64]: serde::Serialize` is not satisfied
```
This is because the clickhouse crate's serde dependency doesn't support const generic
array serialization for arrays > 32 elements. The `BigArray` annotation is required.

### 2. Option<T> vs Non-Nullable Columns
When ClickHouse returns empty strings `""` from LEFT JOINs (because the joined
table has non-nullable String columns), Rust `Option<String>` expects proper
NULL values, not empty strings.

**Fix:** Use `String` instead of `Option<String>` in Rust structs:
```rust
// Wrong - causes "tag for enum is not valid"
pub name: Option<String>,

// Correct - handles empty strings from LEFT JOIN
pub name: String,
```

### 3. Float64 Aggregation Results
Sum/count aggregations on certain column types return Float64, not UInt64.

**Fix:** Use `f64` in Rust struct:
```rust
// Wrong
pub loops: u64,

// Correct
pub loops: f64,
```

## Solution

### 1. Check ClickHouse column types
```sql
DESCRIBE TABLE your_view FORMAT TabSeparated
```

### 2. Match Rust types to ClickHouse types

**For SELECT (deserialization):**
| ClickHouse Type | Rust Type |
|-----------------|-----------|
| String | String |
| FixedString(N) | String (with CAST in SQL) or [u8; N] with BigArray |
| UInt64 | u64 |
| Float64 | f64 |
| Nullable(String) | Option<String> |
| String from LEFT JOIN | String (not Option<String>) |

**For INSERT (serialization):**
| ClickHouse Type | Rust Type | Notes |
|-----------------|-----------|-------|
| String | String | Works as-is |
| FixedString(N) | [u8; N] + `#[serde(with = "BigArray")]` | NEVER use String — causes silent corruption |
| UInt64 | u64 | Works as-is |
| DateTime | DateTime<Utc> + `#[serde(with = "clickhouse::serde::chrono::datetime")]` | |

### 3. Fix views to cast types
```sql
CREATE VIEW fixed_view AS
SELECT
    CAST(pubkey AS String) AS pubkey,  -- Fix FixedString
    name,  -- String stays String, handle empty in Rust
    loops  -- Float64 matches f64 in Rust
FROM ...
```

## Verification
Query directly via HTTP interface to confirm data format:
```bash
curl -u 'user:pass' 'https://clickhouse-host:8443' \
  --data-binary "SELECT * FROM your_view LIMIT 1 FORMAT JSONEachRow"
```

## Example

**ClickHouse schema:**
```sql
pubkey FixedString(64)
name String  -- from LEFT JOIN, can be empty ""
loops Float64
```

**Wrong Rust struct:**
```rust
pub struct Entry {
    pub pubkey: String,       // Fails: FixedString null padding
    pub name: Option<String>, // Fails: "" not NULL
    pub loops: u64,           // Fails: Float64 not UInt64
}
```

**Correct Rust struct + SQL:**
```rust
// Struct
pub struct Entry {
    pub pubkey: String,  // Works with CAST
    pub name: String,    // Handles empty strings
    pub loops: f64,      // Matches Float64
}
```
```sql
-- View
SELECT CAST(pubkey AS String) AS pubkey, name, loops FROM ...
```

## Notes
- The clickhouse-rs crate uses binary protocol, not JSON, so errors appear at deserialization
- AggregatingMergeTree `*State` columns require `*Merge()` functions in queries
- Run `DESCRIBE TABLE` to see exact column types
- Test queries via HTTP interface first to isolate schema vs client issues

## References
- [clickhouse-rs crate](https://crates.io/crates/clickhouse)
- [ClickHouse FixedString](https://clickhouse.com/docs/en/sql-reference/data-types/fixedstring)
- [ClickHouse Nullable](https://clickhouse.com/docs/en/sql-reference/data-types/nullable)
