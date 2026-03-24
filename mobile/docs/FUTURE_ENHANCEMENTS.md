Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This file may reference deleted screens, older branding, or superseded implementation details. Start with docs/README.md and docs/archive/README.md for current guidance.

# OpenVine Future Enhancements

## Moderation System

### NIP-59 Gift-Wrapped Reports (Private Reporting)

**Status:** Planned for future implementation

**Purpose:** Make kind 1984 reports private using NIP-59 gift wrap encryption

**Current State:**
- Reports are public kind 1984 events broadcast to all relays
- Anyone can see who reported what
- Reporter identity is public

**Future State:**
- Reports are NIP-59 gift-wrapped (encrypted)
- Only intended moderator can decrypt
- Reporter identity hidden from public
- Metadata (timestamps, tags) obscured

**Benefits:**
- **Privacy** - Reporter identity protected
- **Safety** - Prevents retaliation/harassment against reporters
- **Trust** - Users more likely to report if anonymous
- **Metadata protection** - Time-analysis attacks prevented

**Implementation:**

```dart
// Add to ContentReportingService
class ContentReportingService {
  bool _useGiftWrap = false; // Feature flag

  Future<void> enablePrivateReporting({
    required String moderatorPubkey,
  }) async {
    _useGiftWrap = true;
    _moderatorPubkey = moderatorPubkey;
  }

  Future<Event?> _createReportingEvent(...) async {
    if (_useGiftWrap) {
      // NIP-59: Create rumor (unsigned event)
      final rumor = _createReportRumor(...);

      // Seal with reporter's key
      final seal = await _sealRumor(rumor, _moderatorPubkey);

      // Gift wrap with ephemeral key
      final giftWrap = await _wrapSeal(seal, _moderatorPubkey);

      return giftWrap; // kind 1059
    } else {
      // Current: Public kind 1984
      return _createPublicReport(...);
    }
  }
}
```

**NIP-59 Layers:**
1. **Rumor** - Unsigned kind 1984 event (the report)
2. **Seal** (kind 13) - Encrypted with reporter's key
3. **Gift Wrap** (kind 1059) - Encrypted with ephemeral key

**Dependencies:**
- NIP-44 encryption support in nostr_sdk
- Ephemeral key generation
- Inbox relay support (NIP-17)

**References:**
- [NIP-59: Gift Wrap](https://github.com/nostr-protocol/nips/blob/master/59.md)
- [NIP-44: Encryption](https://github.com/nostr-protocol/nips/blob/master/44.md)
- [NIP-17: Private DMs](https://github.com/nostr-protocol/nips/blob/master/17.md)

**Configuration:**

```dart
// Settings screen
class ModerationSettings {
  final bool usePrivateReporting;
  final String? preferredModeratorPubkey;

  // If enabled, all reports are gift-wrapped
  // If disabled, reports are public (current behavior)
}
```

**User Experience:**

Settings screen toggle:
```
[ ] Private Reports
    Reports will be encrypted and only visible to moderators.
    Your identity will be protected.

    ⚠️  Requires moderator support for NIP-59
```

**Moderator Support:**

Faro would need to support receiving gift-wrapped reports:
- Subscribe to kind 1059 events on inbox relay
- Decrypt gift wrap using moderator's private key
- Extract and decrypt seal
- Process the rumor (actual report)

**Timeline:**
- Phase 1: Implement basic gift wrap support in nostr_sdk
- Phase 2: Add gift wrap option to ContentReportingService
- Phase 3: Update Faro to receive gift-wrapped reports
- Phase 4: Make private reporting default

**Testing:**
- Unit tests for gift wrap encryption/decryption
- Integration test: Send gift-wrapped report to test moderator
- Verify public relays cannot decrypt
- Verify moderator receives and decrypts correctly

---

## Other Future Enhancements

### Faro Routing (Directed Reports)

**Status:** Deferred - currently using public reporting

Add `P` tag to route reports to specific Faro moderators:

```dart
tags.add(['P', faroModeratorPubkey]);
```

Benefits:
- Direct reports to your app's moderation team
- Faster response time
- User choice of moderation provider

### Multi-Instance Faro Support

Allow users to choose between multiple Faro moderators:
- OpenVine official
- Community-run instances
- Niche moderators (tech, art, news)

### Moderator Reputation System

Track moderator statistics:
- Labels published
- False positive rate (user feedback)
- Response time
- Specialization areas
- User trust scores

### AI-Assisted Labeling

Use ML models as additional labelers:
- CSAM detection (PhotoDNA, etc)
- NSFW classification
- Spam detection
- Language detection

ML models publish labels just like human moderators.

### Collaborative Moderation

Multiple moderators maintain shared lists:
- Federated blocklists
- Collaborative review workflows
- Moderator vouching networks

### Appeal Process

Allow users to appeal moderation decisions:
- Submit appeal as kind 1985 counter-label
- Second moderator reviews
- Transparent appeal status

### Label Analytics

Dashboard showing:
- Most common labels on your content
- Moderators who labeled you
- Appeal success rate
- Label distribution over time

### Cross-Client Label Sync

Standardize label namespaces across Nostr ecosystem:
- `org.nostr.moderation.*` - Universal labels
- Mapping between client-specific namespaces
- Label translation/compatibility

### Advanced Filtering

More sophisticated filtering rules:
- Boolean logic (nsfw AND violence)
- Confidence thresholds
- Time-based rules (recent vs old labels)
- Context-aware filtering (hide in public, allow in DMs)
