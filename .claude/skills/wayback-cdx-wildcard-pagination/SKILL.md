---
name: wayback-cdx-wildcard-pagination
description: |
  Fix empty results when paginating Wayback Machine CDX API with wildcard URL queries.
  Use when: (1) CDX query with url=foo/* and page=0 returns empty/0 bytes but works without
  page parameter, (2) CDX pagination returns no data for wildcard prefix searches,
  (3) Need to paginate large CDX result sets using wildcard URL matching.
  Covers showResumeKey, offset, and page parameter incompatibilities.
author: Claude Code
version: 1.0.0
date: 2026-02-20
---

# Wayback CDX API: Wildcard Query Pagination

## Problem
The Wayback Machine CDX API's `page=N` pagination parameter returns **empty results**
when combined with wildcard URL queries (`url=domain.com/path/*`), even though the
same query without `page=` returns data. This causes scripts to incorrectly report
"no results found" when there are actually hundreds of thousands of results.

## Context / Trigger Conditions
- CDX query with `url=*.example.com/*` or `url=example.com/path/*` and `page=0` returns 0 bytes
- Same query without `page=` parameter returns expected data
- Using `web.archive.org/cdx/search/cdx` API endpoint
- `matchType=prefix` + `collapse=urlkey` + `page=N` combination also fails silently
- Script works with `limit=5` but fails when adding `page=0`

## Solution

### Option 1: Use `showResumeKey=true` (Recommended)
The most reliable pagination method. CDX appends a base64 resume token after a blank
line separator in the response.

```python
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

    data = fetch_cdx(params)
    if not data:
        break

    # Resume key is after the last blank line
    parts = data.rstrip().rsplit('\n\n', 1)
    if len(parts) == 2:
        data_lines = parts[0].strip().split('\n')
        resume_key = parts[1].strip()
    else:
        data_lines = parts[0].strip().split('\n')
        resume_key = None

    # Process data_lines...

    if not resume_key or len(data_lines) < limit:
        break
```

### Option 2: Use `offset=N`
Works but less efficient for very large result sets.

```python
offset = 0
limit = 10000
while True:
    params = {
        'url': 'example.com/path/*',
        'output': 'text',
        'fl': 'original',
        'limit': str(limit),
        'offset': str(offset),
    }
    data = fetch_cdx(params)
    lines = data.strip().split('\n')
    if not lines or not lines[0]:
        break
    offset += len(lines)
```

### What NOT to do
```python
# THIS RETURNS EMPTY for wildcard queries:
params = {
    'url': 'example.com/path/*',
    'page': '0',        # <-- INCOMPATIBLE with wildcard
    'limit': '10000',
}

# THIS ALSO FAILS from some IPs:
params = {
    'url': 'example.com/path/',
    'matchType': 'prefix',
    'collapse': 'urlkey',
    'page': '0',
}
```

## Verification
- Query with `showResumeKey=true` and no `page=` param returns data
- Response ends with a blank line followed by a base64 token (the resume key)
- Subsequent request with `resumeKey=<token>` returns the next page

## Example
Fetching all vine.co/oembed/* URLs (690K+ captures, 312K unique vine IDs):
```bash
# This works:
curl "https://web.archive.org/cdx/search/cdx?url=vine.co/oembed/*&output=text&fl=original&limit=10000&showResumeKey=true"

# This returns empty:
curl "https://web.archive.org/cdx/search/cdx?url=vine.co/oembed/*&output=text&fl=original&limit=10000&page=0"
```

## Notes
- `page=N` works fine for non-wildcard queries (e.g., exact URL lookups)
- The `showResumeKey` approach is server-side cursor-based, more efficient than offset
- Keep `limit` at 10000 or less to avoid timeouts, especially from cloud IPs
- Always add `time.sleep(3-5)` between pages to be polite to the CDX server
- The CDX API has no official documentation for this incompatibility

## References
- CDX API informal docs: https://github.com/internetarchive/wayback/tree/master/wayback-cdx-server
- CDX pagination: The `page` API was designed for the pywb CDX server and may not be fully compatible with all query modes on the production Wayback CDX
