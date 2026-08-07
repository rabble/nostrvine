---
name: wayback-cdx-cloud-ip-workaround
description: |
  Fix Wayback Machine CDX API returning empty results or timing out from cloud/datacenter
  IPs (Cloud Run, AWS Lambda, GCE, etc.) while working fine locally. Use when:
  (1) CDX queries timeout or return 0 bytes from Cloud Run/cloud functions but work from
  local machine, (2) urllib.request.urlopen times out for web.archive.org from server,
  (3) Wayback Machine CDX silently returns empty from datacenter IPs with no HTTP error,
  (4) Need to run CDX-dependent scripts on Cloud Run or similar cloud compute.
  Workaround: fetch locally, upload to cloud storage, import on cloud compute.
author: Claude Code
version: 1.0.0
date: 2026-02-20
---

# Wayback CDX API: Cloud/Datacenter IP Workaround

## Problem
The Wayback Machine CDX API (`web.archive.org/cdx/search/cdx`) silently refuses to
serve data to requests from cloud provider IP ranges (Google Cloud Run, AWS, GCE, etc.).
There is no HTTP error code — requests either timeout or return 0 bytes. The same
queries work perfectly from residential/local IPs.

## Context / Trigger Conditions
- CDX API returns empty (0 bytes) or times out from Cloud Run, Lambda, GCE, etc.
- Same query via curl on local machine returns expected data
- No HTTP error codes (not 429, not 403) — just empty or timeout
- Other external APIs (Common Crawl, Arctic Shift, Arquivo.pt) work fine from the same cloud instance
- Even with VPC connector + static IP configured, CDX still fails
- Increasing timeouts and retries doesn't help

## Solution

### The Pattern: Local Fetch → Cloud Storage → Cloud Import

Since CDX won't respond to cloud IPs, split the workflow:

1. **Fetch locally**: Run CDX queries from your local machine, save results to a file
2. **Upload to cloud storage**: `gsutil cp` the file to GCS (or S3, etc.)
3. **Import on cloud**: Have your Cloud Run job read from cloud storage instead of CDX

### Implementation

**Step 1: Local fetch script**
```python
# Run this locally — CDX works from residential IPs
import urllib.request, urllib.parse

CDX = 'https://web.archive.org/cdx/search/cdx'
results = set()
resume_key = None

while True:
    params = {
        'url': 'example.com/path/*',
        'output': 'text',
        'fl': 'original',
        'filter': 'statuscode:200',
        'limit': '10000',
        'showResumeKey': 'true',
    }
    if resume_key:
        params['resumeKey'] = resume_key

    url = f"{CDX}?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, headers={'User-Agent': 'MyBot/0.1'})
    with urllib.request.urlopen(req, timeout=120) as resp:
        raw = resp.read().decode('utf-8', errors='replace')

    parts = raw.rstrip().rsplit('\n\n', 1)
    data_lines = parts[0].strip().split('\n')
    resume_key = parts[1].strip() if len(parts) == 2 else None

    for line in data_lines:
        results.add(process_line(line))  # Extract what you need

    if not resume_key or len(data_lines) < 10000:
        break
    time.sleep(3)

# Save to file
with open('/tmp/results.txt', 'w') as f:
    for item in sorted(results):
        f.write(f'{item}\n')
```

**Step 2: Upload to GCS**
```bash
gsutil cp /tmp/results.txt gs://my-bucket/imports/results.txt
```

**Step 3: Cloud Run job with --from-gcs flag**
```python
def load_from_gcs(gcs_path: str) -> set[str]:
    """Load IDs from a GCS text file."""
    import subprocess
    result = subprocess.run(
        ["gsutil", "cp", gcs_path, "/tmp/results.txt"],
        capture_output=True, text=True, timeout=120
    )
    if result.returncode != 0:
        raise RuntimeError(f"gsutil failed: {result.stderr}")

    items = set()
    with open("/tmp/results.txt") as f:
        for line in f:
            items.add(line.strip())
    return items

# In main():
parser.add_argument("--from-gcs", type=str, default=None,
                    help="Import from GCS file instead of CDX")

if args.from_gcs:
    items = load_from_gcs(args.from_gcs)
else:
    items = fetch_from_cdx(delay=args.delay)
```

**Step 4: Deploy with --from-gcs**
```bash
gcloud run jobs deploy my-job \
    --args="-m,my_module,--from-gcs,gs://my-bucket/imports/results.txt" \
    ...
```

## Verification
- Local fetch completes successfully with expected data volume
- File uploads to GCS without errors
- Cloud Run job reads from GCS and imports to database
- `gsutil ls -l gs://my-bucket/imports/results.txt` shows expected file size

## Example
Real-world case: Fetching 312,427 vine IDs from Wayback CDX oEmbed captures.
- CDX failed from Cloud Run (4 attempts over multiple deploys, all returning 0 bytes)
- Local fetch completed in ~4 minutes with resumeKey pagination
- Uploaded 3.6MB text file to GCS
- Cloud Run imported 170,108 new IDs from GCS in ~10 minutes

## Notes
- This affects `web.archive.org` specifically. Other CDX servers (index.commoncrawl.org) work fine from cloud IPs
- The Internet Archive may whitelist specific IPs on request — contact them if you have a legitimate archival use case
- Even with a whitelisted static IP via VPC connector, the CDX API may still not respond (whitelisting may apply to download, not CDX)
- `collapse=urlkey` and `matchType=prefix` are more likely to fail than simple wildcard queries, but even wildcards fail from cloud IPs
- This workaround adds a manual step (local fetch + upload) but is reliable and only needs to be done once per data source
- For frequently-changing data, consider scheduling the local fetch via cron and automating the GCS upload

## References
- Wayback CDX API: https://github.com/internetarchive/wayback/tree/master/wayback-cdx-server
- Related skill: wayback-cdx-wildcard-pagination (for the pagination aspect)
