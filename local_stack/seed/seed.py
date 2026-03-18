"""Seed script for E2E testing: generates and publishes test video events.

Generates NUM_UNIQUE_VIDEOS distinct high-bitrate MP4s via ffmpeg (each
with a different noise seed so SHA-256 hashes differ), uploads them to a
local blossom server, transcodes 720p + 480p .ts variants into MinIO,
then publishes NUM_VIDEOS kind-34236 Nostr events to a local relay with
a realistic distribution of authors, hashtags, and timestamps.

The multiple unique videos prevent HTTP cache from masking download time
differences in performance tests.
"""

import hashlib
import json
import os
import random
import subprocess
import sys
import tempfile
import time
from urllib.request import Request, urlopen
from urllib.error import URLError

import coincurve
import websockets
import websockets.sync.client

# ---------------------------------------------------------------------------
# Configuration (environment variables with defaults)
# ---------------------------------------------------------------------------
RELAY_URL = os.environ.get("RELAY_URL", "ws://funnelcake-relay:7777")
BLOSSOM_URL = os.environ.get("BLOSSOM_URL", "http://blossom:3000")
# Public URL used in Nostr events — the emulator reaches the host via 10.0.2.2
BLOSSOM_PUBLIC_URL = os.environ.get("BLOSSOM_PUBLIC_URL", "http://10.0.2.2:43003")
NUM_VIDEOS = int(os.environ.get("NUM_VIDEOS", "100"))
NUM_UNIQUE_VIDEOS = int(os.environ.get("NUM_UNIQUE_VIDEOS", "10"))

MINIO_ENDPOINT = os.environ.get("MINIO_ENDPOINT", "http://minio:9000")
MINIO_BUCKET = os.environ.get("MINIO_BUCKET", "divine-blossom-local")
MINIO_ACCESS_KEY = os.environ.get("MINIO_ACCESS_KEY", "minioadmin")
MINIO_SECRET_KEY = os.environ.get("MINIO_SECRET_KEY", "minioadmin")

SEED_PHRASE = "divine-e2e-seed-phrase-2026"
NUM_AUTHORS = 20
NUM_POPULAR = 5
POPULAR_VIDEOS = 16  # each popular author gets ~16 videos

POPULAR_HASHTAGS = ["music", "dance", "comedy", "art", "nature"]
RARE_HASHTAGS = [
    "travel", "food", "tech", "fitness", "gaming",
    "fashion", "diy", "pets", "science", "history",
]

TITLE_TEMPLATES = [
    "Morning vibes",
    "Check this out",
    "Sunset moment",
    "Quick tutorial",
    "Behind the scenes",
    "My favorite spot",
    "Weekend mood",
    "Late night thoughts",
    "New creation",
    "Just for fun",
    "Daily inspiration",
    "Street view",
    "Chill session",
    "Something different",
    "Watch till the end",
    "Life update",
    "Random clip",
    "Throwback",
    "Fresh drop",
    "On repeat",
]


# ---------------------------------------------------------------------------
# Crypto helpers (NIP-01 event signing with BIP-340 Schnorr)
# ---------------------------------------------------------------------------
def derive_keypair(index: int) -> tuple[bytes, str]:
    """Derive a deterministic secp256k1 keypair from seed + index.

    Returns (private_key_bytes, x_only_pubkey_hex).
    """
    secret = hashlib.sha256(f"{SEED_PHRASE}:{index}".encode()).digest()
    privkey = coincurve.PrivateKey(secret)
    # x-only public key: drop the 0x02/0x03 prefix byte
    full_pubkey = privkey.public_key.format(compressed=True)
    x_only = full_pubkey[1:]  # 32 bytes
    return secret, x_only.hex()


def sign_event(event: dict, privkey_bytes: bytes) -> dict:
    """Compute event id and BIP-340 Schnorr signature."""
    # Canonical serialization per NIP-01
    serialized = json.dumps(
        [
            0,
            event["pubkey"],
            event["created_at"],
            event["kind"],
            event["tags"],
            event["content"],
        ],
        separators=(",", ":"),
        ensure_ascii=False,
    )
    event_id = hashlib.sha256(serialized.encode()).digest()
    event["id"] = event_id.hex()

    privkey = coincurve.PrivateKey(privkey_bytes)
    sig = privkey.sign_schnorr(event_id)
    event["sig"] = sig.hex()
    return event


# ---------------------------------------------------------------------------
# Video generation via ffmpeg
# ---------------------------------------------------------------------------
def generate_test_video(path: str, seed_index: int = 0) -> None:
    """Generate a 6-second 1080x1920 H.264 High profile MP4 at ~15 Mbps.

    Each seed_index produces different random noise (via geq random seed)
    so the resulting file has a unique SHA-256 hash. The video is large
    enough to demonstrate bandwidth starvation when the client doesn't
    use transcoded variants.
    """
    # Different random seed per video for unique content
    noise_seed = seed_index + 1
    freq = 220 + seed_index * 40  # different tone per video

    cmd = [
        "ffmpeg", "-y",
        # Video: noise pattern (incompressible, forces target bitrate)
        "-f", "lavfi", "-i",
        f"nullsrc=s=1080x1920:d=6:r=30,"
        f"geq='random({noise_seed})*255:128:128',"
        f"format=yuv420p,"
        f"drawtext=text='diVine E2E {seed_index}':fontsize=80:"
        f"fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2",
        # Audio: unique sine frequency
        "-f", "lavfi", "-i", f"sine=frequency={freq}:duration=6",
        # Encoding: H.264 High profile at 15 Mbps
        "-c:v", "libx264", "-profile:v", "high", "-level", "4.2",
        "-b:v", "15M", "-maxrate", "15M", "-bufsize", "30M",
        "-c:a", "aac", "-b:a", "128k",
        "-movflags", "+faststart",
        "-pix_fmt", "yuv420p",
        path,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"ffmpeg stderr:\n{result.stderr}", file=sys.stderr)
        sys.exit(1)
    size = os.path.getsize(path)
    print(f"Generated test video {seed_index}: {path} ({size:,} bytes, ~15 Mbps)")


def extract_thumbnail(video_path: str, thumb_path: str) -> None:
    """Extract first frame from video as JPEG thumbnail."""
    cmd = [
        "ffmpeg", "-y",
        "-i", video_path,
        "-vframes", "1",
        "-q:v", "2",
        thumb_path,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"ffmpeg thumbnail stderr:\n{result.stderr}", file=sys.stderr)
        sys.exit(1)
    size = os.path.getsize(thumb_path)
    print(f"Generated thumbnail: {thumb_path} ({size} bytes)")


def generate_transcoded_variants(
    source_path: str,
    out_720p: str,
    out_480p: str,
) -> None:
    """Transcode the source video into 720p and 480p MPEG-TS variants.

    These match the layout divine-blossom serves at /{hash}/hls/stream_*.ts.
    """
    for label, outpath, scale, vbitrate, abitrate in [
        ("720p", out_720p, "1280:720", "2500k", "128k"),
        ("480p", out_480p, "854:480", "1000k", "96k"),
    ]:
        cmd = [
            "ffmpeg", "-y",
            "-i", source_path,
            "-vf", f"scale={scale}",
            "-c:v", "libx264", "-profile:v", "main", "-level", "3.1",
            "-b:v", vbitrate, "-maxrate", vbitrate,
            "-bufsize", str(int(vbitrate.replace("k", "")) * 2) + "k",
            "-c:a", "aac", "-b:a", abitrate,
            "-f", "mpegts",
            "-pix_fmt", "yuv420p",
            outpath,
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"ffmpeg {label} stderr:\n{result.stderr}", file=sys.stderr)
            sys.exit(1)
        size = os.path.getsize(outpath)
        print(f"  Transcoded {label}: {outpath} ({size:,} bytes)")


def upload_variants_to_minio(
    sha256_hash: str,
    path_720p: str,
    path_480p: str,
) -> None:
    """Upload transcoded .ts variants to MinIO at the expected key paths.

    Keys: {sha256_hash}/hls/stream_720p.ts and stream_480p.ts.
    Fails loudly if boto3 or MinIO is unavailable — silent fallback would
    hide a broken test setup.
    """
    import boto3
    from botocore.exceptions import ClientError

    try:
        s3 = boto3.client(
            "s3",
            endpoint_url=MINIO_ENDPOINT,
            aws_access_key_id=MINIO_ACCESS_KEY,
            aws_secret_access_key=MINIO_SECRET_KEY,
        )

        # Ensure bucket exists
        try:
            s3.head_bucket(Bucket=MINIO_BUCKET)
        except ClientError:
            s3.create_bucket(Bucket=MINIO_BUCKET)
            print(f"  Created MinIO bucket: {MINIO_BUCKET}")

        for label, path, key_suffix in [
            ("720p", path_720p, "hls/stream_720p.ts"),
            ("480p", path_480p, "hls/stream_480p.ts"),
        ]:
            key = f"{sha256_hash}/{key_suffix}"
            s3.upload_file(
                path,
                MINIO_BUCKET,
                key,
                ExtraArgs={"ContentType": "video/mp2t"},
            )
            print(f"  Uploaded {label} to MinIO: s3://{MINIO_BUCKET}/{key}")

    except Exception as e:
        print(f"  MinIO variant upload failed: {type(e).__name__}: {e}", file=sys.stderr)
        sys.exit(1)


# ---------------------------------------------------------------------------
# Blossom upload
# ---------------------------------------------------------------------------
def build_upload_auth(privkey_bytes: bytes, pubkey_hex: str) -> str:
    """Build a kind 24242 Nostr auth header for blossom uploads.

    Returns the full Authorization header value: 'Nostr <base64-event-json>'.
    """
    import base64

    now = int(time.time())
    event = {
        "kind": 24242,
        "pubkey": pubkey_hex,
        "created_at": now,
        "content": "",
        "tags": [
            ["t", "upload"],
            ["expiration", str(now + 300)],
        ],
    }
    event = sign_event(event, privkey_bytes)
    event_json = json.dumps(event, separators=(",", ":"), ensure_ascii=False)
    encoded = base64.b64encode(event_json.encode()).decode()
    return f"Nostr {encoded}"


def upload_to_blossom(
    file_path: str,
    content_type: str = "video/mp4",
    privkey_bytes: bytes | None = None,
    pubkey_hex: str | None = None,
) -> dict:
    """Upload a file to blossom via PUT /upload with kind 24242 auth.

    Returns response JSON. If no keypair is provided, generates one.
    """
    if privkey_bytes is None or pubkey_hex is None:
        privkey_bytes, pubkey_hex = derive_keypair(0)

    with open(file_path, "rb") as f:
        data = f.read()

    auth = build_upload_auth(privkey_bytes, pubkey_hex)
    req = Request(
        f"{BLOSSOM_URL}/upload",
        data=data,
        method="PUT",
        headers={
            "Content-Type": content_type,
            "Authorization": auth,
        },
    )
    with urlopen(req, timeout=60) as resp:
        body = json.loads(resp.read().decode())

    print(f"Uploaded to blossom: url={body['url']} sha256={body['sha256']}")
    return body


# ---------------------------------------------------------------------------
# Author / video distribution
# ---------------------------------------------------------------------------
def build_author_video_map(rng: random.Random) -> list[int]:
    """Return a list of NUM_VIDEOS author indices with realistic distribution.

    First NUM_POPULAR authors are popular (~16 each), rest get ~1-2 each.
    """
    assignments = []

    # Popular authors
    for author_idx in range(NUM_POPULAR):
        assignments.extend([author_idx] * POPULAR_VIDEOS)

    # Long-tail authors: fill remaining slots
    remaining = NUM_VIDEOS - len(assignments)
    long_tail_authors = list(range(NUM_POPULAR, NUM_AUTHORS))
    for i in range(remaining):
        assignments.append(long_tail_authors[i % len(long_tail_authors)])

    rng.shuffle(assignments)
    return assignments


def pick_hashtags(rng: random.Random) -> list[str]:
    """Pick 1-3 hashtags with 70% popular, 30% rare weighting."""
    count = rng.randint(1, 3)
    tags = []
    for _ in range(count):
        if rng.random() < 0.7:
            tags.append(rng.choice(POPULAR_HASHTAGS))
        else:
            tags.append(rng.choice(RARE_HASHTAGS))
    return list(set(tags))  # deduplicate


def generate_timestamp(rng: random.Random) -> int:
    """Generate a deterministic timestamp in a recent range.

    Uses a fixed base epoch so repeated runs produce identical events.
    The relay deduplicates by event ID (hash of content + created_at),
    so identical timestamps mean identical event IDs = no duplicates.
    """
    # Fixed base: 2026-03-01T00:00:00Z
    base_epoch = 1772006400
    seven_days = 7 * 24 * 3600
    # Exponential distribution: higher density near 0 (recent)
    seconds_ago = int(rng.expovariate(1.0 / (24 * 3600)))
    # Clamp to 7 days
    seconds_ago = min(seconds_ago, seven_days)
    return base_epoch - seconds_ago


# ---------------------------------------------------------------------------
# Event construction
# ---------------------------------------------------------------------------
def build_event(
    index: int,
    author_privkey: bytes,
    author_pubkey: str,
    blossom_url: str,
    blossom_sha256: str,
    thumb_url: str,
    timestamp: int,
    hashtags: list[str],
    rng: random.Random,
) -> dict:
    """Build and sign a kind 34236 Nostr event."""
    title = f"{TITLE_TEMPLATES[index % len(TITLE_TEMPLATES)]} #{index}"

    tags = [
        ["d", f"seed-{index}"],
        ["title", title],
        [
            "imeta",
            f"url {blossom_url}",
            "m video/mp4",
            f"image {thumb_url}",
            f"x {blossom_sha256}",
        ],
        ["duration", "6"],
    ]
    for ht in hashtags:
        tags.append(["t", ht])
    tags.append(["alt", f"Seed video: {title}"])
    tags.append(["client", "diVine-e2e-seed"])

    event = {
        "kind": 34236,
        "pubkey": author_pubkey,
        "created_at": timestamp,
        "content": "",
        "tags": tags,
    }
    return sign_event(event, author_privkey)


# ---------------------------------------------------------------------------
# Relay publishing
# ---------------------------------------------------------------------------
def publish_events(events: list[dict]) -> tuple[int, int]:
    """Publish events to the relay via WebSocket. Returns (ok_count, fail_count)."""
    ok_count = 0
    fail_count = 0

    with websockets.sync.client.connect(RELAY_URL, close_timeout=10) as ws:
        for i, event in enumerate(events):
            msg = json.dumps(["EVENT", event])
            ws.send(msg)

            # Wait for OK response
            try:
                raw = ws.recv(timeout=10)
                response = json.loads(raw)
                if (
                    isinstance(response, list)
                    and len(response) >= 3
                    and response[0] == "OK"
                ):
                    if response[2]:
                        ok_count += 1
                    else:
                        fail_count += 1
                        reason = response[3] if len(response) > 3 else "unknown"
                        print(
                            f"  REJECTED event {i}: {reason}",
                            file=sys.stderr,
                        )
                else:
                    # Unexpected response; treat as failure
                    fail_count += 1
                    print(
                        f"  Unexpected response for event {i}: {raw}",
                        file=sys.stderr,
                    )
            except TimeoutError:
                fail_count += 1
                print(f"  Timeout waiting for OK on event {i}", file=sys.stderr)

            if (i + 1) % 20 == 0:
                print(f"  Published {i + 1}/{len(events)} events...")

    return ok_count, fail_count


# ---------------------------------------------------------------------------
# Service readiness
# ---------------------------------------------------------------------------
def wait_for_services(max_retries: int = 30, delay: float = 2.0) -> None:
    """Poll blossom and relay until they respond, or exit."""
    print("Waiting for services to be ready...")

    # Check blossom
    for attempt in range(max_retries):
        try:
            req = Request(BLOSSOM_URL, method="GET")
            with urlopen(req, timeout=5):
                pass
            print(f"  Blossom ready at {BLOSSOM_URL}")
            break
        except (URLError, OSError, TimeoutError):
            if attempt == max_retries - 1:
                print(f"Blossom not ready after {max_retries} attempts", file=sys.stderr)
                sys.exit(1)
            time.sleep(delay)

    # Check relay (WebSocket connect + disconnect)
    for attempt in range(max_retries):
        try:
            with websockets.sync.client.connect(RELAY_URL, close_timeout=3):
                pass
            print(f"  Relay ready at {RELAY_URL}")
            break
        except (OSError, TimeoutError, websockets.exceptions.WebSocketException):
            if attempt == max_retries - 1:
                print(f"Relay not ready after {max_retries} attempts", file=sys.stderr)
                sys.exit(1)
            time.sleep(delay)

    print("All services ready.")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def check_already_seeded() -> bool:
    """Check if seed data already exists by querying the relay."""
    _, pubkey_0 = derive_keypair(0)
    sub_id = "seed-check"
    req = json.dumps([
        "REQ", sub_id,
        {"kinds": [34236], "authors": [pubkey_0], "limit": 1},
    ])

    print(f"Checking if seed data exists (author={pubkey_0[:16]}...)...")
    try:
        with websockets.sync.client.connect(RELAY_URL, close_timeout=5) as ws:
            ws.send(req)
            for _ in range(10):
                raw = ws.recv(timeout=5)
                msg = json.loads(raw)
                if msg[0] == "EVENT" and msg[1] == sub_id:
                    ws.send(json.dumps(["CLOSE", sub_id]))
                    print("  Found existing seed event.")
                    return True
                if msg[0] == "EOSE":
                    ws.send(json.dumps(["CLOSE", sub_id]))
                    print("  No seed data found.")
                    return False
    except (OSError, TimeoutError, websockets.exceptions.WebSocketException) as e:
        print(f"  Check failed ({type(e).__name__}), proceeding with seed.")
    return False


def generate_and_upload_video(vid_idx: int) -> dict:
    """Generate one unique video, upload raw + variants, return asset info.

    Returns dict with keys: url, sha256, thumb_url.
    """
    with tempfile.NamedTemporaryFile(suffix=".mp4", delete=False) as tmp:
        video_path = tmp.name
    with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as tmp:
        thumb_path = tmp.name
    with tempfile.NamedTemporaryFile(suffix=".ts", delete=False) as tmp:
        path_720p = tmp.name
    with tempfile.NamedTemporaryFile(suffix=".ts", delete=False) as tmp:
        path_480p = tmp.name

    try:
        generate_test_video(video_path, seed_index=vid_idx)
        extract_thumbnail(video_path, thumb_path)

        print(f"Uploading video {vid_idx} to blossom...")
        blossom_resp = upload_to_blossom(video_path, "video/mp4")
        print(f"Uploading thumbnail {vid_idx} to blossom...")
        thumb_resp = upload_to_blossom(thumb_path, "image/jpeg")

        # Transcode and upload variants to MinIO
        print(f"Transcoding variants for video {vid_idx}...")
        generate_transcoded_variants(video_path, path_720p, path_480p)
        print(f"Uploading variants {vid_idx} to MinIO...")
        upload_variants_to_minio(blossom_resp["sha256"], path_720p, path_480p)

        video_sha256 = blossom_resp["sha256"]
        thumb_sha256 = thumb_resp["sha256"]
        # Rewrite URLs to the emulator-accessible address (10.0.2.2)
        video_url = f"{BLOSSOM_PUBLIC_URL}/{video_sha256}"
        thumb_url = f"{BLOSSOM_PUBLIC_URL}/{thumb_sha256}"

        return {
            "url": video_url,
            "sha256": video_sha256,
            "thumb_url": thumb_url,
        }
    finally:
        for p in (video_path, thumb_path, path_720p, path_480p):
            try:
                os.unlink(p)
            except FileNotFoundError:
                pass


def main() -> None:
    print(
        f"Config: RELAY_URL={RELAY_URL} BLOSSOM_URL={BLOSSOM_URL} "
        f"NUM_VIDEOS={NUM_VIDEOS} NUM_UNIQUE_VIDEOS={NUM_UNIQUE_VIDEOS}"
    )

    wait_for_services()

    if check_already_seeded():
        print("Seed data already exists, skipping.")
        return

    # 1. Generate keypairs
    print(f"\nGenerating {NUM_AUTHORS} author keypairs...")
    keypairs = [derive_keypair(i) for i in range(NUM_AUTHORS)]
    for i, (_, pubkey) in enumerate(keypairs):
        label = "popular" if i < NUM_POPULAR else "long-tail"
        print(f"  Author {i} ({label}): {pubkey}")

    # 2. Generate and upload unique videos + thumbnails + variants
    # Each video has a different noise seed so SHA-256 hashes differ,
    # preventing HTTP cache from masking download time in perf tests.
    print(f"\nGenerating {NUM_UNIQUE_VIDEOS} unique test videos (1080x1920, ~15 Mbps each)...")
    video_assets: list[dict] = []

    for vid_idx in range(NUM_UNIQUE_VIDEOS):
        asset = generate_and_upload_video(vid_idx)
        video_assets.append(asset)
        print(f"  Video {vid_idx}: {asset['url']}")

    print(f"All {NUM_UNIQUE_VIDEOS} videos uploaded successfully")

    # 3. Build events (round-robin across unique videos)
    print(f"\nBuilding {NUM_VIDEOS} events...")
    rng = random.Random(42)
    author_assignments = build_author_video_map(rng)
    events = []

    for i in range(NUM_VIDEOS):
        author_idx = author_assignments[i]
        privkey, pubkey = keypairs[author_idx]
        timestamp = generate_timestamp(rng)
        hashtags = pick_hashtags(rng)

        # Distribute unique videos round-robin across events
        asset = video_assets[i % NUM_UNIQUE_VIDEOS]

        event = build_event(
            index=i,
            author_privkey=privkey,
            author_pubkey=pubkey,
            blossom_url=asset["url"],
            blossom_sha256=asset["sha256"],
            thumb_url=asset["thumb_url"],
            timestamp=timestamp,
            hashtags=hashtags,
            rng=rng,
        )
        events.append(event)

    # 4. Publish to relay
    print(f"\nPublishing {len(events)} events to {RELAY_URL}...")
    ok_count, fail_count = publish_events(events)

    # 5. Summary
    print(f"\nPublished {ok_count}/{NUM_VIDEOS} events ({fail_count} failed)")
    if fail_count > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
