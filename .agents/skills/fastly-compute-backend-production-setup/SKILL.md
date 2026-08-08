---
name: fastly-compute-backend-production-setup
description: |
  Fix "Requested backend named 'X' does not exist" or TLS alert errors in Fastly Compute@Edge.
  Use when: (1) Backend works locally but fails in production with "backend does not exist",
  (2) TLS alert received (alert_id=0) errors when calling external APIs from Fastly,
  (3) Backends defined in fastly.toml aren't available after deployment. The fastly.toml
  [[backends]] section only applies during initial service creation - existing services
  require backends to be added via CLI or API with proper SSL/SNI configuration.
author: Claude Code
version: 1.0.0
date: 2025-01-28
---

# Fastly Compute Backend Production Setup

## Problem
Backends defined in `fastly.toml` work during local development with `fastly compute serve`
but return "Requested backend named 'X' does not exist" errors in production after deployment
with `fastly compute publish`.

## Context / Trigger Conditions
- Error: `Requested backend named 'funnelcake' does not exist`
- Error: `TLS alert received (alert_id=0)` when connecting to HTTPS backends
- Backend works with `fastly compute serve` locally
- `fastly.toml` has `[[backends]]` section properly configured
- Service was created before the backend was added to fastly.toml

## Root Cause
The `[[backends]]` section in `fastly.toml` is only processed during **initial service creation**
via the `[setup]` configuration. Once a service exists, changes to backends in fastly.toml
are ignored - you must add/modify backends through the Fastly CLI or API.

From the Fastly CLI output:
> INFO: Processing of the fastly.toml [setup] configuration happens only for a new service.
> Once a service is created, any further changes to the service or its resources must be
> made manually.

## Solution

### Step 1: Create the backend via CLI

```bash
fastly backend create \
  --service-id YOUR_SERVICE_ID \
  --version active \
  --autoclone \
  --name backend-name \
  --address api.example.com \
  --port 443 \
  --override-host api.example.com \
  --use-ssl \
  --ssl-cert-hostname api.example.com \
  --ssl-sni-hostname api.example.com
```

Key flags:
- `--autoclone`: Creates a new version automatically
- `--ssl-cert-hostname`: Required for SSL certificate validation
- `--ssl-sni-hostname`: Required for TLS SNI (fixes alert_id=0 errors)

### Step 2: Activate the new version

```bash
fastly service-version activate --service-id YOUR_SERVICE_ID --version VERSION_NUMBER
```

### Step 3: Verify backend exists

```bash
fastly backend list --service-id YOUR_SERVICE_ID --version active
```

### Step 4: Redeploy your code

After adding the backend, redeploy to ensure the code and backend are in the same version:

```bash
fastly compute publish
```

Then verify backends still exist in the new version:

```bash
fastly backend list --service-id YOUR_SERVICE_ID --version active
```

## Verification
1. Check logs with `fastly log-tail --service-id YOUR_SERVICE_ID`
2. Make a request that uses the backend
3. Confirm no "backend does not exist" or TLS errors in logs

## Example

Given this fastly.toml (which works locally but not in production):

```toml
[[backends]]
  name = "funnelcake"
  address = "relay.dvines.org"
  port = 443
  override_host = "relay.dvines.org"
  use_ssl = true
```

Add the backend to an existing service:

```bash
# Create backend with SSL properly configured
fastly backend create \
  --service-id WfOrPTFYmwwxRvqrfralLA \
  --version active \
  --autoclone \
  --name funnelcake \
  --address relay.dvines.org \
  --port 443 \
  --override-host relay.dvines.org \
  --use-ssl \
  --ssl-cert-hostname relay.dvines.org \
  --ssl-sni-hostname relay.dvines.org

# Activate the new version
fastly service-version activate --service-id WfOrPTFYmwwxRvqrfralLA --version 49

# Redeploy code
fastly compute publish
```

## Notes
- Each `fastly compute publish` creates a new version that inherits backends from the previous active version
- If you need different backends for different environments, consider using environment variables or separate services
- The `--autoclone` flag is essential - you cannot modify an active version directly
- Backend names in your code must exactly match the `--name` parameter

## Related Errors
- `Requested backend named 'X' does not exist` - Backend not created in service
- `TLS alert received (alert_id=0)` - Missing SNI hostname configuration
- `Mandatory SSL cert checks require specifying cert hostname` - Missing ssl-cert-hostname

## References
- [Fastly Compute backends documentation](https://www.fastly.com/documentation/reference/compute/fastly-toml/#backends)
- [Fastly CLI backend commands](https://www.fastly.com/documentation/reference/cli/backend/)
