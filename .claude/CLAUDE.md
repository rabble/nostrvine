# divine-mobile - AI Assistant Guidelines

You are an AI coding assistant working on **divine-mobile**, a decentralized vine-like video sharing application powered by Nostr.

## Core Principles

- **Quality First** - Write tests before implementation
- **Consistency** - Follow established patterns across the codebase
- **Simplicity** - Choose the simplest solution that works
- **Maintainability** - Write code that's easy to change

---

# Standards Reference

All generic Flutter/Dart standards are organized in `.claude/rules/`:

| Topic | File | Key Content |
|-------|------|-------------|
| Architecture | `rules/architecture.md` | Layered architecture (UI→BLOC→REPOSITORY→CLIENT), barrel files |
| State Management | `rules/state_management.md` | BLoC (new features) + Riverpod (legacy), event transformers |
| Code Style | `rules/code_style.md` | Naming, widgets over methods, Dart best practices |
| Testing | `rules/testing.md` | Test organization, isolation, golden files, BLoC testing |
| Routing | `rules/routing.md` | GoRouter patterns, type-safe routes, redirects |
| UI/Theming | `rules/ui_theming.md` | ThemeData, typography, spacing, accessibility |
| Error Handling | `rules/error_handling.md` | Exceptions, documentation, security basics |

---

# Tool Preferences

## Dart MCP Server
**ALWAYS** use the **Dart MCP Server** (`mcp__dart__*`) for all Flutter/Dart operations:
- Running tests (`mcp__dart__run_tests`)
- Analyzing code (`mcp__dart__analyze_files`)
- Formatting code (`mcp__dart__dart_format`)
- Running pub commands (`mcp__dart__pub`)
- Launching/debugging apps (`mcp__dart__launch_app`, `mcp__dart__hot_reload`)
- Searching pub.dev (`mcp__dart__pub_dev_search`)

**Fallback**: Use shell commands (`flutter test`, `dart analyze`, etc.) only if MCP unavailable.

## Nostr MCP Server
**ALWAYS** use the **Nostr MCP Server** (`mcp__nostr__*`) for all Nostr-related lookups:
- Reading NIPs (`mcp__nostr__read_nip`)
- Looking up event kinds (`mcp__nostr__read_kind`)
- Looking up tags (`mcp__nostr__read_tag`)
- Reading protocol basics (`mcp__nostr__read_protocol`)
- Browsing NIPs index (`mcp__nostr__read_nips_index`)

**Fallback**: `https://nostrbook.dev/llms.txt` (only if MCP unavailable)

---

# Project-Specific Rules

## CRITICAL - Nostr ID Rule

**YOU MUST NEVER TRUNCATE NOSTR IDS.** This applies EVERYWHERE:

- ❌ FORBIDDEN: `eventId.substring(0, 8)`, `pubkey.substring(0, 8)`, `id.take(8)`, etc.
- ❌ FORBIDDEN in logging: `Log.info('Video: ${video.id.substring(0, 8)}')`
- ❌ FORBIDDEN in production code: displaying shortened IDs in UI
- ❌ FORBIDDEN in debug output: console logs, error messages, analytics
- ❌ FORBIDDEN in tests: test descriptions, assertions, mock data
- ✅ REQUIRED: ALWAYS use full Nostr IDs (64-character hex event IDs, npub/nsec formats)
- ✅ If display space is limited, use UI truncation (ellipsis in middle) NOT string manipulation

**Rationale**: Truncated IDs are useless for debugging, searching logs, and correlating events across systems.

---

## UI/UX Requirements

**CRITICAL**: divine-mobile is a **DARK MODE ONLY** application.

### VineTheme Color Usage

**RULE**: Always use `VineTheme` color constants instead of raw `Colors.*` values.

| Instead of | Use |
|------------|-----|
| `Colors.white` | `VineTheme.whiteText` or `VineTheme.primaryText` |
| `Colors.black` | `VineTheme.backgroundColor` |
| `Colors.grey` | `VineTheme.secondaryText` or `VineTheme.lightText` |
| `Colors.white.withOpacity(0.7)` | `VineTheme.onSurfaceVariant` (75% white) |
| `Colors.white.withOpacity(0.5)` | `VineTheme.onSurfaceMuted` (50% white) |

**Exception**: `Colors.transparent` is acceptable (universal constant like `EdgeInsets.zero`).

### Theme Colors

- **Background**: `VineTheme.backgroundColor`
- **Text**: `VineTheme.whiteText`, `VineTheme.primaryText`, `VineTheme.secondaryText`
- **Accent**: `VineTheme.vineGreen` for primary accents
- **Cards**: `VineTheme.cardBackground` for elevated surfaces
- **Icons**: `VineTheme.iconButtonBackground` for button containers
- **NO LIGHT MODE**: Do not implement light mode themes, auto-switching, or light color schemes

**Rationale**: The dark mode aesthetic is core to the app's visual identity.

---

## Nostr Event Requirements

divine-mobile requires specific Nostr event types:
- **Kind 0**: User profiles (NIP-01) - display names and avatars
- **Kind 3**: Contact lists (NIP-02) - follow/following relationships
- **Kind 6**: Reposts (NIP-18) - video repost/reshare functionality
- **Kind 7**: Reactions (NIP-25) - like/heart interactions
- **Kind 34236**: Addressable short looping videos (NIP-71) - primary video content

See `mobile/docs/NOSTR_EVENT_TYPES.md` for complete documentation.

---

## Project Architecture

### Technology Stack
- **Frontend**: Flutter (Dart) with Camera plugin
- **Backend**: Cloudflare Workers + R2 Storage
- **Protocol**: Nostr (decentralized social network)
- **Media Processing**: Real-time frame capture → GIF creation

### Upload Architecture
```
Flutter App → Blossom Server → Nostr Event
```

Benefits:
- User-configurable Blossom media servers
- Fully decentralized media hosting
- No centralized backend dependencies

### Share URL Formats
- Profile URLs: `https://divine.video/profile/{npub}`
- Video URLs: `https://divine.video/video/{videoId}`

---

## Video Feed Architecture

divine-mobile uses a **Riverpod-based reactive architecture** for managing video feeds.

### Core Components

**VideoEventService** (`lib/services/video_event_service.dart`):
- Manages Nostr video event subscriptions by type
- Maintains separate event lists per `SubscriptionType`
- Provides type-safe getters: `homeFeedVideos`, `discoveryVideos`, `getVideos(subscriptionType)`
- Handles pagination, deduplication, and real-time streaming

**Feed Providers**:

| Provider | File | Purpose |
|----------|------|---------|
| `videoEventsProvider` | `lib/providers/video_events_providers.dart` | Discovery/explore feed (all public videos) |
| `homeFeedProvider` | `lib/providers/home_feed_provider.dart` | Personalized feed (followed users only) |

### Feed Types

- **Home Feed**: Videos from followed users, auto-refreshes every 10 minutes
- **Discovery/Explore**: All public videos, Popular Now and Trending tabs
- **Hashtag Feeds**: Videos filtered by specific hashtag
- **Profile Feeds**: Videos from a specific user

---

## Pre-Commit Workflow (MANDATORY)

This project uses code generation (Riverpod, Freezed, JSON serializable, Mockito).

**ALWAYS** run these steps before committing:

1. **Regenerate code** (if modified `@riverpod`, `@freezed`, `@JsonSerializable`, or `@GenerateMocks`):
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

2. **Format code**:
   ```bash
   dart format --output=none --set-exit-if-changed lib test
   ```

3. **Analyze code**:
   ```bash
   flutter analyze
   ```

4. **Stage specific files** (NEVER use `git add -A` or `git add .`):
   ```bash
   git add lib/path/to/file.dart lib/path/to/file.g.dart
   ```

**Why build_runner is critical**: Riverpod providers generate `.g.dart` files. If you don't regenerate, CI will fail with "Generated files are out of date".

---

## API Documentation

- **Backend Reference**: `docs/BACKEND_API_REFERENCE.md`
- **Nostr Events**: `mobile/docs/NOSTR_EVENT_TYPES.md`

---

# Communication Style

## Be Constructive
- Focus on improvement, not criticism
- Explain the "why" behind recommendations
- Provide specific, actionable feedback
- Recognize good practices

## Be Educational
- Teach patterns and principles
- Explain trade-offs
- Share best practices
- Link to documentation when helpful

## Be Practical
- Prioritize actionable advice
- Consider team context
- Balance ideal vs pragmatic
- Respect existing codebase patterns

## Be Concise
- Get to the point quickly
- Use clear, simple language
- Avoid unnecessary jargon
- Format for scannability

---

# Quality Checklist

Before considering any task complete:

- [ ] Code follows VGE patterns (see `rules/architecture.md`)
- [ ] New code is 100% tested (see `rules/testing.md`)
- [ ] Lint rules pass (`very_good_analysis`)
- [ ] Uses VineTheme colors (no raw `Colors.*`)
- [ ] Full Nostr IDs (never truncated)
- [ ] Pre-commit workflow completed
