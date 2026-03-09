# Divine Moderation System Architecture

## Overview

Divine implements a **stackable, user-controlled moderation system** inspired by Bluesky's labeler architecture, using Nostr's NIP-32 (labeling) and NIP-56 (reporting) specifications.

## Design Principles

1. **User Sovereignty** - Users control their moderation stack
2. **Composability** - Multiple moderation sources stack together
3. **Transparency** - Clear visibility into why content is filtered
4. **Decentralization** - No single authority controls moderation
5. **Client-Side Enforcement** - Clients decide how to apply labels

## Architecture Layers

```
┌─────────────────────────────────────────────────────────┐
│           Divine Moderation Stack (Stackable)         │
├─────────────────────────────────────────────────────────┤
│  Layer 1: Built-in Safety (Default, Always Active)     │
│           - CSAM detection                               │
│           - Illegal content filters                      │
│           - Apple App Store compliance                   │
├─────────────────────────────────────────────────────────┤
│  Layer 2: User's Personal Filters (Always Active)       │
│           - NIP-51 Mute Lists (kind 10000) ✅           │
│           - Personal blocks/mutes                        │
│           - Keyword filters                              │
├─────────────────────────────────────────────────────────┤
│  Layer 3: Subscribed Moderator Feeds (User Choice)      │
│           - Trusted labelers (kind 1985) 🔨             │
│           - Curator mute lists (kind 10000) ✅          │
│           - Up to 20 subscriptions                       │
├─────────────────────────────────────────────────────────┤
│  Layer 4: Community Signals (Optional)                  │
│           - Friend reports aggregation (kind 1984) 🔨   │
│           - Threshold-based filtering                    │
│           - Reputation signals                           │
└─────────────────────────────────────────────────────────┘

Legend: ✅ Implemented | 🔨 To Implement
```

## Event Types

### Kind 1984 - Reporting (NIP-56)

**Purpose:** Users report objectionable content to signal violations

**Structure:**
```json
{
  "kind": 1984,
  "content": "Report description",
  "tags": [
    ["p", "<reported_pubkey>"],  // Required
    ["e", "<reported_event_id>"], // For note reports
    ["report", "spam"],           // Report type
    ["client", "openvine"]
  ]
}
```

**Report Types:**
- `nudity` - Pornographic content
- `malware` - Malicious software
- `profanity` - Hateful speech
- `illegal` - Potentially unlawful
- `spam` - Unwanted promotional content
- `impersonation` - Pretending to be another user
- `other` - Miscellaneous violations

**Use Cases:**
- User reports individual pieces of content
- Aggregated for community moderation
- "If 3+ friends report, auto-blur"

### Kind 1985 - Labeling (NIP-32)

**Purpose:** Apply flexible labels to content for moderation and classification

**Structure:**
```json
{
  "kind": 1985,
  "content": "",
  "tags": [
    ["L", "com.openvine.moderation"],      // Namespace
    ["l", "nsfw", "com.openvine.moderation"], // Label
    ["e", "<event_id>", "<relay_hint>"],   // What's labeled
    ["p", "<pubkey>"]                       // Optional: author
  ]
}
```

**Label Namespaces:**

| Namespace | Purpose | Labels |
|-----------|---------|--------|
| `com.openvine.moderation` | Safety/content warnings | `nsfw`, `violence`, `spam`, `csam` |
| `com.openvine.quality` | Content quality | `high-quality`, `low-quality`, `misleading` |
| `social.nos.moderation` | Interop with NOS | Shared moderation labels |
| `ugc` | User-generated classification | Community tags |

**Use Cases:**
- Moderators apply warning labels
- Content classification
- Recommendations ("high-quality")
- Distributed curation

## Services Architecture

### 1. ModerationLabelService

**Responsibility:** Subscribe to and process kind 1985 label events

```dart
class ModerationLabelService {
  // Subscribe to labels from specific moderators
  Future<void> subscribeToLabeler(String moderatorPubkey);

  // Get all labels for an event
  List<ModerationLabel> getLabelsForEvent(String eventId);

  // Get all labels for a pubkey
  List<ModerationLabel> getLabelsForPubkey(String pubkey);

  // Check if event has specific label
  bool hasLabel(String eventId, String namespace, String label);

  // Get label statistics
  Map<String, int> getLabelCounts(String eventId);
}
```

**Label Storage:**
```dart
class ModerationLabel {
  final String labelId;         // Event ID of kind 1985
  final String namespace;       // L tag
  final String label;           // l tag
  final String? targetEventId;  // e tag
  final String? targetPubkey;   // p tag
  final String moderatorPubkey; // Who applied label
  final DateTime createdAt;
  final String? reason;         // Optional context
}
```

### 2. ReportAggregationService

**Responsibility:** Track and aggregate kind 1984 report events

```dart
class ReportAggregationService {
  // Subscribe to reports from trusted network
  Future<void> subscribeToNetworkReports(List<String> trustedPubkeys);

  // Get report aggregation for content
  ReportAggregation getReportsForEvent(String eventId);

  // Get reports for user
  ReportAggregation getReportsForPubkey(String pubkey);

  // Check if content exceeds report threshold
  bool exceedsReportThreshold(String eventId, int threshold);

  // Get reporting statistics
  Map<String, dynamic> getReportStats();
}
```

**Report Aggregation:**
```dart
class ReportAggregation {
  final String targetId;         // Event or pubkey
  final int totalReports;
  final Map<String, int> reasonCounts; // spam: 5, nudity: 2
  final List<String> reporterPubkeys;
  final int trustedReporterCount; // From your network
  final DateTime lastReportedAt;
  final ModerationRecommendation recommendation;
}

enum ModerationRecommendation {
  allow,      // No action needed
  warn,       // Show content warning
  blur,       // Blur by default
  hide,       // Hide completely
}
```

### 3. ModeratorRegistryService

**Responsibility:** Manage subscribed moderators/labelers

```dart
class ModeratorRegistryService {
  // Subscribe to a moderator feed
  Future<void> subscribeModerator(ModeratorProfile moderator);

  // Unsubscribe from moderator
  Future<void> unsubscribeModerator(String moderatorPubkey);

  // Get all subscribed moderators
  List<ModeratorProfile> getSubscribedModerators();

  // Check if moderator is trusted
  bool isTrustedModerator(String pubkey);

  // Get moderator statistics
  ModeratorStats getModeratorStats(String pubkey);
}
```

**Moderator Profile:**
```dart
class ModeratorProfile {
  final String pubkey;
  final String displayName;
  final String? description;
  final String? website;
  final List<String> specialties; // ['nsfw', 'spam', 'misinformation']
  final ModerationPolicy policy;
  final DateTime subscribedAt;
  final int? labelCount; // Labels applied
  final double? accuracy; // If we track feedback
}

class ModerationPolicy {
  final String policyUrl; // Link to public policy
  final List<String> coveredNamespaces;
  final String language; // 'en', 'es', etc
  final bool isOpen; // Accept applications
}
```

### 4. ModerationFeedService

**Responsibility:** Unified coordinator for all moderation sources

```dart
class ModerationFeedService {
  final ModerationLabelService _labelService;
  final ReportAggregationService _reportService;
  final ModeratorRegistryService _registryService;
  final ContentModerationService _muteService; // Existing

  // Check content against ALL moderation sources
  Future<ModerationDecision> checkContent(Event event);

  // Get detailed moderation breakdown
  ModerationBreakdown getBreakdown(String eventId);

  // Update user's moderation preferences
  Future<void> updatePreferences(ModerationPreferences prefs);
}
```

**Unified Decision:**
```dart
class ModerationDecision {
  final bool shouldFilter;
  final ModerationAction action; // allow, warn, blur, hide, block
  final List<ModerationSource> sources; // Why was this decision made?
  final ContentSeverity severity;
  final String? warningMessage;
}

class ModerationSource {
  final ModerationSourceType type;
  final String id; // Moderator pubkey or list ID
  final String reason;
  final DateTime timestamp;
}

enum ModerationSourceType {
  builtInSafety,    // Layer 1
  personalMuteList, // Layer 2
  subscribedLabeler, // Layer 3
  communityReports,  // Layer 4
}

enum ModerationAction {
  allow,   // Show normally
  warn,    // Show with warning badge
  blur,    // Blur thumbnail/preview
  hide,    // Collapse, click to reveal
  block,   // Don't show at all
}
```

### 5. Updated ContentModerationService

**Integration with feed system:**

```dart
class ContentModerationService {
  final ModerationFeedService _feedService;

  // Existing methods stay the same
  // Add delegation to feed service:

  @override
  ModerationResult checkContent(Event event) {
    // Check local mute lists (fast path)
    final localResult = _checkLocalMutes(event);
    if (localResult.shouldFilter) return localResult;

    // Delegate to feed service for comprehensive check
    final feedDecision = await _feedService.checkContent(event);
    return _convertToModerationResult(feedDecision);
  }
}
```

## User Experience Flows

### Flow 1: User Subscribes to Moderator

```
User Profile → Moderation Settings → Browse Moderators
  ↓
Select Moderator Feed (e.g., "TechHub NSFW Filter")
  ↓
View Policy & Stats → Subscribe
  ↓
Feed Service subscribes to moderator's kind 1985 events
  ↓
Labels automatically applied to content in real-time
```

### Flow 2: Content Filtering Decision

```
User opens feed → VideoFeedItem loads
  ↓
ModerationFeedService.checkContent(event)
  ↓
Check Layer 1: Built-in Safety ❌ Pass
  ↓
Check Layer 2: User Mute Lists ❌ Pass
  ↓
Check Layer 3: Subscribed Labelers
  ↓ (Found: "nsfw" label from 2 trusted moderators)
Apply: BLUR action + content warning
  ↓
Check Layer 4: Community Reports
  ↓ (Found: 5 reports, 2 from friends)
Confirm: BLUR action
  ↓
Return ModerationDecision(action: blur, sources: [labeler1, labeler2, reports])
  ↓
UI: Show blurred thumbnail + "Content may be sensitive (NSFW)"
```

### Flow 3: User Reports Content

```
User taps "Report" on video
  ↓
Select reason (spam, harassment, etc)
  ↓
ContentReportingService creates kind 1984 event ✅ (Already implemented)
  ↓
Broadcast to relays
  ↓
ReportAggregationService picks up report
  ↓
If threshold reached → Update moderation decision
  ↓
Content auto-blurred for users who trust this reporter
```

## Data Synchronization

### Label Subscription Pattern

```dart
// Subscribe to a moderator's labels
await _nostrService.subscribeToEvents(
  filters: [
    Filter(
      authors: [moderatorPubkey],
      kinds: [1985], // Label events
      since: DateTime.now().subtract(Duration(days: 30)),
    )
  ],
  onEvent: (Event labelEvent) {
    final label = _parseLabelEvent(labelEvent);
    _labelStore.addLabel(label);
    _notifyListeners(); // Update UI
  },
);
```

### Report Aggregation Pattern

```dart
// Subscribe to reports from trusted network
final trustedPubkeys = [...]; // User's follows
await _nostrService.subscribeToEvents(
  filters: [
    Filter(
      authors: trustedPubkeys,
      kinds: [1984], // Report events
      since: DateTime.now().subtract(Duration(hours: 24)),
    )
  ],
  onEvent: (Event reportEvent) {
    _aggregateReport(reportEvent);
    _updateThresholds();
  },
);
```

## Configuration & Settings

### User Preferences

```dart
class ModerationPreferences {
  // Layer 1: Built-in (always active)
  final bool enableBuiltInSafety = true;

  // Layer 2: Personal
  final bool enablePersonalMutes = true;

  // Layer 3: Subscribed Moderators
  final bool enableSubscribedLabelers = true;
  final int maxSubscribedModerators = 20; // Bluesky limit

  // Layer 4: Community Signals
  final bool enableCommunityReports = true;
  final int reportThreshold = 3; // Auto-blur if 3+ friends report
  final bool onlyTrustedReports = true; // Only count follows

  // Action preferences
  final Map<String, ModerationAction> labelActions = {
    'nsfw': ModerationAction.blur,
    'violence': ModerationAction.hide,
    'spam': ModerationAction.hide,
    'csam': ModerationAction.block,
  };
}
```

### Default Moderators

```dart
// Divine provides curated default moderators
final defaultModerators = [
  ModeratorProfile(
    pubkey: 'openvine_safety_team_pubkey',
    displayName: 'Divine Safety',
    description: 'Official Divine content safety team',
    specialties: ['csam', 'illegal', 'malware'],
    policy: ModerationPolicy(
      policyUrl: 'https://openvine.com/moderation-policy',
      coveredNamespaces: ['com.openvine.moderation'],
      language: 'en',
      isOpen: false,
    ),
  ),
];
```

## Interoperability

### Cross-Platform Label Namespaces

To ensure compatibility with other Nostr clients:

```
com.openvine.moderation.*  - Divine-specific
social.nos.moderation.*    - Nos client labels
social.damus.moderation.*  - Damus client labels
org.nostr.moderation.*     - Universal Nostr labels
```

### Label Mapping

```dart
final labelMapping = {
  // Map external labels to internal categories
  'social.nos.moderation.nsfw': ContentFilterReason.sexualContent,
  'social.damus.moderation.spam': ContentFilterReason.spam,
  'org.nostr.moderation.csam': ContentFilterReason.csam,
};
```

## Performance Considerations

### Caching Strategy

```dart
// Label cache (LRU, 10k entries, 1 hour TTL)
final _labelCache = LRUCache<String, List<ModerationLabel>>(
  maxSize: 10000,
  ttl: Duration(hours: 1),
);

// Report aggregation cache (5k entries, 15 min TTL)
final _reportCache = LRUCache<String, ReportAggregation>(
  maxSize: 5000,
  ttl: Duration(minutes: 15),
);
```

### Incremental Loading

- Subscribe to labels for visible content only
- Lazy-load moderation data as user scrolls
- Batch queries for efficiency

### Embedded Relay Storage

Labels and reports should be stored in embedded relay for:
- Offline access
- Fast queries
- Privacy (don't leak browsing patterns)

## Privacy & Security

### Privacy Protections

1. **Label Privacy** - Don't reveal which moderators user subscribes to
2. **Report Privacy** - User reports use their keypair (inherently public)
3. **Local Processing** - Moderation decisions made client-side
4. **No Central Registry** - No central server tracks subscriptions

### Security Considerations

1. **Moderator Impersonation** - Verify moderator identity via NIP-05
2. **Label Spam** - Rate limit label processing
3. **Report Abuse** - Ignore reports from blocked users
4. **Malicious Labels** - User can unsubscribe instantly

## Implementation Phases

### Phase 1: Foundation (Current Sprint)
- ✅ NIP-51 mute list subscription
- 🔨 ModerationLabelService (kind 1985)
- 🔨 ModeratorRegistryService
- 🔨 Basic label parsing and storage

### Phase 2: Core Features
- 🔨 ReportAggregationService (kind 1984)
- 🔨 ModerationFeedService coordinator
- 🔨 Integration with ContentModerationService
- 🔨 Basic UI for subscribing to moderators

### Phase 3: User Experience
- 🔨 Moderator discovery/browse UI
- 🔨 Detailed moderation explanations
- 🔨 User feedback on moderation quality
- 🔨 Custom label actions

### Phase 4: Advanced Features
- 🔨 Moderator reputation system
- 🔨 Label analytics and insights
- 🔨 Cross-client label sync
- 🔨 Community moderator applications

## Success Metrics

1. **Adoption**: % of users who subscribe to ≥1 moderator
2. **Effectiveness**: Reduction in user-reported content
3. **Trust**: User satisfaction with moderation decisions
4. **Performance**: <100ms average moderation decision time
5. **Coverage**: % of content with ≥1 moderation signal

## Future Enhancements

- **Federated Moderator Networks** - Moderators vouch for each other
- **AI-Assisted Labeling** - ML models as labelers
- **Collaborative Lists** - Multiple moderators maintain shared lists
- **Appeal Process** - Users can appeal moderation decisions
- **Label Ontology** - Standardized label taxonomy across ecosystem
