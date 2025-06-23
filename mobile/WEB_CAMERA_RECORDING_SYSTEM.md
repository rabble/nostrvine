# 🎬 Web Camera Recording System Documentation

## Overview

The OpenVine web camera recording system provides a seamless Vine-style recording experience in web browsers using native web APIs. It implements the same press-to-record, release-to-pause functionality as mobile platforms.

## Architecture

### Core Components

1. **WebCameraService** (`lib/services/web_camera_service.dart`)
   - Handles getUserMedia API for camera access
   - Manages MediaRecorder for video recording
   - Provides WebCameraPreview widget for camera display

2. **WebCameraInterface** (`lib/services/vine_recording_controller.dart:169-233`)
   - Platform-specific implementation for web recording
   - Integrates WebCameraService with universal recording system
   - Handles web-specific segment recording logic

3. **VineRecordingController** (Universal controller)
   - Orchestrates recording across all platforms
   - Manages recording state, segments, and progress
   - Provides consistent API for UI components

## Recording Flow

### 1. Initialization
```dart
// Controller initialization
final controller = VineRecordingController();
await controller.initialize(); // Creates WebCameraInterface for web

// Web camera initialization  
await webCameraService.initialize(); // Requests getUserMedia permissions
```

### 2. Start/Stop/Continue System

#### Press to Record (Start Segment)
```dart
await controller.startRecording();
```
**Web Implementation:**
- Creates new `MediaRecorder` instance
- Calls `mediaRecorder.start()`
- Begins progress tracking timer
- Updates UI to recording state

#### Release to Pause (Stop Segment)  
```dart
await controller.stopRecording();
```
**Web Implementation:**
- Calls `mediaRecorder.stop()`
- Waits for 'stop' event to collect recorded data
- Creates blob URL from recorded chunks
- Saves segment metadata
- Updates progress and UI state

#### Continue Recording (New Segment)
- Same as "Press to Record" - creates new MediaRecorder
- Continues from where previous segment left off
- Accumulates total recording duration

### 3. Recording Completion
```dart
final videoFile = await controller.finishRecording();
```
**Web Implementation:**
- Returns blob URL(s) for recorded segments
- Handles single or multi-segment scenarios
- Prepares data for upload/processing

## Key Features

### ✅ Implemented Features

1. **Native Web Camera Access**
   - Uses `navigator.mediaDevices.getUserMedia()`
   - Supports video + audio recording
   - Front/back camera switching (where available)

2. **Segmented Recording**
   - Press-and-hold to record segments
   - Release to pause between segments  
   - Each segment is a separate MediaRecorder session

3. **Real-time Progress Tracking**
   - Live progress bar during recording
   - 6-second maximum duration enforcement
   - Visual feedback for recording state

4. **Browser Compatibility**
   - Automatic MIME type detection (`video/webm`, `video/mp4`)
   - Graceful fallbacks for browser differences
   - Error handling for unsupported browsers

5. **Flutter Integration**
   - WebCameraPreview widget using HtmlElementView
   - Platform view registry for native HTML elements
   - Seamless integration with Flutter UI

### 🔄 Current Limitations

1. **Multi-segment Compilation**
   - Individual segments recorded as separate blobs
   - No automatic video stitching (planned enhancement)
   - Single segment mode works perfectly

2. **File System Access**
   - Web uses blob URLs instead of file paths
   - Download functionality available
   - Upload requires blob-to-bytes conversion

## Testing the System

### Manual Testing Steps

1. **Open the test page**: `/mobile/test_web_camera.html`
2. **Initialize Camera**: Click "Initialize Camera" button
3. **Grant Permissions**: Allow camera/microphone access
4. **Test Recording**:
   - **Press and hold** "Hold to Record" button
   - **Watch progress bar** fill up
   - **Release** to pause (segment saved)
   - **Press and hold again** to continue
   - **Observe segment list** updating

### Expected Behavior

- ✅ Camera preview appears immediately after initialization
- ✅ Recording indicator shows during active recording
- ✅ Progress bar updates in real-time
- ✅ Segments are saved on release
- ✅ Total duration accumulates correctly
- ✅ Recording stops automatically at 6 seconds
- ✅ Can reset and start new recording

## Browser Compatibility

### Supported Browsers
- ✅ Chrome (desktop/mobile)
- ✅ Firefox (desktop/mobile)  
- ✅ Safari (desktop/mobile)
- ✅ Edge (desktop)

### Required Features
- `navigator.mediaDevices.getUserMedia()`
- `MediaRecorder` API
- `Blob` and `URL.createObjectURL()`
- `HtmlElementView` (Flutter web)

## API Reference

### WebCameraService Methods

```dart
// Initialize camera access
await webCameraService.initialize();

// Start recording segment
await webCameraService.startRecording();

// Stop recording and get blob URL
String blobUrl = await webCameraService.stopRecording();

// Switch camera (front/back)
await webCameraService.switchCamera();

// Download recorded video
webCameraService.downloadRecording(blobUrl, 'vine.webm');

// Cleanup resources
webCameraService.dispose();
```

### VineRecordingController Web Integration

```dart
// Universal controller works the same across platforms
final controller = VineRecordingController();
await controller.initialize(); // Automatically uses WebCameraInterface on web

// Recording methods work identically
await controller.startRecording();
await controller.stopRecording();
final videoFile = await controller.finishRecording();

// Progress tracking
double progress = controller.progress; // 0.0 to 1.0
Duration remaining = controller.remainingDuration;
bool canRecord = controller.canRecord;
```

## Technical Implementation Details

### MediaRecorder Configuration
```javascript
mediaRecorder = new MediaRecorder(mediaStream, {
  mimeType: getSupportedMimeType() // Auto-detected best format
});
```

### Segment Data Structure
```dart
class RecordingSegment {
  final DateTime startTime;
  final DateTime endTime; 
  final Duration duration;
  final String? filePath; // Blob URL for web
}
```

### Progress Timer Implementation
- 50ms interval updates during recording
- Real-time duration calculation
- Automatic stop at 6-second limit

## Integration with OpenVine App

The web camera system is fully integrated into the main OpenVine app:

1. **UniversalCameraScreen** uses VineRecordingController
2. **Platform detection** automatically selects WebCameraInterface on web
3. **Same UI components** work across all platforms
4. **Upload system** handles blob URLs for web recordings
5. **Video metadata screen** processes web recordings identically

## Future Enhancements

1. **Video Segment Stitching**: Automatic compilation of multi-segment recordings
2. **Advanced Camera Controls**: Zoom, focus, exposure controls
3. **Background Recording**: Record while app is backgrounded
4. **WebRTC Integration**: Peer-to-peer video sharing
5. **WebAssembly Processing**: Client-side video effects and filters

---

The web camera recording system provides a robust, native web experience that matches the quality and functionality of mobile platforms while leveraging modern web APIs for optimal performance.