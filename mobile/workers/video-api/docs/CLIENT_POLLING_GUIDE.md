# Video Status Polling Client Implementation Guide

## Overview

This guide provides best practices for implementing video status polling in client applications. The status endpoint allows clients to check the processing state of uploaded videos using exponential backoff to minimize server load.

## Endpoint

```
GET /v1/media/status/{videoId}
```

- **videoId**: Must be a valid UUID v4 format
- Returns current processing status and metadata when available

## Status Types

### 1. `pending_upload`
- Video record created but upload not yet received
- **Next poll**: 2-5 seconds
- **Cache**: 30 seconds

### 2. `processing`
- Video is being processed by Cloudflare Stream
- **Next poll**: Use exponential backoff
- **Cache**: No cache

### 3. `published`
- Video successfully processed and ready for playback
- **Next poll**: Stop polling - video is ready
- **Cache**: 1 hour client, 24 hours CDN
- **Response includes**: HLS/DASH URLs, thumbnail URL

### 4. `failed`
- Processing failed permanently
- **Next poll**: Stop polling - terminal state
- **Cache**: 30 minutes
- **Response includes**: User-friendly error message

### 5. `quarantined`
- Video flagged by moderation
- **Next poll**: Stop polling - terminal state
- **Cache**: 30 minutes

## Client Implementation

### JavaScript/TypeScript Example

```typescript
class VideoStatusPoller {
  private readonly videoId: string;
  private readonly apiBase: string;
  private readonly baseInterval = 2000; // Start with 2 seconds
  private readonly maxInterval = 30000; // Cap at 30 seconds
  private readonly maxDuration = 300000; // 5 minute total timeout
  private startTime: number;
  private currentInterval: number;

  constructor(videoId: string, apiBase: string) {
    if (!this.isValidUUID(videoId)) {
      throw new Error('Invalid video ID format - must be UUID v4');
    }
    
    this.videoId = videoId;
    this.apiBase = apiBase;
    this.currentInterval = this.baseInterval;
  }

  private isValidUUID(uuid: string): boolean {
    const uuidV4Regex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    return uuidV4Regex.test(uuid);
  }

  async pollUntilReady(): Promise<VideoStatus> {
    this.startTime = Date.now();
    
    while (Date.now() - this.startTime < this.maxDuration) {
      try {
        const response = await fetch(`${this.apiBase}/v1/media/status/${this.videoId}`);
        
        if (!response.ok) {
          if (response.status === 404) {
            throw new Error('Video not found');
          }
          if (response.status === 429) {
            // Rate limited - back off more aggressively
            this.currentInterval = Math.min(this.currentInterval * 3, this.maxInterval);
            await this.sleep(this.currentInterval);
            continue;
          }
          throw new Error(`Status check failed: ${response.status}`);
        }
        
        const data = await response.json();
        
        // Handle terminal states
        if (data.status === 'published') {
          return data; // Success!
        }
        
        if (data.status === 'failed' || data.status === 'quarantined') {
          throw new Error(data.error || `Video ${data.status}`);
        }
        
        // Continue polling for non-terminal states
        console.log(`Video status: ${data.status}, next check in ${this.currentInterval}ms`);
        
        // Exponential backoff: 2s → 4s → 8s → 16s → 30s (capped)
        await this.sleep(this.currentInterval);
        this.currentInterval = Math.min(this.currentInterval * 2, this.maxInterval);
        
      } catch (error) {
        if (error instanceof Error && 
            (error.message.includes('not found') || 
             error.message.includes('failed') || 
             error.message.includes('quarantined'))) {
          throw error; // Don't retry terminal errors
        }
        
        console.error('Polling error:', error);
        await this.sleep(this.currentInterval);
      }
    }
    
    throw new Error('Video processing timeout after 5 minutes');
  }

  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

// Usage example
async function uploadAndPollVideo(file: File): Promise<void> {
  try {
    // 1. Upload video and get video ID
    const videoId = await uploadVideo(file);
    console.log('Video uploaded, ID:', videoId);
    
    // 2. Start polling
    const poller = new VideoStatusPoller(videoId, 'https://api.openvine.co');
    const status = await poller.pollUntilReady();
    
    // 3. Video is ready!
    console.log('Video published!', {
      hlsUrl: status.hlsUrl,
      dashUrl: status.dashUrl,
      thumbnailUrl: status.thumbnailUrl
    });
    
    // 4. Update UI to show video
    showVideo(status);
    
  } catch (error) {
    console.error('Video processing failed:', error);
    showError(error.message);
  }
}
```

### Flutter/Dart Example

```dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class VideoStatusPoller {
  final String videoId;
  final String apiBase;
  final Duration baseInterval = Duration(seconds: 2);
  final Duration maxInterval = Duration(seconds: 30);
  final Duration maxDuration = Duration(minutes: 5);
  
  late DateTime _startTime;
  late Duration _currentInterval;
  
  VideoStatusPoller({
    required this.videoId,
    required this.apiBase,
  }) {
    if (!_isValidUUID(videoId)) {
      throw ArgumentError('Invalid video ID format - must be UUID v4');
    }
    _currentInterval = baseInterval;
  }
  
  bool _isValidUUID(String uuid) {
    final uuidV4Regex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidV4Regex.hasMatch(uuid);
  }
  
  Future<VideoStatus> pollUntilReady() async {
    _startTime = DateTime.now();
    
    while (DateTime.now().difference(_startTime) < maxDuration) {
      try {
        final response = await http.get(
          Uri.parse('$apiBase/v1/media/status/$videoId'),
        );
        
        if (response.statusCode == 404) {
          throw Exception('Video not found');
        }
        
        if (response.statusCode == 429) {
          // Rate limited - back off more aggressively
          _currentInterval = Duration(
            milliseconds: (_currentInterval.inMilliseconds * 3)
                .clamp(0, maxInterval.inMilliseconds),
          );
          await Future.delayed(_currentInterval);
          continue;
        }
        
        if (response.statusCode != 200) {
          throw Exception('Status check failed: ${response.statusCode}');
        }
        
        final data = json.decode(response.body);
        final status = data['status'] as String;
        
        // Handle terminal states
        if (status == 'published') {
          return VideoStatus.fromJson(data);
        }
        
        if (status == 'failed' || status == 'quarantined') {
          throw Exception(data['error'] ?? 'Video $status');
        }
        
        // Continue polling for non-terminal states
        print('Video status: $status, next check in ${_currentInterval.inSeconds}s');
        
        // Exponential backoff
        await Future.delayed(_currentInterval);
        _currentInterval = Duration(
          milliseconds: (_currentInterval.inMilliseconds * 2)
              .clamp(0, maxInterval.inMilliseconds),
        );
        
      } catch (error) {
        if (error.toString().contains('not found') ||
            error.toString().contains('failed') ||
            error.toString().contains('quarantined')) {
          rethrow; // Don't retry terminal errors
        }
        
        print('Polling error: $error');
        await Future.delayed(_currentInterval);
      }
    }
    
    throw TimeoutException('Video processing timeout after 5 minutes');
  }
}

// Usage in Flutter widget
class VideoUploadScreen extends StatefulWidget {
  @override
  _VideoUploadScreenState createState() => _VideoUploadScreenState();
}

class _VideoUploadScreenState extends State<VideoUploadScreen> {
  bool _isProcessing = false;
  String? _errorMessage;
  VideoStatus? _videoStatus;
  
  Future<void> _uploadAndPollVideo(File videoFile) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });
    
    try {
      // 1. Upload video
      final videoId = await uploadVideo(videoFile);
      
      // 2. Start polling
      final poller = VideoStatusPoller(
        videoId: videoId,
        apiBase: 'https://api.openvine.co',
      );
      
      final status = await poller.pollUntilReady();
      
      // 3. Video is ready!
      setState(() {
        _videoStatus = status;
        _isProcessing = false;
      });
      
      // Navigate to video player
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(
            hlsUrl: status.hlsUrl,
            thumbnailUrl: status.thumbnailUrl,
          ),
        ),
      );
      
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
        _isProcessing = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Processing video...'),
            Text('This may take a few minutes'),
          ],
        ),
      );
    }
    
    // ... rest of UI
  }
}
```

## Best Practices

### 1. **Always Use Exponential Backoff**
- Start with 2 seconds
- Double the interval after each request
- Cap at 30 seconds maximum
- Total timeout of 5 minutes

### 2. **Handle Rate Limiting Gracefully**
- Detect 429 responses
- Triple the backoff interval when rate limited
- Show appropriate UI feedback

### 3. **Respect Cache Headers**
- Published videos can be cached client-side
- Don't re-poll for terminal states (failed, quarantined)
- Use conditional requests when appropriate

### 4. **Provide User Feedback**
```javascript
// Good: Informative progress updates
setStatus('Uploading video...');
setStatus('Processing video (this may take a few minutes)...');
setStatus('Almost ready...');
setStatus('Video published!');

// Bad: Generic or no feedback
setStatus('Please wait...');
```

### 5. **Handle Errors Appropriately**
- Network errors: Retry with backoff
- 404 errors: Stop polling, show "not found"
- 429 errors: Increase backoff aggressively
- Failed/quarantined: Stop polling, show error

### 6. **UUID Validation**
Always validate UUID format before making requests:
```javascript
const uuidV4Regex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
if (!uuidV4Regex.test(videoId)) {
  throw new Error('Invalid video ID format');
}
```

## Testing Your Implementation

### 1. **Test Different Status Transitions**
- pending_upload → processing → published
- pending_upload → processing → failed
- pending_upload → processing → quarantined

### 2. **Test Error Scenarios**
- Invalid UUID format
- Non-existent video ID
- Network failures
- Rate limiting

### 3. **Test Timeout Behavior**
- Ensure polling stops after 5 minutes
- Verify exponential backoff works correctly

### 4. **Load Testing**
```bash
# Simulate multiple concurrent polls
for i in {1..10}; do
  node poll-video.js $VIDEO_ID &
done
```

## Response Examples

### Published Video
```json
{
  "status": "published",
  "hlsUrl": "https://customer-xxx.cloudflarestream.com/xxx/manifest/video.m3u8",
  "dashUrl": "https://customer-xxx.cloudflarestream.com/xxx/manifest/video.mpd",
  "thumbnailUrl": "https://customer-xxx.cloudflarestream.com/xxx/thumbnails/thumbnail.jpg",
  "createdAt": "2024-01-01T12:00:00.000Z"
}
```

### Processing Video
```json
{
  "status": "processing"
}
```

### Failed Video
```json
{
  "status": "failed",
  "error": "Processing timeout - please try uploading again"
}
```

## Common Pitfalls to Avoid

1. **Don't Poll Too Frequently**
   - Bad: Fixed 1-second interval
   - Good: Exponential backoff

2. **Don't Ignore Rate Limits**
   - Bad: Retry immediately on 429
   - Good: Triple backoff on rate limit

3. **Don't Poll Forever**
   - Bad: No timeout
   - Good: 5-minute maximum

4. **Don't Show Technical Errors**
   - Bad: "Error: ETIMEOUT"
   - Good: "Video processing is taking longer than expected"

## Monitoring and Analytics

Track these metrics in your client:
- Average time to published status
- Polling attempt count per video
- Rate limit hit frequency
- Error rates by type
- Timeout rates

This data helps optimize polling intervals and improve user experience.