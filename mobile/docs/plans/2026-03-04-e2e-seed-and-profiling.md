# E2E Test Data Seeding & Performance Profiling — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Seed the local Docker environment with 100 real test videos at startup, then extend the E2E test to exercise feed loading, navigation, and relay subscriptions against realistic data.

**Architecture:** A seed container (Python + ffmpeg) runs at `docker-compose up` time after relay + blossom are healthy. It generates one 6s MP4, uploads to blossom, then publishes 100 kind 34236 events with varied metadata (20 authors, realistic hashtag/timestamp distribution). The user journey test then exercises this data for profiling.

**Tech Stack:** Python 3, ffmpeg, coincurve (secp256k1 signing), websockets, Docker

---

## Context

### Key Files (read-only reference)

- `local_stack/docker-compose.yml` — Docker stack definition
- `local_stack/profile.sh` — profiler wrapper script
- `local_stack/merge_logs.py` — log merger
- `mobile/integration_test/auth/user_journey_test.dart` — test to update
- `mobile/integration_test/helpers/relay_helpers.dart` — existing relay helper
- `mobile/integration_test/helpers/constants.dart` — port constants

### Blossom Upload Protocol (BUD-02)

- Endpoint: `PUT /upload`
- Body: raw binary file
- Auth: `Authorization: Nostr {base64(signed kind 24242 event)}`
- Response: `{"url": "...", "sha256": "...", "size": ..., "type": "..."}`
- Local blossom has uploads DISABLED by default — need config file to enable

### Relay WebSocket Protocol (NIP-01)

- Send: `["EVENT", {event_json}]`
- Response: `["OK", "{event_id}", true/false, "{message}"]`
- From seed container: `ws://funnelcake-relay:7777`

### FunnelCake Relay Validation (kind 34236)

The relay rejects events missing:
1. `imeta` tag with a `url` component
2. `image` component in `imeta` (thumbnail)

---

## Tasks

### Task 1: Create blossom config for local dev

**Files:**
- Create: `local_stack/blossom-config.yml`
- Modify: `local_stack/docker-compose.yml` — mount config + add healthcheck

**Step 1:** Create `local_stack/blossom-config.yml`:

```yaml
# Blossom config for local E2E development
# Enables uploads without auth for seeding and testing
publicDomain: "http://localhost:43003"
databasePath: data/sqlite.db

dashboard:
  enabled: false

upload:
  enabled: true
  requireAuth: false
  requirePubkeyInRule: false

storage:
  backend: local
  removeWhenNoOwners: false
  local:
    dir: ./data/blobs

rules:
  - type: "*"
    expiration: false
```

**Step 2:** Update `local_stack/docker-compose.yml` blossom service — mount config and add healthcheck:

```yaml
blossom:
  image: ghcr.io/hzrd149/blossom-server:master
  ports:
    - "43003:3000"
  volumes:
    - blossom-data:/app/data
    - ./blossom-config.yml:/app/config.yml:ro
  healthcheck:
    test: ["CMD-SHELL", "wget -q --spider http://localhost:3000/ || exit 1"]
    interval: 3s
    timeout: 3s
    retries: 10
```

**Step 3:** Add healthcheck to funnelcake-relay:

```yaml
funnelcake-relay:
  # ... existing config ...
  healthcheck:
    test: ["CMD-SHELL", "wget -q --spider http://localhost:7777/ || exit 1"]
    interval: 3s
    timeout: 3s
    retries: 10
```

**Step 4:** Verify blossom accepts uploads:

```bash
docker compose -f local_stack/docker-compose.yml restart blossom
# Wait for healthy
ffmpeg -f lavfi -i "testsrc=duration=1:size=320x240:rate=15" -c:v libx264 -pix_fmt yuv420p -y /tmp/test.mp4
curl -X PUT "http://localhost:43003/upload" -H "Content-Type: video/mp4" --data-binary @/tmp/test.mp4
# Expected: JSON response with url, sha256, size
```

**Step 5:** Commit:

```bash
git add local_stack/blossom-config.yml local_stack/docker-compose.yml
git commit -m "feat(e2e): enable blossom uploads and add healthchecks"
```

---

### Task 2: Create seed script

**Files:**
- Create: `local_stack/seed/seed.py`
- Create: `local_stack/seed/requirements.txt`

**Step 1:** Create `local_stack/seed/requirements.txt`:

```
coincurve>=20.0.0
websockets>=12.0
```

**Step 2:** Create `local_stack/seed/seed.py` with the following structure:

```python
#!/usr/bin/env python3
"""Seed the local E2E environment with 100 test videos.

Generates one 6-second MP4 via ffmpeg, uploads it to the local blossom server,
then publishes 100 kind 34236 Nostr events to the local relay with varied
metadata (20 authors, realistic hashtag/timestamp distribution).
"""

import asyncio
import base64
import hashlib
import json
import os
import random
import struct
import subprocess
import sys
import time
from pathlib import Path

import websockets
from coincurve import PrivateKey

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
RELAY_URL = os.environ.get("RELAY_URL", "ws://funnelcake-relay:7777")
BLOSSOM_URL = os.environ.get("BLOSSOM_URL", "http://blossom:3000")
NUM_VIDEOS = int(os.environ.get("NUM_VIDEOS", "100"))
NUM_AUTHORS = 20
POPULAR_AUTHORS = 5       # each gets ~16 videos (80 total)
LONGTAIL_AUTHORS = 15     # each gets ~1-2 videos (20 total)
SEED_PHRASE = "e2e-divine-test-seed-2026"

POPULAR_HASHTAGS = ["music", "dance", "comedy", "art", "nature"]
RARE_HASHTAGS = [
    "cooking", "travel", "fitness", "tech", "gaming",
    "fashion", "pets", "diy", "science", "books",
]
TITLE_TEMPLATES = [
    "Morning vibes", "Late night session", "Quick take", "Just vibing",
    "Something new", "Check this out", "Daily moment", "Creative flow",
    "Behind the scenes", "On the move", "Golden hour", "Rainy day",
    "Weekend mood", "Studio time", "Street view", "Sunset chase",
    "First try", "One more time", "Fresh start", "Throwback",
]

# ---------------------------------------------------------------------------
# Crypto helpers (NIP-01 event signing)
# ---------------------------------------------------------------------------
def generate_keypair(index: int) -> tuple[str, str]:
    """Derive a deterministic keypair from seed phrase + index."""
    seed = hashlib.sha256(f"{SEED_PHRASE}:{index}".encode()).digest()
    privkey = PrivateKey(seed)
    pubkey = privkey.public_key.format(compressed=False)[1:33].hex()
    # Actually, for Nostr we need the x-only pubkey (BIP-340)
    pubkey_bytes = privkey.public_key.format(compressed=True)
    # x-only = drop the prefix byte of compressed key
    pubkey = pubkey_bytes[1:].hex()
    return seed.hex(), pubkey


def sign_event(event_json: dict, privkey_hex: str) -> dict:
    """Sign a Nostr event (NIP-01)."""
    # Compute event ID
    serialized = json.dumps(
        [0, event_json["pubkey"], event_json["created_at"],
         event_json["kind"], event_json["tags"], event_json["content"]],
        separators=(",", ":"),
        ensure_ascii=False,
    )
    event_id = hashlib.sha256(serialized.encode()).hexdigest()
    event_json["id"] = event_id

    # Schnorr sign (BIP-340)
    privkey = PrivateKey(bytes.fromhex(privkey_hex))
    sig = privkey.sign_schnorr(bytes.fromhex(event_id))
    event_json["sig"] = sig.hex()
    return event_json


# ---------------------------------------------------------------------------
# Video generation
# ---------------------------------------------------------------------------
def generate_test_video(output_path: str) -> tuple[str, int]:
    """Generate a 6-second test video with ffmpeg. Returns (sha256, size)."""
    subprocess.run(
        [
            "ffmpeg", "-y",
            "-f", "lavfi",
            "-i", "testsrc=duration=6:size=720x1280:rate=30",
            "-f", "lavfi",
            "-i", "sine=frequency=440:duration=6",
            "-c:v", "libx264",
            "-preset", "ultrafast",
            "-pix_fmt", "yuv420p",
            "-c:a", "aac",
            "-b:a", "64k",
            output_path,
        ],
        check=True,
        capture_output=True,
    )
    data = Path(output_path).read_bytes()
    sha256 = hashlib.sha256(data).hexdigest()
    return sha256, len(data)


# ---------------------------------------------------------------------------
# Blossom upload
# ---------------------------------------------------------------------------
def upload_to_blossom(video_path: str) -> str:
    """Upload video to blossom, return the blob URL."""
    import urllib.request

    data = Path(video_path).read_bytes()
    req = urllib.request.Request(
        f"{BLOSSOM_URL}/upload",
        data=data,
        method="PUT",
        headers={"Content-Type": "video/mp4"},
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        result = json.loads(resp.read())
        print(f"Blossom upload OK: {result.get('url', result)}")
        return result["url"]


# ---------------------------------------------------------------------------
# Event publishing
# ---------------------------------------------------------------------------
def build_video_event(
    pubkey: str,
    title: str,
    hashtags: list[str],
    video_url: str,
    sha256: str,
    created_at: int,
    index: int,
) -> dict:
    """Build a kind 34236 video event."""
    tags = [
        ["d", f"seed-{index}"],
        ["title", title],
        [
            "imeta",
            f"url {video_url}",
            "m video/mp4",
            f"image {video_url}",
            f"x {sha256}",
        ],
        ["duration", "6"],
        ["alt", f"Seed video: {title}"],
        ["client", "diVine-e2e-seed"],
    ]
    for tag in hashtags:
        tags.append(["t", tag])

    return {
        "pubkey": pubkey,
        "created_at": created_at,
        "kind": 34236,
        "tags": tags,
        "content": "",
    }


def build_video_distribution() -> list[dict]:
    """Build 100 video events with realistic distribution."""
    rng = random.Random(42)  # deterministic
    now = int(time.time())
    week_ago = now - 7 * 86400

    # Generate keypairs
    keypairs = [generate_keypair(i) for i in range(NUM_AUTHORS)]

    # Assign video counts: 5 popular (16 each) + 15 longtail (1-2 each)
    assignments = []
    for i in range(POPULAR_AUTHORS):
        for _ in range(16):
            assignments.append(i)
    remaining = NUM_VIDEOS - len(assignments)
    for i in range(LONGTAIL_AUTHORS):
        count = 2 if i < remaining - LONGTAIL_AUTHORS else 1
        for _ in range(min(count, remaining - len([a for a in assignments if a >= POPULAR_AUTHORS]))):
            assignments.append(POPULAR_AUTHORS + i)
    # Pad if needed
    while len(assignments) < NUM_VIDEOS:
        assignments.append(rng.randint(0, POPULAR_AUTHORS - 1))
    assignments = assignments[:NUM_VIDEOS]
    rng.shuffle(assignments)

    events = []
    for idx, author_idx in enumerate(assignments):
        privkey_hex, pubkey = keypairs[author_idx]

        # Timestamp: weighted toward recent (exponential decay)
        t = rng.expovariate(1 / (2 * 86400))  # mean = 2 days ago
        created_at = max(week_ago, now - int(min(t, 7 * 86400)))

        # Hashtags: 70% chance popular, 30% rare, 1-2 tags
        tags = []
        for _ in range(rng.randint(1, 2)):
            if rng.random() < 0.7:
                tags.append(rng.choice(POPULAR_HASHTAGS))
            else:
                tags.append(rng.choice(RARE_HASHTAGS))
        tags = list(set(tags))  # dedupe

        title = f"{rng.choice(TITLE_TEMPLATES)} #{idx + 1}"

        events.append({
            "author_idx": author_idx,
            "privkey_hex": privkey_hex,
            "pubkey": pubkey,
            "title": title,
            "hashtags": tags,
            "created_at": created_at,
            "index": idx,
        })

    return events


async def publish_events(events: list[dict], video_url: str, sha256: str):
    """Publish all events to the relay via WebSocket."""
    async with websockets.connect(RELAY_URL) as ws:
        ok_count = 0
        fail_count = 0

        for ev_data in events:
            event = build_video_event(
                pubkey=ev_data["pubkey"],
                title=ev_data["title"],
                hashtags=ev_data["hashtags"],
                video_url=video_url,
                sha256=sha256,
                created_at=ev_data["created_at"],
                index=ev_data["index"],
            )
            signed = sign_event(event, ev_data["privkey_hex"])
            await ws.send(json.dumps(["EVENT", signed]))

            # Wait for OK
            resp = json.loads(await asyncio.wait_for(ws.recv(), timeout=10))
            if resp[0] == "OK" and resp[2] is True:
                ok_count += 1
            else:
                fail_count += 1
                print(f"WARN: Event {ev_data['index']} rejected: {resp}")

        print(f"Published {ok_count}/{len(events)} events ({fail_count} failed)")
        if fail_count > 0:
            sys.exit(1)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def wait_for_services(max_retries: int = 30, delay: float = 2.0):
    """Wait for relay and blossom to be reachable."""
    import urllib.request
    import urllib.error

    for name, url in [("Blossom", BLOSSOM_URL), ("Relay", RELAY_URL.replace("ws://", "http://"))]:
        for attempt in range(max_retries):
            try:
                urllib.request.urlopen(url, timeout=5)
                print(f"{name} ready")
                break
            except (urllib.error.URLError, OSError):
                if attempt < max_retries - 1:
                    time.sleep(delay)
                else:
                    print(f"ERROR: {name} not reachable at {url}")
                    sys.exit(1)


def main():
    print("=== E2E Seed: Starting ===")
    wait_for_services()

    # Generate video
    video_path = "/tmp/seed-video.mp4"
    print("Generating test video...")
    sha256, size = generate_test_video(video_path)
    print(f"Video: {size} bytes, sha256={sha256}")

    # Upload to blossom
    print("Uploading to blossom...")
    video_url = upload_to_blossom(video_path)
    print(f"Blossom URL: {video_url}")

    # Build event distribution
    print(f"Building {NUM_VIDEOS} video events...")
    events = build_video_distribution()

    # Publish to relay
    print("Publishing to relay...")
    asyncio.run(publish_events(events, video_url, sha256))

    print("=== E2E Seed: Complete ===")


if __name__ == "__main__":
    main()
```

**Step 3:** Commit:

```bash
git add local_stack/seed/
git commit -m "feat(e2e): add seed script for 100 test videos"
```

---

### Task 3: Create seed Dockerfile and add to docker-compose

**Files:**
- Create: `local_stack/seed/Dockerfile`
- Modify: `local_stack/docker-compose.yml` — add e2e-seed service

**Step 1:** Create `local_stack/seed/Dockerfile`:

```dockerfile
FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY seed.py .

CMD ["python", "seed.py"]
```

**Step 2:** Add e2e-seed service to `local_stack/docker-compose.yml` after the blossom service:

```yaml
  # ---------------------------------------------------------------------------
  # E2E seed data (runs once at startup)
  # ---------------------------------------------------------------------------
  e2e-seed:
    build: ./seed
    depends_on:
      funnelcake-relay:
        condition: service_healthy
      blossom:
        condition: service_healthy
    environment:
      RELAY_URL: ws://funnelcake-relay:7777
      BLOSSOM_URL: http://blossom:3000
      NUM_VIDEOS: "100"
    restart: "no"
```

**Step 3:** Rebuild and test:

```bash
cd /path/to/repo
docker compose -f local_stack/docker-compose.yml up -d --build e2e-seed
docker compose -f local_stack/docker-compose.yml logs -f e2e-seed
# Expected: "Published 100/100 events (0 failed)"
```

**Step 4:** Verify data in relay:

```bash
# Quick check via WebSocket — request kind 34236 events
echo '["REQ","test",{"kinds":[34236],"limit":5}]' | websocat ws://localhost:47777
# Expected: 5 EVENT responses followed by EOSE
```

**Step 5:** Commit:

```bash
git add local_stack/seed/Dockerfile local_stack/docker-compose.yml
git commit -m "feat(e2e): add seed container to docker-compose"
```

---

### Task 4: Update user journey test for seeded data

**Files:**
- Modify: `mobile/integration_test/auth/user_journey_test.dart`

**Step 1:** Update Phase 5 — the explore feed now has 100 seeded videos, so finding content should be reliable. Remove the soft assertion and make it a hard expect. Also remove the single-video publish since we now have seeded data (keep `publishTestVideoEvent` for testing the relay helper, but the feed check targets seeded content):

Replace Phase 4 + Phase 5 with:

```dart
// ── Phase 4: Publish a test video to local relay ──
debugPrint('── Phase 4: Publishing test video to relay ──');
final videoTitle =
    'E2E Journey ${DateTime.now().millisecondsSinceEpoch}';
final eventId = await publishTestVideoEvent(title: videoTitle);
expect(eventId, isNotEmpty, reason: 'Should publish event to relay');

// Give the relay a moment to index
await tester.pump(const Duration(seconds: 2));

// ── Phase 5: Verify explore feed has seeded content ──
debugPrint('── Phase 5: Checking explore feed for seeded content ──');

// Tap "New" tab to see latest events (seeded + our just-published one)
final newTab = find.text('New');
if (newTab.evaluate().isNotEmpty) {
  await tester.tap(newTab);
  await tester.pump(const Duration(seconds: 1));
}

// Wait for feed content to load — with 100 seeded videos this
// should be reliable. Look for any seeded video title pattern.
final feedLoaded = await waitForText(
  tester,
  'seed-',  // All seeded d-tags start with "seed-"
  maxSeconds: 20,
);

// If seed data isn't visible by title, check for general feed content
if (!feedLoaded) {
  // The feed may show thumbnails/cards without visible title text.
  // At minimum, the explore tabs should be populated.
  await tester.pump(const Duration(seconds: 5));
}

debugPrint('Phase 5 complete — explore feed exercised');
```

Wait — actually the seeded titles won't necessarily appear as visible Text widgets in the feed (the explore screen shows video thumbnails in a grid, not titles). Let me reconsider. The key profiling value is that the relay handles 100+ events in REQ/EOSE, which happens automatically when the explore screen loads. We don't need to assert on specific titles.

**Revised Phase 5:** Keep it simple — the value is in the profiler timeline, not in-test assertions:

```dart
// ── Phase 5: Verify explore feed loads (100+ seeded videos) ──
debugPrint('── Phase 5: Waiting for explore feed to load ──');

// The explore screen loads on arrival. With 100 seeded videos,
// EOSE timing in the profiler shows realistic relay performance.
// Wait for feed content to stabilize.
await tester.pump(const Duration(seconds: 5));

// Tap through explore tabs to trigger different relay queries
for (final tabName in ['New', 'Popular']) {
  final tab = find.text(tabName);
  if (tab.evaluate().isNotEmpty) {
    await tester.tap(tab);
    await tester.pump(const Duration(seconds: 3));
    debugPrint('Explored "$tabName" tab');
  }
}
```

**Step 2:** The rest of Phase 6-7 stays as-is.

**Step 3:** Run the profiled test:

```bash
mise run e2e_profile integration_test/auth/user_journey_test.dart
```

**Step 4:** Verify the profiler report shows realistic EOSE timing:

```bash
grep "EOSE received" test_reports/*.jsonl | tail -10
# Expected: "EOSE received for discovery after Xms with ~100 events"
```

**Step 5:** Commit:

```bash
git add mobile/integration_test/auth/user_journey_test.dart
git commit -m "feat(e2e): update user journey for seeded feed data"
```

---

## Verification

1. `docker compose -f local_stack/docker-compose.yml up -d` — seed container runs and exits 0
2. `docker compose -f local_stack/docker-compose.yml logs e2e-seed` — shows "Published 100/100 events"
3. `mise run e2e_profile` — test passes, report shows:
   - Auth phases (register, verify, token exchange)
   - Feed loads with ~100 events in EOSE
   - Tab navigation lifecycle (REQ/CLOSE patterns)
   - Relay subscription timing across services
4. Report has entries from: app, keycast, funnelcake-relay, funnelcake-api, blossom
