---
name: gorse-clickhouse-cloud-incompatible
description: |
  Fix Gorse recommendation engine failing to connect to ClickHouse Cloud with EOF errors.
  Use when: (1) Gorse pods crash with "failed to connect data database" and "EOF" error,
  (2) Using ClickHouse Cloud (*.clickhouse.cloud) as Gorse data store,
  (3) TLS connection works (verified with openssl) but Gorse still fails,
  (4) Tried secure=true, different ports (8443, 9440), timeout params without success.
  The Gorse ClickHouse driver is incompatible with ClickHouse Cloud's native protocol.
author: Claude Code
version: 1.0.0
date: 2026-01-30
---

# Gorse + ClickHouse Cloud Incompatibility

## Problem
Gorse recommendation engine fails to connect to ClickHouse Cloud with EOF errors
during protocol negotiation, even though TLS handshake succeeds.

## Context / Trigger Conditions
- Gorse master/server pods show CrashLoopBackOff
- Logs show: `failed to connect data database: EOF` or `transport failed to send a request to ClickHouse: EOF`
- Using ClickHouse Cloud (*.clickhouse.cloud) as the GORSE_DATA_STORE
- TLS connection works when tested with openssl s_client
- Tried various connection parameters without success

## Root Cause
Despite the `clickhouse://` URL scheme suggesting native protocol, Gorse actually uses the
**HTTP interface** on port 8123 (not the native protocol on port 9000/9440). ClickHouse Cloud's
HTTP interface on port 8443 has compatibility issues with Gorse's driver.

Key facts:
- **Gorse uses ClickHouse HTTP interface (port 8123), NOT native protocol (port 9000)**
- ClickHouse Cloud port 8443: HTTP/HTTPS protocol
- ClickHouse Cloud port 9440: Native protocol with TLS
- Gorse only accepts: `clickhouse://`, `mysql://`, `postgres://`, `mongodb://`
- Gorse does NOT support `https://` scheme (returns "unsupported data storage backend")
- Redis is only for cache store, NOT data store
- If you use port 9000 with in-cluster ClickHouse, you'll get: "Port 9000 is for clickhouse-client program. You must use port 8123 for HTTP."

## Solution Options

### Option 1: Use In-Cluster ClickHouse (Recommended)
Deploy ClickHouse Operator with an in-cluster instance for Gorse:
```yaml
# Standard in-cluster connection works
GORSE_DATA_STORE: "clickhouse://user:password@clickhouse-host:8123/gorse"
```

### Option 2: Use Different Database
Gorse supports MySQL and PostgreSQL as data stores:
```yaml
GORSE_DATA_STORE: "mysql://user:password@host:3306/gorse"
# or
GORSE_DATA_STORE: "postgres://user:password@host:5432/gorse"
```

### Option 3: Deploy ClickHouse Proxy
Set up a proxy (like chproxy) that translates between protocols.

### Option 4: Fallback to Popular Videos
Keep Gorse disabled and let the API fallback to popularity-based recommendations:
```json
{"videos": [...], "source": "popular"}
```

## Verification
After choosing a solution, check Gorse master logs:
```bash
kubectl logs -l app=gorse-master -n gorse --tail=20
```

Should show successful connection instead of EOF errors.

## Notes
- The TLS layer works fine - the issue is at the ClickHouse protocol level
- This may be fixed in future versions of the clickhouse-go driver
- In-cluster ClickHouse doesn't have this issue because it uses plain connection on port 8123
