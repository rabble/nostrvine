Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This file may reference deleted screens, older branding, or superseded implementation details. Start with docs/README.md and docs/archive/README.md for current guidance.

# OpenVine Nostr Relay Architecture

## Overview

OpenVine uses a sophisticated relay architecture where the Flutter app contains an embedded Nostr relay that acts as an intelligent proxy between the app and external relays.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter App                              │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    NostrService                          │  │
│  │                  (uses nostr_sdk)                        │  │
│  └────────────────────┬─────────────────────────────────────┘  │
│                       │                                         │
│                       │ WebSocket                               │
│                       │ ws://localhost:7447                     │
│                       ▼                                         │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              EmbeddedNostrRelay                          │  │
│  │         (flutter_embedded_nostr_relay)                   │  │
│  │                                                          │  │
│  │  • SQLite local storage                                  │  │
│  │  • WebSocket server on port 7447                         │  │
│  │  • External relay management                             │  │
│  │  • P2P sync capabilities                                 │  │
│  └────────────────────┬─────────────────────────────────────┘  │
│                       │                                         │
└───────────────────────┼─────────────────────────────────────────┘
                        │
                        │ WebSocket connections
                        │ managed by embedded relay
                        ▼
         ┌──────────────────────────────┐
         │   External Nostr Relays      │
         │                              │
         │  • wss://relay3.openvine.co  │
         │  • wss://relay.damus.io      │
         │  • wss://nos.lol             │
         └──────────────────────────────┘
```

## Component Responsibilities

### 1. NostrService (App Layer)
- **Role**: Nostr client that connects to the local embedded relay
- **Library**: Uses `nostr_sdk` package
- **Connection**: Connects via WebSocket to `ws://localhost:7447`
- **Functions**:
  - Subscribes to events using REQ messages
  - Publishes events using EVENT messages
  - Manages user keys and authentication
  - Handles app-specific business logic

### 2. EmbeddedNostrRelay (Embedded Layer)
- **Role**: Full Nostr relay implementation running inside the Flutter app
- **Library**: `flutter_embedded_nostr_relay` package
- **Functions**:
  - **Local Storage**: SQLite database for caching events
  - **WebSocket Server**: Listens on localhost:7447 for client connections
  - **External Relay Proxy**: Manages connections to external relays
  - **Event Routing**: Routes events between local storage, app, and external relays
  - **P2P Sync**: Optional peer-to-peer synchronization via BLE/WiFi Direct
  - **NIP-65 Support**: Implements relay list metadata for relay discovery

### 3. External Relays (Network Layer)
- **Role**: Traditional Nostr relays on the internet
- **Primary**: `wss://relay3.openvine.co` (OpenVine's dedicated relay)
- **Secondary**: Other public relays for redundancy

## Data Flow

### Publishing Events
1. App creates event using NostrService
2. NostrService sends EVENT message to embedded relay via WebSocket
3. Embedded relay:
   - Stores event in local SQLite
   - Publishes to all connected external relays
   - Routes to any local subscriptions

### Subscribing to Events
1. App creates subscription filter in NostrService
2. NostrService sends REQ message to embedded relay
3. Embedded relay:
   - Queries local SQLite for matching cached events
   - Creates subscriptions on all external relays
   - Streams matching events back to app
4. New events from external relays:
   - Stored in local SQLite cache
   - Routed to matching app subscriptions

## Key Benefits

### 1. Performance
- **Instant Response**: Local SQLite queries return in <10ms
- **Background Sync**: External relay fetching happens asynchronously
- **Caching**: Events are cached locally for offline access

### 2. Privacy
- **Query Privacy**: External relays don't see your viewing patterns
- **Selective Sync**: Only fetch events you're interested in
- **Local First**: Can work entirely offline with P2P sync

### 3. Reliability
- **Offline Support**: App works without internet using cached events
- **Relay Redundancy**: Automatic failover between multiple external relays
- **P2P Fallback**: Can sync via Bluetooth when internet is unavailable

## Implementation Details

### Initialization Sequence

```dart
// 1. Initialize embedded relay
final embeddedRelay = EmbeddedNostrRelay();
await embeddedRelay.initialize();

// 2. Add external relays
await embeddedRelay.addExternalRelay('wss://relay3.openvine.co');
await embeddedRelay.addExternalRelay('wss://relay.damus.io');

// 3. Start WebSocket server
final wsServer = WebSocketServer(
  subscriptionManager: embeddedRelay.subscriptionManager,
  eventStore: embeddedRelay.eventStore,
);
await wsServer.start(port: 7447);

// 4. Connect NostrService as client
final nostrService = NostrService(keyManager);
await nostrService.connectToLocalRelay('ws://localhost:7447');
```

### Configuration Files

#### NostrService Configuration
- Uses `nostr_sdk` to act as a Nostr client
- Connects to localhost:7447 instead of external relays
- All relay management delegated to embedded relay

#### Embedded Relay Configuration
- Default external relay: `wss://relay3.openvine.co`
- Garbage collection enabled for storage management
- WebSocket server on port 7447
- P2P sync optional (disabled by default)

## Common Issues and Solutions

### Issue 1: "Failed to connect to external relay"
**Cause**: NostrService trying to connect directly to external relays
**Solution**: NostrService should ONLY connect to localhost:7447

### Issue 2: "Bad state: Relay not initialized"
**Cause**: Using nostr_sdk's Relay class instead of embedded relay's methods
**Solution**: Use `embeddedRelay.addExternalRelay()` not `Relay.connect()`

### Issue 3: No events received from relays
**Cause**: WebSocket server not started or wrong connection URL
**Solution**: Ensure WebSocket server is started and NostrService connects to ws://localhost:7447

## Testing Strategy

### Unit Tests
- Mock the embedded relay for NostrService tests
- Test WebSocket message handling separately
- Verify event routing logic

### Integration Tests
1. Start embedded relay with test database
2. Add test external relays
3. Verify event flow through all layers
4. Test offline scenarios with cached data

### Performance Tests
- Measure query response times with various database sizes
- Test concurrent subscription handling
- Verify memory usage with large event streams

## Migration Notes

When updating from direct relay connections to embedded relay:

1. **Remove** all direct relay connection code from NostrService
2. **Add** embedded relay initialization
3. **Update** connection URL to localhost:7447
4. **Delegate** relay management to embedded relay
5. **Test** that events flow through the proxy correctly

## Related Documentation

- [Flutter Embedded Nostr Relay README](../../flutter_embedded_nostr_relay/README.md)
- [Riverpod Integration Guide](../../flutter_embedded_nostr_relay/riverpod-integration-guide.md)
- [Nostr Event Types](./NOSTR_EVENT_TYPES.md)
- [NIP-65 Relay List Metadata](https://github.com/nostr-protocol/nips/blob/master/65.md)