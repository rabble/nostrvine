# OpenVine Memory

## Project Overview
OpenVine is a decentralized vine-like video sharing application powered by Nostr with:
- **Flutter Mobile App**: Cross-platform client for capturing and sharing short videos
- **Cloudflare Workers Backend**: Serverless backend for GIF creation and media processing

## Current Focus  
**Camera Integration Implementation** - Building hybrid frame capture for vine recording

## Technology Stack
- **Frontend**: Flutter (Dart) with Camera plugin
- **Backend**: Cloudflare Workers + R2 Storage
- **Protocol**: Nostr (decentralized social network)
- **Media Processing**: Real-time frame capture → GIF creation

## Nostr Event Requirements
OpenVine requires specific Nostr event types for proper functionality:
- **Kind 0**: User profiles (NIP-01) - Required for user display names and avatars
- **Kind 6**: Reposts (NIP-18) - Required for video repost/reshare functionality  
- **Kind 22**: Short videos (NIP-71) - Primary video content
- **Kind 7**: Reactions (NIP-25) - Like/heart interactions
- **Kind 3**: Contact lists (NIP-02) - Follow/following relationships

See `mobile/docs/NOSTR_EVENT_TYPES.md` for complete event type documentation.

## Development Environment

### Local Development Server
**App URL**: http://localhost:53424/

The Flutter app is typically already running locally on Chrome when working on development. Use this URL to access the running app during debugging sessions.

### Debug Environment
- **Platform**: Chrome browser (flutter run -d chrome)
- **Hot Reload**: Available for rapid development
- **Debug Tools**: Chrome DevTools for Flutter debugging

## Build/Test Commands
```bash
# Flutter commands (run from /mobile directory)
flutter run -d chrome --release    # Run in Chrome browser
flutter build apk --debug          # Build Android debug APK
flutter test                       # Run unit tests
flutter analyze                    # Static analysis

# Backend commands (run from /backend directory)  
npm run dev                        # Local Cloudflare Workers development
npm run deploy                     # Deploy to Cloudflare
npm test                           # Run backend tests
```

## Development Workflow Requirements

### Code Quality Checks
**MANDATORY**: Always run `flutter analyze` after completing any task that modifies Dart code. This catches:
- Syntax errors
- Linting issues  
- Type errors
- Import problems
- Dead code warnings

**Process**:
1. Complete code changes
2. Run `flutter analyze` 
3. Fix any issues found
4. Confirm clean analysis before considering task complete

**Never** mark a Flutter task as complete without running analysis and addressing all issues.

### Asynchronous Programming Standards
**CRITICAL RULE**: NEVER use arbitrary delays or `Future.delayed()` as a solution to timing issues. This is crude, unreliable, and unprofessional.

**ALWAYS use proper asynchronous patterns instead**:
- **Callbacks**: Use proper event callbacks and listeners
- **Completers**: Use `Completer<T>` for custom async operations
- **Streams**: Use `Stream` and `StreamController` for event sequences  
- **Future chaining**: Use `then()`, `catchError()`, and `whenComplete()`
- **State management**: Use proper state change notifications
- **Platform channels**: Use method channels with proper completion handling

**Examples of FORBIDDEN patterns**:
```dart
// ❌ NEVER DO THIS
await Future.delayed(Duration(milliseconds: 500));
await Future.delayed(Duration(seconds: 2));
Timer(Duration(milliseconds: 100), () => checkAgain());
```

**Examples of CORRECT patterns**:
```dart
// ✅ Use callbacks and completers
final completer = Completer<String>();
controller.onInitialized = () => completer.complete('ready');
return completer.future;

// ✅ Use streams for events
final controller = StreamController<CameraEvent>();
await controller.stream.where((e) => e.type == 'initialized').first;

// ✅ Use proper state notifications
class Controller extends ChangeNotifier {
  bool _initialized = false;
  bool get isInitialized => _initialized;
  Future<void> waitForInitialization() async {
    if (_initialized) return;
    final completer = Completer<void>();
    void listener() {
      if (_initialized) {
        removeListener(listener);
        completer.complete();
      }
    }
    addListener(listener);
    return completer.future;
  }
}
```

## Key Files
- `mobile/lib/services/camera_service.dart` - Hybrid frame capture implementation
- `mobile/lib/screens/camera_screen.dart` - Camera UI with real preview
- `mobile/spike/frame_capture_approaches/` - Research prototypes and analysis
- `backend/src/` - Cloudflare Workers GIF creation logic

## Recent Decisions
**2024-12-16**: Selected Hybrid Frame Capture approach based on comprehensive prototype analysis
- Combines video recording + real-time streaming with intelligent fallback
- 87.5/100 confidence score from performance benchmarking
- Provides maximum reliability for production vine app

**2024-12-21**: Implemented NIP-18 Repost System (Issue #117)
- Kind 6 events for reposts with proper 'e' and 'p' tag structure
- VideoEventService processes both Kind 22 (videos) and Kind 6 (reposts)  
- UserProfileService requires Kind 0 events for proper "Reposted by" display
- Full UI integration with repost button and attribution indicators

[See ./.claude/memories/ for universal standards]