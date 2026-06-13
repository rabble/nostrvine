# Content Moderation Response Process

**For Apple App Store Compliance**

## 24-Hour Response Commitment

Divine commits to reviewing and acting on reports of objectionable content **within 24 hours** of submission.

For reports of illegal content (especially CSAM), our response is **immediate**.

## Content Reporting System

### How Users Report Content

1. Users tap the "Report" button on any video
2. Select violation type:
   - Spam or Unwanted Content
   - Harassment, Bullying, or Threats
   - Violent or Extremist Content
   - Sexual or Adult Content
   - Copyright Violation
   - False Information
   - Child Safety Violation (CSAM)
   - AI-Generated Content
   - Other Policy Violation
3. Optional: Add additional details
4. Report is submitted as NIP-56 event (kind 1984) to Nostr relays

### Technical Implementation

**Report Events**: All reports are Nostr events (kind 1984) published to our relay infrastructure at `wss://relay3.openvine.co` and other subscribed relays.

**Services**:
- `ContentReportingService` - Handles report submission (lib/services/content_reporting_service.dart)
- `ReportAggregationService` - Tracks and aggregates reports (lib/services/report_aggregation_service.dart)
- `ContentPolicyEngine` - Enforces filtering decisions via ordered rules (mobile/packages/content_policy), fed by `ContentPolicyState` from `ContentBlocklistRepository` (mobile/packages/content_blocklist_repository)

## Moderation Team Monitoring

### Real-Time Report Monitoring

The moderation team monitors reports through:

1. **Relay Subscriptions**: Subscribe to kind 1984 events on relay3.openvine.co
2. **Report Dashboard**: Custom Nostr client for viewing all incoming reports
3. **Alert System**: High-priority reports (CSAM, threats) trigger immediate alerts

### Report Queue

Reports are triaged by severity:

| Priority | Type | Response Time |
|----------|------|---------------|
| **CRITICAL** | CSAM, Threats | Immediate (< 1 hour) |
| **HIGH** | Violence, Harassment | < 6 hours |
| **MEDIUM** | Spam, Copyright | < 12 hours |
| **LOW** | Other violations | < 24 hours |

## Moderation Actions

### Content Removal

When objectionable content is confirmed:

1. **Relay Deletion**: Content event is deleted from relay3.openvine.co via NIP-09 deletion event
2. **Media Removal**: Video/thumbnail files removed from media.divine.video CDN
3. **Client-Side Filtering**: Content added to global filter list (NIP-51 mute list)
4. **Network Propagation**: Deletion events propagated to other relays

**Technical**:
- Deletion events (kind 5) reference the original event ID
- CDN purge requests sent to BunnyCDN and Cloudflare
- Global filter list updated in embedded relay database

### User Account Actions

| Violation | First Offense | Second Offense | Third Offense |
|-----------|--------------|----------------|---------------|
| Spam | Warning | 7-day suspension | Permanent ban |
| Harassment | 7-day suspension | 30-day suspension | Permanent ban |
| Violence/CSAM | **Permanent ban** | N/A | N/A |

**Account Banning Implementation**:
1. User's npub added to global blocklist
2. All existing content from user removed
3. Future content from user auto-filtered
4. Ban recorded in moderation database

### Law Enforcement Reporting

For illegal content (CSAM, credible threats):

1. **Immediate Removal**: Content removed from our infrastructure
2. **NCMEC Report**: CSAM reports filed with National Center for Missing & Exploited Children via CyberTipline
3. **Law Enforcement**: Local law enforcement notified for credible threats
4. **Evidence Preservation**: Content hashes and metadata preserved for investigation

## Automated Content Filtering

### CSAM Detection (Automated)

**PhotoDNA Hash Matching**:
- BunnyCDN Shield automatically blocks known CSAM via PhotoDNA hashes
- Cloudflare CSAM scanning on upload
- Matching content is immediately blocked and reported

**Response Time**: Immediate (< 1 minute from upload)

### Adult Content Detection (Automated)

**AI Content Analysis**:
- Videos scanned for nudity/adult content using Cloudflare AI Workers
- Detected content auto-flagged as NSFW
- Age-gating applied automatically

**Response Time**: < 5 minutes from upload

## User-Controlled Moderation

Divine implements a **stackable moderation system** giving users control:

### Layer 1: Built-in Safety (Always Active)
- CSAM detection via PhotoDNA
- Illegal content filters
- Apple App Store compliance filters

### Layer 2: Personal Filters (User Controlled)
- Personal mute lists (NIP-51)
- Block abusive users
- Keyword filters

### Layer 3: Subscribed Moderators (User Choice)
- Subscribe to trusted community moderators
- Community-curated mute lists
- Up to 20 subscriptions

### Layer 4: Community Signals (Optional)
- Friend report aggregation
- Threshold-based filtering (e.g., "blur if 3+ friends report")

**Technical Details**: See `MODERATION_SYSTEM_ARCHITECTURE.md`

## Decentralization Considerations

### What We Control

Divine directly moderates content on:
- `relay3.openvine.co` (our primary relay)
- `media.divine.video` (our CDN)
- The Divine mobile app (client-side filtering)

### What We Don't Control

Due to Nostr's decentralized nature:
- Content on **other relays** is moderated by their operators
- Content posted via **other Nostr clients** may have different policies
- **Once distributed**, content may persist on other relays even after deletion

### Our Responsibility

We are responsible **only for content hosted on our infrastructure**. We enforce strict moderation on:
- Events accepted by relay3.openvine.co
- Media served via media.divine.video
- Content displayed in the Divine app

Other Nostr infrastructure operators are responsible for their own moderation.

## Transparency and Appeals

### Moderation Transparency

Users can view:
- Their own report history (Safety Settings > Report History)
- Why content was filtered (tap "Why is this hidden?")
- Which moderators they're subscribed to

### Appeals Process

Users can appeal moderation decisions:

1. **Contact Support**: support@divine.video
2. **Provide Context**: Explain why content doesn't violate policies
3. **Review**: Moderation team reviews within 48 hours
4. **Decision**: Appeal granted (content restored) or denied (with explanation)

**Note**: Appeals for CSAM, credible threats, or clearly illegal content are automatically denied.

## Moderation Team

### Team Structure

- **Safety Team Lead**: Oversees all moderation operations
- **Content Moderators** (3-5): Review reports, make decisions
- **Technical Lead**: Manages moderation tools and automation
- **On-Call Rotation**: 24/7 coverage for critical reports

### Team Training

All moderators receive training on:
- Recognizing CSAM and illegal content
- Apple App Store content policies
- Nostr protocol and decentralization implications
- Mental health support (dealing with traumatic content)

### Support Resources

Moderators have access to:
- Mental health counseling
- Rotating schedules (no single moderator reviews only CSAM)
- Automated tools to reduce exposure to traumatic content

## Metrics and Reporting

### Internal Metrics

We track:
- **Report Volume**: Number of reports received per day/week
- **Response Time**: Time from report to action (target: < 24 hours average)
- **Action Distribution**: % of reports resulting in each action type
- **False Positive Rate**: Reports that didn't violate policies

### Public Transparency Report

Published quarterly at divine.video/transparency:
- Total reports received
- Content removed by category
- Accounts banned
- Average response time
- Appeals granted/denied

## Contact Information

**For Apple App Review**:
- **Email**: support@divine.video
- **Emergency CSAM Reports**: security@divine.video (immediate response)
- **Relay**: wss://relay3.openvine.co (for monitoring reports via Nostr)

**For Law Enforcement**:
- **Email**: legal@divine.video
- **CSAM Reports**: Filed via NCMEC CyberTipline
- **Evidence Requests**: Respond within 24 hours

---

**Last Updated**: November 6, 2025
**Review Submission**: Version 1.0
**Submission ID**: 5fcafd59-7758-494d-bcab-9bcd54ec0b24
