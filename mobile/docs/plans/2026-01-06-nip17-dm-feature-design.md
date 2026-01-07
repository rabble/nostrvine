# NIP-17 Direct Messages Feature Design

## Overview

Add support for sending, receiving, and viewing encrypted direct messages using NIP-17 (gift-wrapped private messages). Extends the existing "send video to person" functionality into a full messaging experience.

## Protocol Summary

NIP-17 uses three-layer encryption for privacy:
1. **Kind 14** (rumor) - UNSIGNED message content (deniability)
2. **Kind 13** (seal) - signed and encrypted by sender
3. **Kind 1059** (gift wrap) - wrapped with ephemeral key for anonymity

Optional **kind 10050** specifies user's preferred DM relays.

### Critical Security: Sender Verification

Per NIP-17 spec:
> "Clients MUST verify if pubkey of the kind:13 is the same pubkey on the kind:14, otherwise any sender can impersonate others by simply changing the pubkey on kind:14."

The decryption flow MUST verify `seal.pubkey == rumor.pubkey`.

## Existing Infrastructure

- `NIP17MessageService` - handles sending gift-wrapped messages
- `GiftWrapUtil` - handles encryption/decryption (needs sender verification fix)
- "Send video to person" feature uses this service
- Relay infrastructure already in place

## New Components

### 1. GiftWrapUtil Fix (Security)

**Location**: `packages/nostr_sdk/lib/nip59/gift_wrap_util.dart`

Add sender verification after decryption:
```dart
static Future<Event?> getRumorEvent(Nostr nostr, Event e) async {
  // Decrypt gift wrap to get seal
  var sealText = await nostr.nostrSigner.nip44Decrypt(e.pubkey, e.content);
  if (sealText == null) return null;

  var sealEvent = Event.fromJson(jsonDecode(sealText));
  if (!sealEvent.isValid || !sealEvent.isSigned) return null;

  // Decrypt seal to get rumor
  var rumorText = await nostr.nostrSigner.nip44Decrypt(
    sealEvent.pubkey,
    sealEvent.content,
  );
  if (rumorText == null) return null;

  var rumorEvent = Event.fromJson(jsonDecode(rumorText));

  // CRITICAL: Verify sender isn't impersonating
  if (sealEvent.pubkey != rumorEvent.pubkey) {
    Log.warning('Sender impersonation attempt: seal=${sealEvent.pubkey}, rumor=${rumorEvent.pubkey}');
    return null;
  }

  return rumorEvent;
}
```

### 2. NIP17InboxService

**Purpose**: Receive and decrypt incoming gift-wrapped messages.

**Location**: `lib/services/nip17_inbox_service.dart`

**Responsibilities**:
- Subscribe to kind 1059 events with `p` tag matching current user's pubkey
- Decrypt using fixed `GiftWrapUtil.getRumorEvent()`
- Parse message content (text, video references)
- Use RUMOR's `created_at` for ordering (gift wrap timestamps are randomized)
- Emit stream of `IncomingMessage` objects
- Deduplicate by rumor event ID (same message from multiple relays)

**Key methods**:
```dart
Stream<IncomingMessage> get incomingMessages;
Future<void> startListening();
Future<void> stopListening();
Future<List<IncomingMessage>> fetchHistory({DateTime? since});
```

### 3. DMRepository

**Purpose**: Local storage and state management for conversations.

**Location**: `lib/repositories/dm_repository.dart`

**Database tables** (Drift):

```dart
// Conversation metadata
class DmConversations extends Table {
  TextColumn get ownerPubkey => text()();     // Current user's pubkey (multi-account)
  TextColumn get peerPubkey => text()();      // Other party's pubkey
  DateTimeColumn get lastMessageAt => dateTime()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  TextColumn get lastMessagePreview => text().nullable()();
  BoolColumn get isMuted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {ownerPubkey, peerPubkey};
}

// Individual messages
class DmMessages extends Table {
  TextColumn get rumorId => text()();         // Rumor event ID (for dedup/threading)
  TextColumn get giftWrapId => text()();      // Gift wrap event ID (what relays see)
  TextColumn get ownerPubkey => text()();     // Current user's pubkey
  TextColumn get peerPubkey => text()();      // Conversation partner
  TextColumn get senderPubkey => text()();    // Who sent it (owner or peer)
  TextColumn get content => text()();         // Decrypted content
  DateTimeColumn get createdAt => dateTime()(); // RUMOR's created_at (not gift wrap's!)
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  TextColumn get messageType => text().withDefault(const Constant('text'))();
  TextColumn get metadata => text().nullable()(); // JSON for video refs, etc.
  BoolColumn get isOutgoing => boolean()();   // Sent vs received

  @override
  Set<Column> get primaryKey => {rumorId, ownerPubkey};

  @override
  List<Index> get indexes => [
    Index('idx_dm_peer_time', 'CREATE INDEX idx_dm_peer_time ON dm_messages (owner_pubkey, peer_pubkey, created_at DESC)'),
  ];
}
```

**Deduplication**: Use `rumorId` as primary identifier. Same message from multiple relays has same rumor ID.

**Key methods**:
```dart
Stream<List<Conversation>> watchConversations();
Stream<List<DmMessage>> watchMessages(String peerPubkey);
Future<void> saveMessage(IncomingMessage message);  // Idempotent by rumorId
Future<void> markConversationRead(String peerPubkey);
Future<int> getUnreadCount();
```

### 4. DMProvider (Riverpod)

**Location**: `lib/providers/dm_provider.dart`

```dart
// Total unread count for badge
final unreadDmCountProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(dmRepositoryProvider);
  return repo.watchUnreadCount();
});

// List of conversations
final conversationsProvider = StreamProvider<List<Conversation>>((ref) {
  final repo = ref.watch(dmRepositoryProvider);
  return repo.watchConversations();
});

// Messages for a specific conversation
final conversationMessagesProvider = StreamProvider.family<List<DmMessage>, String>((ref, peerPubkey) {
  final repo = ref.watch(dmRepositoryProvider);
  return repo.watchMessages(peerPubkey);
});
```

### 5. UI Screens

#### InboxScreen
**Location**: `lib/screens/inbox_screen.dart`

- List of conversations sorted by last message time
- Each row shows: avatar, display name, message preview, timestamp, unread badge
- Tap to open ConversationScreen
- Pull-to-refresh
- Empty state when no conversations

#### ConversationScreen
**Location**: `lib/screens/conversation_screen.dart`

- Message thread with single user
- Minimal feed style (like video comments)
- Text messages displayed inline
- Shared videos displayed as tappable thumbnails
- Text input at bottom for composing
- Send button uses existing `NIP17MessageService`
- Mark as read when opened

### 6. Entry Points

1. **Drawer menu** (PRIMARY) - "Messages" item with unread badge
2. **Profile screen** - "Message" button for other users (not on own profile)
3. **Send video flow** - Opens conversation after send (already exists)

**NOT adding to Notifications tabs** - DMs are conversations, not notifications. Semantically different.

## Message Types

```dart
enum DmMessageType { text, videoShare }
```

### Text Message
Plain text content.

### Video Share Message
Detected by presence of:
- `a` tag referencing kind 34236 (addressable video event)
- OR `e` tag with video event ID

```dart
class VideoShareMessage {
  final String? caption;           // Optional text
  final String? videoATag;         // a tag: "34236:<pubkey>:<d-tag>"
  final String? videoEventId;      // e tag reference
}
```

## Relay Strategy

**Sending**:
1. Check recipient's kind 10050 for preferred relays
2. If found: send to their relays + our relays
3. If NOT found: Still attempt on shared relays (deviation from strict NIP-17 for better UX)
   - Note: Strict NIP-17 says don't send without 10050, but many users won't have it set

**Receiving**:
- Subscribe to kind 1059 with our pubkey in `p` tag on normal relays
- No special inbox relay setup required by default

**Decision**: We deviate slightly from strict NIP-17 by attempting delivery without kind 10050. This prioritizes UX (messages work) over strict spec compliance. Can revisit if it causes issues.

## Read/Unread Tracking

- All local (no read receipts sent to sender)
- Messages marked read when conversation is opened
- Unread count shown as badge on drawer item
- Badge on individual conversation rows

## Error Handling

- **Decryption fails**: Log warning, skip message silently
- **Malformed message**: Log, skip
- **Sender verification fails**: Log impersonation attempt, reject message
- **Network issues**: Retry subscription with backoff

## Implementation Order

1. **GiftWrapUtil security fix** - Add sender verification
2. **Database schema** - Add Drift tables (migration v4 or next)
3. **NIP17InboxService** - Receive and decrypt with deduplication
4. **DMRepository** - Local storage and queries
5. **Providers** - Riverpod providers for UI reactivity
6. **ConversationScreen** - Message thread UI (test with existing send flow)
7. **InboxScreen** - Conversation list UI
8. **Entry points** - Drawer item, profile button
9. **Polish** - Empty states, loading states, error handling

Note: Build ConversationScreen before InboxScreen to enable earlier end-to-end testing with existing send video flow.

## Testing Strategy

- Unit tests for decryption + sender verification
- Repository tests with mock database
- Widget tests for conversation UI
- Integration test for send/receive round-trip
- Security test: verify impersonation rejection

## Future Considerations (Not in v1)

- Group DMs (NIP-17 supports this)
- Message reactions
- Read receipts (privacy implications)
- Message deletion
- Media attachments beyond videos
- Push notifications for new DMs
- Kind 10050 configuration in settings
- Offline message queue
