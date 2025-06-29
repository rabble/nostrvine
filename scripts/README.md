# Bulk Thumbnail Generation Scripts

This directory contains scripts to automatically generate thumbnails for videos that don't have them by fetching Kind 22 events from vine.hol.is and calling the OpenVine thumbnail API service.

## Available Scripts

### 1. Node.js Version (Recommended)
**File:** `bulk_thumbnail_generator.js`

This is a standalone Node.js script that doesn't require Flutter/Dart dependencies.

#### Usage:
```bash
# Basic usage
node scripts/bulk_thumbnail_generator.js

# Dry run to see what would be done
node scripts/bulk_thumbnail_generator.js --dry-run --limit 50

# Generate thumbnails for up to 100 videos, batch size 10
node scripts/bulk_thumbnail_generator.js --limit 100 --batch-size 10

# Custom time offset for thumbnail extraction
node scripts/bulk_thumbnail_generator.js --time-offset 3.0
```

#### Options:
- `-l, --limit <number>`: Maximum videos to process (default: 1000)
- `-d, --dry-run`: Don't generate thumbnails, just report what would be done
- `-b, --batch-size <number>`: Number of videos to process in each batch (default: 5)
- `-t, --time-offset <number>`: Time offset in seconds for thumbnail extraction (default: 2.5)
- `-h, --help`: Show help message

### 2. Dart Version
**File:** `lib/scripts/bulk_thumbnail_generator.dart`

This version integrates with the Flutter app's dependencies and logging system.

#### Usage:
```bash
# From the mobile directory
dart run lib/scripts/bulk_thumbnail_generator.dart --dry-run --limit 50
```

### 3. Shell Wrapper
**File:** `generate_thumbnails.sh`

A convenient shell script that wraps the Dart version with user-friendly prompts.

#### Usage:
```bash
# Make executable if needed
chmod +x generate_thumbnails.sh

# Run with confirmation prompt
./generate_thumbnails.sh --limit 50 --dry-run

# Run with custom settings
./generate_thumbnails.sh --batch-size 10 --time-offset 3.0
```

## How It Works

1. **Fetch Events**: Connects to `vine.hol.is` relay to fetch Kind 22 (video) events
2. **Parse Videos**: Extracts video URLs and checks for existing thumbnails
3. **Filter**: Identifies videos that don't have thumbnails
4. **Generate**: Makes API calls to `https://api.openvine.co/thumbnail/{videoId}/generate`
5. **Report**: Shows statistics on success/failure rates

## API Endpoints Used

- **Check existing thumbnail**: `GET https://api.openvine.co/thumbnail/{videoId}?t={timeSeconds}`
- **Generate thumbnail**: `POST https://api.openvine.co/thumbnail/{videoId}/generate`

## Configuration

### Node.js Script Configuration
Edit the `CONFIG` object in `bulk_thumbnail_generator.js`:

```javascript
const CONFIG = {
  RELAY_URL: 'https://vine.hol.is/api/events',
  API_BASE_URL: 'https://api.openvine.co',
  BATCH_SIZE: 5,
  MAX_VIDEOS: 1000,
  TIME_OFFSET: 2.5,
  REQUEST_TIMEOUT: 30000,
  BATCH_DELAY: 2000, // ms between batches
};
```

### Safety Features

- **Batch processing**: Processes videos in small batches to avoid overwhelming the server
- **Rate limiting**: Includes delays between batches
- **Dry run mode**: Test what would be done without making actual API calls
- **Error handling**: Continues processing even if individual videos fail
- **Statistics tracking**: Reports detailed success/failure metrics

## Example Output

```
🚀 OpenVine Bulk Thumbnail Generator (Node.js)
==============================================
📋 Configuration:
   Limit: 100 videos
   Batch size: 5
   Time offset: 2.5s
   Mode: LIVE

📡 Fetching Kind 22 events from https://vine.hol.is/api/events...
📥 Received 85 events from relay
📊 Found 72 total video events
📊 45 videos without thumbnails
📊 27 videos already have thumbnails

🎬 Generating thumbnails for 45 videos...
⚙️ Batch size: 5
⏱️ Time offset: 2.5s

📦 Processing batch 1/9 (5 videos)...
✅ Generated thumbnail for 87444ba2: https://api.openvine.co/thumbnail/87444ba2...
✅ Generated thumbnail for 9f3c2e15: https://api.openvine.co/thumbnail/9f3c2e15...
❌ Failed to generate thumbnail for a7b4c891: HTTP 404: Video not found
✅ Generated thumbnail for 2d8e6f42: https://api.openvine.co/thumbnail/2d8e6f42...
✅ Generated thumbnail for 5c1a9b73: https://api.openvine.co/thumbnail/5c1a9b73...

📈 FINAL STATISTICS
===================
Total videos found: 72
Videos without thumbnails: 45
Thumbnails generated: 38
Thumbnails failed: 7
Success rate: 84.4%
🎉 Successfully generated 38 thumbnails!
```

## Requirements

### Node.js Version
- Node.js 12+ (no additional dependencies)

### Dart Version  
- Flutter/Dart SDK
- All Flutter app dependencies (run `flutter pub get`)

## Troubleshooting

### Common Issues

1. **Network errors**: The script will fall back to sample data if the relay is unavailable
2. **API rate limits**: Increase `BATCH_DELAY` or decrease `BATCH_SIZE` if getting rate limited
3. **Timeout errors**: Increase `REQUEST_TIMEOUT` for slow network connections

### Debug Mode

For more detailed logging, you can modify the scripts to include debug output or use the Dart version which integrates with the app's logging system.