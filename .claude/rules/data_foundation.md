# Data Foundation

Use this rule whenever new work chooses where data should live, how it is
cached, or how a local schema evolves.

## Default Decision Tree

1. **Remote-derived cacheable data** defaults to `cache_sync`.
   This includes data fetched from REST, GraphQL, relays, or other network
   sources when the app can refetch it and callers benefit from
   stale-while-revalidate behavior.
2. **Structured durable app data** belongs in Drift, usually through
   `mobile/packages/db_client`.
   Choose Drift when data needs queries, relationships, indexes, reactive
   streams, account-scoped cleanup, schema evolution, or durable offline
   behavior that is more than a small setting.
3. **Small local-only preferences** may use `SharedPreferences`.
   Keep it to scalar settings, dismissals, feature flags, last-selected UI
   options, and other values where losing the value is recoverable and no
   query/schema model is needed.
4. **Secrets and signing material** never belong in these general stores.
   Use the existing secure-storage/key-management path.
5. **Media bytes and file downloads** use the owning media cache or file
   pipeline, not ad hoc rows in app data stores.

If a value fits multiple buckets, prefer the more structured shared store.
Avoid inventing a feature-local persistence layer just because it is faster to
wire in the moment.

## `cache_sync` Is The Default Cache

For new remote-derived cacheable data, use `cache_sync` unless there is a
clear reason not to.

Good `cache_sync` candidates:

- profile, list, feed, count, or metadata responses that can be regenerated
  from relays or APIs
- data where showing cached content immediately is better than blocking on a
  fresh network response
- account-scoped cache entries that can be invalidated by key prefix
- simple JSON payloads that do not need relational queries

When adding a `cache_sync` cache:

- choose a key shape that is stable, explicit, and scoped by pubkey when the
  data is account-specific
- set a TTL that matches the product freshness expectation
- define invalidation at the repository or service boundary that owns the
  data, not in the UI
- keep serialization failures and corrupt entries recoverable by refetching

Do not create a new cache service, in-memory singleton, Hive box, or
SharedPreferences JSON blob for remote-derived cacheable data until
`cache_sync` has been ruled out in the PR notes.

## Drift Owns Durable Structured Data

Use Drift when the app is the durable owner of structured local state or when
the local copy needs database behavior.

Prefer Drift for:

- drafts, pending queues, outbox state, local-only collections, and offline
  workflow state
- denormalized tables that need indexes, joins, ordering, pruning, or reactive
  watchers
- local data that must survive app restarts and account switches with clear
  cleanup semantics
- data that requires migrations as fields or invariants change

Durable local-only user data belongs in Drift once it grows beyond a small
preference. `SharedPreferences` should not become a hidden document store.

## SharedPreferences Is Narrow

`SharedPreferences` is acceptable for small, flat, local-only values:

- booleans, enums, timestamps, and simple strings
- one-off dismissal or onboarding flags
- user preferences such as selected modes or display options
- compatibility reads while migrating legacy values into the correct store

Do not use `SharedPreferences` for remote caches, lists of domain objects,
large JSON payloads, append-only histories, queues, or anything that needs
partial updates, indexes, or schema migration.

## Hive Is Legacy By Default

New Hive boxes require explicit justification in the issue or PR. The
justification must explain:

- why `cache_sync` is not appropriate
- why Drift is not appropriate
- how corruption, migration, account cleanup, and low-storage behavior are
  handled
- how the box will be tested

Existing Hive-backed paths can stay while they are being retired
incrementally, but new work should not expand Hive usage without a deliberate
storage decision.

## Drift Schema Changes Use Real Migrations

For `db_client` and other Drift databases, schema evolution belongs in Drift
migrations.

- Bump `schemaVersion` when the schema changes for existing installs.
- Add `MigrationStrategy.onUpgrade` steps for table, column, index, and data
  migrations.
- Keep migration tests with generated schema snapshots where the package uses
  them.
- Use `beforeOpen` for startup cleanup and validation only, not as the primary
  place to accumulate `CREATE TABLE IF NOT EXISTS` or `ALTER TABLE` repair SQL.

Startup repair SQL may be used only as a narrow compatibility bridge for
already-shipped damage, and should not be the pattern for new schema changes.

`db_client`'s v1 is a special case for whoever writes its first real
migration. Because the repair block lives in `beforeOpen`, two installs can
both report `user_version = 1` with different tables, columns, and indexes on
disk — and Drift runs `onUpgrade` *before* `beforeOpen`, so the repair has not
run yet when the upgrade step executes. Make the first `1 -> 2` step
idempotent (probe `sqlite_master` / `PRAGMA table_info` before altering), and
treat the generated v1 snapshot as the declared schema rather than as what
every install actually has.

## Review Checklist

Before approving a data/storage change, confirm:

- the selected store matches the decision tree above
- account-scoped data has account-scoped keys or cleanup
- remote caches have explicit freshness and invalidation behavior
- durable local data has migration and recovery behavior
- new Hive usage has a written justification
- Drift schema changes are represented as real migrations
