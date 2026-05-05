---
name: cloud-run-static-outbound-ip
description: |
  Configure static outbound IP addresses for Google Cloud Run jobs/services. Use when:
  (1) External service needs to whitelist your IP (archive.org, APIs, firewalls),
  (2) Cloud Run requests appear from random/changing IPs, (3) Need consistent source IP
  for crawlers, scrapers, or API clients running on Cloud Run. Requires VPC connector +
  Cloud NAT + static IP reservation. Works for both Cloud Run services and jobs.
author: Claude Code
version: 1.0.0
date: 2026-01-26
---

# Cloud Run Static Outbound IP Address

## Problem
Cloud Run uses a shared pool of dynamic outbound IP addresses that change frequently
and are shared across all Google Cloud customers. When external services need to
whitelist your IP (for rate limit exemptions, firewall rules, or special access),
you need a static, predictable outbound IP.

## Context / Trigger Conditions
- External service asks for IP address to whitelist
- Cloud Run requests are being blocked by IP-based rate limiting
- Need to identify your traffic to external APIs
- Running crawlers/scrapers that need consistent source IP
- Error messages about "IP not whitelisted" or similar

## Solution

### Architecture
```
Cloud Run → VPC Connector → VPC Network → Cloud NAT (static IP) → Internet
```

### Step 1: Reserve Static IP Address
```bash
gcloud compute addresses create [NAME]-nat-ip \
  --region=[REGION] \
  --description="Static IP for Cloud Run outbound traffic"

# Get the actual IP address
gcloud compute addresses describe [NAME]-nat-ip \
  --region=[REGION] \
  --format="value(address)"
```

### Step 2: Create Cloud Router
```bash
gcloud compute routers create [NAME]-router \
  --network=default \
  --region=[REGION]
```

### Step 3: Create Cloud NAT with Static IP
```bash
gcloud compute routers nats create [NAME]-nat \
  --router=[NAME]-router \
  --region=[REGION] \
  --nat-external-ip-pool=[NAME]-nat-ip \
  --nat-all-subnet-ip-ranges
```

### Step 4: Enable VPC Access API
```bash
gcloud services enable vpcaccess.googleapis.com
```

### Step 5: Create Serverless VPC Access Connector
```bash
gcloud compute networks vpc-access connectors create [NAME]-connector \
  --region=[REGION] \
  --network=default \
  --range=10.8.0.0/28 \
  --min-instances=2 \
  --max-instances=3 \
  --machine-type=e2-micro
```
Note: The IP range must not conflict with existing subnets. Use a /28 CIDR block.

### Step 6: Update Cloud Run to Use VPC Connector

For Cloud Run Jobs:
```bash
gcloud run jobs deploy [JOB-NAME] \
  --image=[IMAGE] \
  --region=[REGION] \
  --vpc-connector=[NAME]-connector \
  --vpc-egress=all-traffic \
  [... other flags ...]
```

For Cloud Run Services:
```bash
gcloud run deploy [SERVICE-NAME] \
  --image=[IMAGE] \
  --region=[REGION] \
  --vpc-connector=[NAME]-connector \
  --vpc-egress=all-traffic \
  [... other flags ...]
```

**Critical**: `--vpc-egress=all-traffic` is required to route ALL outbound traffic
through the VPC/NAT. Without this, only traffic to internal IPs uses the connector.

## Verification

Test that outbound traffic uses the static IP:
```bash
# Run a container that checks its external IP
gcloud run jobs execute [JOB-NAME] --region=[REGION] \
  --args="curl,-s,https://api.ipify.org"
```

Or add a test endpoint to your service that calls an IP echo service.

## Example: Complete Setup Script

```bash
#!/bin/bash
set -e

PROJECT_ID="my-project"
REGION="us-central1"
NAME="my-crawler"

# Reserve static IP
gcloud compute addresses create ${NAME}-nat-ip --region=$REGION

# Get and display the IP
STATIC_IP=$(gcloud compute addresses describe ${NAME}-nat-ip \
  --region=$REGION --format="value(address)")
echo "Static IP: $STATIC_IP"

# Create router
gcloud compute routers create ${NAME}-router \
  --network=default --region=$REGION

# Create NAT
gcloud compute routers nats create ${NAME}-nat \
  --router=${NAME}-router \
  --region=$REGION \
  --nat-external-ip-pool=${NAME}-nat-ip \
  --nat-all-subnet-ip-ranges

# Enable API and create connector
gcloud services enable vpcaccess.googleapis.com
gcloud compute networks vpc-access connectors create ${NAME}-connector \
  --region=$REGION \
  --network=default \
  --range=10.8.0.0/28 \
  --min-instances=2 \
  --max-instances=3 \
  --machine-type=e2-micro

echo "Setup complete! Use these flags in Cloud Run deployments:"
echo "  --vpc-connector=${NAME}-connector"
echo "  --vpc-egress=all-traffic"
echo ""
echo "Static IP for whitelisting: $STATIC_IP"
```

## Cost Considerations
- **Static IP**: Free while in use, ~$7/month if reserved but unused
- **VPC Connector**: ~$7-20/month (2-3 e2-micro instances minimum)
- **Cloud NAT**: ~$1/month + $0.045/GB processed

Total: ~$10-30/month depending on traffic volume.

## Notes

- All Cloud Run instances/jobs using the same VPC connector share the static IP
- You can scale Cloud Run horizontally without changing IPs
- VPC connector has throughput limits (~200-1000 Mbps depending on instance count)
- For high-throughput needs, increase max-instances on the connector
- Cloud SQL connections don't need to go through NAT (use Cloud SQL connector instead)
- The VPC connector adds ~1-5ms latency to requests

## Cleanup

To remove the setup:
```bash
gcloud compute networks vpc-access connectors delete ${NAME}-connector --region=$REGION
gcloud compute routers nats delete ${NAME}-nat --router=${NAME}-router --region=$REGION
gcloud compute routers delete ${NAME}-router --region=$REGION
gcloud compute addresses delete ${NAME}-nat-ip --region=$REGION
```

## References
- [Cloud Run VPC Connectors](https://cloud.google.com/run/docs/configuring/vpc-connectors)
- [Cloud NAT Overview](https://cloud.google.com/nat/docs/overview)
- [Static Outbound IP for Cloud Run](https://cloud.google.com/run/docs/configuring/static-outbound-ip)
